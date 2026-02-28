const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const InputManager = struct {
    move_left_pressed: bool = false,
    move_right_pressed: bool = false,
    soft_drop_pressed: bool = false,
    rotate_left_pressed: bool = false,
    rotate_right_pressed: bool = false,
    hard_drop_pressed: bool = false,
    pause_pressed: bool = false,
    start_pressed: bool = false,
    quit_pressed: bool = false,

    move_left_held: bool = false,
    move_right_held: bool = false,
    soft_drop_held: bool = false,

    pub fn beginFrame(self: *InputManager) void {
        self.move_left_pressed = false;
        self.move_right_pressed = false;
        self.soft_drop_pressed = false;
        self.rotate_left_pressed = false;
        self.rotate_right_pressed = false;
        self.hard_drop_pressed = false;
        self.pause_pressed = false;
        self.start_pressed = false;
        self.quit_pressed = false;
    }

    pub fn handleKeyDown(self: *InputManager, keysym: c.SDL_Keycode, repeat: u8) void {
        if (repeat != 0) return;
        switch (keysym) {
            c.SDLK_LEFT => {
                self.move_left_pressed = true;
                self.move_left_held = true;
            },
            c.SDLK_RIGHT => {
                self.move_right_pressed = true;
                self.move_right_held = true;
            },
            c.SDLK_DOWN => {
                self.soft_drop_pressed = true;
                self.soft_drop_held = true;
            },
            c.SDLK_z => self.rotate_left_pressed = true,
            c.SDLK_UP => self.rotate_right_pressed = true,
            c.SDLK_x => self.rotate_right_pressed = true,
            c.SDLK_SPACE => self.hard_drop_pressed = true,
            c.SDLK_p => self.pause_pressed = true,
            c.SDLK_RETURN => self.start_pressed = true,
            c.SDLK_ESCAPE => self.quit_pressed = true,
            else => {},
        }
    }

    pub fn handleKeyUp(self: *InputManager, keysym: c.SDL_Keycode) void {
        switch (keysym) {
            c.SDLK_LEFT => self.move_left_held = false,
            c.SDLK_RIGHT => self.move_right_held = false,
            c.SDLK_DOWN => self.soft_drop_held = false,
            else => {},
        }
    }

    pub fn consumePause(self: *InputManager) bool {
        const v = self.pause_pressed;
        self.pause_pressed = false;
        return v;
    }

    pub fn consumeStart(self: *InputManager) bool {
        const v = self.start_pressed;
        self.start_pressed = false;
        return v;
    }

    pub fn consumeQuit(self: *InputManager) bool {
        const v = self.quit_pressed;
        self.quit_pressed = false;
        return v;
    }
};
