//! Execution-layer sync to a trusted head (spec §5.1, §5.2; MEM-11, MIG-01).
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
    #[error("execution engine did not reach block {number} ({hash}) within {timeout:?}")]
    Timeout {
        /// The trusted head's height.
        number: u64,
        /// The trusted head.
        hash: B256,
        /// The timeout that elapsed.
        timeout: Duration,
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
/// view and polling continues.
pub async fn ensure_block<E: Engine + ?Sized>(
    engine: &E,
    number: u64,
    hash: B256,
    timeout: Duration,
    poll: Duration,
) -> Result<(), ElSyncError> {
    let deadline = Instant::now() + timeout;
    if engine.header_by_number(number).await?.is_some_and(|h| h.hash_slow() == hash) {
        return Ok(());
    }
    let accepted = match engine.forkchoice(hash, B256::ZERO, B256::ZERO).await? {
        PayloadVerdict::Valid => true,
        PayloadVerdict::Syncing => false,
        PayloadVerdict::Invalid(reason) => return Err(ElSyncError::Rejected { hash, reason }),
    };
    loop {
        if let Some(header) = engine.header_by_number(number).await? {
            let found = header.hash_slow();
            if found == hash {
                return Ok(());
            }
            if accepted {
                return Err(ElSyncError::Conflict { number, expected: hash, found });
            }
        }
        let now = Instant::now();
        if now >= deadline {
            return Err(ElSyncError::Timeout { number, hash, timeout });
        }
        tokio::time::sleep(poll.min(deadline - now)).await;
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
            Err(ElSyncError::Timeout { number: 7, hash, timeout: TIMEOUT })
        );
        assert_eq!(started.elapsed(), TIMEOUT);
        assert_eq!(forkchoice_calls(&engine).len(), 1, "the forkchoice update is sent once");
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
