const parser = @import("parser.zig");

pub const parse = parser.parse;
pub const Parser = parser.Parser;
pub const ParseTree = parser.ParseTree;
pub const Options = parser.Options;
pub const Diagnostic = parser.Diagnostic;
pub const Severity = parser.Severity;
pub const Label = parser.Label;
pub const SourceType = parser.SourceType;
pub const Lang = parser.Lang;

pub const estree = @import("estree.zig");
