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

pub const vec3 = struct {
    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,

    pub fn add(a: vec3, b: vec3) vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn subtract(a: vec3, b: vec3) vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn dot(a: vec3, b: vec3) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: vec3, b: vec3) vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn length(v: vec3) f64 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: vec3) vec3 {
        const len = vec3.length(v);
        if (len == 0) return v; // avoid divide-by-zero
        return .{
            .x = v.x / len,
            .y = v.y / len,
            .z = v.z / len,
        };
    }
};
