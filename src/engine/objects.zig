const std = @import("std");
const std = @import("std");

const poly = @import("polygon");
const pp = poly.Polygon;
const vectors = @import("vectors");
const vec3 = vectors.vec3;

const Polygon = struct {
    start: usize,
    count: usize,
};

fn parseObj(comptime obj_path: []const u8) struct {
    verts: []const vec3,
    polygons: []const Polygon,
    indices: []const usize,
} {
    var verts_list = std.ArrayList(vec3).init(std.heap.page_allocator);

    var poly_list = std.ArrayList(Polygon).init(std.heap.page_allocator);
    var index_list = std.ArrayList(usize).init(std.heap.page_allocator);

    var lines = std.mem.tokenizeScalar(u8, obj_path, '\n');

    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t");
        if (line.len == 0) continue;

        // -----------------------------
        // Vertices
        // -----------------------------
        if (std.mem.startsWith(u8, line, "v ")) {
            var parts = std.mem.tokenizeScalar(u8, line[2..], ' ');
            const x = std.fmt.parseFloat(f32, parts.next().?, 10) catch unreachable;
            const y = std.fmt.parseFloat(f32, parts.next().?, 10) catch unreachable;
            const z = std.fmt.parseFloat(f32, parts.next().?, 10) catch unreachable;

            verts_list.append(.{ .x = x, .y = y, .z = z }) catch unreachable;
        }

        // -----------------------------
        // Polygon (n-gon)
        // -----------------------------
        else if (std.mem.startsWith(u8, line, "f ")) {
            var parts = std.mem.tokenizeScalar(u8, line[2..], ' ');

            const start = index_list.items.len;
            var count: usize = 0;

            while (parts.next()) |token| {
                const slash = std.mem.indexOfScalar(u8, token, '/');
                const vert_str =
                    if (slash) |i| token[0..i] else token;

                const idx1 = std.fmt.parseInt(usize, vert_str, 10) catch unreachable;

                index_list.append(idx1 - 1) catch unreachable;
                count += 1;
            }

            poly_list.append(.{
                .start = start,
                .count = count,
            }) catch unreachable;
        }
    }

    return .{
        .verts = verts_list.toOwnedSlice() catch unreachable,
        .polygons = poly_list.toOwnedSlice() catch unreachable,
        .indices = index_list.toOwnedSlice() catch unreachable,
    };
}
