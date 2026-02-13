//! Event-driven proposal wait helpers.

use std::time::{Duration, Instant};

use anyhow::{Result, anyhow};
use tokio::sync::watch;

/// Waits for a specific proposal ID using event subscription (zero-delay).
///
/// This is more efficient than polling as it receives notifications
/// immediately when the proposal ID changes.
///
/// # Arguments
///
/// * `rx` - A watch receiver from `EventSyncer::subscribe_proposal_id()`.
/// * `expected_proposal_id` - The proposal ID to wait for.
/// * `timeout` - Maximum time to wait.
///
/// # Returns
///
/// Ok(()) when the proposal ID reaches or exceeds the expected value.
///
/// # Example
///
/// ```ignore
/// let mut rx = event_syncer.subscribe_proposal_id();
/// wait_for_proposal_id(&mut rx, 5, Duration::from_secs(30)).await?;
/// ```
pub async fn wait_for_proposal_id(
    rx: &mut watch::Receiver<u64>,
    expected_proposal_id: u64,
    timeout: Duration,
) -> Result<()> {
    let deadline = Instant::now() + timeout;

    loop {
        // Check current value first
        if *rx.borrow() >= expected_proposal_id {
            return Ok(());
        }

        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!(
                "timed out waiting for proposal {expected_proposal_id}, current: {}",
                *rx.borrow()
            ));
        }

        // Wait for change notification
        match tokio::time::timeout(remaining, rx.changed()).await {
            Ok(Ok(())) => {
                if *rx.borrow() >= expected_proposal_id {
                    return Ok(());
                }
            }
            Ok(Err(_)) => return Err(anyhow!("proposal ID channel closed")),
            Err(_) => {
                return Err(anyhow!(
                    "timed out waiting for proposal {expected_proposal_id}, current: {}",
                    *rx.borrow()
                ));
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::watch;

    #[tokio::test]
    async fn wait_returns_immediately_when_already_reached() {
        let (tx, mut rx) = watch::channel(10u64);
        drop(tx); // Close sender to ensure we don't wait

        let result = wait_for_proposal_id(&mut rx, 5, Duration::from_millis(100)).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn wait_succeeds_when_value_changes() {
        let (tx, mut rx) = watch::channel(0u64);

        tokio::spawn(async move {
            tokio::time::sleep(Duration::from_millis(10)).await;
            tx.send(5).unwrap();
        });

        let result = wait_for_proposal_id(&mut rx, 5, Duration::from_secs(1)).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn wait_times_out_when_value_not_reached() {
        let (_tx, mut rx) = watch::channel(0u64);

        let result = wait_for_proposal_id(&mut rx, 10, Duration::from_millis(50)).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("timed out"));
    }
}
