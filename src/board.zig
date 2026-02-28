const piece_mod = @import("piece.zig");

pub const WIDTH: usize = 10;
pub const HEIGHT: usize = 30;

pub const Board = struct {
    cells: [WIDTH * HEIGHT]u8 = [_]u8{0} ** (WIDTH * HEIGHT),

    pub fn clear(self: *Board) void {
        self.cells = [_]u8{0} ** (WIDTH * HEIGHT);
    }

    pub fn index(x: usize, y: usize) usize {
        return y * WIDTH + x;
    }

    pub fn canPlacePiece(self: *const Board, p: piece_mod.Piece) bool {
        var blocks: [4]piece_mod.Coord = undefined;
        piece_mod.cells(p, &blocks);
        for (blocks) |b| {
            if (
                b.x < 0 or
                b.x >= @as(i32, @intCast(WIDTH)) or
                b.y >= @as(i32, @intCast(HEIGHT))
            ) {
                return false;
            }
            if (b.y < 0) continue;
            if (self.cells[index(@intCast(b.x), @intCast(b.y))] != 0) {
                return false;
            }
        }
        return true;
    }

    pub fn placePiece(self: *Board, p: piece_mod.Piece) void {
        var blocks: [4]piece_mod.Coord = undefined;
        piece_mod.cells(p, &blocks);
        for (blocks) |b| {
            if (
                b.x < 0 or
                b.x >= @as(i32, @intCast(WIDTH)) or
                b.y < 0 or
                b.y >= @as(i32, @intCast(HEIGHT))
            ) continue;
            self.cells[index(@intCast(b.x), @intCast(b.y))] = piece_mod.colorFor(p.kind);
        }
    }

    pub fn findFullLines(self: *const Board, out: *[4]usize) usize {
        var count: usize = 0;
        var y: usize = 0;
        while (y < HEIGHT) : (y += 1) {
            var x: usize = 0;
            var full = true;
            while (x < WIDTH) : (x += 1) {
                if (self.cells[index(x, y)] == 0) {
                    full = false;
                    break;
                }
            }
            if (full) {
                out[count] = y;
                count += 1;
            }
        }
        return count;
    }

    pub fn clearLinesAt(self: *Board, lines_to_clear: []const usize) u32 {
        var write_y: isize = @intCast(HEIGHT - 1);
        var read_y: isize = @intCast(HEIGHT - 1);
        var cleared: u32 = 0;

        while (read_y >= 0) : (read_y -= 1) {
            var should_clear = false;
            for (lines_to_clear) |line| {
                if (line == @as(usize, @intCast(read_y))) {
                    should_clear = true;
                    break;
                }
            }

            if (!should_clear) {
                var x2: usize = 0;
                while (x2 < WIDTH) : (x2 += 1) {
                    self.cells[index(x2, @intCast(write_y))] = self.cells[index(x2, @intCast(read_y))];
                }
                write_y -= 1;
            } else {
                cleared += 1;
            }
        }

        while (write_y >= 0) : (write_y -= 1) {
            var x3: usize = 0;
            while (x3 < WIDTH) : (x3 += 1) {
                self.cells[index(x3, @intCast(write_y))] = 0;
            }
        }

        return cleared;
    }

    pub fn clearLines(self: *Board) u32 {
        var lines: [4]usize = undefined;
        const count = self.findFullLines(&lines);
        return self.clearLinesAt(lines[0..count]);
    }
};
