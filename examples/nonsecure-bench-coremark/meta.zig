// This module defines the additional data provided to the build script
// (`build.zig`) for building this example application.
const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const join = std.mem.join;
const allocPrint = std.fmt.allocPrint;

const ModifyExeStepOpts = @import("../build.zig").ModifyExeStepOpts;

pub fn modifyExeStep(builder: *Builder, step: *LibExeObjStep, opts: ModifyExeStepOpts) !void {
    const sources = "nonsecure-bench-coremark";
    const coremark = sources ++ "/coremark";

    step.addCSourceFile(coremark ++ "/core_list_join.c", opts.c_flags);
    step.addCSourceFile(coremark ++ "/core_main.c", opts.c_flags);
    step.addCSourceFile(coremark ++ "/core_matrix.c", opts.c_flags);
    step.addCSourceFile(coremark ++ "/core_state.c", opts.c_flags);
    step.addCSourceFile(coremark ++ "/core_util.c", opts.c_flags);

    step.addCSourceFile(sources ++ "/core_portme.c", opts.c_flags);
    step.addCSourceFile(sources ++ "/ee_printf.c", opts.c_flags);

    step.addIncludeDir(coremark);
    step.addIncludeDir(sources);

    const flags = join(builder.allocator, " ", opts.c_flags);
    step.defineCMacro(try allocPrint(builder.allocator, "FLAGS_STR=\"{}\"", flags));

    step.defineCMacro("PERFORMANCE_RUN");

    // Automatically derive the iteration count.
    step.defineCMacro("ITERATIONS=0");
}
