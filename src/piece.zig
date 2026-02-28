const random_mod = @import("random.zig");

pub const Piece = struct {
    kind: random_mod.PieceType,
    x: i32,
    y: i32,
    rot: u8,

    pub fn init(kind: random_mod.PieceType, x: i32, y: i32) Piece {
        return Piece{
            .kind = kind,
            .x = x,
            .y = y,
            .rot = 0,
        };
    }
};

pub const Coord = struct {
    x: i32,
    y: i32,
};

pub fn blockCount(_: random_mod.PieceType) usize {
    return 4;
}

const SHAPES: [7][4][4]Coord = .{
    // I
    .{
        .{ .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 2, .y = 0 } },
        .{ .{ .x = 1, .y = -1 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 }, .{ .x = 1, .y = 2 } },
        .{ .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 2, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 2 } },
    },
    // O
    .{
        .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
    },
    // T
    .{
        .{ .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 } },
        .{ .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 0, .y = 0 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 } },
    },
    // S
    .{
        .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 } },
    },
    // Z
    .{
        .{ .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 1, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 } },
        .{ .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 1, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 } },
    },
    // J
    .{
        .{ .{ .x = -1, .y = 0 }, .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 } },
        .{ .{ .x = -1, .y = 0 }, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = -1, .y = 1 } },
    },
    // L
    .{
        .{ .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 }, .{ .x = 1, .y = 0 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = -1, .y = 0 }, .{ .x = -1, .y = 1 }, .{ .x = 0, .y = 1 }, .{ .x = 1, .y = 1 } },
        .{ .{ .x = 0, .y = -1 }, .{ .x = 1, .y = -1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 1 } },
    },
};

pub fn cells(piece_inst: Piece, out: *[4]Coord) void {
    const idx = @as(usize, @intFromEnum(piece_inst.kind));
    const rot = piece_inst.rot & 3;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        out[i] = .{
            .x = piece_inst.x + SHAPES[idx][rot][i].x,
            .y = piece_inst.y + SHAPES[idx][rot][i].y,
        };
    }
}

pub fn rotated(piece_inst: Piece, dir: u8) Piece {
    var next = piece_inst;
    if (dir == 0) {
        next.rot = (piece_inst.rot + 1) & 3;
    } else {
        next.rot = (piece_inst.rot + 3) & 3;
    }
    return next;
}

pub fn colorFor(kind: random_mod.PieceType) u8 {
    return @intFromEnum(kind) + 1;
}
