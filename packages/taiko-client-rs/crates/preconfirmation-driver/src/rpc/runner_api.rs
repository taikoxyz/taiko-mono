//! Runner-specific RPC API implementation.

use std::sync::Arc;

use alloy_primitives::U256;
use async_trait::async_trait;
use preconfirmation_net::NetworkCommand;
use tokio::sync::mpsc;

use crate::{
    Result,
    driver_interface::{DriverClient, InboxReader},
    rpc::{
        NodeStatus, PreconfRpcApi, PreconfSlotInfo, PublishCommitmentRequest,
        PublishCommitmentResponse, PublishTxListRequest, PublishTxListResponse,
        node_api::{build_node_status, publish_commitment_impl, publish_tx_list_impl},
    },
};

/// Runner-specific RPC API implementation backed by the runner state.
pub(crate) struct RunnerRpcApiImpl<I: InboxReader> {
    /// Channel used to send P2P/network commands.
    command_tx: mpsc::Sender<NetworkCommand>,
    /// Driver client used for tip queries.
    driver: Arc<dyn DriverClient>,
    /// Local peer id string reported over RPC.
    local_peer_id: String,
    /// Inbox reader used to determine sync status.
    inbox_reader: I,
    /// Lookahead resolver for slot info by timestamp.
    lookahead_resolver: Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
}

impl<I: InboxReader> RunnerRpcApiImpl<I> {
    /// Create a new runner RPC API instance.
    pub(crate) fn new(
        command_tx: mpsc::Sender<NetworkCommand>,
        driver: Arc<dyn DriverClient>,
        local_peer_id: String,
        inbox_reader: I,
        lookahead_resolver: Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
    ) -> Self {
        Self { command_tx, driver, local_peer_id, inbox_reader, lookahead_resolver }
    }
}

#[async_trait]
impl<I: InboxReader + 'static> PreconfRpcApi for RunnerRpcApiImpl<I> {
    /// Publish a preconfirmation commitment to the P2P network.
    async fn publish_commitment(
        &self,
        request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse> {
        publish_commitment_impl(&self.command_tx, request).await
    }

    /// Publish a raw tx list to the P2P network after hash validation.
    async fn publish_tx_list(
        &self,
        request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        publish_tx_list_impl(&self.command_tx, request).await
    }

    /// Return node status including sync state, tips, and peer identity.
    async fn get_status(&self) -> Result<NodeStatus> {
        let preconf_tip = self.driver.preconf_tip().await?;

        build_node_status(&self.command_tx, &self.inbox_reader, preconf_tip, &self.local_peer_id)
            .await
    }

    /// Return the latest preconfirmation tip height.
    async fn preconf_tip(&self) -> Result<U256> {
        self.driver.preconf_tip().await
    }

    /// Return the preconfirmation slot info (signer and submission window end) for the given L2
    /// block timestamp.
    async fn get_preconf_slot_info(&self, timestamp: U256) -> Result<PreconfSlotInfo> {
        Ok(self.lookahead_resolver.slot_info_for_timestamp(timestamp).await?.into())
    }
}

#[cfg(test)]
mod tests {
    use super::RunnerRpcApiImpl;
    use std::sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    };

    use alloy_primitives::U256;
    use async_trait::async_trait;
    use tokio::sync::mpsc;

    use crate::{
        driver_interface::{DriverClient, PreconfirmationInput},
        rpc::PreconfRpcApi,
    };

    /// Test driver that returns a fixed preconfirmation tip.
    struct TestDriver {
        /// Preconfigured tip height returned by the driver.
        tip: U256,
    }

    #[async_trait::async_trait]
    impl DriverClient for TestDriver {
        /// Accept the preconfirmation input without side effects.
        async fn submit_preconfirmation(&self, _input: PreconfirmationInput) -> crate::Result<()> {
            Ok(())
        }

        /// Report that event sync has completed.
        async fn wait_event_sync(&self) -> crate::Result<()> {
            Ok(())
        }

        /// Return a constant event sync tip for testing.
        async fn event_sync_tip(&self) -> crate::Result<U256> {
            Ok(U256::ZERO)
        }

        /// Return the configured preconfirmation tip.
        async fn preconf_tip(&self) -> crate::Result<U256> {
            Ok(self.tip)
        }
    }

    /// Mock lookahead resolver for runner API tests.
    struct MockLookaheadResolver;

    #[async_trait]
    impl protocol::preconfirmation::PreconfSignerResolver for MockLookaheadResolver {
        async fn signer_for_timestamp(
            &self,
            _: U256,
        ) -> protocol::preconfirmation::Result<alloy_primitives::Address> {
            Ok(alloy_primitives::Address::repeat_byte(0x11))
        }
        async fn slot_info_for_timestamp(
            &self,
            _: U256,
        ) -> protocol::preconfirmation::Result<protocol::preconfirmation::PreconfSlotInfo> {
            Ok(protocol::preconfirmation::PreconfSlotInfo {
                signer: alloy_primitives::Address::repeat_byte(0x11),
                submission_window_end: U256::from(2000),
            })
        }
    }

    /// Inbox reader backed by an atomic counter.
    #[derive(Clone)]
    struct MockInboxReader {
        next_proposal_id: Arc<AtomicU64>,
        target_block: Arc<AtomicU64>,
        head_l1_origin_block_id: Arc<AtomicU64>,
    }

    const NONE_SENTINEL: u64 = u64::MAX;

    impl MockInboxReader {
        fn new(
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

        fn read_optional(value: u64) -> Option<u64> {
            (value != NONE_SENTINEL).then_some(value)
        }
    }

    #[async_trait::async_trait]
    impl crate::driver_interface::InboxReader for MockInboxReader {
        /// Return the next proposal id from the shared atomic.
        async fn get_next_proposal_id(&self) -> crate::Result<u64> {
            Ok(self.next_proposal_id.load(Ordering::SeqCst))
        }

        async fn get_last_block_id_by_batch_id(
            &self,
            _proposal_id: u64,
        ) -> crate::Result<Option<u64>> {
            Ok(Self::read_optional(self.target_block.load(Ordering::SeqCst)))
        }

        async fn get_head_l1_origin_block_id(&self) -> crate::Result<Option<u64>> {
            Ok(Self::read_optional(self.head_l1_origin_block_id.load(Ordering::SeqCst)))
        }
    }

    /// Ensure status reporting includes driver tip and confirmed event-sync tip.
    #[tokio::test]
    async fn runner_api_reports_driver_tip_and_confirmed_event_sync_tip() {
        let (command_tx, mut command_rx) = mpsc::channel(8);
        tokio::spawn(async move {
            if let Some(preconfirmation_net::NetworkCommand::GetPeerCount { respond_to }) =
                command_rx.recv().await
            {
                let _ = respond_to.send(5);
            }
        });

        let driver = Arc::new(TestDriver { tip: U256::from(100) });
        let inbox_reader = MockInboxReader::new(43, Some(88), Some(88));

        let api = RunnerRpcApiImpl::new(
            command_tx,
            driver,
            "peer".to_string(),
            inbox_reader,
            Arc::new(MockLookaheadResolver),
        );

        let status = api.get_status().await.unwrap();
        assert_eq!(status.event_sync_tip, Some(U256::from(88)));
        assert_eq!(status.preconf_tip, U256::from(100));
        assert!(status.is_synced_with_inbox);
    }
}
