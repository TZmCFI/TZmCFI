pub(crate) struct ProfileRtosTraits;

impl super::AppTraits for ProfileRtosTraits {
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
        "profile-rtos".to_string()
    }
}
