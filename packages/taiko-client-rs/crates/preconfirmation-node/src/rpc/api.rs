//! RPC API trait and implementation.

use std::{
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU32, Ordering},
    },
    time::Duration,
};

use alloy_primitives::{B256, U256};
use async_trait::async_trait;
use jsonrpsee::{core::RpcResult, proc_macros::rpc, types::ErrorObjectOwned};
use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{
    GetCommitmentsByNumberResponse, RawTxListGossip, SignedCommitment, b256_to_bytes32,
    u256_to_uint256,
};
use tokio::{
    sync::{RwLock, mpsc, oneshot},
    time::timeout,
};
use tracing::{debug, warn};

use super::types::{
    GetCommitmentsResponse, GetTxListResponse, NodeStatus, PublishResponse, SszRawTxList,
    SszSignedCommitment,
};
use crate::storage::CommitmentStore;

/// RPC API trait for user-facing preconfirmation operations.
#[rpc(server, namespace = "preconf")]
pub trait PreconfRpcApi {
    /// Publish a signed commitment to the P2P network.
    ///
    /// The commitment payload must be SSZ-serialized.
    #[method(name = "publishCommitment")]
    async fn publish_commitment(
        &self,
        commitment: SszSignedCommitment,
    ) -> RpcResult<PublishResponse>;

    /// Publish a transaction list to the P2P network.
    ///
    /// The txlist payload must be SSZ-serialized.
    #[method(name = "publishTxList")]
    async fn publish_tx_list(&self, txlist: SszRawTxList) -> RpcResult<PublishResponse>;

    /// Get commitments within a block range.
    #[method(name = "getCommitments")]
    async fn get_commitments(
        &self,
        from_block: U256,
        to_block: U256,
    ) -> RpcResult<GetCommitmentsResponse>;

    /// Get a transaction list by commitment hash.
    #[method(name = "getTxList")]
    async fn get_tx_list(&self, commitment_hash: B256) -> RpcResult<GetTxListResponse>;

    /// Get current node status.
    #[method(name = "getStatus")]
    async fn get_status(&self) -> RpcResult<NodeStatus>;
}

/// Shared state for the RPC API implementation.
struct PreconfRpcState {
    /// Channel to send commands to the P2P network.
    command_sender: mpsc::Sender<NetworkCommand>,
    /// Commitment store for local cache access.
    store: Arc<dyn CommitmentStore>,
    /// Timeout for P2P network requests.
    p2p_request_timeout: Duration,
    /// Current peer count.
    peer_count: AtomicU32,
    /// Whether the node is synced.
    synced: AtomicBool,
    /// Current preconfirmation tip.
    preconf_tip: RwLock<U256>,
    /// Current event sync tip.
    event_sync_tip: RwLock<U256>,
}

/// Implementation of the preconfirmation RPC API.
#[derive(Clone)]
pub struct PreconfRpcApiImpl {
    /// Shared RPC state.
    state: Arc<PreconfRpcState>,
}

impl PreconfRpcApiImpl {
    /// Creates a new RPC API implementation.
    pub fn new(
        command_sender: mpsc::Sender<NetworkCommand>,
        store: Arc<dyn CommitmentStore>,
        p2p_request_timeout: Duration,
    ) -> Self {
        let state = PreconfRpcState {
            command_sender,
            store,
            p2p_request_timeout,
            peer_count: AtomicU32::new(0),
            synced: AtomicBool::new(false),
            preconf_tip: RwLock::new(U256::ZERO),
            event_sync_tip: RwLock::new(U256::ZERO),
        };

        Self { state: Arc::new(state) }
    }

    /// Updates the peer count.
    pub fn set_peer_count(&self, count: u32) {
        self.state.peer_count.store(count, Ordering::Relaxed);
    }

    /// Updates the synced status.
    pub fn set_synced(&self, synced: bool) {
        self.state.synced.store(synced, Ordering::Relaxed);
    }

    /// Updates the preconfirmation tip.
    pub async fn set_preconf_tip(&self, tip: U256) {
        *self.state.preconf_tip.write().await = tip;
    }

    /// Updates the event sync tip.
    pub async fn set_event_sync_tip(&self, tip: U256) {
        *self.state.event_sync_tip.write().await = tip;
    }

