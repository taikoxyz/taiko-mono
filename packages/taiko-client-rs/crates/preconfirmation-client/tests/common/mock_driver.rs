#![allow(dead_code)]
//! Mock driver client for integration tests.

use std::sync::{
    Arc, Mutex,
    atomic::{AtomicU64, AtomicUsize, Ordering},
};

use alloy_primitives::U256;
use async_trait::async_trait;
use preconfirmation_client::{
    Result as PreconfResult,
    driver_interface::{DriverClient, PreconfirmationInput},
};
use preconfirmation_types::uint256_to_u256;
use tokio::sync::Notify;

/// Mock driver for testing that tracks submissions without real RPC calls.
#[derive(Clone)]
pub struct MockDriver {
    inner: Arc<MockDriverInner>,
}

struct MockDriverInner {
    submissions: AtomicUsize,
    preconf_tip: AtomicU64,
    event_sync_tip: U256,
    submitted_blocks: Mutex<Vec<u64>>,
    notify: Notify,
}

impl MockDriver {
    pub fn new(event_sync_tip: U256, preconf_tip: U256) -> Self {
        Self {
            inner: Arc::new(MockDriverInner {
                submissions: AtomicUsize::new(0),
                preconf_tip: AtomicU64::new(preconf_tip.to::<u64>()),
                event_sync_tip,
                submitted_blocks: Mutex::new(Vec::new()),
                notify: Notify::new(),
            }),
        }
    }

    pub async fn wait_for_submissions(&self, count: usize) {
        loop {
            let notified = self.inner.notify.notified();
            if self.inner.submissions.load(Ordering::Acquire) >= count {
                return;
            }
            notified.await;
        }
    }

    pub fn submitted_blocks(&self) -> Vec<u64> {
        self.inner.submitted_blocks.lock().unwrap().clone()
    }

    pub fn submission_count(&self) -> usize {
        self.inner.submissions.load(Ordering::Acquire)
    }
}

#[async_trait]
impl DriverClient for MockDriver {
    async fn submit_preconfirmation(&self, input: PreconfirmationInput) -> PreconfResult<()> {
        let block_number =
            uint256_to_u256(&input.commitment.commitment.preconf.block_number).to::<u64>();
        self.inner.submitted_blocks.lock().unwrap().push(block_number);
        self.inner.submissions.fetch_add(1, Ordering::AcqRel);
        self.inner.preconf_tip.fetch_max(block_number, Ordering::AcqRel);
        self.inner.notify.notify_waiters();
        Ok(())
    }

    async fn wait_event_sync(&self) -> PreconfResult<()> {
        Ok(())
    }

    async fn event_sync_tip(&self) -> PreconfResult<U256> {
        Ok(self.inner.event_sync_tip)
    }

    async fn preconf_tip(&self) -> PreconfResult<U256> {
        Ok(U256::from(self.inner.preconf_tip.load(Ordering::Acquire)))
    }
}
