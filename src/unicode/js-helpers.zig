const std = @import("std");
const tables = @import("id-tables.zig");

pub fn canStartJsIdentifier(cp: u32) bool {
    if (cp < 128) {
        return (cp >= 'a' and cp <= 'z') or
            (cp >= 'A' and cp <= 'Z') or
            cp == '_' or cp == '$';
    }

    return tables.queryBitTable(cp, &tables.id_start_root, &tables.id_start_leaf);
}

pub fn canContinueJsIdentifier(cp: u32) bool {
    if (cp < 128) {
        return (cp >= 'a' and cp <= 'z') or
            (cp >= 'A' and cp <= 'Z') or
            cp == '_' or cp == '$' or
            (cp >= '0' and cp <= '9');
    }

    return tables.queryBitTable(cp, &tables.id_continue_root, &tables.id_continue_leaf);
}
