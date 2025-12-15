const std = @import("std");
const ast = @import("../ast.zig");
const Parser = @import("../parser.zig").Parser;
const Error = @import("../parser.zig").Error;
const token = @import("../token.zig");

const expressions = @import("expressions.zig");
const statements = @import("statements.zig");
const literals = @import("literals.zig");
const patterns = @import("patterns.zig");
const functions = @import("functions.zig");
const class = @import("class.zig");
const variables = @import("variables.zig");

/// ImportDeclaration :
///   import ImportClause FromClause WithClause? ;
///   import ModuleSpecifier WithClause? ;
///   import source ImportedDefaultBinding FromClause ;
///   import defer NameSpaceImport FromClause ;
pub fn parseImportDeclaration(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    try parser.advance(); // consume 'import'

    // Side-effect import: import 'module'
    if (parser.current_token.type == .string_literal) {
        return parseSideEffectImport(parser, start, null);
    }

    // Check for import phase: source or defer
    var phase: ?ast.ImportPhase = null;
    if (parser.current_token.type == .source) {
        phase = .source;
        try parser.advance(); // consume 'source'
        return parseSourcePhaseImport(parser, start);
    } else if (parser.current_token.type == .@"defer") {
        phase = .@"defer";
        try parser.advance(); // consume 'defer'
        return parseDeferPhaseImport(parser, start);
    }

    // Regular import: parse import clause (specifiers)
    const specifiers = try parseImportClause(parser) orelse return null;

    // expect 'from'
    if (parser.current_token.type != .from) {
        try parser.report(parser.current_token.span, "Expected 'from' after import clause", .{
            .help = "Import statements require 'from' followed by a module specifier: import x from 'module'",
        });
        return null;
    }
    try parser.advance(); // consume 'from'

    // parse module specifier
    const source = try parseModuleSpecifier(parser) orelse return null;

    // parse optional with clause
    const attributes = try parseWithClause(parser);

    const end = try parser.eatSemicolon(parser.getSpan(source).end);

    return try parser.addNode(.{
        .import_declaration = .{
            .specifiers = specifiers,
            .source = source,
            .attributes = attributes,
            .phase = phase,
        },
    }, .{ .start = start, .end = end });
}

/// Parse side-effect import: import 'module'
fn parseSideEffectImport(parser: *Parser, start: u32, phase: ?ast.ImportPhase) Error!?ast.NodeIndex {
    const source = try parseModuleSpecifier(parser) orelse return null;
    const attributes = try parseWithClause(parser);
    const end = try parser.eatSemicolon(parser.getSpan(source).end);

    return try parser.addNode(.{
        .import_declaration = .{
            .specifiers = ast.IndexRange.empty,
            .source = source,
            .attributes = attributes,
            .phase = phase,
        },
    }, .{ .start = start, .end = end });
}

/// Parse source phase import: import source X from "X"
/// Source phase imports must have exactly one ImportDefaultSpecifier
fn parseSourcePhaseImport(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    // Parse the default binding
    const default_spec = try parseImportDefaultSpecifier(parser) orelse return null;

    // Store in specifiers array
    const checkpoint = parser.scratch_a.begin();
    try parser.scratch_a.append(parser.allocator(), default_spec);
    const specifiers = try parser.addExtra(parser.scratch_a.take(checkpoint));

    // expect 'from'
    if (parser.current_token.type != .from) {
        try parser.report(parser.current_token.span, "Expected 'from' after source phase import binding", .{
            .help = "Source phase imports require 'from': import source x from 'module'",
        });
        return null;
    }
    try parser.advance(); // consume 'from'

    // parse module specifier
    const source = try parseModuleSpecifier(parser) orelse return null;

    // Source phase imports do not support import attributes
    const end = try parser.eatSemicolon(parser.getSpan(source).end);

    return try parser.addNode(.{
        .import_declaration = .{
            .specifiers = specifiers,
            .source = source,
            .attributes = ast.IndexRange.empty,
            .phase = .source,
        },
    }, .{ .start = start, .end = end });
}

