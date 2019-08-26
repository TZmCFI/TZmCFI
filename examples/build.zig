const builtin = @import("builtin");
const std = @import("std");
const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;
const LibExeObjStep = @import("std").build.LibExeObjStep;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const want_gdb = b.option(bool, "gdb", "Build for using gdb with qemu") orelse false;
    const enable_trace = b.option(bool, "trace", "Enable tracing") orelse false;

    const arch = builtin.Arch{ .thumb = .v8m_mainline };

    // The utility program for creating a CMSE import library
    // -------------------------------------------------------
    const mkimplib = "../target/debug/tzmcfi_mkimplib";

    // The Secure part
    // -------------------------------------------------------
    // This part is shared by all Non-Secure applications.
    const exe_s_name = if (want_gdb) "secure-dbg" else "secure";
    const exe_s = b.addExecutable(exe_s_name, "secure.zig");
    exe_s.setLinkerScriptPath("secure/linker.ld");
    exe_s.setTarget(arch, .freestanding, .eabi);
    exe_s.setBuildMode(mode);
    exe_s.addAssemblyFile("common/startup.s");
    exe_s.setOutputDir("zig-cache");
    exe_s.addPackagePath("tzmcfi-monitor", "../src/monitor.zig");
    exe_s.addPackagePath("arm_cmse", "../src/drivers/arm_cmse.zig");
    exe_s.addPackagePath("arm_m", "../src/drivers/arm_m.zig");
    exe_s.addIncludeDir("../include");
    exe_s.addBuildOption(bool, "ENABLE_TRACE", enable_trace);

    // CMSE import library (generated from the Secure binary)
    // -------------------------------------------------------
    // It includes the absolute addresses of Non-Secure-callable functions
    // exported by the Secure code. Usually it's generated by passing the
    // `--cmse-implib` option to a supported version of `arm-none-eabi-gcc`, but
    // since it might not be available, we use a custom tool to do that.
    const implib_path = "zig-cache/secure_implib.s";
    var implib_args = std.ArrayList([]const u8).init(b.allocator);
    try implib_args.appendSlice([_][]const u8{
        mkimplib,
        exe_s.getOutputPath(),
        "-o",
        implib_path,
    });

    const implib = b.addSystemCommand(implib_args.toSliceConst());
    implib.step.dependOn(&exe_s.step);

    const implib_step = b.step("implib", "Create a CMSE import library");
    implib_step.dependOn(&implib.step);

    // FreeRTOS (This runs in Non-Secure mode)
    // -------------------------------------------------------
    const kernel_name = if (want_gdb) "freertos-dbg" else "freertos";
    const kernel = b.addStaticLibrary(kernel_name, "freertos.zig");
    kernel.setTarget(arch, .freestanding, .eabi);
    kernel.setBuildMode(mode);

    const kernel_include_dirs = [_][]const u8{
        "freertos/include",
        "freertos/portable/GCC/ARM_CM33/non_secure",
        "freertos/portable/GCC/ARM_CM33/secure",
        "nonsecure-common", // For `FreeRTOSConfig.h`
    };
    for (kernel_include_dirs) |path| {
        kernel.addIncludeDir(path);
    }

    const kernel_source_files = [_][]const u8{
        "freertos/croutine.c",
        "freertos/event_groups.c",
        "freertos/list.c",
        "freertos/queue.c",
        "freertos/stream_buffer.c",
        "freertos/tasks.c",
        "freertos/timers.c",
        "freertos/portable/Common/mpu_wrappers.c",
        "freertos/portable/GCC/ARM_CM33/non_secure/port.c",
        "freertos/portable/GCC/ARM_CM33/non_secure/portasm.c",
        "freertos/portable/MemMang/heap_4.c",
    };
    for (kernel_source_files) |file| {
        kernel.addCSourceFile(file, [_][]const u8{});
    }

    // The Non-Secure part
    // -------------------------------------------------------
    // This build script defines multiple Non-Secure applications.
    // There are separate build steps defined for each application, allowing
    // the user to choose whichever application they want to start.
    const ns_app_deps = NsAppDeps{
        .arch = arch,
        .mode = mode,
        .want_gdb = want_gdb,
        .implib_path = implib_path,
        .implib_step = &implib.step,
        .exe_s = exe_s,
        .kernel_include_dirs = &kernel_include_dirs,
        .kernel = kernel,
    };
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "rtosbasic",
        .root = "nonsecure-rtosbasic.zig",
        .use_freertos = true,
    });
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "basic",
        .root = "nonsecure-basic.zig",
        .use_freertos = false,
    });

    // We don't define the default rule.
}

