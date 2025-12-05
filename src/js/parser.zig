const std = @import("std");
const token = @import("token.zig");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

const expressions = @import("syntax/expressions.zig");
const literals = @import("syntax/literals.zig");
const patterns = @import("syntax/patterns.zig");
const variables = @import("syntax/variables.zig");
const functions = @import("syntax/functions.zig");

pub const Severity = enum {
    @"error",
    warning,
    hint,
    info,

    pub fn toString(self: Severity) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
            .hint => "hint",
            .info => "info",
        };
    }
};

pub const Label = struct {
    span: ast.Span,
    message: []const u8,
};

pub const Diagnostic = struct {
    severity: Severity = .@"error",
    message: []const u8,
    span: ast.Span,
    help: ?[]const u8 = null,
    labels: []const Label = &.{},
};

pub const SourceType = enum { Script, Module };
pub const Lang = enum { Js, Ts, Jsx, Tsx, Dts };

pub const Options = struct {
    source_type: SourceType = .Module,
    lang: Lang = .Js,
    is_strict: bool = true,
};

/// Must be deinitialized to free the arena-allocated memory.
pub const ParseTree = struct {
    /// Root node of the AST (always a Program node)
    program: ast.NodeIndex,
    /// Source code that was parsed
    source: []const u8,
    /// All nodes in the AST
    nodes: std.MultiArrayList(ast.Node),
    /// Extra data storage for variadic node children
    extra: std.ArrayList(ast.NodeIndex),
    /// Diagnostics (errors, warnings, etc.) encountered during parsing
    diagnostics: std.ArrayList(Diagnostic),
    /// Arena allocator owning all the memory
    arena: std.heap.ArenaAllocator,

    pub inline fn hasErrors(self: ParseTree) bool {
        for (self.diagnostics.items) |d| {
            if (d.severity == .@"error") return true;
        }
        return false;
    }

    pub inline fn hasDiagnostics(self: ParseTree) bool {
        return self.diagnostics.items.len > 0;
    }

    pub fn deinit(self: *const ParseTree) void {
        self.arena.deinit();
    }
};

const ParserContext = struct {
    in_async: bool,
    in_generator: bool,
    allow_in: bool,
};

pub const Error = error{OutOfMemory};