/// Parse defer phase import: import defer * as X from "X"
/// Defer phase imports must have exactly one ImportNamespaceSpecifier
fn parseDeferPhaseImport(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    // Defer imports require namespace import: * as name
    if (parser.current_token.type != .star) {
        try parser.report(parser.current_token.span, "Expected '*' for defer phase import", .{
            .help = "Defer phase imports must use namespace form: import defer * as name from 'module'",
        });
        return null;
    }

    const ns_spec = try parseImportNamespaceSpecifier(parser) orelse return null;

    // Store in specifiers array
    const checkpoint = parser.scratch_a.begin();
    try parser.scratch_a.append(parser.allocator(), ns_spec);
    const specifiers = try parser.addExtra(parser.scratch_a.take(checkpoint));

    // expect 'from'
    if (parser.current_token.type != .from) {
        try parser.report(parser.current_token.span, "Expected 'from' after defer phase import binding", .{
            .help = "Defer phase imports require 'from': import defer * as x from 'module'",
        });
        return null;
    }
    try parser.advance(); // consume 'from'

    // parse module specifier
    const source = try parseModuleSpecifier(parser) orelse return null;

    // Defer phase imports do not support import attributes
    const end = try parser.eatSemicolon(parser.getSpan(source).end);

    return try parser.addNode(.{
        .import_declaration = .{
            .specifiers = specifiers,
            .source = source,
            .attributes = ast.IndexRange.empty,
            .phase = .@"defer",
        },
    }, .{ .start = start, .end = end });
}

