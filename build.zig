const std = @import("std");
const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "Library linkage type") orelse .static;

    const upstream = b.dependency("upstream", .{});
    const src = upstream.path("");

    const os = target.result.os.tag;
    const is_linux = os == .linux;

    const gen_fourcc = b.addExecutable(.{
        .name = "gen_table_fourcc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gen_table_fourcc.zig"),
            .target = b.graph.host,
        }),
    });
    const gen_run = b.addRunArtifact(gen_fourcc);
    gen_run.addFileArg(src.path(b, "include/drm/drm_fourcc.h"));
    const fourcc_wf = b.addWriteFiles();
    _ = fourcc_wf.addCopyFile(gen_run.captureStdOut(.{}), "generated_static_table_fourcc.h");

    // Module
    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    mod.addIncludePath(src);
    mod.addIncludePath(src.path(b, "include/drm"));
    mod.addIncludePath(fourcc_wf.getDirectory());

    const flags: []const []const u8 = flags: {
        var list: std.ArrayListUnmanaged([]const u8) = .empty;
        try list.ensureTotalCapacity(b.allocator, 1 << 4);

        list.appendSliceAssumeCapacity(&.{
            "-fvisibility=hidden",
            "-DHAVE_LIBDRM_ATOMIC_PRIMITIVES=1",
            "-DHAVE_VISIBILITY=1",
            "-D_GNU_SOURCE",
            "-DHAVE_OPEN_MEMSTREAM=1",
            "-DHAVE_SECURE_GETENV=1",
            "-DHAVE_SYS_SELECT_H=1",
            "-DHAVE_ALLOCA_H=1",
        });
        if (is_linux) list.appendAssumeCapacity("-DMAJOR_IN_SYSMACROS=1");
        break :flags try list.toOwnedSlice(b.allocator);
    };

    mod.addCSourceFiles(.{ .root = src, .files = &.{
        "xf86drm.c",
        "xf86drmHash.c",
        "xf86drmRandom.c",
        "xf86drmSL.c",
        "xf86drmMode.c",
    }, .flags = flags });

    // Library
    const lib = b.addLibrary(.{ .name = "drm", .root_module = mod, .linkage = linkage });

    // Install headers
    inline for (.{ "xf86drm.h", "xf86drmMode.h", "libsync.h" }) |h|
        lib.installHeader(src.path(b, h), h);
    lib.installHeadersDirectory(src.path(b, "include/drm"), "libdrm", .{});

    b.installArtifact(lib);
}
