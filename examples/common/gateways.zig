// This module imports the Secure gateways exported by `exportNonSecureCallable`.
pub extern fn debugOutput(count: usize, ptr: [*]const u8, r2: usize, r3: usize) usize;

pub extern fn scheduleSamplePc(cycles: usize, _r1: usize, _r2: usize, _r3: usize) usize;
pub extern fn getSampledPc(_r0: usize, _r1: usize, _r2: usize, _r3: usize) usize;
