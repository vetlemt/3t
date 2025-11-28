const std = @import("std");
const os = std.os;
const io = std.io;
const posix = std.posix;
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

// Structure to hold shared state between threads
pub const InputState = struct {
    input: [1024]u8,
    input_len: usize,
    mutex: Thread.Mutex,
    done: bool,

    pub fn init() InputState {
        return .{
            .input = undefined,
            .input_len = 0,
            .mutex = Thread.Mutex{},
            .done = false,
        };
    }

    pub fn append(self: *InputState, char: u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.input_len < self.input.len) {
            self.input[self.input_len] = char;
            self.input_len += 1;
        }
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
pub fn readInput(state: *InputState) !void {
    var stdin = std.fs.File.stdin().reader(&.{});
    const reader = &stdin.interface;

    var byte: [1]u8 = undefined;
    while (!state.isDone()) {
        reader.readSliceAll(&byte) catch |err| {
            std.debug.print("Error reading input: {}\n", .{err});
            return;
        };
        state.append(byte[0]);
        if (byte[0] == 'q') { // Exit on 'q'
            state.setDone();
            break;
        }
    }
}
