use std::time::{SystemTime, UNIX_EPOCH};

/// Return the current UNIX timestamp in seconds.
pub fn current_unix_timestamp() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|duration| duration.as_secs()).unwrap_or(0)
}
