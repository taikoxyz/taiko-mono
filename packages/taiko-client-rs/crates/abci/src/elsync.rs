//! Execution-layer sync to a trusted head, at `InitChain` and at the first `Info` (MEM-11,
//! MIG-01).
//!
//! History up to the activation boundary, and any height the EL is missing at startup, is
//! fetched by the EL itself over devp2p: [`ensure_block`] points the EL's forkchoice at a block
//! hash the app already trusts (the genesis anchor `H*`, or a committed height) and waits until
//! the EL serves that block as canonical.

use std::time::Duration;

use alloy_primitives::B256;
use tokio::time::Instant;

use crate::engine::{Engine, EngineError, PayloadVerdict};

/// Why [`ensure_block`] failed.
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum ElSyncError {
    /// An Engine API or RPC call failed.
    #[error(transparent)]
    Engine(#[from] EngineError),
    /// The EL answered the forkchoice update to the trusted head with `INVALID`.
    #[error("execution engine rejected trusted head {hash}: {reason}")]
    Rejected {
        /// The trusted head.
        hash: B256,
        /// The engine's `validationError`.
        reason: String,
    },
    /// The EL accepted the trusted head as `VALID` but serves another block at its height.
    #[error("execution engine holds {found} at height {number} after accepting head {expected}")]
    Conflict {
        /// The trusted head's height.
        number: u64,
        /// The trusted head.
        expected: B256,
        /// The hash of the block the EL serves at `number`.
        found: B256,
    },
    /// The EL did not serve the trusted head at its height within the timeout.
    #[error(
        "execution engine did not reach block {number} ({hash}) within {timeout:?}{}",
        .last_error.as_ref().map(|e| format!(" (last poll failed: {e})")).unwrap_or_default()
    )]
    Timeout {
        /// The trusted head's height.
        number: u64,
        /// The trusted head.
        hash: B256,
        /// The timeout that elapsed.
        timeout: Duration,
        /// The retryable error of the last poll, rendered, if that poll failed.
        last_error: Option<String>,
    },
}