    /// Build a JSON-RPC error response.
    fn rpc_error(message: impl Into<String>) -> ErrorObjectOwned {
        ErrorObjectOwned::owned(-32000, message.into(), None::<()>)
    }

    /// Compute the maximum number of commitments to request from the network.
    fn max_commitment_count(from_block: U256, to_block: U256) -> u32 {
        let requested = to_block.saturating_sub(from_block).saturating_add(U256::ONE);
        let cap = U256::from(preconfirmation_types::MAX_COMMITMENTS_PER_RESPONSE as u64);
        let bounded = if requested > cap { cap } else { requested };
        bounded.to::<u64>() as u32
    }

    /// Decode SSZ bytes into a signed commitment.
    fn decode_commitment(bytes: &[u8]) -> Result<SignedCommitment, ErrorObjectOwned> {
        ssz_rs::deserialize(bytes)
            .map_err(|err| Self::rpc_error(format!("invalid commitment bytes: {err}")))
    }

    /// Decode SSZ bytes into a raw transaction list gossip payload.
    fn decode_tx_list(bytes: &[u8]) -> Result<RawTxListGossip, ErrorObjectOwned> {
        ssz_rs::deserialize(bytes)
            .map_err(|err| Self::rpc_error(format!("invalid txlist bytes: {err}")))
    }

    /// Encode a signed commitment into SSZ bytes for RPC responses.
    fn encode_commitment(
        commitment: &SignedCommitment,
    ) -> Result<SszSignedCommitment, ErrorObjectOwned> {
        let bytes = ssz_rs::serialize(commitment)
            .map_err(|err| Self::rpc_error(format!("commitment serialization failed: {err}")))?;
        Ok(SszSignedCommitment { bytes })
    }

    /// Encode a raw tx list gossip payload into SSZ bytes for RPC responses.
    fn encode_tx_list(txlist: &RawTxListGossip) -> Result<SszRawTxList, ErrorObjectOwned> {
        let bytes = ssz_rs::serialize(txlist)
            .map_err(|err| Self::rpc_error(format!("txlist serialization failed: {err}")))?;
        Ok(SszRawTxList { bytes })
    }

    /// Convert a commitments response into a vector, caching the results.
    fn merge_commitments(
        &self,
        response: GetCommitmentsByNumberResponse,
        from_block: U256,
        to_block: U256,
        existing: &mut Vec<SignedCommitment>,
    ) {
        for commitment in response.commitments.iter() {
            let block =
                preconfirmation_types::uint256_to_u256(&commitment.commitment.preconf.block_number);
            if block < from_block || block > to_block {
                continue;
            }
            self.state.store.insert_commitment(commitment.clone());
            if !existing.iter().any(|c| {
                c.commitment.preconf.block_number == commitment.commitment.preconf.block_number
            }) {
                existing.push(commitment.clone());
            }
        }
    }
}

#[async_trait]
impl PreconfRpcApiServer for PreconfRpcApiImpl {
    /// Publish a commitment to the P2P network.
    async fn publish_commitment(
        &self,
        commitment: SszSignedCommitment,
    ) -> RpcResult<PublishResponse> {
        let commitment = Self::decode_commitment(&commitment.bytes)?;
        debug!(
            block_number = ?commitment.commitment.preconf.block_number,
            "publishing commitment"
        );

        self.state
            .command_sender
            .send(NetworkCommand::PublishCommitment(commitment))
            .await
            .map_err(|err| {
                warn!(error = %err, "failed to publish commitment");
                Self::rpc_error(format!("failed to publish: {err}"))
            })?;

        Ok(PublishResponse { success: true })
    }

    /// Publish a txlist to the P2P network.
    async fn publish_tx_list(&self, txlist: SszRawTxList) -> RpcResult<PublishResponse> {
        let txlist = Self::decode_tx_list(&txlist.bytes)?;
        debug!("publishing txlist");

        self.state.command_sender.send(NetworkCommand::PublishRawTxList(txlist)).await.map_err(
            |err| {
                warn!(error = %err, "failed to publish txlist");
                Self::rpc_error(format!("failed to publish: {err}"))
            },
        )?;

        Ok(PublishResponse { success: true })
    }

