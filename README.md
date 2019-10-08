# TZmCFI prototype implementation

<center><img src="docs/banner.jpg"></center>

## Prerequisite

- Either of the following:
    - [QEMU] 4.0.0 or later. Older versions are not tested but might work.
    - Arm [MPS2+] FPGA prototyping board configured with AN505. The encrypted FPGA image of AN505 is available from [Arm's website].
- To enable the compiler-level CFI scheme:
    - Our custom fork of Zig (TODO: Where is it?)
    - Our custom fork of LLVM (TODO: Where is it?)
- If you don't want the compiler-level CFI scheme, you still need:
    - Zig [`2cb1f93`](https://github.com/ziglang/zig/commit/2cb1f93894be3f48f0c49004515fa5e8190f69d9) (Aug 16, 2019) or later
- [Rust](https://www.rust-lang.org/en-US/) 1.31.0 or later.

[QEMU]: https://www.qemu.org
[MPS2+]: https://www.arm.com/products/development-tools/development-boards/mps2-plus
[Arm's website]: https://developer.arm.com/tools-and-software/development-boards/fpga-prototyping-boards/download-fpga-images?_ga=2.138343728.123477322.1561466661-1332644519.1559889185

## Running the example application

    $ cargo +nightly build --all

    $ cd examples
    $ zig build -Drelease-small qemu:rtosbasic
    (^A-X to quit)

The supported build options that can be passed to `zig build` are listed below:

### `-Dgdb` — Build for debugging

The `-Dgdb` option causes qemu to stop until GDB conenction. Do the following to attach a debugger:

    $ arm-none-eabi-gdb zig-cache/secure -ex "target remote 127.0.0.1:1234"

This option also changes the output filenames for no reason. (TODO: Remove this behabviour?)

### `-Dcfi[-type]={true|false}` — Toggle CFI mechanisms

As the name implies, it enables or disables the control flow integrity mechanism. Useful for comparative experiments. The following mechanisms are implemented:

- `-Dcfi-ctx` toggles the use of TZmCFI context management API. This is technically not a CFI mechanism, but is a prerequisite for other mechanisms.
- `-Dcfi-ses` toggles TZmCFI shadow exception stacks (a specialized variant of traditional shadow stacks for interrupt handling).
- `-Dcfi-ss` toggles TZmCFI shadow stacks.
- `-Dcfi-icall` toggles LLVM indirect call sanitizer.
- `-Dcfi` toggles all mechanisms listed above.

### `-Dlog-{none|critical|warning|trace}` — Set log level

Changes the verbosity of TZmCFI's tracing output generated by `log` function. This is useful for debugging.

This option controls `@import("root").TC_LOG_LEVEL`.

### `-Dprofile` — Enable profiler

Enable the collection of statistical information. The profiler API must be used to actually utilize the profiler. The collected information is logged with level `Critical` when `TCDebugDumpProfile` is called.

This option controls `@import("root").TC_ENABLE_PROFILER`.

### Standard build modes

Zig defines four standard build modes (at the point of writing), which you can choose via one of the following command-line options (the descriptions are taken from [Zig's website]):

|       Parameter        | Debug (default) | `-Drelease-safe` | `-Drelease-fast` | `-Drelease-small` |
|------------------------|-----------------|------------------|------------------|-------------------|
| Optimizations¹         |                 | `-O3`            | `-O3`            | `-Os`             |
| Runtime safety checks² | On              | On               |                  |                   |

¹ improve speed, harm debugging, harm compile time

² harm speed, harm size, crash instead of undefined behavior

[Zig's website]: https://ziglang.org/#Performance-and-Safety-Choose-Two
