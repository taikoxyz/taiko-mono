//! Bounded polling.

use std::{fmt, future::Future, time::Duration};

use anyhow::{Result, bail};
use tokio::time::{Instant, sleep};

/// Marks an error of a [`wait_until`] check as final: the wait fails at once with it instead of
/// polling on until its timeout (e.g. an app that halted will never reach the awaited height).
#[derive(Debug)]
pub struct Fatal(pub anyhow::Error);

impl fmt::Display for Fatal {
    /// The wrapped error with its causes.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:#}", self.0)
    }
}

impl std::error::Error for Fatal {}

/// Polls `check` every `interval` until it yields `Some`, failing after `timeout`.
///
/// Errors from `check` count as "not yet"; the last one is included in the timeout error. A
/// [`Fatal`] error ends the wait at once.
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
            Err(e) if e.is::<Fatal>() => return Err(e.context(format!("waiting for {what}"))),
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

#[cfg(test)]
mod tests {
    use super::*;
    use anyhow::anyhow;

    #[tokio::test]
    async fn a_fatal_error_ends_the_wait_at_once() {
        let started = std::time::Instant::now();
        let mut calls = 0;
        let err =
            wait_until("height 5", Duration::from_secs(60), Duration::from_millis(10), || {
                calls += 1;
                async { Err::<Option<()>, _>(Fatal(anyhow!("app 0 halted: boom")).into()) }
            })
            .await
            .expect_err("a fatal error fails the wait");
        assert_eq!(calls, 1);
        assert!(started.elapsed() < Duration::from_secs(5), "waited {:?}", started.elapsed());
        assert_eq!(format!("{err:#}"), "waiting for height 5: app 0 halted: boom");
    }

    #[tokio::test]
    async fn other_errors_count_as_not_yet() {
        let mut calls = 0;
        let value =
            wait_until("three calls", Duration::from_secs(5), Duration::from_millis(1), || {
                calls += 1;
                let n = calls;
                async move { if n < 3 { bail!("not yet") } else { Ok(Some(n)) } }
            })
            .await
            .expect("the third call succeeds");
        assert_eq!(value, 3);

        let err =
            wait_until("never", Duration::from_millis(20), Duration::from_millis(1), || async {
                Err::<Option<()>, _>(anyhow!("still down"))
            })
            .await
            .expect_err("times out");
        assert!(format!("{err:#}").contains("last error: still down"), "{err:#}");
    }
}
