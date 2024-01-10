const builtin = @import("builtin");
const std = @import("std");

const sdl_path = thisDir() ++ "/lib/SDL";

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}

pub fn link(b: *std.Build, exe: *std.Build.Step.Compile, linkage: std.Build.Step.Compile.Linkage) void {
    exe.linkLibC();

    b.installBinFile(sdl_path ++ "/bin/SDL2.dll", "SDL2.dll");
    b.installBinFile(sdl_path ++ "/bin/SDL2_image.dll", "SDL2_image.dll");
    b.installBinFile(sdl_path ++ "/bin/SDL2_ttf.dll", "SDL2_ttf.dll");

    exe.addIncludePath(.{ .path = sdl_path ++ "/include" });
    exe.addLibraryPath(.{ .path = sdl_path ++ "/lib" });

    if (builtin.target.isDarwin()) {
        exe.linkSystemLibrary("freetype");
        exe.linkSystemLibrary("harfbuzz");
        exe.linkSystemLibrary("bz2");
        exe.linkSystemLibrary("zlib");
        exe.linkSystemLibrary("graphite2");
        exe.linkSystemLibrary("iconv");

        exe.linkFramework("IOKit");
        exe.linkFramework("Cocoa");
        exe.linkFramework("CoreAudio");
        exe.linkFramework("Carbon");
        exe.linkFramework("Metal");
        exe.linkFramework("QuartzCore");
        exe.linkFramework("AudioToolbox");
        exe.linkFramework("ForceFeedback");
        exe.linkFramework("GameController");
        exe.linkFramework("CoreHaptics");
    } else if (builtin.target.os.tag == .windows) {
        switch (linkage) {
            .static => {
                exe.addObjectFile(.{ .path = sdl_path ++ "/lib/libSDL2.a" });
                exe.addObjectFile(.{ .path = sdl_path ++ "/lib/libSDL2_image.a" });
                exe.addObjectFile(.{ .path = sdl_path ++ "/lib/libSDL2_ttf.a" });

                const static_libs = [_][]const u8{
                    "setupapi",
                    "user32",
                    "gdi32",
                    "winmm",
                    "imm32",
                    "ole32",
                    "oleaut32",
                    "shell32",
                    "version",
                    "uuid",
                    "rpcrt4",
                };

                for (static_libs) |lib| {
                    exe.linkSystemLibrary(lib);
                }
            },
            .dynamic => {
                exe.addObjectFile(.{ .path = sdl_path ++ "/lib/libSDL2.dll.a" });
                exe.addObjectFile(.{ .path = sdl_path ++ "/lib/libSDL2_image.dll.a" });
                exe.addObjectFile(.{ .path = sdl_path ++ "/lib/libSDL2_ttf.dll.a" });
            },
        }
    } else if (builtin.os.tag == .linux) {
        exe.linkSystemLibrary("sdl2");
        exe.linkSystemLibrary("sdl2_image");
        exe.linkSystemLibrary("sdl2_ttf");
    }

    const lib = switch (linkage) {
        .static => b.addStaticLibrary(.{
            .name = "sdl2",
            .root_source_file = .{ .path = thisDir() ++ "/src/sdl.zig" },
            .target = exe.root_module.resolved_target.?,
            .optimize = exe.root_module.optimize.?,
        }),
        .dynamic => b.addSharedLibrary(.{
            .name = "sdl2",
            .root_source_file = .{ .path = thisDir() ++ "/src/sdl.zig" },
            .target = exe.root_module.resolved_target.?,
            .optimize = exe.root_module.optimize.?,
        }),
    };

    exe.linkLibrary(lib);
}

pub fn getModule(b: *std.Build) *std.Build.Module {
    return b.createModule(.{
        .source_file = .{ .path = thisDir() ++ "/src/sdl.zig" },
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const basic_example = b.addExecutable(.{
        .name = "basic",
        .root_source_file = .{ .path = "example/basic.zig" },
        .target = target,
        .optimize = optimize,
    });

    link(b, basic_example, .static);

    const run_cmd = b.addRunArtifact(basic_example);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("example-basic", "Run the basic example");
    run_step.dependOn(&run_cmd.step);
}
