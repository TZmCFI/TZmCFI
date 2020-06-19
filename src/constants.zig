const c = @cImport({
    @cInclude("TZmCFI/Trampolines.h");
});

pub const VEC_TABLE = struct {
    pub const HDR_SIGNATURE: usize = c.TC_VEC_TABLE_HDR_SIGNATURE;
    pub const HDR_SIGNATURE_MASK: usize = c.TC_VEC_TABLE_HDR_SIGNATURE_MASK;
    pub const HDR_SIZE_MASK: usize = c.TC_VEC_TABLE_HDR_SIZE_MASK;

    pub const TRAMPOLINE_STRIDE: usize = c.TC_VEC_TABLE_TRAMPOLINE_STRIDE;
    pub const TRAMPOLINE_STRIDE_SHIFT = 4;
};

comptime {
    if (1 << VEC_TABLE.TRAMPOLINE_STRIDE_SHIFT != VEC_TABLE.TRAMPOLINE_STRIDE) {
        @compileError("TRAMPOLINE_STRIDE_SHIFT contains an incorrect value");
    }
}
