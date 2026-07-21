//! Test-only helpers for serializing and scoping process-environment mutations.

use std::{env, sync::Mutex};

/// Serializes tests that mutate or read process environment variables, which are process-global
/// and would otherwise race under the parallel test runner.
pub(crate) static ENV_LOCK: Mutex<()> = Mutex::new(());

/// RAII guard that restores an environment variable to its previous state on drop.
pub(crate) struct EnvGuard {
    key: &'static str,
    previous: Option<String>,
}

impl EnvGuard {
    pub(crate) fn set(key: &'static str, value: &str) -> Self {
        let previous = env::var(key).ok();
        // SAFETY: ENV_LOCK serializes these test-only process-environment mutations.
        unsafe { env::set_var(key, value) };
        Self { key, previous }
    }

    pub(crate) fn unset(key: &'static str) -> Self {
        let previous = env::var(key).ok();
        // SAFETY: ENV_LOCK serializes these test-only process-environment mutations.
        unsafe { env::remove_var(key) };
        Self { key, previous }
    }
}

impl Drop for EnvGuard {
    fn drop(&mut self) {
        // SAFETY: ENV_LOCK serializes these test-only process-environment mutations.
        unsafe {
            match &self.previous {
                Some(value) => env::set_var(self.key, value),
                None => env::remove_var(self.key),
            }
        }
    }
}
