pub(crate) struct BenchCoreMarkTraits;

impl super::AppTraits for BenchCoreMarkTraits {
    fn should_use_shadow_exception_stacks(&self) -> bool {
        false
    }

    fn should_use_shadow_stacks(&self) -> bool {
        true
    }

    fn should_use_context_management(&self) -> bool {
        false
    }

    fn should_use_accel_raise_pri(&self) -> bool {
        false
    }

    fn should_use_icall_sanitizer(&self) -> bool {
        true
    }

    fn name(&self) -> String {
        "bench-coremark".to_string()
    }

    fn output_terminator(&self) -> &[u8] {
        b"* portable_fini - system halted"
    }
}
