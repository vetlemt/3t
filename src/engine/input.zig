const std = @import("std");
const os = std.os;
const io = std.io;
const posix = std.posix;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

const vectors = @import("vectors");
const vec2 = vectors.vec2;

//const c = @cImport(@cInclude("device_events.h"));
// Structure to hold shared state between threads

const KeyType = enum {
    W,
    A,
    S,
    D,
    SPACE,
    ESC,
};

const KeyState = struct {
    key: KeyType,
    held: bool,
    pub fn init(key_type: KeyType) KeyState {
        return .{ .key = key_type, .held = false };
    }
};

pub const InputKeys = struct {
    w: bool = false,
    a: bool = false,
    s: bool = false,
    d: bool = false,
    space: bool = false,
    esc: bool = false,
};

pub const InputState = struct {
    input: [1024]u8 = undefined,
    input_len: usize = 0,
    mutex: Thread.Mutex,
    done: bool = false,
    keys: InputKeys,
    mouse_movement: vec2,

    pub fn init() InputState {
        var s: InputState = undefined;
        s.mutex = Thread.Mutex{};
        return s;
    }

    pub fn pressed(self: *InputState, key: KeyType) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        switch (key) {
            KeyType.W => {
                self.keys.w = true;
            },
            KeyType.A => {
                self.keys.a = true;
            },
            KeyType.S => {
                self.keys.s = true;
            },
            KeyType.D => {
                self.keys.d = true;
            },
            KeyType.SPACE => {
                self.keys.space = true;
            },
            KeyType.ESC => {
                self.keys.esc = true;
            },
        }
    }

    pub fn released(self: *InputState, key: KeyType) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        switch (key) {
            KeyType.W => {
                self.keys.w = false;
            },
            KeyType.A => {
                self.keys.a = false;
            },
            KeyType.S => {
                self.keys.s = false;
            },
            KeyType.D => {
                self.keys.d = false;
            },
            KeyType.SPACE => {
                self.keys.space = false;
            },
            KeyType.ESC => {
                self.keys.esc = false;
            },
        }
    }

    pub fn key_change(self: *InputState, key: KeyType, value: i32) void {
        if (value == 1) self.pressed(key);
        if (value == 0) self.released(key);
    }

    pub fn append(self: *InputState, char: u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.input_len < self.input.len) {
            self.input[self.input_len] = char;
            self.input_len += 1;
        }
    }

    pub fn get_keys(self: *InputState) InputKeys {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.keys;
    }

    fn register_mouse_movement(self: *InputState, amount: i32, is_x: bool) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (is_x) {
            self.mouse_movement.x += @floatFromInt(amount);
        } else self.mouse_movement.y += @floatFromInt(amount);
    }

    pub fn get_mouse_movement(self: *InputState) vec2 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const movement = self.mouse_movement;
        self.mouse_movement.x = 0;
        self.mouse_movement.y = 0;
        return movement;
    }

    pub fn getInput(self: *InputState, allocator: Allocator) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const slice = try allocator.dupe(u8, self.input[0..self.input_len]);
        self.input_len = 0; // Reset buffer
        return slice;
    }

    pub fn setDone(self: *InputState) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.done = true;
    }

    pub fn isDone(self: *InputState) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.done;
    }
};

// Function to configure terminal to raw mode
pub fn enableRawMode() !posix.termios {
    const fd = std.fs.File.stdin().handle;
    var term = try posix.tcgetattr(fd);
    const original = term;

    // Disable canonical mode (line buffering) and echo
    term.lflag.ICANON = false;
    term.lflag.ECHO = false;
    term.cc[@intFromEnum(posix.V.MIN)] = 1; // Read at least 1 character
    term.cc[@intFromEnum(posix.V.TIME)] = 0; // No timeout

    try posix.tcsetattr(fd, .FLUSH, term);
    return original;
}

// Function to restore terminal settings
pub fn restoreTerminal(original: posix.termios) !void {
    const fd = std.fs.File.stdin().handle; //std.io.getStdIn().handle;
    try posix.tcsetattr(fd, .FLUSH, original);
}

// Thread function to read input
pub fn read_keyboard_input_thread(state: *InputState) !void {
    var keyboard_dev = try std.fs.openFileAbsolute("/dev/input/event16", .{});
    defer keyboard_dev.close();
    var keyboard_reader = keyboard_dev.reader(&.{});

    const Event = extern struct {
        tv_sec: u64,
        tv_usec: u64,
        e_type: u16,
        code: u16,
        value: i32,
    };
    var e: Event = undefined;
    var buffer: [24]u8 = undefined;
    while (!state.isDone()) {
        try keyboard_reader.interface.readSliceAll(&buffer);
        @memcpy(std.mem.asBytes(&e), &buffer);
        //std.debug.print(" keyboard: {}.{} type {}, code {} value {}\n", .{ e.tv_sec, e.tv_usec, e.e_type, e.code, e.value });

        switch (e.code) {
            1 => {
                state.key_change(KeyType.ESC, e.value);
                state.setDone();
            },
            17 => {
                state.key_change(KeyType.W, e.value);
            },
            30 => {
                state.key_change(KeyType.A, e.value);
            },
            31 => {
                state.key_change(KeyType.S, e.value);
            },
            32 => {
                state.key_change(KeyType.D, e.value);
            },
            57 => {
                state.key_change(KeyType.SPACE, e.value);
            },
            else => {},
        }
    }
}

// Thread function to read input
pub fn read_mouse_input_thread(state: *InputState) !void {
    var mouse_dev = try std.fs.openFileAbsolute("/dev/input/event6", .{});
    defer mouse_dev.close();
    var mouse_reader = mouse_dev.reader(&.{});

    const Event = extern struct {
        tv_sec: u64,
        tv_usec: u64,
        e_type: u16,
        code: u16,
        value: i32,
    };
    var e: Event = undefined;
    var buffer: [24]u8 = undefined;
    while (!state.isDone()) {
        try mouse_reader.interface.readSliceAll(&buffer);
        @memcpy(std.mem.asBytes(&e), &buffer);
        //std.debug.print(" mouse: type {x}, code {x} value {x}\n", .{ e.e_type, e.code, e.value });

        switch (e.code) {
            0 => {
                state.register_mouse_movement(e.value, true);
            },
            1 => {
                state.register_mouse_movement(e.value, false);
            },
            else => {},
        }
    }
}
