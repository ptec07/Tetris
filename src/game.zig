const std = @import("std");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const input = @import("input.zig");
const board = @import("board.zig");
const piece_mod = @import("piece.zig");
const random_mod = @import("random.zig");

const DIGIT_FONT: [10][5]u8 = .{
    .{ 0b111, 0b101, 0b101, 0b101, 0b111 }, // 0
    .{ 0b010, 0b110, 0b010, 0b010, 0b111 }, // 1
    .{ 0b111, 0b001, 0b111, 0b100, 0b111 }, // 2
    .{ 0b111, 0b001, 0b110, 0b001, 0b111 }, // 3
    .{ 0b101, 0b101, 0b111, 0b001, 0b001 }, // 4
    .{ 0b111, 0b100, 0b111, 0b001, 0b111 }, // 5
    .{ 0b111, 0b100, 0b111, 0b101, 0b111 }, // 6
    .{ 0b111, 0b001, 0b001, 0b001, 0b001 }, // 7
    .{ 0b111, 0b101, 0b111, 0b101, 0b111 }, // 8
    .{ 0b111, 0b101, 0b111, 0b001, 0b111 }, // 9
};

const HUD_TEXT_COLOR = [4]u8{ 196, 214, 255, 255 };

fn clampDigit(v: u32) u8 {
    return @intCast(@min(v, 9));
}

pub const GameState = enum {
    menu,
    playing,
    paused,
    game_over,
};

