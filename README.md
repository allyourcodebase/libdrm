# libdrm zig

[libdrm](https://gitlab.freedesktop.org/mesa/libdrm), packaged for the Zig build system.

Core library only (no GPU-specific sub-libraries).

## Using

First, update your `build.zig.zon`:

```
zig fetch --save git+https://github.com/allyourcodebase/libdrm.git
```

Then in your `build.zig`:

```zig
const libdrm = b.dependency("libdrm", .{ .target = target, .optimize = optimize });
exe.linkLibrary(libdrm.artifact("drm"));
```
