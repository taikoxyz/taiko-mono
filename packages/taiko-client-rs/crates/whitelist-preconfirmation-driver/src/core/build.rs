//! Shared build-path orchestration for whitelist preconfirmation payloads.

use std::{marker::PhantomData, sync::Arc};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::{Address, B256, U256};
use alloy_provider::Provider;
use alloy_rpc_types::Header as RpcHeader;
use async_trait::async_trait;
use driver::PreconfPayload;
use metrics::histogram;
use tracing::debug;

use crate::{
    api::types::{BuildPreconfBlockRequest, BuildPreconfBlockResponse},
    codec::{WhitelistExecutionPayloadEnvelope, block_signing_hash, encode_envelope_ssz},
    error::Result,
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::NetworkCommand,
};

/// Runtime adapter used by the shared build service.
#[async_trait]
pub(crate) trait PreconfBuildRuntime: Send + Sync {
    /// Ensure the local node is ready to accept a new build request.
    async fn ensure_build_node_ready(&self, request: &BuildPreconfBlockRequest) -> Result<()>;

    /// Validate the fee recipient before building.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()>;

    /// Derive the request prev-randao from the parent block.
    async fn derive_prev_randao(&self, parent_hash: B256, block_number: u64) -> Result<B256>;

    /// Validate request payload semantics before insertion.
    fn validate_request_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
    ) -> Result<()>;

    /// Build the driver payload submitted to event sync.
    fn build_driver_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
        signature: [u8; 65],
    ) -> Result<TaikoPayloadAttributes>;

    /// Submit a candidate preconfirmation payload for local insertion.
    async fn submit_preconfirmation_payload(&self, payload: PreconfPayload) -> Result<()>;

    /// Load the inserted canonical block header from local L2 state.
    async fn inserted_block_header(&self, block_number: u64) -> Result<RpcHeader>;

    /// Sign the provided digest.
    fn sign_digest(&self, digest: B256) -> Result<[u8; 65]>;

    /// Persist the per-block signature used by RPC readers.
    async fn set_l1_origin_signature(
        &self,
        block_number: u64,
        block_hash_signature: [u8; 65],
    ) -> Result<()>;

    /// Update the shared highest-unsafe marker.
    async fn update_highest_unsafe(&self, block_number: u64);

    /// Publish one outbound network command.
    async fn publish_network_command(
        &self,
        command: NetworkCommand,
        command_name: &'static str,
    ) -> Result<()>;

    /// Handle any end-of-sequencing side effects after the payload publish succeeds.
    async fn handle_end_of_sequencing(
        &self,
        request: &BuildPreconfBlockRequest,
        block_hash: B256,
    ) -> Result<()>;

    /// Return the chain ID used for signing and validation.
    fn chain_id(&self) -> u64;
}

/// Shared build/insert/sign/publish orchestration reused across ingress paths.
#[derive(Clone)]
pub(crate) struct PreconfBuildService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Runtime adapter that provides API/P2P-specific operations.
    runtime: Arc<dyn PreconfBuildRuntime>,
    /// Marker preserving the provider type used by the surrounding service.
    _provider: PhantomData<fn() -> P>,
}

