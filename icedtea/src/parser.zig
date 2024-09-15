const std = @import("std");

pub const NodeTag = enum {
    element,
    text,
};

pub const Node = struct {
    tag: NodeTag,
    capture: []u8,
};

pub const Document = struct { nodes: std.ArrayList(Node) };

pub fn parse(s: []u8, alloc: std.mem.Allocator) !Document {
    var doc = Document{
        .nodes = std.ArrayList(Node).init(alloc),
    };
    var s_sliced = s;
    while (s_sliced.len > 0) {
        const node = switch (s_sliced[0]) {
            '<' => Node{ .tag = .element, .capture = parse_element(s_sliced) },
            else => Node{ .tag = .text, .capture = parse_text(s_sliced) },
        };
        s_sliced = s_sliced[node.capture.len..];
        try doc.nodes.append(node);
    }
    return doc;
}

pub fn parse_element(s: []u8) []u8 {
    const opt_index = std.ascii.indexOfIgnoreCase(s, ">");
    if (opt_index) |index| {
        return s[0 .. index + 1];
    } else {
        return s;
    }
}

pub fn parse_text(s: []u8) []u8 {
    const opt_index = std.ascii.indexOfIgnoreCase(s, "<");
    if (opt_index) |index| {
        return s[0..index];
    } else {
        return s;
    }
}
