use regex::bytes::Regex;
use std::error::Error;
use thiserror::Error;

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

    fn process_output(&self, output: &[u8]) -> Result<Option<Vec<u8>>, Box<dyn Error>> {
        if let Some(m) = ERROR_RE.captures(output) {
            Err(CoreMarkError(String::from_utf8_lossy(&m[1]).to_string()).into())
        } else if let Some(m) = OUTPUT_RE.captures(output) {
            Ok(Some(
                format!(r#"{{ "score": {} }}"#, std::str::from_utf8(&m[1]).unwrap()).into_bytes(),
            ))
        } else {
            Err("Could not locate a CoreMark score.".into())
        }
    }
}

#[derive(Debug, Error)]
#[error("CoreMark returned an error: {0:?}")]
struct CoreMarkError(String);

lazy_static::lazy_static! {
    static ref OUTPUT_RE: Regex = Regex::new(r".*CoreMark 1.0 : ([0-9.]+)").unwrap();
    static ref ERROR_RE: Regex = Regex::new(r"ERROR! (.*)").unwrap();
}
