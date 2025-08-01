const std = @import("std");

const DATA_NONE = "";
const DATA_BLACK = "\x1B[0;30m";
const DATA_RED = "\x1B[0;31m";
const DATA_GREEN = "\x1B[0;32m";
const DATA_YELLOW = "\x1B[0;33m";
const DATA_BLUE = "\x1B[0;34m";
const DATA_PURPLE = "\x1B[0;35m";
const DATA_CYAN = "\x1B[0;36m";
const DATA_WHITE = "\x1B[0;37m";

const DATA_BG_BLACK = "\x1B[40m";
const DATA_BG_RED = "\x1B[41m";
const DATA_BG_GREEN = "\x1B[42m";
const DATA_BG_YELLOW = "\x1B[43m";
const DATA_BG_BLUE = "\x1B[44m";
const DATA_BG_PURPLE = "\x1B[45m";
const DATA_BG_CYAN = "\x1B[46m";
const DATA_BG_WHITE = "\x1B[47m";

const DATA_RESET = "\x1B[0m";
const DATA_CLEAR = "\x1B[2J";

pub const Color = *const []const u8;

pub const NONE: Color = &DATA_NONE[0..DATA_NONE.len];
pub const RED: Color = &DATA_RED[0..DATA_RED.len];
pub const BLACK: Color = &DATA_BLACK[0..DATA_BLACK.len];
pub const GREEN: Color = &DATA_GREEN[0..DATA_GREEN.len];
pub const YELLOW: Color = &DATA_YELLOW[0..DATA_YELLOW.len];
pub const BLUE: Color = &DATA_BLUE[0..DATA_BLUE.len];
pub const PURPLE: Color = &DATA_PURPLE[0..DATA_PURPLE.len];
pub const CYAN: Color = &DATA_CYAN[0..DATA_CYAN.len];
pub const WHITE: Color = &DATA_WHITE[0..DATA_WHITE.len];

pub const BG_RED: Color = &DATA_BG_RED[0..DATA_BG_RED.len];
pub const BG_BLACK: Color = &DATA_BG_BLACK[0..DATA_BG_BLACK.len];
pub const BG_GREEN: Color = &DATA_BG_GREEN[0..DATA_BG_GREEN.len];
pub const BG_YELLOW: Color = &DATA_BG_YELLOW[0..DATA_BG_YELLOW.len];
pub const BG_BLUE: Color = &DATA_BG_BLUE[0..DATA_BG_BLUE.len];
pub const BG_PURPLE: Color = &DATA_BG_PURPLE[0..DATA_BG_PURPLE.len];
pub const BG_CYAN: Color = &DATA_BG_CYAN[0..DATA_BG_CYAN.len];
pub const BG_WHITE: Color = &DATA_BG_WHITE[0..DATA_BG_WHITE.len];

pub const RESET: *const []const u8 = &DATA_RESET[0..DATA_RESET.len];
pub const CLEAR: *const []const u8 = &DATA_CLEAR[0..DATA_CLEAR.len];