/// Ensures the EL serves block `hash` as its canonical block at height `number`.
///
/// Returns at once if it already does. Otherwise sends one forkchoice update with `head = hash`
/// (safe and finalized unknown), which makes an EL lacking the block download it from its peers,
/// then polls `header_by_number(number)` every `poll` until it matches or `timeout` has elapsed
/// since the call started ([`ElSyncError::Timeout`]).
///
/// An `INVALID` answer is [`ElSyncError::Rejected`]. After a `VALID` answer the EL must serve
/// `hash` at `number`; another block there is [`ElSyncError::Conflict`] (the EL disagrees about
/// the trusted chain). While the EL reports `SYNCING`, another block at `number` is the EL's old
/// view and polling continues. A poll failing with a retryable error
/// ([`EngineError::is_retryable`], e.g. the EL restarting or too busy to answer in time) counts
/// as "not yet"; the initial check, the forkchoice update and any other error end the sync.
pub async fn ensure_block<E: Engine + ?Sized>(
    engine: &E,
    number: u64,
    hash: B256,
    timeout: Duration,
    poll: Duration,
) -> Result<(), ElSyncError> {
    // `None` (a timeout too large to represent) never expires.
    let deadline = Instant::now().checked_add(timeout);
    if engine.header_by_number(number).await?.is_some_and(|h| h.hash_slow() == hash) {
        return Ok(());
    }
    let accepted = match engine.forkchoice(hash, B256::ZERO, B256::ZERO).await? {
        PayloadVerdict::Valid => true,
        PayloadVerdict::Syncing => false,
        PayloadVerdict::Invalid(reason) => return Err(ElSyncError::Rejected { hash, reason }),
    };
    loop {
        let last_error = match engine.header_by_number(number).await {
            Ok(Some(header)) => {
                let found = header.hash_slow();
                if found == hash {
                    return Ok(());
                }
                if accepted {
                    return Err(ElSyncError::Conflict { number, expected: hash, found });
                }
                None
            }
            Ok(None) => None,
            Err(e) if e.is_retryable() => {
                tracing::debug!(number, %hash, error = %e, "EL sync poll failed; retrying");
                Some(e.to_string())
            }
            Err(e) => return Err(e.into()),
        };
        let now = Instant::now();
        let pause = match deadline {
            Some(deadline) if now >= deadline => {
                return Err(ElSyncError::Timeout { number, hash, timeout, last_error });
            }
            Some(deadline) => poll.min(deadline - now),
            None => poll,
        };
        tokio::time::sleep(pause).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{EngineCall, MockEngine};
    use alloy_consensus::Header;

    const TIMEOUT: Duration = Duration::from_secs(60);
    const POLL: Duration = Duration::from_secs(1);

    fn header(number: u64, salt: u64) -> Header {
        Header { number, timestamp: salt, ..Header::default() }
    }

    fn forkchoice_calls(engine: &MockEngine) -> Vec<EngineCall> {
        engine
            .calls()
            .into_iter()
            .filter(|call| matches!(call, EngineCall::Forkchoice { .. }))
            .collect()
    }

    #[tokio::test(start_paused = true)]
    async fn present_block_needs_no_forkchoice() {
        let target = header(7, 1);
        let engine = MockEngine::with_chain([target.clone()]);
        assert_eq!(ensure_block(&engine, 7, target.hash_slow(), TIMEOUT, POLL).await, Ok(()));
        assert!(forkchoice_calls(&engine).is_empty());
    }

    /// The EL syncs: one forkchoice update to the trusted head, then polling until the block
    /// appears.
    #[tokio::test(start_paused = true)]
    async fn syncing_engine_is_polled_until_the_block_appears() {
        let target = header(7, 1);
        let hash = target.hash_slow();
        let engine = MockEngine::with_chain([target]);
        {
            let mut state = engine.state();
            state.forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));
            // Initial check: missing. Right after the update: the EL's old block at height 7
            // (not a conflict while SYNCING). First poll: missing. Second poll: the chain.
            state.header_script.extend([Ok(None), Ok(Some(header(7, 2))), Ok(None)]);
        }

        let started = Instant::now();
        assert_eq!(ensure_block(&engine, 7, hash, TIMEOUT, POLL).await, Ok(()));
        assert_eq!(
            forkchoice_calls(&engine),
            [EngineCall::Forkchoice { head: hash, safe: B256::ZERO, finalized: B256::ZERO }]
        );
        assert_eq!(started.elapsed(), 2 * POLL);
    }

    /// An EL that already holds the block off its canonical chain makes it canonical (`VALID`).
    #[tokio::test(start_paused = true)]
    async fn valid_forkchoice_makes_a_known_block_canonical() {
        let target = header(7, 1);
        let engine = MockEngine::with_chain([header(7, 9)]);
        engine.insert_known(target.clone());
        assert_eq!(ensure_block(&engine, 7, target.hash_slow(), TIMEOUT, POLL).await, Ok(()));
    }

    #[tokio::test(start_paused = true)]
    async fn another_block_after_valid_is_a_conflict() {
        let other = header(7, 9);
        let engine = MockEngine::with_chain([other.clone()]);
        engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Valid));

        let hash = header(7, 1).hash_slow();
        assert_eq!(
            ensure_block(&engine, 7, hash, TIMEOUT, POLL).await,
            Err(ElSyncError::Conflict { number: 7, expected: hash, found: other.hash_slow() })
        );
    }

    #[tokio::test(start_paused = true)]
    async fn syncing_engine_that_never_arrives_times_out() {
        let engine = MockEngine::with_chain([header(7, 9)]);
        engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));

        let hash = header(7, 1).hash_slow();
        let started = Instant::now();
        assert_eq!(
            ensure_block(&engine, 7, hash, TIMEOUT, POLL).await,
            Err(ElSyncError::Timeout { number: 7, hash, timeout: TIMEOUT, last_error: None })
        );
        assert_eq!(started.elapsed(), TIMEOUT);
        assert_eq!(forkchoice_calls(&engine).len(), 1, "the forkchoice update is sent once");
    }

    /// A poll failing with a retryable error (the EL restarting, a timeout) is "not yet": the
    /// sync keeps polling and succeeds once the EL serves the block.
    #[tokio::test(start_paused = true)]
    async fn retryable_poll_errors_keep_polling() {
        let target = header(7, 1);
        let hash = target.hash_slow();
        let engine = MockEngine::with_chain([target]);
        {
            let mut state = engine.state();
            state.forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));
            state.header_script.extend([
                Ok(None),
                Err(EngineError::Transport("connection refused".into())),
                Err(EngineError::ErrorReply {
                    call: "eth_getBlockByNumber".into(),
                    code: -32603,
                    message: "internal error".into(),
                }),
            ]);
        }

        let started = Instant::now();
        assert_eq!(ensure_block(&engine, 7, hash, TIMEOUT, POLL).await, Ok(()));
        assert_eq!(started.elapsed(), 2 * POLL);
        assert_eq!(forkchoice_calls(&engine).len(), 1, "the forkchoice update is sent once");
    }

    /// A sync that only ever saw retryable poll errors times out naming the last one.
    #[tokio::test(start_paused = true)]
    async fn a_timeout_after_failing_polls_names_the_last_error() {
        let engine = MockEngine::new();
        let down = EngineError::Transport("connection refused".into());
        {
            let mut state = engine.state();
            state.forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));
            state.header_script.push_back(Ok(None));
            state.header_script.extend((0..=TIMEOUT.as_secs()).map(|_| Err(down.clone())));
        }

        let hash = header(7, 1).hash_slow();
        let err = ensure_block(&engine, 7, hash, TIMEOUT, POLL).await.unwrap_err();
        assert_eq!(
            err,
            ElSyncError::Timeout {
                number: 7,
                hash,
                timeout: TIMEOUT,
                last_error: Some(down.to_string())
            }
        );
        assert!(err.to_string().contains("last poll failed: "), "{err}");
    }

    /// A non-retryable poll error (a reply of the wrong shape, a hash mismatch) ends the sync.
    #[tokio::test(start_paused = true)]
    async fn a_non_retryable_poll_error_ends_the_sync() {
        let engine = MockEngine::new();
        let bad = EngineError::BadReply("eth_getBlockByNumber: null".into());
        {
            let mut state = engine.state();
            state.forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));
            state.header_script.extend([Ok(None), Err(bad.clone())]);
        }

        let hash = header(7, 1).hash_slow();
        assert_eq!(
            ensure_block(&engine, 7, hash, TIMEOUT, POLL).await,
            Err(ElSyncError::Engine(bad))
        );
    }

    /// A timeout too large to add to the clock never expires instead of panicking.
    #[tokio::test(start_paused = true)]
    async fn an_unrepresentable_timeout_does_not_panic() {
        let target = header(7, 1);
        let hash = target.hash_slow();
        let engine = MockEngine::with_chain([target]);
        {
            let mut state = engine.state();
            state.forkchoice_script.push_back(Ok(PayloadVerdict::Syncing));
            state.header_script.extend([Ok(None), Ok(None)]);
        }
        assert_eq!(ensure_block(&engine, 7, hash, Duration::MAX, POLL).await, Ok(()));
    }

    #[tokio::test(start_paused = true)]
    async fn invalid_trusted_head_is_rejected() {
        let engine = MockEngine::new();
        engine.state().forkchoice_script.push_back(Ok(PayloadVerdict::Invalid("bad".into())));

        let hash = header(7, 1).hash_slow();
        assert_eq!(
            ensure_block(&engine, 7, hash, TIMEOUT, POLL).await,
            Err(ElSyncError::Rejected { hash, reason: "bad".into() })
        );
    }

    #[tokio::test(start_paused = true)]
    async fn engine_errors_propagate() {
        let engine = MockEngine::new();
        engine.state().header_script.push_back(Err(EngineError::Transport("down".into())));
        assert_eq!(
            ensure_block(&engine, 7, B256::ZERO, TIMEOUT, POLL).await,
            Err(ElSyncError::Engine(EngineError::Transport("down".into())))
        );
    }
}
