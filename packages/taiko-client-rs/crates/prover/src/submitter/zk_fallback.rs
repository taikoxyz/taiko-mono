//! Latched ZK→SGX drain/resume state shared across per-proposal proof tasks
//! (Go `prover/proof_submitter/zk_fallback.go`).
//!
//! Go guards a `bool` with a mutex on the shared submitter; here the latch is an
//! `AtomicBool` on the shared `Arc<Pipeline>`, and `compare_exchange` gives the
//! same one-shot transition (only the task that flips the latch fires the clear).

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Duration,
};

use crate::{metrics::ProverMetrics, producer::ZkBacklogController};

/// Bounds the best-effort background retries of `POST /v3/prover/clear`
/// (Go `clearBackoffMaxRetries`).
const CLEAR_MAX_RETRIES: usize = 5;

/// Shared ZK-backlog drain/resume latch + raiko2 control-plane handle.
pub(crate) struct ZkFallback {
    /// True while draining the ZK backlog via SGX.
    in_sgx: AtomicBool,
    /// raiko2 control-plane client; `None` disables the machine.
    controller: Option<Arc<dyn ZkBacklogController>>,
    /// Constant backoff between background clear retries (= proof polling interval).
    clear_retry_interval: Duration,
}

impl ZkFallback {
    /// Build a latch. With `controller == None` the machine is inactive and the
    /// submitter keeps the stateless distance behavior.
    pub(crate) fn new(
        controller: Option<Arc<dyn ZkBacklogController>>,
        clear_retry_interval: Duration,
    ) -> Self {
        Self { in_sgx: AtomicBool::new(false), controller, clear_retry_interval }
    }

    /// Whether a control-plane client is wired (one half of "machine active").
    pub(crate) fn has_controller(&self) -> bool {
        self.controller.is_some()
    }

    /// Whether the submitter is currently draining via SGX.
    pub(crate) fn in_sgx(&self) -> bool {
        self.in_sgx.load(Ordering::Acquire)
    }

    /// Latch into SGX-draining mode. Returns `true` only for the caller that
    /// performed the transition (it owns the one-off backlog clear).
    pub(crate) fn mark_sgx(&self) -> bool {
        let won =
            self.in_sgx.compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire).is_ok();
        if won {
            ProverMetrics::set_zk_backlog_sgx_mode(true);
        }
        won
    }

    /// Unlatch SGX-draining mode. Returns `true` only for the caller that
    /// performed the transition.
    pub(crate) fn resume(&self) -> bool {
        let won =
            self.in_sgx.compare_exchange(true, false, Ordering::AcqRel, Ordering::Acquire).is_ok();
        if won {
            ProverMetrics::set_zk_backlog_sgx_mode(false);
        }
        won
    }

    /// Whether SGX-draining can switch back to ZK: (A) the backlog is drained
    /// (`proposal_id <= last_finalized + 1`), and only then (B) the ZK backend
    /// reports `clean`. A status error degrades to resuming on (A) alone, so the
    /// prover never gets stuck on SGX if raiko2 #93 is absent.
    pub(crate) async fn can_resume(&self, proposal_id: u64, last_finalized: u64) -> bool {
        if proposal_id > last_finalized + 1 {
            return false;
        }
        let Some(controller) = self.controller.as_ref() else {
            return true;
        };
        match controller.status_clean().await {
            Ok(clean) => clean,
            Err(err) => {
                tracing::warn!(
                    %err,
                    proposal_id,
                    "ZK prover status unavailable, resuming ZK on backlog-drained condition alone"
                );
                true
            }
        }
    }

    /// Clear the ZK backlog in the background with bounded retries. Best-effort:
    /// clearing only accelerates the drain, so a final failure is logged and
    /// ignored. Spawned detached so it outlives the triggering proposal's task.
    pub(crate) fn fire_clear_async(&self) {
        let Some(controller) = self.controller.clone() else {
            return;
        };
        ProverMetrics::inc_zk_backlog_clear();
        let interval = self.clear_retry_interval;
        tokio::spawn(async move {
            for attempt in 0..=CLEAR_MAX_RETRIES {
                match controller.clear_backlog().await {
                    Ok(()) => {
                        tracing::info!("cleared ZK backlog after entering SGX-draining mode");
                        return;
                    }
                    Err(err) => {
                        tracing::warn!(%err, attempt, "failed to clear ZK backlog, retrying");
                        if attempt < CLEAR_MAX_RETRIES {
                            tokio::time::sleep(interval).await;
                        }
                    }
                }
            }
            tracing::warn!("failed to clear ZK backlog after retries");
        });
    }
}

#[cfg(test)]
pub(crate) use test_support::FakeZkBacklog;

#[cfg(test)]
mod test_support {
    use std::sync::atomic::{AtomicI32, Ordering};

    use crate::{producer::ZkBacklogController, raiko::RaikoError};

