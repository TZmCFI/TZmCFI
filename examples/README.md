# TZmCFI Example Applications

Please see the `README.md` file in the top-level directory for how to run the example application.

This directory is organized as follows:

- Device drivers
    - `drivers` contains device drivers for supported target platforms.
- Shared code
    - `common` contains things which are shared by both of the Secure and Non-Secure parts of the example applications.
    - `ports` contains board-specific code for each supported target board, which is shared by both of the Secure and Non-Secure parts of the example applications.
- Secure (bootloader + TZmCFI Monitor + serial output abstraction)
    - `secure` contains the Secure bootloader/entry point. It imports TZmCFI (`../src`) under the package name `tzmcfi-monitor`, which exports several gateway functions through a C interface. `secure.zig` is the root source file of the Secure module and provides a configuration for TZmCFI Monitor, which is picked up using `@import("root")`.
- Non-Secure
    - `nonsecure-*.zig` is the root source file of each example application. Some applications have their own directory while others don't.
    - `freertos` contains the source code of FreeRTOS as well as the Armv8-M (+ TZmCFI) port of FreeRTOS. FreeRTOS is compiled as a separate module, which is statically linked to the main module of an application. Some part of the OS confiugration and the port resides in `nonsecure-common` instead.
    - `nonsecure-common` contains things which are shared by the Non-Secure parts of the example applications.