pub const Parser = struct {
    source: []const u8,
    lexer: lexer.Lexer,
    arena: std.heap.ArenaAllocator,
    diagnostics: std.ArrayList(Diagnostic) = .empty,
    nodes: std.MultiArrayList(ast.Node) = .empty,
    extra: std.ArrayList(ast.NodeIndex) = .empty,
    current_token: token.Token = undefined,

    scratch_statements: ScratchBuffer = .{},
    scratch_directives: ScratchBuffer = .{},

    // multiple scratches to handle multiple extras at the same time
    scratch_a: ScratchBuffer = .{},
    scratch_b: ScratchBuffer = .{},
    //

    context: ParserContext,

    strict_mode: bool,
    source_type: SourceType,
    lang: Lang,

    pub fn init(backing_allocator: std.mem.Allocator, source: []const u8, options: Options) Parser {
        return .{
            .source = source,
            .lexer = lexer.Lexer.init(backing_allocator, source),
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
            .source_type = options.source_type,
            .lang = options.lang,
            .strict_mode = options.is_strict,
            .context = .{ .in_async = false, .in_generator = false, .allow_in = false },
        };
    }

    pub inline fn allocator(self: *Parser) std.mem.Allocator {
        return self.arena.allocator();
    }

    /// Parse the source code and return a ParseTree.
    /// The Parser is consumed and should not be used after calling this method.
    /// The caller owns the returned ParseTree and must call deinit() on it.
    pub fn parse(self: *Parser) Error!ParseTree {
        try self.ensureCapacity();

        try self.advance();

        const start = self.current_token.span.start;

        const program_data = try self.parseBody(null);

        const end = self.current_token.span.start;

        const program = try self.addNode(
            .{
                .program = .{
                    .source_type = if (self.source_type == .Module) .Module else .Script,
                    .body = program_data.statements,
                    .directives = program_data.directives,
                },
            },
            .{ .start = start, .end = end },
        );

        const tree = ParseTree{
            .program = program,
            .source = self.source,
            .nodes = self.nodes,
            .extra = self.extra,
            .diagnostics = self.diagnostics,
            .arena = self.arena,
        };

        self.lexer.deinit();

        return tree;
    }

    const BodyResult = struct { statements: ast.IndexRange, directives: ast.IndexRange };

    pub fn parseBody(self: *Parser, terminator: ?token.TokenType) Error!BodyResult {
        const statements_checkpoint = self.scratch_statements.begin();
        const directives_checkpoint = self.scratch_directives.begin();

        while (!self.isAtBodyEnd(terminator)) {
            if (self.current_token.type == .StringLiteral) {
                if (try self.parseDirective()) |directive| {
                    try self.scratch_directives.append(self.allocator(), directive);
                }
                continue;
            }

            if (try self.parseStatement()) |statement| {
                try self.scratch_statements.append(self.allocator(), statement);
            } else {
                try self.synchronize(terminator);
            }
        }

        return .{
            .statements = try self.addExtra(self.scratch_statements.take(statements_checkpoint)),
            .directives = try self.addExtra(self.scratch_directives.take(directives_checkpoint)),
        };
    }

    inline fn isAtBodyEnd(self: *Parser, terminator: ?token.TokenType) bool {
        return self.current_token.type == .EOF or
            (terminator != null and self.current_token.type == terminator.?);
    }

    pub fn parseStatement(self: *Parser) Error!?ast.NodeIndex {
        return switch (self.current_token.type) {
            .Var, .Const, .Let, .Using => variables.parseVariableDeclaration(self),
            .Function => functions.parseFunction(self, .{}),
            .Async => functions.parseFunction(self, .{ .is_async = true }),
            .Declare => blk: {
                if (!self.isTs()) {
                    break :blk try self.parseExpressionStatement();
                }
                break :blk functions.parseFunction(self, .{ .is_declare = true });
            },

            .Await => blk: {
                const await_token = self.current_token;

                // TODO: remove lookahead method, and use a way without lookahead, like when we implement
                // top level awaits
                // leave this as is for now
                if ((self.lookAhead() orelse break :blk null).type == .Using) {
                    break :blk variables.parseVariableDeclaration(self);
                }

                try self.report(
                    await_token.span,
                    // TODO: message is not always right, there is top level awaits
                    // fix it when implement that
                    "'await' is only valid at the start of an 'await using' declaration or inside async functions",
                    .{
                        .help = "If you intended to declare a disposable resource, use 'await using'. Otherwise, 'await' can only appear inside an async function.",
                    },
                );
                break :blk null;
            },

            else => self.parseExpressionStatement(),
        };
    }

    pub fn parseDirective(self: *Parser) Error!?ast.NodeIndex {
        const current_token = self.current_token;

        const start = current_token.span.start;

        const expression = try literals.parseStringLiteral(self) orelse return null;

        const end = self.eatSemicolon(current_token.span.end);

        // without quotes
        const value_start = start + 1;
        const value_len: u16 = @intCast(current_token.lexeme.len - 2);

        return try self.addNode(.{
            .directive = .{
                .expression = expression,
                .value_start = value_start,
                .value_len = value_len,
            },
        }, .{ .start = start, .end = end });
    }

    pub fn parseExpressionStatement(self: *Parser) Error!?ast.NodeIndex {
        const expression = try expressions.parseExpression(self, 0) orelse return null;
        const span = self.getSpan(expression);

        return try self.addNode(
            .{ .expression_statement = .{ .expression = expression } },
            .{ .start = span.start, .end = self.eatSemicolon(span.end) },
        );
    }

    pub inline fn isTs(self: *Parser) bool {
        return self.lang == .Ts or self.lang == .Tsx or self.lang == .Dts;
    }

    // utils

    pub fn lookAhead(self: *Parser) ?token.Token {
        return self.current_token;
    }

    pub inline fn addNode(self: *Parser, data: ast.NodeData, span: ast.Span) Error!ast.NodeIndex {
        const index: ast.NodeIndex = @intCast(self.nodes.len);
        try self.nodes.append(self.allocator(), .{ .data = data, .span = span });
        return index;
    }

    pub fn addExtra(self: *Parser, indices: []const ast.NodeIndex) Error!ast.IndexRange {
        const start: u32 = @intCast(self.extra.items.len);
        const len: u32 = @intCast(indices.len);
        try self.extra.appendSlice(self.allocator(), indices);
        return .{ .start = start, .len = len };
    }

    pub inline fn getSpan(self: *const Parser, index: ast.NodeIndex) ast.Span {
        return self.nodes.items(.span)[index];
    }

    pub inline fn getData(self: *const Parser, index: ast.NodeIndex) ast.NodeData {
        return self.nodes.items(.data)[index];
    }

    pub inline fn getExtra(self: *const Parser, range: ast.IndexRange) []const ast.NodeIndex {
        return self.extra.items[range.start..][0..range.len];
    }

    pub fn advance(self: *Parser) Error!void {
        self.current_token = self.lexer.nextToken() catch |e| blk: {
            if (e == error.OutOfMemory) return error.OutOfMemory;

            const lex_err: lexer.LexicalError = @errorCast(e);

            try self.diagnostics.append(self.allocator(), .{
                .message = lexer.getLexicalErrorMessage(lex_err),
                .span = .{ .start = self.lexer.token_start, .end = self.lexer.cursor },
                .help = lexer.getLexicalErrorHelp(lex_err),
            });

            break :blk token.Token.eof(0);
        };
    }

    pub inline fn replaceTokenAndAdvance(self: *Parser, tok: token.Token) Error!void {
        self.current_token = tok;
        try self.advance();
    }

    pub inline fn expect(self: *Parser, token_type: token.TokenType, message: []const u8, help: ?[]const u8) Error!bool {
        if (self.current_token.type == token_type) {
            try self.advance();
            return true;
        }

        try self.report(self.current_token.span, message, .{ .help = help });
        return false;
    }

    pub inline fn eatSemicolon(self: *Parser, end: u32) u32 {
        // consume optional semicolon and adjust span
        if (self.current_token.type == .Semicolon) {
            self.advance() catch {};
            return end + 1;
        }

        return end;
    }

    pub const ReportOptions = struct {
        severity: Severity = .@"error",
        help: ?[]const u8 = null,
        labels: []const Label = &.{},
    };

    pub inline fn report(self: *Parser, span: ast.Span, message: []const u8, opts: ReportOptions) Error!void {
        try self.diagnostics.append(self.allocator(), .{
            .severity = opts.severity,
            .message = message,
            .span = span,
            .help = opts.help,
            .labels = opts.labels,
        });
    }

    pub inline fn reportFmt(self: *Parser, span: ast.Span, comptime format: []const u8, args: anytype, opts: ReportOptions) Error!void {
        const message = try std.fmt.allocPrint(self.allocator(), format, args);
        try self.report(span, message, opts);
    }

    pub inline fn label(self: *Parser, span: ast.Span, message: []const u8) Label {
        _ = self;
        return .{ .span = span, .message = message };
    }

    pub fn makeLabels(self: *Parser, labels: []const Label) Error![]const Label {
        return try self.allocator().dupe(Label, labels);
    }

    pub fn formatMessage(self: *Parser, comptime format: []const u8, args: anytype) Error![]u8 {
        return try std.fmt.allocPrint(self.allocator(), format, args);
    }

    // this is very basic now
    fn synchronize(self: *Parser, terminator: ?token.TokenType) Error!void {
        try self.advance();

        while (self.current_token.type != .EOF) {
            // stop at the block terminator to avoid consuming the closing brace
            if (terminator) |t| {
                if (self.current_token.type == t) return;
            }

            if (self.current_token.type == .Semicolon) {
                try self.advance();
                return;
            }

            switch (self.current_token.type) {
                .Class, .Function, .Var, .For, .If, .While, .Return, .Let, .Const, .Using => return,
                else => {},
            }

            try self.advance();
        }
    }

    fn ensureCapacity(self: *Parser) Error!void {
        if (self.nodes.capacity > 0) return;

        const alloc = self.allocator();
        const estimated_nodes = @max(1024, (self.source.len * 3) / 4);
        const estimated_extra = estimated_nodes / 2;

        try self.nodes.ensureTotalCapacity(alloc, estimated_nodes);
        try self.extra.ensureTotalCapacity(alloc, estimated_extra);
        try self.diagnostics.ensureTotalCapacity(alloc, 32);
        try self.scratch_statements.items.ensureTotalCapacity(alloc, 256);
        try self.scratch_directives.items.ensureTotalCapacity(alloc, 256);
        try self.scratch_a.items.ensureTotalCapacity(alloc, 256);
        try self.scratch_b.items.ensureTotalCapacity(alloc, 256);
    }
};

const ScratchBuffer = struct {
    items: std.ArrayList(ast.NodeIndex) = .empty,

    pub inline fn begin(self: *ScratchBuffer) usize {
        return self.items.items.len;
    }

    pub inline fn append(self: *ScratchBuffer, alloc: std.mem.Allocator, index: ast.NodeIndex) Error!void {
        try self.items.append(alloc, index);
    }

    pub inline fn take(self: *ScratchBuffer, checkpoint: usize) []const ast.NodeIndex {
        const slice = self.items.items[checkpoint..];
        self.items.shrinkRetainingCapacity(checkpoint);
        return slice;
    }

    pub inline fn reset(self: *ScratchBuffer, checkpoint: usize) void {
        self.items.shrinkRetainingCapacity(checkpoint);
    }
};
