# TZmCFI prototype implementation

## Prerequisite

- [GNU Arm Embedded Toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm), version 7 or newer
- [CMSIS Version](https://github.com/ARM-software/CMSIS_5) 5.5.0 or later, whose path must be set to the environment variable `CMSIS_PATH`
- [Rust](https://www.rust-lang.org/en-US/) 1.31.0 or later.

## Running the example application

    $ cargo +nightly build --all

    $ cd examples
    $ zig build -Drelease-small qemu
    (^A-X to quit)

The `-Dgdb` option causes qemu to stop until GDB conenction. Do the following to attach a debugger:

    $ arm-none-eabi-gdb zig-cache/secure -ex "target remote 127.0.0.1:1234"