pub const Game = struct {
    state: GameState = .menu,
    running: bool = true,

    board: board.Board = .{},
    rng: random_mod.RandomBag,
    next_piece: random_mod.PieceType,

    active_piece: ?piece_mod.Piece = null,

    clear_lines_pending: [4]usize = [_]usize{0} ** 4,
    clear_lines_pending_count: u8 = 0,
    clear_effect_timer_ms: f32 = 0.0,
    clear_effect_delay_ms: f32 = 140.0,

    frame_counter: u64 = 0,
    state_elapsed_ms: f32 = 0.0,
    gravity_ms: f32 = 800.0,
    gravity_accumulator_ms: f32 = 0.0,
    gravity_min_ms: f32 = 90.0,
    drop_bonus_multiplier: u32 = 2,

    das_delay_ms: f32 = 160.0,
    arr_ms: f32 = 45.0,
    left_repeat_ms: f32 = -1.0,
    right_repeat_ms: f32 = -1.0,

    score: u32 = 0,
    lines_cleared: u32 = 0,
    lines_for_next_level: u32 = 10,
    level: u32 = 1,
    combo: u32 = 0,

    pub fn init() Game {
        var rng = random_mod.RandomBag.init(0x5AA55AA5_12345678);
        return Game{
            .rng = rng,
            .next_piece = rng.next(),
        };
    }

    fn reset(self: *Game) void {
        self.board.clear();
        self.active_piece = null;
        self.score = 0;
        self.lines_cleared = 0;
        self.lines_for_next_level = 10;
        self.combo = 0;
        self.level = 1;
        self.gravity_ms = 800.0;
        self.gravity_accumulator_ms = 0.0;
        self.state_elapsed_ms = 0.0;
        self.left_repeat_ms = -1;
        self.right_repeat_ms = -1;
        self.clear_lines_pending_count = 0;
        self.clear_effect_timer_ms = 0.0;
    }

    fn satAddU32(self_value: *u32, increment: u32) void {
        const result = @addWithOverflow(self_value.*, increment);
        self_value.* = if (result[1] == 1) std.math.maxInt(u32) else result[0];
    }

    fn satMulU32(a: u32, b: u32) u32 {
        const result = @mulWithOverflow(a, b);
        return if (result[1] == 1) std.math.maxInt(u32) else result[0];
    }

    pub fn update(self: *Game, dt_ms: f32, input_state: *input.InputManager) void {
        self.frame_counter +%= 1;
        self.state_elapsed_ms += dt_ms;

        if (input_state.consumeQuit()) {
            self.running = false;
            return;
        }

        if (input_state.consumePause()) {
            switch (self.state) {
                .playing => self.state = .paused,
                .paused => self.state = .playing,
                else => {},
            }
            return;
        }

        switch (self.state) {
            .menu => {
                if (input_state.consumeStart()) {
                    self.state = .playing;
                    self.state_elapsed_ms = 0;
                    self.gravity_accumulator_ms = 0;
                    self.reset();
                    self.spawnPiece();
                    self.left_repeat_ms = -1;
                    self.right_repeat_ms = -1;
                }
            },
            .playing => self.updatePlaying(dt_ms, input_state),
            .paused => {
                self.left_repeat_ms = -1;
                self.right_repeat_ms = -1;
            },
            .game_over => {
                if (input_state.consumeStart()) {
                    self.state = .menu;
                    self.state_elapsed_ms = 0;
                }
            },
        }
    }

    fn updatePlaying(self: *Game, dt_ms: f32, input_state: *input.InputManager) void {
        if (self.clear_lines_pending_count > 0) {
            self.clear_effect_timer_ms += dt_ms;
            if (self.clear_effect_timer_ms >= self.clear_effect_delay_ms) {
                const cleared = self.board.clearLinesAt(self.clear_lines_pending[0..@as(usize, self.clear_lines_pending_count)]);
                self.applyLineClear(cleared);
                self.clear_lines_pending_count = 0;
                self.clear_effect_timer_ms = 0;
                self.spawnPiece();
            }
            return;
        }

        if (self.active_piece == null) {
            self.spawnPiece();
            if (self.state == .game_over) {
                return;
            }
        }

        if (input_state.move_left_pressed) {
            _ = self.tryMove(-1, 0);
            self.left_repeat_ms = 0;
        } else if (!input_state.move_left_held) {
            self.left_repeat_ms = -1;
        }
        if (input_state.move_right_pressed) {
            _ = self.tryMove(1, 0);
            self.right_repeat_ms = 0;
        } else if (!input_state.move_right_held) {
            self.right_repeat_ms = -1;
        }

        if (self.left_repeat_ms >= 0) {
            self.applyHoldRepeat(dt_ms, &self.left_repeat_ms, -1);
        }
        if (self.right_repeat_ms >= 0) {
            self.applyHoldRepeat(dt_ms, &self.right_repeat_ms, 1);
        }

        if (input_state.rotate_left_pressed) {
            self.tryRotate(0);
        }
        if (input_state.rotate_right_pressed) {
            self.tryRotate(1);
        }
        if (input_state.hard_drop_pressed) {
            self.hardDrop();
            return;
        }

        var gravity_step = self.gravity_ms;
        const is_soft_drop = input_state.soft_drop_pressed or input_state.soft_drop_held;
        if (is_soft_drop) {
            gravity_step = @max(25.0, self.gravity_ms * 0.06);
        }

        self.gravity_accumulator_ms += dt_ms;
        while (self.gravity_accumulator_ms >= gravity_step) {
            self.gravity_accumulator_ms -= gravity_step;
            if (self.tryMove(0, 1)) {
                if (is_soft_drop) {
                    Game.satAddU32(&self.score, 1);
                }
            } else {
                self.lockActive();
                return;
            }
        }
    }

    fn applyHoldRepeat(self: *Game, dt_ms: f32, timer: *f32, dir: i32) void {
        timer.* += dt_ms;
        if (timer.* < self.das_delay_ms) {
            return;
        }

        timer.* -= self.das_delay_ms;
        while (timer.* >= self.arr_ms) {
            _ = self.tryMove(dir, 0);
            timer.* -= self.arr_ms;
        }
    }

    fn spawnPiece(self: *Game) void {
        const spawn_x = 3;
        const spawn_y = 0;
        const p = piece_mod.Piece.init(self.next_piece, spawn_x, spawn_y);
        self.next_piece = self.rng.next();

        if (self.board.canPlacePiece(p)) {
            self.active_piece = p;
            return;
        }

        self.active_piece = null;
        self.state = .game_over;
    }

    fn tryMove(self: *Game, dx: i32, dy: i32) bool {
        if (self.active_piece == null) {
            return false;
        }

        var moved = self.active_piece.?;
        moved.x += dx;
        moved.y += dy;

        if (self.board.canPlacePiece(moved)) {
            self.active_piece = moved;
            return true;
        }
        return false;
    }

    fn tryRotate(self: *Game, dir: u8) void {
        if (self.active_piece == null) {
            return;
        }

        const rotated_piece = piece_mod.rotated(self.active_piece.?, dir);
        if (self.board.canPlacePiece(rotated_piece)) {
            self.active_piece = rotated_piece;
            return;
        }

        var kicked = rotated_piece;
        kicked.x += 1;
        if (self.board.canPlacePiece(kicked)) {
            self.active_piece = kicked;
            return;
        }

        kicked.x -= 2;
        if (self.board.canPlacePiece(kicked)) {
            self.active_piece = kicked;
            return;
        }

        kicked.x += 1;
        kicked.y += 1;
        if (self.board.canPlacePiece(kicked)) {
            self.active_piece = kicked;
            return;
        }

        kicked.y -= 2;
        if (self.board.canPlacePiece(kicked)) {
            self.active_piece = kicked;
            return;
        }
    }

    fn hardDrop(self: *Game) void {
        var dropped: u32 = 0;
        while (self.tryMove(0, 1)) {
            dropped += 1;
        }

        if (dropped > 0) {
            const add = Game.satMulU32(dropped, self.drop_bonus_multiplier);
            Game.satAddU32(&self.score, add);
        }

        self.lockActive();
    }

    fn lockActive(self: *Game) void {
        if (self.active_piece == null) {
            return;
        }

        self.board.placePiece(self.active_piece.?);
        self.active_piece = null;

        var clear_rows: [4]usize = undefined;
        const clear_count = self.board.findFullLines(&clear_rows);
        if (clear_count > 0) {
            var i: usize = 0;
            while (i < clear_count) : (i += 1) {
                self.clear_lines_pending[i] = clear_rows[i];
            }
            self.clear_lines_pending_count = @intCast(clear_count);
            self.clear_effect_timer_ms = 0;
            return;
        }

        {
            self.applyNoClear();
            self.spawnPiece();
        }
    }

    fn applyLineClear(self: *Game, count: u32) void {
        const score_lut = [5]u32{ 0, 40, 100, 300, 1200 };
        const lines = @min(count, 4);
        const base = Game.satMulU32(score_lut[@as(usize, @intCast(lines))], self.level);
        const combo_bonus = if (self.combo > 0) @min(self.combo, 2) else 0;
        Game.satAddU32(&self.score, base);
        Game.satAddU32(&self.score, Game.satMulU32(base / 5, combo_bonus));
        Game.satAddU32(&self.lines_cleared, count);
        Game.satAddU32(&self.combo, 1);

        while (self.lines_cleared >= self.lines_for_next_level) {
            if (self.level == std.math.maxInt(u32)) {
                self.lines_for_next_level = std.math.maxInt(u32);
                break;
            }
            self.level +%= 1;
            Game.satAddU32(&self.lines_for_next_level, 10);
            self.gravity_ms = @max(self.gravity_min_ms, 800.0 - 70.0 * @as(f32, @floatFromInt(self.level - 1)));
        }
    }

    fn applyNoClear(self: *Game) void {
        self.combo = 0;
    }

    fn drawDigit(
        renderer: *c.SDL_Renderer,
        x: i32,
        y: i32,
        size: i32,
        gap: i32,
        digit: u8,
        color: [4]u8,
    ) void {
        const row_bits = DIGIT_FONT[clampDigit(@intCast(digit))];
        var ry: i32 = 0;
        while (ry < 5) : (ry += 1) {
            var rx: i32 = 0;
            while (rx < 3) : (rx += 1) {
                const bit = @as(u8, 1) << @as(u3, @intCast(2 - rx));
                if ((row_bits[@as(usize, @intCast(ry))] & bit) == 0) {
                    continue;
                }
                _ = c.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
                const rect = c.SDL_Rect{
                    .x = x + rx * (size + gap),
                    .y = y + ry * (size + gap),
                    .w = size,
                    .h = size,
                };
                _ = c.SDL_RenderFillRect(renderer, &rect);
            }
        }
    }

    fn drawNumber(
        renderer: *c.SDL_Renderer,
        x: i32,
        y: i32,
        value: u32,
        size: i32,
        gap: i32,
        color: [4]u8,
    ) void {
        var digits: [10]u8 = undefined;
        var digit_count: usize = 0;
        var n = value;

        if (n == 0) {
            digits[0] = 0;
            digit_count = 1;
        } else {
            while (n > 0 and digit_count < digits.len) : (digit_count += 1) {
                digits[digit_count] = @intCast(n % 10);
                n /= 10;
            }
        }

        var i: usize = 0;
        while (i < digit_count) : (i += 1) {
            const d = digits[digit_count - 1 - i];
            drawDigit(
                renderer,
                x + @as(i32, @intCast(i)) * 4 * (size + gap),
                y,
                size,
                gap,
                d,
                color,
            );
        }
    }

    fn drawPanel(
        renderer: *c.SDL_Renderer,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
    ) void {
        _ = c.SDL_SetRenderDrawColor(renderer, 24, 29, 48, 255);
        const bg = c.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
        _ = c.SDL_RenderFillRect(renderer, &bg);

        _ = c.SDL_SetRenderDrawColor(renderer, 90, 120, 180, 255);
        _ = c.SDL_RenderDrawRect(renderer, &bg);
    }

    fn drawStatusLabel(renderer: *c.SDL_Renderer, x: i32, y: i32, color: [4]u8) void {
        _ = c.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            const px = x + @as(i32, @intCast(i)) * 3;
            const py = if ((i % 2) == 0) y else y + 2;
            const r = c.SDL_Rect{ .x = px, .y = py, .w = 2, .h = 2 };
            _ = c.SDL_RenderFillRect(renderer, &r);
        }
    }

    fn isClearingRow(self: *const Game, row: usize) bool {
        var i: usize = 0;
        while (i < @as(usize, self.clear_lines_pending_count)) : (i += 1) {
            if (self.clear_lines_pending[i] == row) {
                return true;
            }
        }
        return false;
    }

    fn drawLineClearSparkles(
        renderer: *c.SDL_Renderer,
        board_x: i32,
        board_y: i32,
        cell_size: i32,
        row: usize,
        frame_counter: u64,
    ) void {
        const row_y = board_y + @as(i32, @intCast(row)) * cell_size;
        const board_w = cell_size * @as(i32, @intCast(board.WIDTH));
        const flash: u8 = if ((frame_counter % 2) == 0) 220 else 140;

        _ = c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND);
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, flash);
        const row_rect = c.SDL_Rect{ .x = board_x, .y = row_y, .w = board_w, .h = cell_size };
        _ = c.SDL_RenderFillRect(renderer, &row_rect);

        var bx: usize = 0;
        while (bx < board.WIDTH) : (bx += 1) {
            const px = board_x + @as(i32, @intCast(bx)) * cell_size;
            const spark_pattern = (frame_counter + @as(u64, bx) + @as(u64, row)) % 8;
            if (spark_pattern < 3) {
                const offset = @as(i32, @intCast(spark_pattern % 3));
                _ = c.SDL_SetRenderDrawColor(renderer, 180, 250, 255, 255);
                const spark = c.SDL_Rect{ .x = px + offset, .y = row_y + offset, .w = 4, .h = 4 };
                _ = c.SDL_RenderFillRect(renderer, &spark);
                _ = c.SDL_SetRenderDrawColor(renderer, 255, 160, 80, 255);
                const spark2 = c.SDL_Rect{ .x = px + cell_size - offset - 4, .y = row_y + cell_size - offset - 4, .w = 4, .h = 4 };
                _ = c.SDL_RenderFillRect(renderer, &spark2);
            }
        }
        _ = c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_NONE);
    }

    pub fn render(self: *Game, renderer_ptr: *anyopaque) void {
        const renderer: *c.SDL_Renderer = @ptrCast(renderer_ptr);
        _ = c.SDL_SetRenderDrawColor(renderer, 18, 22, 30, 255);
        _ = c.SDL_RenderClear(renderer);

        const board_x: i32 = 80;
        const board_y: i32 = 40;
        const cell_size: i32 = 28;
        const board_w: i32 = cell_size * @as(i32, @intCast(board.WIDTH));
        const board_h: i32 = cell_size * @as(i32, @intCast(board.HEIGHT));

        const board_rect = c.SDL_Rect{
            .x = board_x,
            .y = board_y,
            .w = board_w,
            .h = board_h,
        };

        _ = c.SDL_SetRenderDrawColor(renderer, 28, 30, 44, 255);
        _ = c.SDL_RenderFillRect(renderer, &board_rect);
        _ = c.SDL_SetRenderDrawColor(renderer, 66, 87, 138, 255);
        _ = c.SDL_RenderDrawRect(renderer, &board_rect);

        const palette = [_][4]u8{
            .{ 0, 0, 0, 255 },
            .{ 64, 128, 255, 255 },
            .{ 255, 255, 64, 255 },
            .{ 192, 64, 192, 255 },
            .{ 64, 255, 128, 255 },
            .{ 255, 64, 64, 255 },
            .{ 80, 255, 255, 255 },
            .{ 255, 148, 64, 255 },
        };

        var by: usize = 0;
        while (by < board.HEIGHT) : (by += 1) {
            var bx: usize = 0;
            while (bx < board.WIDTH) : (bx += 1) {
                const cell = self.board.cells[board.Board.index(bx, by)];
                if (cell == 0) continue;

                const color = palette[@as(usize, @min(cell, 7))];
                _ = c.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);

                const px = board_x + @as(i32, @intCast(bx)) * cell_size;
                const py = board_y + @as(i32, @intCast(by)) * cell_size;
                var r = c.SDL_Rect{
                    .x = px,
                    .y = py,
                    .w = cell_size,
                    .h = cell_size,
                };
                _ = c.SDL_RenderFillRect(renderer, &r);
            }
        }

        if (self.clear_lines_pending_count > 0) {
            var clear_y: usize = 0;
            while (clear_y < board.HEIGHT) : (clear_y += 1) {
                if (self.isClearingRow(clear_y)) {
                    Game.drawLineClearSparkles(renderer, board_x, board_y, cell_size, clear_y, self.frame_counter);
                }
            }
        }

        if (self.active_piece) |a| {
            var blocks: [4]piece_mod.Coord = undefined;
            piece_mod.cells(a, &blocks);
            for (blocks) |b| {
                if (b.x < 0 or
                    b.y < 0 or
                    b.x >= @as(i32, @intCast(board.WIDTH)) or
                    b.y >= @as(i32, @intCast(board.HEIGHT)))
                {
                    continue;
                }

                const x = board_x + b.x * cell_size;
                const y = board_y + b.y * cell_size;
                const color = palette[@as(usize, @intFromEnum(a.kind) + 1)];
                _ = c.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
                const rect = c.SDL_Rect{ .x = x, .y = y, .w = cell_size, .h = cell_size };
                _ = c.SDL_RenderFillRect(renderer, &rect);
            }
        }

        const preview_size: i32 = 22;
        const preview_x: i32 = board_x + board_w + 28;
        const preview_y: i32 = board_y + 24;

        const next_piece: piece_mod.Piece = piece_mod.Piece.init(self.next_piece, 0, 0);
        var next_blocks: [4]piece_mod.Coord = undefined;
        piece_mod.cells(next_piece, &next_blocks);
        for (next_blocks) |b| {
            const x = preview_x + (b.x + 1) * preview_size;
            const y = preview_y + (b.y + 1) * preview_size;
            const color = palette[@as(usize, @intFromEnum(self.next_piece) + 1)];
            _ = c.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]);
            const rect = c.SDL_Rect{ .x = x, .y = y, .w = preview_size - 1, .h = preview_size - 1 };
            _ = c.SDL_RenderFillRect(renderer, &rect);
        }

        const panel_x = board_x + board_w + 16;
        const panel_w: i32 = 220;
        const panel_h: i32 = board_h;
        drawPanel(renderer, panel_x, board_y, panel_w, panel_h);

        var state_color: [4]u8 = HUD_TEXT_COLOR;
        switch (self.state) {
            .menu => state_color = .{ 64, 160, 255, 255 },
            .playing => state_color = .{ 64, 255, 128, 255 },
            .paused => state_color = .{ 255, 220, 64, 255 },
            .game_over => state_color = .{ 255, 80, 80, 255 },
        }
        _ = c.SDL_SetRenderDrawColor(renderer, state_color[0], state_color[1], state_color[2], state_color[3]);
        const state_box = c.SDL_Rect{ .x = panel_x + 14, .y = board_y + 10, .w = 18, .h = 18 };
        _ = c.SDL_RenderFillRect(renderer, &state_box);

        drawStatusLabel(renderer, panel_x + 44, board_y + 16, HUD_TEXT_COLOR);

        drawNumber(
            renderer,
            panel_x + 16,
            board_y + 58,
            self.score,
            4,
            1,
            HUD_TEXT_COLOR,
        );
        drawNumber(
            renderer,
            panel_x + 16,
            board_y + 118,
            self.lines_cleared,
            4,
            1,
            HUD_TEXT_COLOR,
        );
        drawNumber(
            renderer,
            panel_x + 16,
            board_y + 178,
            self.level,
            4,
            1,
            HUD_TEXT_COLOR,
        );
        drawNumber(
            renderer,
            panel_x + 16,
            board_y + 238,
            self.combo,
            4,
            1,
            HUD_TEXT_COLOR,
        );

    }
};
