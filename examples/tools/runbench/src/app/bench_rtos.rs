pub(crate) struct BenchRtosTraits;

impl super::AppTraits for BenchRtosTraits {
    fn should_use_shadow_exception_stacks(&self) -> bool {
        true
    }

    fn should_use_shadow_stacks(&self) -> bool {
        true
    }

    fn should_use_context_management(&self) -> bool {
        true
    }

    fn should_use_accel_raise_pri(&self) -> bool {
        true
    }

    fn should_use_icall_sanitizer(&self) -> bool {
        true
    }

    fn name(&self) -> String {
        "bench-rtos".to_string()
    }

    fn output_terminator(&self) -> &[u8] {
        b"Done!"
    }
}
