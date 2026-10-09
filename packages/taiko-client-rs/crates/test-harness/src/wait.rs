//! Bounded polling.

use std::{future::Future, time::Duration};

use anyhow::{Result, bail};
use tokio::time::{Instant, sleep};

/// Polls `check` every `interval` until it yields `Some`, failing after `timeout`.
///
/// Errors from `check` count as "not yet"; the last one is included in the timeout error.
pub async fn wait_until<T, F, Fut>(
    what: &str,
    timeout: Duration,
    interval: Duration,
    mut check: F,
) -> Result<T>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<Option<T>>>,
{
    let deadline = Instant::now() + timeout;
    let mut last_error = None;
    loop {
        match check().await {
            Ok(Some(value)) => return Ok(value),
            Ok(None) => {}
            Err(e) => last_error = Some(e),
        }
        if Instant::now() >= deadline {
            match last_error {
                Some(e) => {
                    bail!("timed out after {timeout:?} waiting for {what}; last error: {e:#}")
                }
                None => bail!("timed out after {timeout:?} waiting for {what}"),
            }
        }
        sleep(interval).await;
    }
}
