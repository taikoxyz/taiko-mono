//! Runner-specific RPC API implementation.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use async_trait::async_trait;
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, TxListBytes};
use ssz_rs::Deserialize;
use tokio::sync::mpsc;

use crate::{
    Result,
    driver_interface::{DriverClient, InboxReader},
    error::PreconfirmationClientError,
    rpc::{
        NodeStatus, PreconfRpcApi, PublishCommitmentRequest, PublishCommitmentResponse,
        PublishTxListRequest, PublishTxListResponse,
    },
};

/// Provides access to the latest canonical proposal id.
pub trait CanonicalProposalIdProvider: Send + Sync {
    /// Returns the latest canonical proposal id processed by the driver.
    fn canonical_proposal_id(&self) -> u64;
}

/// Runner-specific RPC API implementation backed by the runner state.
pub(crate) struct RunnerRpcApiImpl<I: InboxReader> {
    /// Channel used to send P2P/network commands.
    command_tx: mpsc::Sender<NetworkCommand>,
    /// Provider for the latest canonical proposal id.
    canonical_id: Arc<dyn CanonicalProposalIdProvider>,
    /// Driver client used for tip queries.
    driver: Arc<dyn DriverClient>,
    /// Local peer id string reported over RPC.
    local_peer_id: String,
    /// Inbox reader used to determine sync status.
    inbox_reader: I,
}

impl<I: InboxReader> RunnerRpcApiImpl<I> {
    /// Create a new runner RPC API instance.
    pub(crate) fn new(
        command_tx: mpsc::Sender<NetworkCommand>,
        canonical_id: Arc<dyn CanonicalProposalIdProvider>,
        driver: Arc<dyn DriverClient>,
        local_peer_id: String,
        inbox_reader: I,
    ) -> Self {
        Self { command_tx, canonical_id, driver, local_peer_id, inbox_reader }
    }
}

#[async_trait]
impl<I: InboxReader + 'static> PreconfRpcApi for RunnerRpcApiImpl<I> {
    /// Publish a preconfirmation commitment to the P2P network.
    async fn publish_commitment(
        &self,
        request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse> {
        let commitment_bytes = request.commitment.as_ref();
        let signed_commitment = SignedCommitment::deserialize(commitment_bytes).map_err(|e| {
            PreconfirmationClientError::Validation(format!("invalid commitment SSZ: {e}"))
        })?;

        let commitment_hash = preconfirmation_types::keccak256_bytes(commitment_bytes);
        let tx_list_hash =
            B256::from_slice(signed_commitment.commitment.preconf.raw_tx_list_hash.as_slice());

        self.command_tx
            .send(NetworkCommand::PublishCommitment(signed_commitment))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishCommitmentResponse {
            commitment_hash: B256::from(commitment_hash.0),
            tx_list_hash,
        })
    }

    /// Publish a raw tx list to the P2P network after hash validation.
    async fn publish_tx_list(
        &self,
        request: PublishTxListRequest,
    ) -> Result<PublishTxListResponse> {
        let raw_tx_list = TxListBytes::try_from(request.tx_list.to_vec())
            .map_err(|_| PreconfirmationClientError::Validation("txlist too large".into()))?;

        let calculated_hash = preconfirmation_types::keccak256_bytes(&raw_tx_list);
        if calculated_hash.0 != request.tx_list_hash.0 {
            return Err(PreconfirmationClientError::Validation(format!(
                "tx_list_hash mismatch: expected {}, got {}",
                request.tx_list_hash, calculated_hash
            )));
        }

        let raw_tx_list_hash = Bytes32::try_from(calculated_hash.0.to_vec())
            .expect("keccak256 always produces 32 bytes");
        let gossip = RawTxListGossip { raw_tx_list_hash, txlist: raw_tx_list };

        self.command_tx
            .send(NetworkCommand::PublishRawTxList(gossip))
            .await
            .map_err(|e| PreconfirmationClientError::Network(format!("failed to publish: {e}")))?;

        Ok(PublishTxListResponse { tx_list_hash: request.tx_list_hash })
    }

    /// Return node status including sync state, tips, and peer identity.
    async fn get_status(&self) -> Result<NodeStatus> {
        let canonical_proposal_id = self.canonical_id.canonical_proposal_id();

        let (tx, rx) = tokio::sync::oneshot::channel();
        let peer_count =
            match self.command_tx.send(NetworkCommand::GetPeerCount { respond_to: tx }).await {
                Ok(()) => rx.await.unwrap_or(0),
                Err(_) => 0,
            };

        let next_proposal_id = self.inbox_reader.get_next_proposal_id().await?;
        let is_synced_with_inbox =
            next_proposal_id == 0 || canonical_proposal_id >= next_proposal_id.saturating_sub(1);

        Ok(NodeStatus {
            is_synced_with_inbox,
            preconf_tip: self.driver.preconf_tip().await?,
            canonical_proposal_id,
            peer_count,
            peer_id: self.local_peer_id.clone(),
        })
    }

    /// Return the latest preconfirmation tip height.
    async fn preconf_tip(&self) -> Result<U256> {
        self.driver.preconf_tip().await
    }

    /// Return the latest canonical proposal id.
    async fn canonical_proposal_id(&self) -> Result<u64> {
        Ok(self.canonical_id.canonical_proposal_id())
    }
}

#[cfg(test)]
mod tests {
    use super::{CanonicalProposalIdProvider, RunnerRpcApiImpl};
    use std::sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    };

    use alloy_primitives::U256;
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

    /// Canonical id provider backed by an atomic counter.
    #[derive(Clone)]
    struct TestCanonicalId(
        /// Shared canonical id value for tests.
        Arc<AtomicU64>,
    );

    impl CanonicalProposalIdProvider for TestCanonicalId {
        /// Read the latest canonical proposal id.
        fn canonical_proposal_id(&self) -> u64 {
            self.0.load(Ordering::SeqCst)
        }
    }

    /// Inbox reader backed by an atomic counter.
    #[derive(Clone)]
    struct MockInboxReader(
        /// Shared next proposal id value for tests.
        Arc<AtomicU64>,
    );

    #[async_trait::async_trait]
    impl crate::driver_interface::InboxReader for MockInboxReader {
        /// Return the next proposal id from the shared atomic.
        async fn get_next_proposal_id(&self) -> crate::Result<u64> {
            Ok(self.0.load(Ordering::SeqCst))
        }
    }

    /// Ensure status reporting includes driver tip and canonical id.
    #[tokio::test]
    async fn runner_api_reports_driver_tip_and_canonical_id() {
        let (command_tx, mut command_rx) = mpsc::channel(8);
        tokio::spawn(async move {
            if let Some(preconfirmation_net::NetworkCommand::GetPeerCount { respond_to }) =
                command_rx.recv().await
            {
                let _ = respond_to.send(5);
            }
        });

        let driver = Arc::new(TestDriver { tip: U256::from(100) });
        let canonical = TestCanonicalId(Arc::new(AtomicU64::new(42)));
        let inbox_reader = MockInboxReader(Arc::new(AtomicU64::new(43)));

        let api = RunnerRpcApiImpl::new(
            command_tx,
            Arc::new(canonical),
            driver,
            "peer".to_string(),
            inbox_reader,
        );

        let status = api.get_status().await.unwrap();
        assert_eq!(status.canonical_proposal_id, 42);
        assert_eq!(status.preconf_tip, U256::from(100));
        assert!(status.is_synced_with_inbox);
    }
}
