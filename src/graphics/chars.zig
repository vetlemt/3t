const DATA_NONE = " ";
const DATA_FULL = "█";
const DATA_LOWER = "▄";
const DATA_UPPER = "▀";
const DATA_LEFT = "▌";
const DATA_RIGHT = "▐";

pub const Pointer = *const []const u8;

pub const NONE: *const []const u8 = &DATA_NONE[0..DATA_NONE.len];
pub const FULL: *const []const u8 = &DATA_FULL[0..DATA_FULL.len];
pub const LOWER: *const []const u8 = &DATA_LOWER[0..DATA_LOWER.len];
pub const UPPER: *const []const u8 = &DATA_UPPER[0..DATA_UPPER.len];
pub const LEFT: *const []const u8 = &DATA_LEFT[0..DATA_LEFT.len];
pub const RIGHT: *const []const u8 = &DATA_RIGHT[0..DATA_RIGHT.len];
