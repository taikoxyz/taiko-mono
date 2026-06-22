//! Shared test doubles used by crate-internal unit tests.

use std::sync::{
    Arc,
    atomic::{AtomicU64, Ordering},
};

use alloy_primitives::{Address, U256};
use async_trait::async_trait;

use crate::driver_interface::{DriverClient, InboxReader, PreconfirmationInput};

/// Mock lookahead resolver returning a fixed signer and submission window end.
pub(crate) struct MockLookaheadResolver {
    /// Signer returned for every timestamp.
    signer: Address,
    /// Submission window end returned for every timestamp.
    submission_window_end: U256,
}

impl MockLookaheadResolver {
    /// Create a resolver returning the given signer and submission window end.
    pub(crate) fn new(signer: Address, submission_window_end: U256) -> Self {
        Self { signer, submission_window_end }
    }
}

impl Default for MockLookaheadResolver {
    /// Default resolver: signer `0x11..11` and submission window end 2000.
    fn default() -> Self {
        Self::new(Address::repeat_byte(0x11), U256::from(2000))
    }
}

#[async_trait]
impl protocol::preconfirmation::PreconfSignerResolver for MockLookaheadResolver {
    async fn signer_for_timestamp(&self, _: U256) -> protocol::preconfirmation::Result<Address> {
        Ok(self.signer)
    }

    async fn slot_info_for_timestamp(
        &self,
        _: U256,
    ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo> {
        Ok(protocol::preconfirmation::PreconfSlotInfo {
            signer: self.signer,
            submission_window_end: self.submission_window_end,
        })
    }
}

/// Stub driver that accepts every submission and returns fixed tips.
#[derive(Default)]
pub(crate) struct StubDriver {
    /// Preconfigured tip height returned by `preconf_tip`.
    preconf_tip: U256,
}

impl StubDriver {
    /// Create a stub driver returning the given preconfirmation tip.
    pub(crate) fn with_preconf_tip(preconf_tip: U256) -> Self {
        Self { preconf_tip }
    }
}

#[async_trait]
impl DriverClient for StubDriver {
    async fn submit_preconfirmation(&self, _: PreconfirmationInput) -> crate::Result<()> {
        Ok(())
    }

    async fn wait_event_sync(&self) -> crate::Result<()> {
        Ok(())
    }

    async fn event_sync_tip(&self) -> crate::Result<U256> {
        Ok(U256::ZERO)
    }

    async fn preconf_tip(&self) -> crate::Result<U256> {
        Ok(self.preconf_tip)
    }
}

/// Sentinel encoding `None` in the atomic fields of [`MockInboxReader`].
const NONE_SENTINEL: u64 = u64::MAX;

/// Inbox reader backed by atomic counters.
#[derive(Clone)]
pub(crate) struct MockInboxReader {
    /// Next proposal ID returned by the reader.
    next_proposal_id: Arc<AtomicU64>,
    /// Last block mapped to the target proposal (`NONE_SENTINEL` = `None`).
    target_block: Arc<AtomicU64>,
    /// Confirmed `head_l1_origin` block ID (`NONE_SENTINEL` = `None`).
    head_l1_origin_block_id: Arc<AtomicU64>,
}

impl MockInboxReader {
    /// Create a reader with the given proposal ID, target block, and head L1 origin.
    pub(crate) fn new(
        next_proposal_id: u64,
        target_block: Option<u64>,
        head_l1_origin: Option<u64>,
    ) -> Self {
        Self {
            next_proposal_id: Arc::new(AtomicU64::new(next_proposal_id)),
            target_block: Arc::new(AtomicU64::new(target_block.unwrap_or(NONE_SENTINEL))),
            head_l1_origin_block_id: Arc::new(AtomicU64::new(
                head_l1_origin.unwrap_or(NONE_SENTINEL),
            )),
        }
    }

    /// Decode a stored value into `Option<u64>` using the sentinel encoding.
    fn read_optional(value: u64) -> Option<u64> {
        (value != NONE_SENTINEL).then_some(value)
    }
}

#[async_trait]
impl InboxReader for MockInboxReader {
    async fn get_next_proposal_id(&self) -> crate::Result<u64> {
        Ok(self.next_proposal_id.load(Ordering::SeqCst))
    }

    async fn get_last_block_id_by_batch_id(&self, _proposal_id: u64) -> crate::Result<Option<u64>> {
        Ok(Self::read_optional(self.target_block.load(Ordering::SeqCst)))
    }

    async fn get_head_l1_origin_block_id(&self) -> crate::Result<Option<u64>> {
        Ok(Self::read_optional(self.head_l1_origin_block_id.load(Ordering::SeqCst)))
    }
}