/// Parse import clause
/// ImportClause :
///   ImportedDefaultBinding
///   NameSpaceImport
///   NamedImports
///   ImportedDefaultBinding , NameSpaceImport
///   ImportedDefaultBinding , NamedImports
fn parseImportClause(parser: *Parser) Error!?ast.IndexRange {
    const checkpoint = parser.scratch_a.begin();

    // check for namespace import: * as name
    if (parser.current_token.type == .star) {
        const ns = try parseImportNamespaceSpecifier(parser) orelse {
            parser.scratch_a.reset(checkpoint);
            return null;
        };
        try parser.scratch_a.append(parser.allocator(), ns);
        return try parser.addExtra(parser.scratch_a.take(checkpoint));
    }

    // check for named imports: { foo, bar }
    if (parser.current_token.type == .left_brace) {
        return parseNamedImports(parser);
    }

    // default import: import foo from 'module'
    const default_import = try parseImportDefaultSpecifier(parser) orelse {
        parser.scratch_a.reset(checkpoint);
        return null;
    };
    try parser.scratch_a.append(parser.allocator(), default_import);

    // check for: import foo, * as bar from 'module'
    //        or: import foo, { bar } from 'module'
    if (parser.current_token.type == .comma) {
        try parser.advance(); // consume ','

        if (parser.current_token.type == .star) {
            const ns = try parseImportNamespaceSpecifier(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            try parser.scratch_a.append(parser.allocator(), ns);
        } else if (parser.current_token.type == .left_brace) {
            const named = try parseNamedImports(parser) orelse {
                parser.scratch_a.reset(checkpoint);
                return null;
            };
            // append all named imports
            for (parser.getExtra(named)) |spec| {
                try parser.scratch_a.append(parser.allocator(), spec);
            }
        } else {
            try parser.report(parser.current_token.span, "Expected namespace import (* as name) or named imports ({...}) after ','", .{});
            parser.scratch_a.reset(checkpoint);
            return null;
        }
    }

    return try parser.addExtra(parser.scratch_a.take(checkpoint));
}

/// Parse default import specifier: import foo from 'module'
fn parseImportDefaultSpecifier(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;

    const local = try parseImportedBinding(parser) orelse return null;
    const end = parser.getSpan(local).end;

    return try parser.addNode(.{
        .import_default_specifier = .{ .local = local },
    }, .{ .start = start, .end = end });
}

/// Parse namespace import: * as name
fn parseImportNamespaceSpecifier(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;

    if (!try parser.expect(.star, "Expected '*' for namespace import", null)) return null;

    if (parser.current_token.type != .as) {
        try parser.report(parser.current_token.span, "Expected 'as' after '*' in namespace import", .{
            .help = "Namespace imports must use the form: * as name",
        });
        return null;
    }
    try parser.advance(); // consume 'as'

    const local = try parseImportedBinding(parser) orelse return null;
    const end = parser.getSpan(local).end;

    return try parser.addNode(.{
        .import_namespace_specifier = .{ .local = local },
    }, .{ .start = start, .end = end });
}

/// Parse named imports: { foo, bar as baz }
fn parseNamedImports(parser: *Parser) Error!?ast.IndexRange {
    const checkpoint = parser.scratch_a.begin();

    if (!try parser.expect(.left_brace, "Expected '{' to start named imports", null)) return null;

    while (parser.current_token.type != .right_brace and parser.current_token.type != .eof) {
        const spec = try parseImportSpecifier(parser) orelse {
            parser.scratch_a.reset(checkpoint);
            return null;
        };
        try parser.scratch_a.append(parser.allocator(), spec);

        if (parser.current_token.type == .comma) {
            try parser.advance();
        } else {
            break;
        }
    }

    if (!try parser.expect(.right_brace, "Expected '}' to close named imports", null)) {
        parser.scratch_a.reset(checkpoint);
        return null;
    }

    return try parser.addExtra(parser.scratch_a.take(checkpoint));
}

/// Parse import specifier: foo or foo as bar or "string" as bar
fn parseImportSpecifier(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;

    // parse imported name (can be identifier or string literal)
    const imported = try parseModuleExportName(parser) orelse return null;

    var local: ast.NodeIndex = undefined;

    // check for 'as' alias
    if (parser.current_token.type == .as) {
        try parser.advance(); // consume 'as'
        local = try parseImportedBinding(parser) orelse return null;
    } else {
        // no alias - local is the same as imported
        // but we need to convert IdentifierName to BindingIdentifier if it's not a string
        const imported_data = parser.getData(imported);
        if (imported_data == .string_literal) {
            try parser.report(parser.getSpan(imported), "String literal imports require an 'as' clause", .{
                .help = "Use: import { \"name\" as localName } from 'module'",
            });
            return null;
        }
        // convert identifier_name to binding_identifier
        const id_data = imported_data.identifier_name;
        local = try parser.addNode(.{
            .binding_identifier = .{
                .name_start = id_data.name_start,
                .name_len = id_data.name_len,
            },
        }, parser.getSpan(imported));
    }

    const end = parser.getSpan(local).end;

    return try parser.addNode(.{
        .import_specifier = .{
            .imported = imported,
            .local = local,
        },
    }, .{ .start = start, .end = end });
}

/// Parse ImportedBinding: BindingIdentifier[~Yield, +Await]
fn parseImportedBinding(parser: *Parser) Error!?ast.NodeIndex {
    return patterns.parseBindingIdentifier(parser);
}

// =============================================================================
// Export Declaration
// https://tc39.es/ecma262/#sec-exports
// =============================================================================

/// Parse an export declaration
pub fn parseExportDeclaration(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;
    try parser.advance(); // consume 'export'

    // TypeScript: export = expression
    if (parser.isTs() and parser.current_token.type == .assign) {
        return parseTSExportAssignment(parser, start);
    }

    // TypeScript: export as namespace name
    if (parser.isTs() and parser.current_token.type == .as) {
        return parseTSNamespaceExportDeclaration(parser, start);
    }

    // export default ...
    if (parser.current_token.type == .default) {
        return parseExportDefaultDeclaration(parser, start);
    }

    // export * from 'module'
    // export * as name from 'module'
    if (parser.current_token.type == .star) {
        return parseExportAllDeclaration(parser, start);
    }

    // export { foo, bar }
    // export { foo } from 'module'
    if (parser.current_token.type == .left_brace) {
        return parseExportNamedFromClause(parser, start);
    }

    // export var/let/const/function/class
    return parseExportWithDeclaration(parser, start);
}

/// Parse TypeScript export = expression
fn parseTSExportAssignment(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    try parser.advance(); // consume '='

    const expression = try expressions.parseExpression(parser, 2, .{}) orelse return null;
    const end = try parser.eatSemicolon(parser.getSpan(expression).end);

    return try parser.addNode(.{
        .ts_export_assignment = .{ .expression = expression },
    }, .{ .start = start, .end = end });
}

/// Parse TypeScript export as namespace name
fn parseTSNamespaceExportDeclaration(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    try parser.advance(); // consume 'as'

    if (parser.current_token.type != .@"namespace") {
        try parser.report(parser.current_token.span, "Expected 'namespace' after 'export as'", .{});
        return null;
    }
    try parser.advance(); // consume 'namespace'

    const id = try literals.parseIdentifierName(parser);
    const end = try parser.eatSemicolon(parser.getSpan(id).end);

    return try parser.addNode(.{
        .ts_namespace_export_declaration = .{ .id = id },
    }, .{ .start = start, .end = end });
}

/// Parse export default declaration
fn parseExportDefaultDeclaration(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    try parser.advance(); // consume 'default'

    var declaration: ast.NodeIndex = undefined;
    var is_decl = false;

    // export default function [name]() {}
    if (parser.current_token.type == .function) {
        declaration = try functions.parseFunction(parser, .{ .is_default_export = true }, null) orelse return null;
        is_decl = true;
    }
    // export default async function [name]() {}
    else if (parser.current_token.type == .async and !parser.current_token.has_line_terminator_before) {
        const async_start = parser.current_token.span.start;
        try parser.advance(); // consume 'async'
        if (parser.current_token.type == .function) {
            declaration = try functions.parseFunction(parser, .{ .is_default_export = true, .is_async = true }, async_start) orelse return null;
            is_decl = true;
        } else {
            // async as an identifier - parse as expression
            parser.current_token = .{
                .type = .identifier,
                .span = .{ .start = async_start, .end = async_start + 5 },
                .lexeme = "async",
                .has_line_terminator_before = false,
            };
            declaration = try expressions.parseExpression(parser, 2, .{}) orelse return null;
        }
    }
    // export default class [name] {}
    else if (parser.current_token.type == .class) {
        declaration = try class.parseClass(parser, .{ .is_default_export = true }, null) orelse return null;
        is_decl = true;
    }
    // export default expression
    else {
        declaration = try expressions.parseExpression(parser, 2, .{}) orelse return null;
    }

    const decl_span = parser.getSpan(declaration);

    // function/class declarations don't need semicolon
    const end = if (is_decl)
        decl_span.end
    else
        try parser.eatSemicolon(decl_span.end);

    return try parser.addNode(.{
        .export_default_declaration = .{ .declaration = declaration },
    }, .{ .start = start, .end = end });
}

/// Parse export * from 'module' or export * as name from 'module'
fn parseExportAllDeclaration(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    try parser.advance(); // consume '*'

    var exported: ast.NodeIndex = ast.null_node;

    // check for: export * as name from 'module'
    if (parser.current_token.type == .as) {
        try parser.advance(); // consume 'as'
        exported = try parseModuleExportName(parser) orelse return null;
    }

    // expect 'from'
    if (parser.current_token.type != .from) {
        try parser.report(parser.current_token.span, "Expected 'from' after export *", .{
            .help = "Export all declarations require 'from': export * from 'module'",
        });
        return null;
    }
    try parser.advance(); // consume 'from'

    const source = try parseModuleSpecifier(parser) orelse return null;
    const attributes = try parseWithClause(parser);
    const end = try parser.eatSemicolon(parser.getSpan(source).end);

    return try parser.addNode(.{
        .export_all_declaration = .{
            .exported = exported,
            .source = source,
            .attributes = attributes,
        },
    }, .{ .start = start, .end = end });
}

/// Parse export { foo, bar } or export { foo } from 'module'
fn parseExportNamedFromClause(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    const result = try parseExportSpecifiers(parser) orelse return null;
    const specifiers = result.specifiers;

    var source: ast.NodeIndex = ast.null_node;
    var attributes: ast.IndexRange = ast.IndexRange.empty;
    var end = parser.current_token.span.start;

    // check for re-export: export { foo } from 'module'
    if (parser.current_token.type == .from) {
        try parser.advance(); // consume 'from'
        source = try parseModuleSpecifier(parser) orelse return null;
        attributes = try parseWithClause(parser);
        end = parser.getSpan(source).end;
    } else {
        // local export: export { foo }
        // validate that all specifiers are valid local references (not string literals)
        // and check for strict mode reserved words using the captured token types
        const specs = parser.getExtra(specifiers);
        for (specs, 0..) |spec_idx, i| {
            const spec = parser.getData(spec_idx).export_specifier;
            const local_data = parser.getData(spec.local);
            const local_span = parser.getSpan(spec.local);

            // check for string literal local - not allowed without 'from'
            if (local_data == .string_literal) {
                try parser.report(local_span, "A string literal cannot be used as an exported binding without 'from'", .{
                    .help = "Use: export { \"name\" } from 'some-module' or export { localName as \"name\" }",
                });
                return null;
            }

            // check for strict mode reserved words using the captured token type
            const local_token_type: token.TokenType = @enumFromInt(result.local_token_types[i]);
            if (local_token_type.isStrictModeReserved()) {
                const local_name = parser.source[local_data.identifier_name.name_start..][0..local_data.identifier_name.name_len];
                try parser.reportFmt(
                    local_span,
                    "A reserved word cannot be used as an exported binding without 'from'",
                    .{},
                    .{ .help = try parser.formatMessage("Did you mean `export {{ {s} as {s} }} from 'some-module'`?", .{ local_name, local_name }) },
                );
                return null;
            }
        }
    }

    end = try parser.eatSemicolon(end);

    return try parser.addNode(.{
        .export_named_declaration = .{
            .declaration = ast.null_node,
            .specifiers = specifiers,
            .source = source,
            .attributes = attributes,
        },
    }, .{ .start = start, .end = end });
}

/// Parse export var/let/const/function/class
fn parseExportWithDeclaration(parser: *Parser, start: u32) Error!?ast.NodeIndex {
    var declaration: ast.NodeIndex = undefined;

    switch (parser.current_token.type) {
        .@"var", .@"const", .let => {
            declaration = try variables.parseVariableDeclaration(parser) orelse return null;
        },
        .function => {
            declaration = try functions.parseFunction(parser, .{}, null) orelse return null;
        },
        .async => {
            const async_start = parser.current_token.span.start;
            try parser.advance(); // consume 'async'
            declaration = try functions.parseFunction(parser, .{ .is_async = true }, async_start) orelse return null;
        },
        .class => {
            declaration = try class.parseClass(parser, .{}, null) orelse return null;
        },
        else => {
            try parser.report(parser.current_token.span, "Expected declaration after 'export'", .{
                .help = "Use 'export var', 'export let', 'export const', 'export function', or 'export class'",
            });
            return null;
        },
    }

    return try parser.addNode(.{
        .export_named_declaration = .{
            .declaration = declaration,
            .specifiers = ast.IndexRange.empty,
            .source = ast.null_node,
            .attributes = ast.IndexRange.empty,
        },
    }, .{ .start = start, .end = parser.getSpan(declaration).end });
}

/// Result of parsing export specifiers - includes token types for validation
const ExportSpecifiersResult = struct {
    specifiers: ast.IndexRange,
    /// Token types of each local name (parallel to specifiers)
    /// Stored as u32 values of token.TokenType enum
    local_token_types: []const u32,
};

/// Parse export specifiers: { foo, bar as baz }
/// Also tracks token types of local names for strict mode reserved word validation
fn parseExportSpecifiers(parser: *Parser) Error!?ExportSpecifiersResult {
    const checkpoint = parser.scratch_a.begin();
    const token_checkpoint = parser.scratch_b.begin();

    if (!try parser.expect(.left_brace, "Expected '{' to start export specifiers", null)) return null;

    while (parser.current_token.type != .right_brace and parser.current_token.type != .eof) {
        // Capture the token type of the local name BEFORE parsing
        const local_token_type = parser.current_token.type;

        const spec = try parseExportSpecifier(parser) orelse {
            parser.scratch_a.reset(checkpoint);
            parser.scratch_b.reset(token_checkpoint);
            return null;
        };
        try parser.scratch_a.append(parser.allocator(), spec);
        // Store token type as u32 (same size as NodeIndex)
        try parser.scratch_b.append(parser.allocator(), @intFromEnum(local_token_type));

        if (parser.current_token.type == .comma) {
            try parser.advance();
        } else {
            break;
        }
    }

    if (!try parser.expect(.right_brace, "Expected '}' to close export specifiers", null)) {
        parser.scratch_a.reset(checkpoint);
        parser.scratch_b.reset(token_checkpoint);
        return null;
    }

    return .{
        .specifiers = try parser.addExtra(parser.scratch_a.take(checkpoint)),
        .local_token_types = parser.scratch_b.take(token_checkpoint),
    };
}

/// Parse export specifier: foo or foo as bar
fn parseExportSpecifier(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;

    // parse local name (can be identifier or string literal)
    const local = try parseModuleExportName(parser) orelse return null;

    var exported: ast.NodeIndex = undefined;

    // check for 'as' alias
    if (parser.current_token.type == .as) {
        try parser.advance(); // consume 'as'
        exported = try parseModuleExportName(parser) orelse return null;
    } else {
        // no alias - exported is the same as local
        exported = local;
    }

    const end = parser.getSpan(exported).end;

    return try parser.addNode(.{
        .export_specifier = .{
            .local = local,
            .exported = exported,
        },
    }, .{ .start = start, .end = end });
}

// =============================================================================
// Common Module Parsing Utilities
// =============================================================================

/// Parse ModuleExportName: IdentifierName or StringLiteral
fn parseModuleExportName(parser: *Parser) Error!?ast.NodeIndex {
    if (parser.current_token.type == .string_literal) {
        return literals.parseStringLiteral(parser);
    }

    if (parser.current_token.type.isIdentifierLike()) {
        return try literals.parseIdentifierName(parser);
    }

    try parser.report(parser.current_token.span, "Expected identifier or string literal", .{});
    return null;
}

/// Parse ModuleSpecifier: StringLiteral
fn parseModuleSpecifier(parser: *Parser) Error!?ast.NodeIndex {
    if (parser.current_token.type != .string_literal) {
        try parser.report(parser.current_token.span, "Expected module specifier (string literal)", .{
            .help = "Module specifiers must be string literals, e.g., './module.js' or 'package'",
        });
        return null;
    }

    return literals.parseStringLiteral(parser);
}

/// Parse WithClause / ImportAttributes
/// WithClause :
///   with { }
///   with { WithEntries ,? }
fn parseWithClause(parser: *Parser) Error!ast.IndexRange {
    // check for 'with' or 'assert' keyword
    if (parser.current_token.type != .with and parser.current_token.type != .assert) {
        return ast.IndexRange.empty;
    }

    try parser.advance(); // consume 'with' or 'assert'

    if (!try parser.expect(.left_brace, "Expected '{' after 'with' in import attributes", null)) {
        return ast.IndexRange.empty;
    }

    const checkpoint = parser.scratch_a.begin();

    while (parser.current_token.type != .right_brace and parser.current_token.type != .eof) {
        const attr = try parseImportAttribute(parser) orelse {
            parser.scratch_a.reset(checkpoint);
            return ast.IndexRange.empty;
        };
        try parser.scratch_a.append(parser.allocator(), attr);

        if (parser.current_token.type == .comma) {
            try parser.advance();
        } else {
            break;
        }
    }

    if (!try parser.expect(.right_brace, "Expected '}' to close import attributes", null)) {
        parser.scratch_a.reset(checkpoint);
        return ast.IndexRange.empty;
    }

    return parser.addExtra(parser.scratch_a.take(checkpoint));
}

/// Parse ImportAttribute: key : value
fn parseImportAttribute(parser: *Parser) Error!?ast.NodeIndex {
    const start = parser.current_token.span.start;

    // parse key (IdentifierName or StringLiteral)
    const key = try parseAttributeKey(parser) orelse return null;

    if (!try parser.expect(.colon, "Expected ':' in import attribute", null)) return null;

    // parse value (must be StringLiteral)
    if (parser.current_token.type != .string_literal) {
        try parser.report(parser.current_token.span, "Import attribute value must be a string literal", .{});
        return null;
    }
    const value = try literals.parseStringLiteral(parser) orelse return null;

    return try parser.addNode(.{
        .import_attribute = .{
            .key = key,
            .value = value,
        },
    }, .{ .start = start, .end = parser.getSpan(value).end });
}

/// Parse AttributeKey: IdentifierName or StringLiteral
fn parseAttributeKey(parser: *Parser) Error!?ast.NodeIndex {
    if (parser.current_token.type == .string_literal) {
        return literals.parseStringLiteral(parser);
    }

    if (parser.current_token.type.isIdentifierLike()) {
        return try literals.parseIdentifierName(parser);
    }

    try parser.report(parser.current_token.span, "Expected identifier or string literal for attribute key", .{});
    return null;
}

// =============================================================================
// Dynamic Import
// https://tc39.es/ecma262/#sec-import-calls
// =============================================================================

/// Parse dynamic import: import(source), import(source, options), import.source(source), import.defer(source)
pub fn parseDynamicImport(parser: *Parser, import_keyword: ast.NodeIndex, phase: ?ast.ImportPhase) Error!?ast.NodeIndex {
    const start = parser.getSpan(import_keyword).start;

    if (!try parser.expect(.left_paren, "Expected '(' after import", null)) return null;

    // parse source expression
    const source = try expressions.parseExpression(parser, 2, .{}) orelse return null;

    var options: ast.NodeIndex = ast.null_node;

    // check for options argument (only for regular imports, not phase imports)
    if (phase == null and parser.current_token.type == .comma) {
        try parser.advance(); // consume ','

        // allow trailing comma
        if (parser.current_token.type != .right_paren) {
            options = try expressions.parseExpression(parser, 2, .{}) orelse return null;

            // allow trailing comma after options
            if (parser.current_token.type == .comma) {
                try parser.advance();
            }
        }
    }

    const end = parser.current_token.span.end;

    if (!try parser.expect(.right_paren, "Expected ')' after import()", "Dynamic import call must end with ')'")) return null;

    return try parser.addNode(.{
        .import_expression = .{
            .source = source,
            .options = options,
            .phase = phase,
        },
    }, .{ .start = start, .end = end });
}

