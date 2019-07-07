# TZmCFI prototype implementation

## Prerequisite

- [GNU Arm Embedded Toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm), version 7 or newer
- [CMSIS Version](https://github.com/ARM-software/CMSIS_5) 5.5.0 or later, whose path must be set to the environment variable `CMSIS_PATH`
- [Rust](https://www.rust-lang.org/en-US/) 1.31.0 or later.

## Running the example application

    $ cargo +nightly build --all

    $ make -C Example/Secure
    $ make -C Example/App
    $ qemu-system-arm -kernel Example/Secure/SecureMonitor.elf -device loader,file=Example/App/NonSecureExample.elf -machine mps2-an505 -nographic -s
    (^A-X to quit)

The `-s` option causes qemu to accept an incoming GDB connection (add `-S` if you want qemu to stop until the conenction). Do the following to attach a debugger:

    $ arm-none-eabi-gdb Example/Secure/SecureMonitor.elf -ex "target remote 127.0.0.1:1234"