    /// Get commitments within a block range.
    async fn get_commitments(
        &self,
        from_block: U256,
        to_block: U256,
    ) -> RpcResult<GetCommitmentsResponse> {
        if from_block > to_block {
            return Err(Self::rpc_error("from_block must be <= to_block"));
        }

        let mut commitments = Vec::new();
        let mut missing = false;

        let mut block = from_block;
        loop {
            if let Some(commitment) = self.state.store.get_commitment(&block) {
                commitments.push(commitment);
            } else {
                missing = true;
            }

            if block >= to_block {
                break;
            }
            block = block.saturating_add(U256::ONE);
        }

        if !missing {
            let commitments =
                commitments.iter().map(Self::encode_commitment).collect::<Result<Vec<_>, _>>()?;
            return Ok(GetCommitmentsResponse { commitments });
        }

        let max_count = Self::max_commitment_count(from_block, to_block);
        let (respond_to, response_rx) = oneshot::channel();
        self.state
            .command_sender
            .send(NetworkCommand::RequestCommitments {
                respond_to: Some(respond_to),
                start_block: u256_to_uint256(from_block),
                max_count,
                peer: None,
            })
            .await
            .map_err(|err| {
                warn!(error = %err, "failed to request commitments");
                Self::rpc_error(format!("failed to request commitments: {err}"))
            })?;

        let response = timeout(self.state.p2p_request_timeout, response_rx)
            .await
            .map_err(|_| Self::rpc_error("commitment request timed out"))?
            .map_err(|err| Self::rpc_error(format!("commitment response dropped: {err}")))?
            .map_err(|err| Self::rpc_error(format!("commitment request failed: {err}")))?;

        self.merge_commitments(response, from_block, to_block, &mut commitments);

        let commitments =
            commitments.iter().map(Self::encode_commitment).collect::<Result<Vec<_>, _>>()?;

        Ok(GetCommitmentsResponse { commitments })
    }

    /// Get a transaction list by commitment hash.
    async fn get_tx_list(&self, commitment_hash: B256) -> RpcResult<GetTxListResponse> {
        if let Some(txlist) = self.state.store.get_txlist(&commitment_hash) {
            let txlist = Self::encode_tx_list(&txlist)?;
            return Ok(GetTxListResponse { txlist: Some(txlist) });
        }

        let (respond_to, response_rx) = oneshot::channel();
        self.state
            .command_sender
            .send(NetworkCommand::RequestRawTxList {
                respond_to: Some(respond_to),
                raw_tx_list_hash: b256_to_bytes32(commitment_hash),
                peer: None,
            })
            .await
            .map_err(|err| {
                warn!(error = %err, "failed to request txlist");
                Self::rpc_error(format!("failed to request txlist: {err}"))
            })?;

        let response = timeout(self.state.p2p_request_timeout, response_rx)
            .await
            .map_err(|_| Self::rpc_error("txlist request timed out"))?
            .map_err(|err| Self::rpc_error(format!("txlist response dropped: {err}")))?
            .map_err(|err| Self::rpc_error(format!("txlist request failed: {err}")))?;

        let txlist = RawTxListGossip {
            raw_tx_list_hash: response.raw_tx_list_hash,
            txlist: response.txlist,
        };
        self.state.store.insert_txlist(commitment_hash, txlist.clone());

        let txlist = Self::encode_tx_list(&txlist)?;

        Ok(GetTxListResponse { txlist: Some(txlist) })
    }

    /// Get the current node status.
    async fn get_status(&self) -> RpcResult<NodeStatus> {
        Ok(NodeStatus {
            preconf_tip: *self.state.preconf_tip.read().await,
            event_sync_tip: *self.state.event_sync_tip.read().await,
            peer_count: self.state.peer_count.load(Ordering::Relaxed),
            synced: self.state.synced.load(Ordering::Relaxed),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::PreconfRpcApiServer;

    /// Ensure the RPC server trait is generated.
    #[test]
    fn rpc_trait_exists() {
        fn assert_trait<T: PreconfRpcApiServer>() {}
        assert_trait::<super::PreconfRpcApiImpl>();
    }
}