const NsAppDeps = struct {
    // General
    arch: builtin.Arch,
    mode: builtin.Mode,
    want_gdb: bool,

    // Secure dependency
    implib_path: []const u8,
    implib_step: *Step,
    exe_s: *LibExeObjStep,

    // FreeRTOS
    kernel_include_dirs: []const []const u8,
    kernel: *LibExeObjStep,
};

const NsAppInfo = struct {
    name: []const u8,
    root: []const u8,
    use_freertos: bool = false,
};

/// Define build steps for a single example application.
///
///  - `build:name`
///  - `qemu:name`
///
fn defineNonSecureApp(
    b: *Builder,
    ns_app_deps: NsAppDeps,
    comptime app_info: NsAppInfo,
) !void {
    const arch = ns_app_deps.arch;
    const mode = ns_app_deps.mode;
    const want_gdb = ns_app_deps.want_gdb;
    const implib_path = ns_app_deps.implib_path;
    const implib_step = ns_app_deps.implib_step;
    const exe_s = ns_app_deps.exe_s;
    const kernel_include_dirs = ns_app_deps.kernel_include_dirs;
    const kernel = ns_app_deps.kernel;

    const name = app_info.name;

    // The Non-Secure part
    // -------------------------------------------------------
    const exe_ns_name = if (want_gdb) name ++ "-dbg" else name;
    const exe_ns = b.addExecutable(exe_ns_name, app_info.root);
    exe_ns.setLinkerScriptPath("nonsecure-common/linker.ld");
    exe_ns.setTarget(arch, .freestanding, .eabi);
    exe_ns.setBuildMode(mode);
    exe_ns.addAssemblyFile("common/startup.s");
    exe_ns.addAssemblyFile("../src/nonsecure_vector.S");
    exe_ns.setOutputDir("zig-cache");
    exe_ns.addIncludeDir("../include");
    exe_ns.addPackagePath("arm_m", "../src/drivers/arm_m.zig");

    if (app_info.use_freertos) {
        for (kernel_include_dirs) |path| {
            exe_ns.addIncludeDir(path);
        }
        exe_ns.linkLibrary(kernel);
        exe_ns.addCSourceFile("nonsecure-common/oshooks.c", [_][]const u8{});
    }

    exe_ns.addAssemblyFile(implib_path);
    exe_ns.step.dependOn(implib_step);

    const exe_both = b.step("build:" ++ name, "Build Secure and Non-Secure executables");
    exe_both.dependOn(&exe_s.step);
    exe_both.dependOn(&exe_ns.step);

    // Launch QEMU
    // -------------------------------------------------------
    const qemu = b.step("qemu:" ++ name, "Run the program in qemu");
    var qemu_args = std.ArrayList([]const u8).init(b.allocator);

    const qemu_device_arg = try std.fmt.allocPrint(
        b.allocator,
        "loader,file={}",
        exe_ns.getOutputPath(),
    );
    try qemu_args.appendSlice([_][]const u8{
        "qemu-system-arm",
        "-kernel",
        exe_s.getOutputPath(),
        "-device",
        qemu_device_arg,
        "-machine",
        "mps2-an505",
        "-nographic",
        "-d",
        "guest_errors",
        "-semihosting",
        "-semihosting-config",
        "target=native",
        "-s",
    });
    if (want_gdb) {
        try qemu_args.appendSlice([_][]const u8{"-S"});
    }
    const run_qemu = b.addSystemCommand(qemu_args.toSliceConst());
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(exe_both);
}
