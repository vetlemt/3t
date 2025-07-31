const DATA_RED = "\x1B[0;31m";
const DATA_BLACK = "\x1B[0;30m";
const DATA_GREEN = "\x1B[0;32m";
const DATA_YELLOW = "\x1B[0;33m";
const DATA_BLUE = "\x1B[0;34m";
const DATA_PURPLE = "\x1B[0;35m";
const DATA_CYAN = "\x1B[0;36m";
const DATA_WHITE = "\x1B[0;37m";
const DATA_RESET = "\x1B[0m";
const DATA_CLEAR = "\x1B[2J";

pub const Type = *const []const u8;

pub const RED: *const []const u8 = &DATA_RED[0..DATA_RED.len];
pub const BLACK: *const []const u8 = &DATA_BLACK[0..DATA_BLACK.len];
pub const GREEN: *const []const u8 = &DATA_GREEN[0..DATA_GREEN.len];
pub const YELLOW: *const []const u8 = &DATA_YELLOW[0..DATA_YELLOW.len];
pub const BLUE: *const []const u8 = &DATA_BLUE[0..DATA_BLUE.len];
pub const PURPLE: *const []const u8 = &DATA_PURPLE[0..DATA_PURPLE.len];
pub const CYAN: *const []const u8 = &DATA_CYAN[0..DATA_CYAN.len];
pub const WHITE: *const []const u8 = &DATA_WHITE[0..DATA_WHITE.len];

pub const RESET: *const []const u8 = &DATA_RESET[0..DATA_RESET.len];
pub const CLEAR: *const []const u8 = &DATA_CLEAR[0..DATA_CLEAR.len];
