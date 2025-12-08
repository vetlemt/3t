const std = @import("std");

const poly = @import("polygon");
const Polygon = poly.Polygon;
const vectors = @import("vectors");
const vec3 = vectors.vec3;

pub const Poly = struct {
    start: usize,
    count: usize,
};

pub const ObjectIndex = struct {
    v: usize,
    n: usize,
};

pub const Object = struct {};

fn computeFaceNormal(indices: []const ObjectIndex, verts: []const vec3) vec3 {
    // Need at least 3 vertices
    if (indices.len < 3) return .{ .x = 0, .y = 0, .z = 0 };

    const a = verts[indices[0].v];
    const b = verts[indices[1].v];
    const c = verts[indices[2].v];

    // Compute (b - a) × (c - a)
    const ab = vec3.subtract(b, a);
    const ac = vec3.subtract(c, a);

    const normal = vec3.cross(ab, ac);
    return vec3.normalize(normal);
}

pub fn importModel(comptime obj_path: []const u8) struct {
    verts: []const vec3,
    normals: []const vec3,
    polygons: []const Poly,
    indices: []const ObjectIndex,
} {
    const file = @embedFile(obj_path);

    var verts_list = std.array_list.Managed(vec3).init(std.heap.page_allocator);

    var poly_list = std.array_list.Managed(Poly).init(std.heap.page_allocator);
    var index_list = std.array_list.Managed(ObjectIndex).init(std.heap.page_allocator);
    var normals_list = std.array_list.Managed(vec3).init(std.heap.page_allocator);
    var lines = std.mem.tokenizeScalar(u8, file, '\n');

    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t");
        if (line.len == 0) continue;

        // -----------------------------
        // Vertices
        // -----------------------------
        if (std.mem.startsWith(u8, line, "v ")) {
            var parts = std.mem.tokenizeScalar(u8, line[2..], ' ');
            const x = std.fmt.parseFloat(f32, parts.next().?) catch unreachable;
            const y = std.fmt.parseFloat(f32, parts.next().?) catch unreachable;
            const z = std.fmt.parseFloat(f32, parts.next().?) catch unreachable;

            verts_list.append(.{ .x = x, .y = y, .z = z }) catch unreachable;
        }

        // -----------------------------
        // Normals
        // -----------------------------
        else if (std.mem.startsWith(u8, line, "vn ")) {
            var parts = std.mem.tokenizeScalar(u8, line[3..], ' ');
            const x = std.fmt.parseFloat(f32, parts.next().?) catch unreachable;
            const y = std.fmt.parseFloat(f32, parts.next().?) catch unreachable;
            const z = std.fmt.parseFloat(f32, parts.next().?) catch unreachable;
            normals_list.append(.{ .x = x, .y = y, .z = z }) catch unreachable;
        }

        // -----------------------------
        // Polygon (n-gon)
        // -----------------------------
        else if (std.mem.startsWith(u8, line, "f ")) {
            var parts = std.mem.splitScalar(u8, line[2..], ' ');

            const start = index_list.items.len;
            var count: usize = 0;

            while (parts.next()) |token| {
                if (token.len == 0) continue;

                // Split v/t/n
                var subtokens = std.mem.splitScalar(u8, token, '/');

                const v_str = subtokens.next().?; // "1"
                _ = subtokens.next(); // texture ignored
                const n_str = subtokens.next(); // may be null if no normals

                const v_idx = std.fmt.parseInt(usize, v_str, 10) catch unreachable;

                var n_idx: usize = 0;
                if (n_str) |ns| {
                    n_idx = std.fmt.parseInt(usize, ns, 10) catch unreachable;
                    n_idx -= 1; // 1-based to 0-based
                }

                index_list.append(.{
                    .v = v_idx - 1, // 1-based to 0-based
                    .n = n_idx,
                }) catch unreachable;

                count += 1;
            }

            // Slice of indices belonging to this polygon
            const face_indices = index_list.items[start .. start + count];
            // Compute polygon normal from geometry
            const poly_normal = computeFaceNormal(face_indices, verts_list.items);
            // Compute average normal from OBJ `vn`
            var avg_normal = vec3{ .x = 0, .y = 0, .z = 0 };
            for (face_indices) |idx| {
                avg_normal.x += normals_list.items[idx.n].x;
                avg_normal.y += normals_list.items[idx.n].y;
                avg_normal.z += normals_list.items[idx.n].z;
            }
            avg_normal = vec3.normalize(avg_normal);

            // If polygon faces the wrong way, reverse the index order
            if (vec3.dot(poly_normal, avg_normal) < 0) {
                std.mem.reverse(ObjectIndex, index_list.items[start .. start + count]);
            }

            poly_list.append(.{
                .start = start,
                .count = count,
            }) catch unreachable;
        }
    }

    return .{
        .verts = verts_list.toOwnedSlice() catch unreachable,
        .normals = normals_list.toOwnedSlice() catch unreachable,
        .polygons = poly_list.toOwnedSlice() catch unreachable,
        .indices = index_list.toOwnedSlice() catch unreachable,
    };
}
