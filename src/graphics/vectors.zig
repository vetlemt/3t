pub const vec2i = struct {
    x: i64,
    y: i64,
};

pub const vec2 = struct {
    x: f64,
    y: f64,

    pub fn from(v2i: vec2i) vec2 {
        return vec2{
            .x = @as(f64, @floatFromInt(v2i.x)),
            .y = @as(f64, @floatFromInt(v2i.y)),
        };
    }

    pub fn to_int(self: *vec2) vec2i {
        return vec2i{
            .x = @as(i64, @intFromFloat(self.x)),
            .y = @as(i64, @intFromFloat(self.y)),
        };
    }
};

pub const vec2z = struct { x: i64, y: i64, z: f64 };
pub const vec1z = struct {
    x: i64,
    z: f64,

    pub fn to_vec2z(self: *const vec1z, y: i64) vec2z {
        return vec2z{ .x = self.x, .y = y, .z = self.z };
    }
};

pub const vec3 = struct { x: f64 = 0, y: f64 = 0, z: f64 = 0 };