impl<P> PreconfBuildService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build a shared preconfirmation build service from a runtime adapter.
    pub(crate) fn new(runtime: Arc<dyn PreconfBuildRuntime>) -> Self {
        Self { runtime, _provider: PhantomData }
    }

    /// Build, sign, publish, and return a preconfirmation block.
    pub(crate) async fn build_and_publish(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        let started_at = std::time::Instant::now();
        self.runtime.ensure_build_node_ready(&request).await?;
        let prev_randao =
            self.runtime.derive_prev_randao(request.parent_hash, request.block_number).await?;
        self.runtime.ensure_fee_recipient_allowed(request.fee_recipient).await?;
        self.runtime.validate_request_payload(&request, prev_randao)?;

        let driver_payload = self.runtime.build_driver_payload(&request, prev_randao, [0u8; 65])?;
        self.runtime.submit_preconfirmation_payload(PreconfPayload::new(driver_payload)).await?;
        let inserted_block = self.runtime.inserted_block_header(request.block_number).await?;

        if inserted_block.inner.parent_hash != request.parent_hash {
            return Err(crate::error::WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block parent hash mismatch at block {}: expected {}, got {}",
                request.block_number, request.parent_hash, inserted_block.inner.parent_hash
            )));
        }
        if inserted_block.inner.number != request.block_number {
            return Err(crate::error::WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block number mismatch: expected {}, got {}",
                request.block_number, inserted_block.inner.number
            )));
        }

        let block_hash = inserted_block.hash;
        let block_number = inserted_block.inner.number;
        let block_hash_signature = self
            .runtime
            .sign_digest(block_signing_hash(self.runtime.chain_id(), block_hash.as_slice()))?;
        self.runtime.set_l1_origin_signature(block_number, block_hash_signature).await?;
        self.runtime.update_highest_unsafe(block_number).await;

        let execution_payload = WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: request.end_of_sequencing,
            is_forced_inclusion: request.is_forced_inclusion,
            parent_beacon_block_root: None,
            execution_payload: alloy_rpc_types_engine::ExecutionPayloadV1 {
                parent_hash: inserted_block.inner.parent_hash,
                fee_recipient: inserted_block.inner.beneficiary,
                state_root: inserted_block.inner.state_root,
                receipts_root: inserted_block.inner.receipts_root,
                logs_bloom: inserted_block.inner.logs_bloom,
                prev_randao: inserted_block.inner.mix_hash,
                block_number,
                gas_limit: inserted_block.inner.gas_limit,
                gas_used: inserted_block.inner.gas_used,
                timestamp: inserted_block.inner.timestamp,
                extra_data: inserted_block.inner.extra_data.clone(),
                base_fee_per_gas: U256::from(
                    inserted_block.inner.base_fee_per_gas.unwrap_or(request.base_fee_per_gas),
                ),
                block_hash,
                transactions: vec![request.transactions.clone()],
            },
            signature: Some(block_hash_signature),
        };
        let envelope = Arc::new(execution_payload);
        let wire_signature = self.runtime.sign_digest(block_signing_hash(
            self.runtime.chain_id(),
            &encode_envelope_ssz(&envelope),
        ))?;

        debug!(
            block_number,
            block_hash = %block_hash,
            "publishing signed whitelist preconfirmation payload"
        );
        self.runtime
            .publish_network_command(
                NetworkCommand::PublishUnsafePayload {
                    signature: wire_signature,
                    envelope: envelope.clone(),
                },
                "publish",
            )
            .await?;

        if request.end_of_sequencing.unwrap_or(false) {
            self.runtime.handle_end_of_sequencing(&request, block_hash).await?;
        }

        histogram!(WhitelistPreconfirmationDriverMetrics::BUILD_PRECONF_BLOCK_DURATION_SECONDS)
            .record(started_at.elapsed().as_secs_f64());

        Ok(BuildPreconfBlockResponse { block_header: inserted_block })
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    };

    use alethia_reth_primitives::payload::attributes::{
        RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
    };
    use alloy_consensus::Header;
    use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_provider::RootProvider;
    use alloy_rpc_types::Header as RpcHeader;
    use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
    use hashlink::LinkedHashMap;
    use tokio::sync::Mutex;

    use super::*;
    use crate::core::state::SharedDriverState;

    fn sample_request() -> BuildPreconfBlockRequest {
        BuildPreconfBlockRequest {
            parent_hash: B256::from([0x11u8; 32]),
            fee_recipient: Address::from([0x22u8; 20]),
            block_number: 7,
            gas_limit: 30_000_000,
            timestamp: 1_735_000_000,
            transactions: Bytes::from(vec![0xAA, 0xBB, 0xCC]),
            extra_data: Bytes::from(vec![0x55u8; 8]),
            base_fee_per_gas: 1_000_000_000,
            end_of_sequencing: None,
            is_forced_inclusion: Some(false),
        }
    }

    fn sample_header(request: &BuildPreconfBlockRequest) -> RpcHeader {
        RpcHeader::new(Header {
            parent_hash: request.parent_hash,
            beneficiary: request.fee_recipient,
            state_root: B256::from([0x33u8; 32]),
            receipts_root: B256::from([0x44u8; 32]),
            logs_bloom: Bloom::default(),
            mix_hash: B256::from([0x55u8; 32]),
            number: request.block_number,
            gas_limit: request.gas_limit,
            gas_used: 21_000,
            timestamp: request.timestamp,
            extra_data: request.extra_data.clone(),
            base_fee_per_gas: Some(request.base_fee_per_gas),
            ..Header::default()
        })
    }

    fn sample_driver_payload(
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
    ) -> TaikoPayloadAttributes {
        TaikoPayloadAttributes {
            payload_attributes: EthPayloadAttributes {
                timestamp: request.timestamp,
                prev_randao,
                suggested_fee_recipient: request.fee_recipient,
                withdrawals: Some(Vec::new()),
                parent_beacon_block_root: None,
            },
            base_fee_per_gas: U256::from(request.base_fee_per_gas),
            block_metadata: TaikoBlockMetadata {
                beneficiary: request.fee_recipient,
                gas_limit: request.gas_limit,
                timestamp: U256::from(request.timestamp),
                mix_hash: prev_randao,
                tx_list: Some(Bytes::from(vec![0x01])),
                extra_data: request.extra_data.clone(),
            },
            l1_origin: RpcL1Origin {
                block_id: U256::from(request.block_number),
                l2_block_hash: B256::ZERO,
                l1_block_height: None,
                l1_block_hash: None,
                build_payload_args_id: [0u8; 8],
                is_forced_inclusion: request.is_forced_inclusion.unwrap_or(false),
                signature: [0u8; 65],
            },
            anchor_transaction: None,
        }
    }

    struct FakeBuildRuntime {
        chain_id: u64,
        prev_randao: B256,
        inserted_header: RpcHeader,
        shared_state: SharedDriverState,
        submitted_payloads: Mutex<Vec<PreconfPayload>>,
        published_commands: Mutex<Vec<NetworkCommand>>,
        signatures: Mutex<Vec<(u64, [u8; 65])>>,
        digest_counter: AtomicU64,
    }

    impl FakeBuildRuntime {
        fn new(request: &BuildPreconfBlockRequest, shared_state: SharedDriverState) -> Self {
            Self {
                chain_id: 167,
                prev_randao: B256::from([0x77u8; 32]),
                inserted_header: sample_header(request),
                shared_state,
                submitted_payloads: Mutex::new(Vec::new()),
                published_commands: Mutex::new(Vec::new()),
                signatures: Mutex::new(Vec::new()),
                digest_counter: AtomicU64::new(1),
            }
        }
    }

    #[async_trait]
    impl PreconfBuildRuntime for FakeBuildRuntime {
        async fn ensure_build_node_ready(&self, _request: &BuildPreconfBlockRequest) -> Result<()> {
            Ok(())
        }

        async fn ensure_fee_recipient_allowed(&self, _fee_recipient: Address) -> Result<()> {
            Ok(())
        }

        async fn derive_prev_randao(&self, _parent_hash: B256, _block_number: u64) -> Result<B256> {
            Ok(self.prev_randao)
        }

        fn validate_request_payload(
            &self,
            _request: &BuildPreconfBlockRequest,
            _prev_randao: B256,
        ) -> Result<()> {
            Ok(())
        }

        fn build_driver_payload(
            &self,
            request: &BuildPreconfBlockRequest,
            prev_randao: B256,
            _signature: [u8; 65],
        ) -> Result<TaikoPayloadAttributes> {
            Ok(sample_driver_payload(request, prev_randao))
        }

        async fn submit_preconfirmation_payload(&self, payload: PreconfPayload) -> Result<()> {
            self.submitted_payloads.lock().await.push(payload);
            Ok(())
        }

        async fn inserted_block_header(&self, _block_number: u64) -> Result<RpcHeader> {
            Ok(self.inserted_header.clone())
        }

        fn sign_digest(&self, _digest: B256) -> Result<[u8; 65]> {
            let id = self.digest_counter.fetch_add(1, Ordering::SeqCst) as u8;
            Ok([id; 65])
        }

        async fn set_l1_origin_signature(
            &self,
            block_number: u64,
            block_hash_signature: [u8; 65],
        ) -> Result<()> {
            self.signatures.lock().await.push((block_number, block_hash_signature));
            Ok(())
        }

        async fn update_highest_unsafe(&self, block_number: u64) {
            *self.shared_state.highest_unsafe_l2_payload_block_id.lock().await = block_number;
        }

        async fn publish_network_command(
            &self,
            command: NetworkCommand,
            _command_name: &'static str,
        ) -> Result<()> {
            self.published_commands.lock().await.push(command);
            Ok(())
        }

        async fn handle_end_of_sequencing(
            &self,
            _request: &BuildPreconfBlockRequest,
            _block_hash: B256,
        ) -> Result<()> {
            Ok(())
        }

        fn chain_id(&self) -> u64 {
            self.chain_id
        }
    }

    #[tokio::test]
    async fn build_and_publish_publishes_payload_and_updates_highest_unsafe() {
        let request = sample_request();
        let shared_state = SharedDriverState {
            highest_unsafe_l2_payload_block_id: Arc::new(Mutex::new(0)),
            end_of_sequencing_by_epoch: Arc::new(Mutex::new(LinkedHashMap::new())),
        };
        let runtime = Arc::new(FakeBuildRuntime::new(&request, shared_state.clone()));
        let service = PreconfBuildService::<RootProvider>::new(runtime.clone());

        let response = service
            .build_and_publish(request.clone())
            .await
            .expect("shared build path should succeed");

        assert_eq!(response.block_header.inner.number, request.block_number);
        assert_eq!(
            *shared_state.highest_unsafe_l2_payload_block_id.lock().await,
            request.block_number
        );

        let published_commands = runtime.published_commands.lock().await;
        assert_eq!(published_commands.len(), 1);
        let NetworkCommand::PublishUnsafePayload { signature, envelope } = &published_commands[0]
        else {
            panic!("expected unsafe payload publish command");
        };
        assert_eq!(envelope.execution_payload.block_number, request.block_number);
        assert_eq!(envelope.execution_payload.transactions, vec![request.transactions.clone()]);

        assert_eq!(signature, &[2u8; 65], "shared path should sign the published SSZ envelope",);
        assert_eq!(
            runtime.signatures.lock().await[0],
            (request.block_number, [1u8; 65]),
            "shared path should persist the block-hash signature before publish",
        );
    }
}
