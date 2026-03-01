const std = @import("std");
const LinkMode = std.builtin.LinkMode;

const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os = target.result.os.tag;
    const arch = target.result.cpu.arch;

    const options = .{
        .linkage = b.option(LinkMode, "linkage", "Library linkage type") orelse
            .static,
    };

    const flags: []const []const u8 = flags: {
        var list: std.ArrayList([]const u8) = .empty;
        try list.ensureTotalCapacity(b.allocator, 1 << 2);

        list.appendAssumeCapacity("-fvisibility=hidden");
        if (os.isBSD()) list.appendSliceAssumeCapacity(&.{ "-Wno-macro-redefined", "-Wno-#warnings" });

        break :flags try list.toOwnedSlice(b.allocator);
    };

    const upstream = b.dependency("libdrm_c", .{});

    const fourcc_wf = b.addWriteFiles();
    const gen = b.addRunArtifact(b.addExecutable(.{
        .name = "gen_table_fourcc",
        .root_module = b.createModule(.{ .root_source_file = b.path("tools/gen_table_fourcc.zig"), .target = b.graph.host }),
    }));
    gen.addFileArg(upstream.path("include/drm/drm_fourcc.h"));
    _ = fourcc_wf.addCopyFile(gen.captureStdOut(.{}), "generated_static_table_fourcc.h");

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("include/drm"));
    mod.addIncludePath(fourcc_wf.getDirectory());
    mod.addCMacro("HAVE_LIBDRM_ATOMIC_PRIMITIVES", "1");
    mod.addCMacro("HAVE_VISIBILITY", "1");
    mod.addCMacro("_GNU_SOURCE", "");
    mod.addCMacro("HAVE_OPEN_MEMSTREAM", "1");
    mod.addCMacro("HAVE_SECURE_GETENV", "1");
    mod.addCMacro("HAVE_SYS_SELECT_H", "1");
    mod.addCMacro("HAVE_ALLOCA_H", "1");
    if (os == .linux) mod.addCMacro("MAJOR_IN_SYSMACROS", "1");
    if (os.isBSD()) mod.addCMacro("HAVE_SYS_SYSCTL_H", "1");
    if (arch.endian() == .big) mod.addCMacro("HAVE_BIG_ENDIAN", "1");

    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = srcs, .flags = flags });

    const lib = b.addLibrary(.{
        .name = "drm",
        .root_module = mod,
        .linkage = options.linkage,
        .version = try .parse(manifest.version),
    });
    inline for (.{ "xf86drm.h", "xf86drmMode.h", "libsync.h" }) |h|
        lib.installHeader(upstream.path(h), h);
    lib.installHeadersDirectory(upstream.path("include/drm"), "libdrm", .{});
    lib.installHeadersDirectory(upstream.path("include/drm"), "", .{});
    b.installArtifact(lib);
}

const srcs: []const []const u8 = &.{
    "xf86drm.c",
    "xf86drmHash.c",
    "xf86drmRandom.c",
    "xf86drmSL.c",
    "xf86drmMode.c",
};
