const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Game = @import("game.zig");
const InputManager = @import("input.zig").InputManager;
const AudioSystem = @import("audio.zig").AudioSystem;

const InitError = error{
    WindowInitFailed,
    RendererInitFailed,
    InitializeFailed,
};

fn initialize() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_TIMER | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO) != 0) {
        return InitError.InitializeFailed;
    }
}

fn deinitialize() void {
    c.SDL_Quit();
}

fn createWindowAndRenderer() !struct { *c.SDL_Window, *c.SDL_Renderer } {
    const win = c.SDL_CreateWindow(
        "Tetris (Zig)",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        640,
        940,
        c.SDL_WINDOW_SHOWN,
    ) orelse return InitError.WindowInitFailed;

    const r = c.SDL_CreateRenderer(
        win,
        -1,
        c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
    ) orelse {
        c.SDL_DestroyWindow(win);
        return InitError.RendererInitFailed;
    };

    return .{ win, r };
}

const AudioPlaybackState = enum {
    stopped,
    playing,
    paused,
};

pub fn main() !void {
    try initialize();
    defer deinitialize();

    const win, const renderer = try createWindowAndRenderer();
    defer c.SDL_DestroyRenderer(renderer);
    defer c.SDL_DestroyWindow(win);

    var game = Game.Game.init();
    var input = InputManager{};
    var audio = AudioSystem{};
    try audio.init();
    const music_path: [*:0]const u8 = "assets/tetris.wav";
    var audio_state: AudioPlaybackState = .stopped;

    var event: c.SDL_Event = undefined;
    var last_ms = c.SDL_GetTicks64();

    while (game.running) {
        input.beginFrame();

        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => game.running = false,
                c.SDL_KEYDOWN => input.handleKeyDown(event.key.keysym.sym, event.key.repeat),
                c.SDL_KEYUP => input.handleKeyUp(event.key.keysym.sym),
                else => {},
            }
        }

        const now_ms = c.SDL_GetTicks64();
        const dt_ms: f32 = @as(f32, @floatFromInt(now_ms - last_ms));
        last_ms = now_ms;

        game.update(dt_ms, &input);

        if (audio.initialized) {
            switch (game.state) {
                .playing => {
                    switch (audio_state) {
                        .stopped => {
                            AudioSystem.playBackground(&audio, music_path, true) catch {};
                            audio_state = .playing;
                        },
                        .paused => {
                            AudioSystem.resumeMusic(&audio);
                            audio_state = .playing;
                        },
                        .playing => {
                            if (!AudioSystem.isActive(&audio)) {
                                AudioSystem.playBackground(&audio, music_path, true) catch {};
                            }
                        },
                    }
                },
                .paused => {
                    if (audio_state == .playing) {
                        AudioSystem.pauseMusic(&audio);
                        audio_state = .paused;
                    }
                },
                .menu, .game_over => {
                    if (audio_state != .stopped) {
                        AudioSystem.stop(&audio);
                        audio_state = .stopped;
                    }
                },
            }
        }

        game.render(@as(*anyopaque, @ptrCast(renderer)));
        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(16);
    }

    if (audio.initialized) {
        AudioSystem.stop(&audio);
    }
    audio.shutdown();
}
