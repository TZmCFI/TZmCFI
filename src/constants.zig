pub const VEC_TABLE = struct {
    pub const HDR_SIGNATURE: usize = 0xf4510000;
    pub const HDR_SIGNATURE_MASK: usize = 0xffff0000;
    pub const HDR_SIZE_MASK: usize = 0x0000ffff;

    pub const TRAMPOLINE_STRIDE: usize = 8;
};
