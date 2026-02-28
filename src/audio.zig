const std = @import("std");

const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_mixer.h");
});

pub const AudioSystem = struct {
    initialized: bool = false,
    music: ?*c.Mix_Music = null,
    path_loaded: [*:0]const u8 = undefined,
    path_loaded_set: bool = false,
    volume: c_int = c.MIX_MAX_VOLUME,

    pub fn init(self: *AudioSystem) !void {
        if (c.Mix_OpenAudio(44100, c.MIX_DEFAULT_FORMAT, 2, 1024) < 0) {
            std.debug.print("Mix_OpenAudio failed: {s}\n", .{std.mem.span(c.Mix_GetError())});
            return;
        }
        const init_flags = c.Mix_Init(c.MIX_INIT_OGG | c.MIX_INIT_OPUS);
        if ((init_flags & (c.MIX_INIT_OGG | c.MIX_INIT_OPUS)) == 0) {
            std.debug.print("Mix_Init failed: requested={x}, got={x}, {s}\n", .{
                (c.MIX_INIT_OGG | c.MIX_INIT_OPUS),
                init_flags,
                std.mem.span(c.Mix_GetError()),
            });
            c.Mix_CloseAudio();
            return;
        }
        self.initialized = true;
        _ = c.Mix_VolumeMusic(self.volume);
    }

    pub fn playBackground(self: *AudioSystem, path: [*:0]const u8, loop: bool) !void {
        if (!self.initialized) return;

        if (!self.path_loaded_set or self.path_loaded != path) {
            if (self.music) |m| {
                _ = c.Mix_HaltMusic();
                c.Mix_FreeMusic(m);
                self.music = null;
            }
            self.music = c.Mix_LoadMUS(path) orelse {
                std.debug.print("Mix_LoadMUS failed for path {s}: {s}\n", .{
                    std.mem.span(path),
                    std.mem.span(c.Mix_GetError()),
                });
                return;
            };
            self.path_loaded = path;
            self.path_loaded_set = true;
        }

        const loops: c_int = if (loop) -1 else 0;
        if (c.Mix_PausedMusic() == 1) {
            c.Mix_ResumeMusic();
            return;
        }
        if (c.Mix_PlayingMusic() == 1) return;

        if (c.Mix_PlayMusic(self.music, loops) < 0) {
            std.debug.print("Mix_PlayMusic failed: {s}\n", .{std.mem.span(c.Mix_GetError())});
        }
    }

    pub fn pauseMusic(self: *AudioSystem) void {
        if (!self.initialized) return;
        if (c.Mix_PlayingMusic() == 1) {
            c.Mix_PauseMusic();
        }
    }

    pub fn resumeMusic(self: *AudioSystem) void {
        if (!self.initialized) return;
        if (c.Mix_PausedMusic() == 1) {
            c.Mix_ResumeMusic();
        }
    }

    pub fn stop(self: *AudioSystem) void {
        if (!self.initialized) return;
        _ = c.Mix_HaltMusic();
    }

    pub fn isActive(self: *AudioSystem) bool {
        if (!self.initialized) return false;
        return c.Mix_PlayingMusic() == 1 or c.Mix_PausedMusic() == 1;
    }

    pub fn shutdown(self: *AudioSystem) void {
        if (!self.initialized) return;

        _ = c.Mix_HaltMusic();
        if (self.music) |m| {
            c.Mix_FreeMusic(m);
            self.music = null;
        }
        c.Mix_Quit();
        c.Mix_CloseAudio();
        self.initialized = false;
    }
};
