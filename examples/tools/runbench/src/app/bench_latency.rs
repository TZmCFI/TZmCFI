pub(crate) struct BenchLatencyTraits;

impl super::AppTraits for BenchLatencyTraits {
    fn should_use_shadow_exception_stacks(&self) -> bool {
        true
    }

    fn should_use_shadow_stacks(&self) -> bool {
        false
    }

    fn should_use_context_management(&self) -> bool {
        false
    }

    fn should_use_accel_raise_pri(&self) -> bool {
        false
    }

    fn should_use_icall_sanitizer(&self) -> bool {
        false
    }

    fn name(&self) -> String {
        "bench-latency".to_string()
    }
}
