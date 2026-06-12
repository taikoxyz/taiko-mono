//! Runner-specific RPC API implementation.

use std::sync::Arc;

use alloy_primitives::U256;
use async_trait::async_trait;
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::Bytes20;
use protocol::codec::ZlibTxListCodec;
use tokio::sync::mpsc;

use crate::{
    Result,
    driver_interface::{DriverClient, InboxReader},
    rpc::{
        NodeStatus, PreconfRpcApi, PreconfSlotInfo, PublishBlockRequest, PublishBlockResponse,
        api_helpers::{build_node_status, publish_block_impl},
    },
};

/// Runner-specific RPC API implementation backed by the runner state.
pub(crate) struct RunnerRpcApiImpl<I: InboxReader> {
    /// Channel used to send P2P/network commands.
    command_tx: mpsc::Sender<NetworkCommand>,
    /// Driver client used for tip queries and preconfirmation submission.
    driver: Arc<dyn DriverClient>,
    /// Inbox reader used to determine sync status.
    inbox_reader: I,
    /// Lookahead resolver for slot info by timestamp.
    lookahead_resolver: Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
    /// Txlist codec for decompression.
    codec: Arc<ZlibTxListCodec>,
    /// Expected slasher address for commitment validation.
    expected_slasher: Option<Bytes20>,
    /// Chain-configured 32-byte signing domain for commitment signatures (spec §4.1/§8).
    signing_domain: [u8; 32],
    /// Local peer ID string used in status responses.
    local_peer_id: String,
}

/// Construction parameters for [`RunnerRpcApiImpl`].
pub(crate) struct RunnerRpcApiParams<I: InboxReader> {
    /// Channel used to send P2P/network commands.
    pub command_tx: mpsc::Sender<NetworkCommand>,
    /// Driver client used for tip queries and preconfirmation submission.
    pub driver: Arc<dyn DriverClient>,
    /// Inbox reader used to determine sync status.
    pub inbox_reader: I,
    /// Lookahead resolver for slot info by timestamp.
    pub lookahead_resolver: Arc<dyn protocol::preconfirmation::PreconfSignerResolver + Send + Sync>,
    /// Txlist codec for decompression.
    pub codec: Arc<ZlibTxListCodec>,
    /// Expected slasher address for commitment validation.
    pub expected_slasher: Option<Bytes20>,
    /// Chain-configured 32-byte signing domain for commitment signatures (spec §4.1/§8).
    pub signing_domain: [u8; 32],
    /// Local peer ID string used in status responses.
    pub local_peer_id: String,
}

impl<I: InboxReader> RunnerRpcApiImpl<I> {
    /// Create a new runner RPC API instance.
    pub(crate) fn new(params: RunnerRpcApiParams<I>) -> Self {
        let RunnerRpcApiParams {
            command_tx,
            driver,
            inbox_reader,
            lookahead_resolver,
            codec,
            expected_slasher,
            signing_domain,
            local_peer_id,
        } = params;
        Self {
            command_tx,
            driver,
            inbox_reader,
            lookahead_resolver,
            codec,
            expected_slasher,
            signing_domain,
            local_peer_id,
        }
    }
}

#[async_trait]
impl<I: InboxReader + 'static> PreconfRpcApi for RunnerRpcApiImpl<I> {
    async fn publish_block(&self, request: PublishBlockRequest) -> Result<PublishBlockResponse> {
        publish_block_impl(
            &self.command_tx,
            self.driver.as_ref(),
            &self.codec,
            self.expected_slasher.as_ref(),
            self.lookahead_resolver.as_ref(),
            &self.signing_domain,
            request,
        )
        .await
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
    use std::sync::Arc;

    use alloy_primitives::U256;
    use preconfirmation_types::MAX_TXLIST_BYTES;
    use protocol::codec::ZlibTxListCodec;
    use tokio::sync::mpsc;

    use crate::{
        rpc::PreconfRpcApi,
        test_support::{MockInboxReader, MockLookaheadResolver, StubDriver},
    };

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

        let driver = Arc::new(StubDriver::with_preconf_tip(U256::from(100)));
        let inbox_reader = MockInboxReader::new(43, Some(88), Some(88));

        let api = RunnerRpcApiImpl::new(super::RunnerRpcApiParams {
            command_tx,
            driver,
            inbox_reader,
            lookahead_resolver: Arc::new(MockLookaheadResolver::default()),
            codec: Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES)),
            expected_slasher: None,
            signing_domain: preconfirmation_types::DOMAIN_PRECONF,
            local_peer_id: "test-peer".to_string(),
        });

        let status = api.get_status().await.unwrap();
        assert_eq!(status.event_sync_tip, Some(U256::from(88)));
        assert_eq!(status.preconf_tip, U256::from(100));
        assert!(status.is_synced_with_inbox);
        assert_eq!(status.peer_id, "test-peer");
        assert_eq!(status.peer_count, 5);
    }

    /// Ensure slot info queries surface the lookahead resolver output.
    #[tokio::test]
    async fn runner_api_returns_resolver_slot_info() {
        let (command_tx, mut command_rx) = mpsc::channel(8);
        tokio::spawn(async move { while command_rx.recv().await.is_some() {} });

        let api = RunnerRpcApiImpl::new(super::RunnerRpcApiParams {
            command_tx,
            driver: Arc::new(StubDriver::default()),
            inbox_reader: MockInboxReader::new(0, None, None),
            lookahead_resolver: Arc::new(MockLookaheadResolver::default()),
            codec: Arc::new(ZlibTxListCodec::new(MAX_TXLIST_BYTES)),
            expected_slasher: None,
            signing_domain: preconfirmation_types::DOMAIN_PRECONF,
            local_peer_id: "test-peer".to_string(),
        });

        let slot_info = api.get_preconf_slot_info(U256::from(500)).await.unwrap();
        assert_eq!(slot_info.signer, alloy_primitives::Address::repeat_byte(0x11));
        assert_eq!(slot_info.submission_window_end, U256::from(2000));
    }
}
