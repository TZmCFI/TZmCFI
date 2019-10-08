const builtin = @import("builtin");
const std = @import("std");
const Builder = @import("std").build.Builder;
const Step = @import("std").build.Step;
const LibExeObjStep = @import("std").build.LibExeObjStep;
const warn = @import("std").debug.warn;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const want_gdb = b.option(bool, "gdb", "Build for using gdb with qemu") orelse false;
    const enable_trace = b.option(bool, "trace", "Enable tracing") orelse false;
    const enable_profile = b.option(bool, "profile", "Enable TZmCFI profiler (e.g., TCDebugDumpProfile)") orelse false;
    const enable_cfi = b.option(bool, "cfi", "Enable TZmCFI (default = true)") orelse false;

    const cfi_opts = CfiOpts {
        .ctx = b.option(bool, "cfi-ctx", "Enable TZmCFI context management (default = cfi)")
            orelse enable_cfi,
        .ses = b.option(bool, "cfi-ses", "Enable TZmCFI shadow exception stacks (default = cfi)")
            orelse enable_cfi,
        .ss = b.option(bool, "cfi-ss", "Enable TZmCFI shadow stacks (default = cfi)")
            orelse enable_cfi,
        .icall = b.option(bool, "cfi-icall", "Enable indirect call CFI (default = cfi)")
            orelse enable_cfi,
    };
    try cfi_opts.validate();

    if (enable_profile and !enable_trace) {
        warn("error: -Dprofile is pointless without -Dtrace\r\n");
        return error.BadTracingOptions;
    }

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
    exe_s.addAssemblyFile("common/startup.S");
    exe_s.setOutputDir("zig-cache");
    exe_s.addPackagePath("tzmcfi-monitor", "../src/monitor.zig");
    exe_s.addPackagePath("arm_cmse", "../src/drivers/arm_cmse.zig");
    exe_s.addPackagePath("arm_m", "../src/drivers/arm_m.zig");
    exe_s.addIncludeDir("../include");
    exe_s.addBuildOption(bool, "ENABLE_TRACE", enable_trace);
    exe_s.addBuildOption(bool, "ENABLE_PROFILE", enable_profile);

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
    var kernel_build_args = std.ArrayList([]const u8).init(b.allocator);
    try kernel_build_args.append("-flto");
    try cfi_opts.addCFlagsTo(&kernel_build_args);
    for (kernel_source_files) |file| {
        kernel.addCSourceFile(file, kernel_build_args.toSliceConst());
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
        .cfi_opts = &cfi_opts,
        .implib_path = implib_path,
        .implib_step = &implib.step,
        .exe_s = exe_s,
        .kernel_include_dirs = &kernel_include_dirs,
        .kernel = kernel,
    };
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "rtosbasic",
        .root = "nonsecure-rtosbasic.zig",
        .meta = struct {
            const use_freertos = true;
            fn modifyExeStep(_builder: *Builder, step: *LibExeObjStep, opts: ModifyExeStepOpts) error{}!void {
                step.addCSourceFile("nonsecure-rtosbasic.cpp", opts.c_flags);
            }
        },
    });
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "basic",
        .root = "nonsecure-basic.zig",
    });
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "bench-coremark",
        .root = "nonsecure-bench-coremark.zig",
        .meta = @import("nonsecure-bench-coremark/meta.zig"),
    });
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "bench-latency",
        .root = "nonsecure-bench-latency.zig",
    });
    try defineNonSecureApp(b, ns_app_deps, NsAppInfo{
        .name = "bench-rtos",
        .root = "nonsecure-bench-rtos.zig",
        .meta = struct {
            const use_freertos = true;
        },
    });

    // We don't define the default rule.
}