    /// Programmable [`ZkBacklogController`] double for the drain/resume tests
    /// (Go `fakeZKBacklog`). Shared by the `ZkFallback` unit tests and the
    /// `Pipeline` integration tests.
    pub(crate) struct FakeZkBacklog {
        /// Value returned by `status_clean` when `status_err` is false.
        pub clean: bool,
        /// When true, `status_clean` returns an error (degrade path).
        pub status_err: bool,
        /// When true, `clear_backlog` returns an error (retry path).
        pub clear_err: bool,
        /// Number of `clear_backlog` calls.
        pub clear_calls: AtomicI32,
        /// Number of `status_clean` calls.
        pub status_calls: AtomicI32,
    }

    impl FakeZkBacklog {
        /// A controller that reports `clean` and never errors.
        pub(crate) fn new(clean: bool) -> Self {
            Self {
                clean,
                status_err: false,
                clear_err: false,
                clear_calls: AtomicI32::new(0),
                status_calls: AtomicI32::new(0),
            }
        }
    }

    #[async_trait::async_trait]
    impl ZkBacklogController for FakeZkBacklog {
        async fn clear_backlog(&self) -> Result<(), RaikoError> {
            self.clear_calls.fetch_add(1, Ordering::SeqCst);
            if self.clear_err { Err(RaikoError::Failed("clear failed".to_owned())) } else { Ok(()) }
        }

        async fn status_clean(&self) -> Result<bool, RaikoError> {
            self.status_calls.fetch_add(1, Ordering::SeqCst);
            if self.status_err {
                Err(RaikoError::Failed("status failed".to_owned()))
            } else {
                Ok(self.clean)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{
        sync::{Arc, atomic::Ordering},
        time::Duration,
    };

    use super::{FakeZkBacklog, ZkFallback};

    fn fallback(clean: bool) -> ZkFallback {
        ZkFallback::new(Some(Arc::new(FakeZkBacklog::new(clean))), Duration::from_millis(1))
    }

    #[test]
    fn mark_sgx_only_first_caller_wins() {
        let f = fallback(true);
        assert!(!f.in_sgx());
        assert!(f.mark_sgx(), "first caller latches");
        assert!(!f.mark_sgx(), "already latched");
        assert!(f.in_sgx());

        assert!(f.resume());
        assert!(!f.in_sgx());
        assert!(f.mark_sgx(), "can latch again after a resume");
    }

    #[test]
    fn mark_sgx_concurrent_single_winner() {
        // `mark_sgx` is sync, so use real threads for a genuine race.
        let f = Arc::new(fallback(true));
        let handles: Vec<_> = (0..50)
            .map(|_| {
                let f = f.clone();
                std::thread::spawn(move || f.mark_sgx())
            })
            .collect();
        let winners = handles.into_iter().map(|h| h.join().unwrap()).filter(|won| *won).count();
        assert_eq!(winners, 1, "exactly one thread performs the transition");
        assert!(f.in_sgx());
    }

    #[tokio::test]
    async fn can_resume_requires_backlog_drained_first() {
        let controller = Arc::new(FakeZkBacklog::new(true));
        let f = ZkFallback::new(Some(controller.clone()), Duration::from_millis(1));
        // proposal_id 100 > last_finalized 10 + 1 → not drained; status not queried.
        assert!(!f.can_resume(100, 10).await);
        assert_eq!(
            controller.status_calls.load(Ordering::SeqCst),
            0,
            "status not queried until the backlog is drained"
        );
    }

    #[tokio::test]
    async fn can_resume_when_drained_and_clean() {
        let f = fallback(true);
        assert!(f.can_resume(11, 10).await, "drained + clean resumes");
    }

    #[tokio::test]
    async fn stays_draining_when_not_clean() {
        let f = fallback(false);
        assert!(!f.can_resume(11, 10).await, "drained but not clean stays draining");
    }

    #[tokio::test]
    async fn degrades_to_drained_only_on_status_error() {
        let controller =
            Arc::new(FakeZkBacklog { clean: false, status_err: true, ..FakeZkBacklog::new(false) });
        let f = ZkFallback::new(Some(controller), Duration::from_millis(1));
        assert!(f.can_resume(11, 10).await, "status error degrades to resume on (A) alone");
    }

    #[tokio::test]
    async fn fire_clear_async_retries_then_gives_up() {
        // Persistent clear failure → exactly CLEAR_MAX_RETRIES + 1 = 6 attempts.
        let controller = Arc::new(FakeZkBacklog { clear_err: true, ..FakeZkBacklog::new(true) });
        let f = ZkFallback::new(Some(controller.clone()), Duration::from_millis(1));
        f.fire_clear_async();
        for _ in 0..1000 {
            if controller.clear_calls.load(Ordering::SeqCst) >= 6 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
        assert_eq!(controller.clear_calls.load(Ordering::SeqCst), 6, "6 attempts then give up");
    }

    #[test]
    fn inactive_without_controller() {
        let f = ZkFallback::new(None, Duration::from_millis(1));
        assert!(!f.has_controller());
    }
}
