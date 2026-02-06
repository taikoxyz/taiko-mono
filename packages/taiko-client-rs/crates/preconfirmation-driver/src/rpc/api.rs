//! Preconfirmation RPC API trait definition.

use alloy_primitives::U256;
use async_trait::async_trait;

use super::types::{
    NodeStatus, PreconfSlotInfo, PublishCommitmentRequest, PublishCommitmentResponse,
    PublishTxListRequest, PublishTxListResponse,
};
use crate::Result;

/// Trait defining the preconfirmation driver node's preconfirmation sidecar JSON-RPC API.
///
/// Implementations must be `Send + Sync` as they will be shared across
/// multiple async tasks handling concurrent RPC requests.
#[async_trait]
pub trait PreconfRpcApi: Send + Sync {
    /// Publish a signed preconfirmation commitment to the P2P network.
    async fn publish_commitment(
        &self,
        request: PublishCommitmentRequest,
    ) -> Result<PublishCommitmentResponse>;

    /// Publish a raw transaction list to the P2P network.
    async fn publish_tx_list(&self, request: PublishTxListRequest)
    -> Result<PublishTxListResponse>;

    /// Get the current status of the preconfirmation driver node.
    async fn get_status(&self) -> Result<NodeStatus>;

    /// Get the current preconfirmation tip block number.
    async fn preconf_tip(&self) -> Result<U256>;

    /// Get the last canonical proposal ID from L1 events.
    async fn canonical_proposal_id(&self) -> Result<u64>;

    /// Get the preconfirmation slot info (signer and submission window end) for a given L2 block
    /// timestamp.
    async fn get_preconf_slot_info(&self, timestamp: U256) -> Result<PreconfSlotInfo>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::{Address, B256};

    struct MockApi;

    #[async_trait]
    impl PreconfRpcApi for MockApi {
        async fn publish_commitment(
            &self,
            _request: PublishCommitmentRequest,
        ) -> Result<PublishCommitmentResponse> {
            Ok(PublishCommitmentResponse { commitment_hash: B256::ZERO, tx_list_hash: B256::ZERO })
        }

        async fn publish_tx_list(
            &self,
            _request: PublishTxListRequest,
        ) -> Result<PublishTxListResponse> {
            Ok(PublishTxListResponse { tx_list_hash: B256::ZERO })
        }

        async fn get_status(&self) -> Result<NodeStatus> {
            Ok(NodeStatus {
                is_synced_with_inbox: true,
                preconf_tip: U256::from(100),
                canonical_proposal_id: 42,
                peer_count: 5,
                peer_id: "test-peer".to_string(),
            })
        }

        async fn preconf_tip(&self) -> Result<U256> {
            Ok(U256::from(100))
        }

        async fn canonical_proposal_id(&self) -> Result<u64> {
            Ok(42)
        }

        async fn get_preconf_slot_info(&self, _timestamp: U256) -> Result<PreconfSlotInfo> {
            Ok(PreconfSlotInfo {
                signer: Address::repeat_byte(0x11),
                submission_window_end: U256::from(2000),
            })
        }
    }

    #[tokio::test]
    async fn test_mock_api() {
        let api = MockApi;

        let status = api.get_status().await.unwrap();
        assert!(status.is_synced_with_inbox);
        assert_eq!(status.preconf_tip, U256::from(100));
        assert_eq!(api.preconf_tip().await.unwrap(), U256::from(100));
        assert_eq!(api.canonical_proposal_id().await.unwrap(), 42);

        let slot_info = api.get_preconf_slot_info(U256::from(123)).await.unwrap();
        assert_eq!(slot_info.signer, Address::repeat_byte(0x11));
        assert_eq!(slot_info.submission_window_end, U256::from(2000));
    }
}