const CfiOpts = struct {
    /// Use TZmCFI context management API
    ctx: bool,
    /// TZmCFI shadow exception stacks
    ses: bool,
    /// TZmCFI shadow stacks
    ss: bool,
    /// LLVM indirect call validator
    icall: bool,

    const Self = @This();

    fn validate(self: *const Self) !void {
        if (self.ss and !self.ctx) {
            // Shadow stacks are managed by context management API.
            warn("error: cfi-ss requires cfi-ctx\n");
            return error.IncompatibleCfiOpts;
        }

        if (self.ses and !self.ctx) {
            // Shadow exception stacks are managed by context management API.
            warn("error: cfi-ses requires cfi-ctx\n");
            return error.IncompatibleCfiOpts;
        }

        if (self.ss and !self.ses) {
            // TZmCFI's shadow stacks do not work without shadow exception stacks.
            // Probably because the shadow stack routines mess up the lowest bit
            // of `EXC_RETURN`.
            warn("error: cfi-ss requires cfi-ses\n");
            return error.IncompatibleCfiOpts;
        }
    }

    fn addCFlagsTo(self: *const Self, args: var) !void {
        try args.append(if (self.ses) "-DHAS_TZMCFI_SES=1" else "-DHAS_TZMCFI_SES=0");
        if (self.ss) {
            try args.append("-fsanitize=shadow-call-stack");
        }
        if (self.icall) {
            try args.append("-fsanitize=cfi-icall");
        }
    }

    fn configureBuildStep(self: *const Self, step: *LibExeObjStep) void {
        step.enable_shadow_call_stack = self.ss;
        // TODO: Enable `cfi-icall` on Zig code

        step.addBuildOption(bool, "HAS_TZMCFI_CTX", self.ctx);
        step.addBuildOption(bool, "HAS_TZMCFI_SES", self.ses);
    }
};

const NsAppDeps = struct {
    // General
    arch: builtin.Arch,
    mode: builtin.Mode,
    want_gdb: bool,
    cfi_opts: *const CfiOpts,

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
    meta: type = struct {},
    c_source: ?[]const u8 = null,
    use_freertos: bool = false,
};

pub const ModifyExeStepOpts = struct {
    c_flags: [][]const u8,
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

    // Additional options
    // -------------------------------------------------------
    const meta = app_info.meta;
    const use_freertos = if (@hasDecl(meta, "use_freertos")) meta.use_freertos else false;

    // The Non-Secure part
    // -------------------------------------------------------
    const exe_ns_name = if (want_gdb) name ++ "-dbg" else name;
    const exe_ns = b.addExecutable(exe_ns_name, app_info.root);
    exe_ns.setLinkerScriptPath("nonsecure-common/linker.ld");
    exe_ns.setTarget(arch, .freestanding, .eabi);
    exe_ns.setBuildMode(mode);
    exe_ns.addAssemblyFile("../src/nonsecure_vector.S");
    exe_ns.setOutputDir("zig-cache");
    exe_ns.addIncludeDir("../include");
    exe_ns.addPackagePath("arm_m", "../src/drivers/arm_m.zig");
    exe_ns.enable_lto = true;

    ns_app_deps.cfi_opts.configureBuildStep(exe_ns);

    // The C/C++ compiler options
    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    try ns_app_deps.cfi_opts.addCFlagsTo(&c_flags);
    try c_flags.append("-flto");
    try c_flags.append("-msoft-float");

    if (@hasDecl(meta, "modifyExeStep")) {
        try meta.modifyExeStep(b, exe_ns, ModifyExeStepOpts{ .c_flags = c_flags.toSliceConst() });
    }

    var startup_args: [][]const u8 = undefined;
    if (ns_app_deps.cfi_opts.ses) {
        startup_args = &comptime [_][]const u8{};
    } else {
        // Disable TZmCFI's exception trampolines by updating VTOR to the
        // original (unpatched) vector table
        startup_args = &comptime [_][]const u8{"-DSET_ORIGINAL_VTOR"};
    }
    exe_ns.addCSourceFile("common/startup.S", startup_args);

    if (use_freertos) {
        for (kernel_include_dirs) |path| {
            exe_ns.addIncludeDir(path);
        }
        exe_ns.linkLibrary(kernel);
        exe_ns.addCSourceFile("nonsecure-common/oshooks.c", c_flags.toSliceConst());
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
