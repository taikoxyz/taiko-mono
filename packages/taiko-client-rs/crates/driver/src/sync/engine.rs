//! Helpers for materialising payload attributes into execution engine blocks.

use std::{io::Read, sync::Arc};

use alethia_reth_consensus::{
    eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee},
    validation::ANCHOR_V3_V4_GAS_LIMIT,
};
use alethia_reth_primitives::{
    engine::types::TaikoExecutionDataSidecar,
    payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256, U256},
    providers::Provider,
};
use alloy_consensus::{
    TxEnvelope,
    proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder},
};
use alloy_primitives::bytes::BufMut;
use alloy_rpc_types::{
    Transaction as RpcTransaction,
    eth::{Block as RpcBlock, Withdrawal},
};
#[cfg(test)]
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV2, ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState,
    PayloadAttributes as EthPayloadAttributes, PayloadId, PayloadStatusEnum,
};
use async_trait::async_trait;
use flate2::read::ZlibDecoder;
use preconfirmation_types::{Bytes20, Bytes32, SignedCommitment, bytes32_to_b256, uint256_to_u256};
use protocol::shasta::constants::shasta_fork_timestamp_for_chain;
use rpc::{
    client::Client,
    engine::{EngineApplyOutcome, EngineError, EngineHead, PreconfEngine},
};
use tracing::{debug, info, instrument, warn};

use crate::{
    derivation::pipeline::shasta::{
        anchor::{AnchorTxConstructor, AnchorV4Input},
        pipeline::util::{
            calculate_shasta_difficulty, compute_build_payload_args_id, decode_transactions,
            encode_extra_data, encode_transactions,
        },
    },
    sync::error::EngineSubmissionError,
};

/// Description of a block inserted via the execution engine.
#[derive(Debug, Clone)]
pub struct EngineBlockOutcome {
    /// The L2 block materialised by the execution engine.
    pub block: RpcBlock<TxEnvelope>,
    /// Payload identifier returned by the engine API.
    pub payload_id: PayloadId,
}

impl EngineBlockOutcome {
    /// Return the number of the inserted block.
    pub fn block_number(&self) -> u64 {
        self.block.header.number
    }

    /// Return the hash of the inserted block.
    pub fn block_hash(&self) -> B256 {
        self.block.header.hash
    }
}

/// Trait that converts derivation payload attributes into concrete execution engine blocks.
#[async_trait]
pub trait PayloadApplier {
    /// Submit the provided payload attributes to the execution engine, building canonical L2
    /// blocks.
    ///
    /// Callers should supply the payloads in chain order as returned by the derivation pipeline.
    /// The implementation queries the current engine head, advances forkchoice, and finally
    /// materialises the payloads into blocks.
    async fn attributes_to_blocks(
        &self,
        payloads: &[TaikoPayloadAttributes],
    ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError>;

    /// Submit a single payload to the execution engine while internally managing forkchoice state.
    async fn apply_payload(
        &self,
        payload: &TaikoPayloadAttributes,
        parent_hash: B256,
        finalized_block_hash: Option<B256>,
    ) -> Result<AppliedPayload, EngineSubmissionError>;
}

/// Trait that injects already-constructed execution payloads into the engine.
#[async_trait]
pub trait ExecutionPayloadInjector {
    /// Submit a fully built execution payload to the engine and materialise the corresponding
    /// block. Implementations should preserve the same engine interaction semantics used by
    /// [`PayloadApplier`].
    async fn apply_execution_payload(
        &self,
        payload: &ExecutionPayloadInputV2,
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, EngineSubmissionError>;
}

/// Configuration parameters for the driver-side preconfirmation engine adapter.
#[derive(Clone, Debug)]
pub struct PreconfEngineConfig {
    /// Base fee sharing percentage encoded into Shasta extra data.
    pub basefee_sharing_pctg: u8,
    /// Flag indicating whether the proposal should be treated as low-bond.
    pub is_low_bond_proposal: bool,
}

impl Default for PreconfEngineConfig {
    /// Use a zero base fee sharing percentage and disable low-bond mode.
    fn default() -> Self {
        Self { basefee_sharing_pctg: 0, is_low_bond_proposal: false }
    }
}

/// Backend capable of providing L1/L2 block context for preconfirmation execution.
#[async_trait]
pub trait PreconfEngineBackend: Send + Sync {
    /// Fetch the latest L2 execution block.
    async fn l2_head_block(&self) -> Result<RpcBlock<TxEnvelope>, EngineError>;
    /// Fetch an L2 block by number.
    async fn l2_block_by_number(&self, number: u64) -> Result<RpcBlock<TxEnvelope>, EngineError>;
    /// Fetch an L1 block by number.
    async fn l1_block_by_number(&self, number: u64) -> Result<RpcBlock<TxEnvelope>, EngineError>;
    /// Fetch the configured L2 chain ID.
    async fn l2_chain_id(&self) -> Result<u64, EngineError>;
    /// Fetch the current L2 sync status from the execution node.
    async fn l2_sync_status(&self) -> Result<alloy_rpc_types::SyncStatus, EngineError>;
}

/// Builder that produces Shasta anchor transactions for preconfirmation blocks.
#[async_trait]
pub trait PreconfAnchorBuilder: Send + Sync {
    /// Assemble an anchor transaction using the provided parent and anchor metadata.
    async fn build_anchor_tx(
        &self,
        parent_hash: B256,
        input: crate::derivation::pipeline::shasta::anchor::AnchorV4Input,
    ) -> Result<TxEnvelope, EngineError>;
}

/// RPC-backed implementation of [`PreconfEngineBackend`].
struct RpcBackend<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Shared RPC client used to access L1/L2 providers.
    rpc: Client<P>,
}

#[async_trait]
impl<P> PreconfEngineBackend for RpcBackend<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Fetch the latest L2 execution block from the RPC provider.
    async fn l2_head_block(&self) -> Result<RpcBlock<TxEnvelope>, EngineError> {
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or_else(|| EngineError::Other("latest L2 block unavailable".to_string()))
    }

    /// Fetch an L2 block by number from the RPC provider.
    async fn l2_block_by_number(&self, number: u64) -> Result<RpcBlock<TxEnvelope>, EngineError> {
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(number))
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or_else(|| EngineError::Other(format!("missing L2 block {number}")))
    }

    /// Fetch an L1 block by number from the RPC provider.
    async fn l1_block_by_number(&self, number: u64) -> Result<RpcBlock<TxEnvelope>, EngineError> {
        self.rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(number))
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or_else(|| EngineError::Other(format!("missing L1 block {number}")))
    }

    /// Fetch the L2 chain ID via the RPC provider.
    async fn l2_chain_id(&self) -> Result<u64, EngineError> {
        self.rpc
            .l2_provider
            .get_chain_id()
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))
    }

    /// Fetch the execution engine sync status from the RPC provider.
    async fn l2_sync_status(&self) -> Result<alloy_rpc_types::SyncStatus, EngineError> {
        self.rpc
            .l2_provider
            .syncing()
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))
    }
}

/// RPC-backed implementation of [`PreconfAnchorBuilder`].
struct RpcAnchorBuilder<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Anchor transaction constructor shared with the Shasta derivation pipeline.
    constructor: AnchorTxConstructor<P>,
}

#[async_trait]
impl<P> PreconfAnchorBuilder for RpcAnchorBuilder<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Assemble the anchor transaction via the Shasta anchor constructor.
    async fn build_anchor_tx(
        &self,
        parent_hash: B256,
        input: AnchorV4Input,
    ) -> Result<TxEnvelope, EngineError> {
        self.constructor
            .assemble_anchor_v4_tx(parent_hash, input)
            .await
            .map_err(|err| EngineError::Other(err.to_string()))
    }
}

/// Adapter that turns preconfirmation commitments into execution-engine payloads.
pub struct DriverPreconfEngine {
    /// Backend used to fetch L1/L2 context for payload construction.
    backend: Arc<dyn PreconfEngineBackend>,
    /// Builder responsible for creating Shasta anchor transactions.
    anchor_builder: Arc<dyn PreconfAnchorBuilder>,
    /// Payload applier used to submit constructed payload attributes.
    payload_applier: Arc<dyn PayloadApplier + Send + Sync>,
    /// Configuration for extra-data encoding.
    config: PreconfEngineConfig,
    /// Shasta fork activation timestamp for base-fee computation.
    shasta_fork_timestamp: u64,
}

/// Built preconfirmation payload attributes and metadata for sidecar ingestion.
#[derive(Debug, Clone)]
pub(crate) struct PreconfPayloadBuild {
    /// Payload attributes constructed from the commitment.
    pub(crate) payload: TaikoPayloadAttributes,
    /// Parent hash that the payload should build on.
    pub(crate) parent_hash: B256,
}

impl DriverPreconfEngine {
    /// Construct a new driver preconfirmation engine adapter from raw components.
    pub fn from_parts(
        backend: Arc<dyn PreconfEngineBackend>,
        anchor_builder: Arc<dyn PreconfAnchorBuilder>,
        payload_applier: Arc<dyn PayloadApplier + Send + Sync>,
        config: PreconfEngineConfig,
        shasta_fork_timestamp: u64,
    ) -> Self {
        Self { backend, anchor_builder, payload_applier, config, shasta_fork_timestamp }
    }

    /// Construct a new adapter using the shared RPC client and default helpers.
    pub async fn new<P>(rpc: Client<P>, config: PreconfEngineConfig) -> Result<Self, EngineError>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
        let chain_id = rpc
            .l2_provider
            .get_chain_id()
            .await
            .map_err(|err| EngineError::Unavailable(err.to_string()))?;
        let shasta_fork_timestamp = shasta_fork_timestamp_for_chain(chain_id)
            .map_err(|err| EngineError::Other(err.to_string()))?;
        let anchor_constructor = AnchorTxConstructor::new(rpc.clone())
            .await
            .map_err(|err| EngineError::Other(err.to_string()))?;

        Ok(Self::from_parts(
            Arc::new(RpcBackend { rpc: rpc.clone() }),
            Arc::new(RpcAnchorBuilder { constructor: anchor_constructor }),
            Arc::new(rpc),
            config,
            shasta_fork_timestamp,
        ))
    }

    /// Build preconfirmation payload attributes and metadata without submitting to the engine.
    pub(crate) async fn build_preconf_payload(
        &self,
        commitment: &SignedCommitment,
        txlist: Option<&[u8]>,
    ) -> Result<PreconfPayloadBuild, EngineError> {
        // Commitment payload body.
        let preconf = &commitment.commitment.preconf;
        // Block number derived from the commitment.
        let block_number = uint256_to_u64(&preconf.block_number)?;
        // L1 anchor block number referenced by the commitment.
        let anchor_block_number = uint256_to_u64(&preconf.anchor_block_number)?;
        // Raw txlist bytes required for non-empty preconfirmations.
        let txlist_bytes = txlist.ok_or_else(|| {
            EngineError::Other("missing txlist for non-empty preconfirmation".to_string())
        })?;
        // Ensure commitment hash matches the provided txlist bytes.
        ensure_txlist_hash_matches(txlist_bytes, &preconf.raw_tx_list_hash)?;
        // Decompressed raw txlist bytes.
        let decoded_txlist = decompress_txlist(txlist_bytes)?;
        // Decoded transactions from the txlist.
        let mut transactions = decode_transactions(&decoded_txlist)
            .map_err(|err| EngineError::Rejected(format!("txlist decode failed: {err}")))?;
        // Parent block number (commitments always reference the previous L2 block).
        let parent_number = block_number
            .checked_sub(1)
            .ok_or_else(|| EngineError::Other("missing parent block for commitment".to_string()))?;
        // Parent L2 block fetched from the backend.
        let parent_block = self.backend.l2_block_by_number(parent_number).await?;
        // Parent block hash for the payload attributes.
        let parent_hash = parent_block.header.hash;
        // Base fee computed from parent block context.
        let base_fee = compute_next_block_base_fee(
            self.backend.as_ref(),
            &parent_block,
            self.shasta_fork_timestamp,
        )
        .await?;
        // Parent difficulty encoded as a B256 for shasta difficulty calculation.
        let parent_difficulty = B256::from(parent_block.header.difficulty.to_be_bytes::<32>());
        // Shasta difficulty for the new block.
        let difficulty = calculate_shasta_difficulty(parent_difficulty, block_number);
        // L1 anchor block fetched from backend.
        let anchor_block = self.backend.l1_block_by_number(anchor_block_number).await?;
        // L1 anchor block hash for payload metadata.
        let anchor_block_hash = anchor_block.header.hash;
        // L1 anchor block state root for payload metadata.
        let anchor_state_root = anchor_block.header.inner.state_root;
        // Coinbase address encoded in the commitment.
        let proposer = bytes20_to_address(&preconf.coinbase);
        // Prover authorization bytes extracted from the commitment.
        let prover_auth = preconf.prover_auth.as_ref().to_vec();
        // Proposal id from the commitment.
        let proposal_id = uint256_to_u64(&preconf.proposal_id)?;
        // Anchor transaction input for the block.
        let anchor_input = AnchorV4Input {
            proposal_id,
            proposer,
            prover_auth: prover_auth.clone(),
            anchor_block_number,
            anchor_block_hash,
            anchor_state_root,
            l2_height: block_number,
            base_fee: U256::from(base_fee),
        };
        // Built anchor transaction.
        let anchor_tx = self.anchor_builder.build_anchor_tx(parent_hash, anchor_input).await?;
        // Transaction list including the anchor tx.
        let mut all_transactions = Vec::with_capacity(transactions.len() + 1);
        // Add anchor transaction first.
        all_transactions.push(anchor_tx);
        // Add the remaining transactions after the anchor.
        all_transactions.append(&mut transactions);
        // RLP-encoded transaction list.
        let tx_list = encode_transactions(&all_transactions);
        // Extra data encoded with basefee sharing + low-bond flags.
        let extra_data =
            encode_extra_data(self.config.basefee_sharing_pctg, self.config.is_low_bond_proposal);
        // Timestamp for the new block.
        let timestamp = uint256_to_u64(&preconf.timestamp)?;
        // Gas limit for the new block including anchor gas.
        let gas_limit = uint256_to_u64(&preconf.gas_limit)?.saturating_add(ANCHOR_V3_V4_GAS_LIMIT);
        // Empty withdrawals list for shasta blocks.
        let withdrawals: Vec<Withdrawal> = Vec::new();
        // Payload args id derived from the payload components.
        let build_payload_args_id = compute_build_payload_args_id(
            parent_hash,
            timestamp,
            difficulty,
            proposer,
            &withdrawals,
            &tx_list,
        );
        // Signature derived from prover authorization.
        let signature = signature_from_prover_auth(&preconf.prover_auth);
        // L1 origin metadata for the payload.
        let l1_origin = RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: Some(U256::from(anchor_block_number)),
            l1_block_hash: Some(anchor_block_hash),
            build_payload_args_id,
            is_forced_inclusion: false,
            signature,
        };
        // Taiko block metadata used to construct the payload attributes.
        let block_metadata = TaikoBlockMetadata {
            beneficiary: proposer,
            gas_limit,
            timestamp: U256::from(timestamp),
            mix_hash: difficulty,
            tx_list,
            extra_data,
        };
        // ETH payload attributes for engine submission.
        let payload_attributes = EthPayloadAttributes {
            timestamp,
            prev_randao: difficulty,
            suggested_fee_recipient: proposer,
            withdrawals: Some(withdrawals),
            parent_beacon_block_root: None,
        };
        // Payload attributes that will be submitted to the engine.
        let payload = TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::from(base_fee),
            block_metadata,
            l1_origin,
        };
        Ok(PreconfPayloadBuild { payload, parent_hash })
    }
}

#[async_trait]
impl PreconfEngine for DriverPreconfEngine {
    /// Return the current execution engine head from the backend.
    async fn engine_head(&self) -> Result<EngineHead, EngineError> {
        let head = self.backend.l2_head_block().await?;
        Ok(EngineHead { block_number: head.header.number, block_hash: head.header.hash })
    }

    /// Report whether the execution engine has finished syncing.
    async fn is_synced(&self) -> Result<bool, EngineError> {
        let status = self.backend.l2_sync_status().await?;
        Ok(matches!(status, alloy_rpc_types::SyncStatus::None))
    }

    /// Apply a preconfirmation commitment by constructing and submitting payload attributes.
    async fn apply_commitment(
        &self,
        commitment: &SignedCommitment,
        txlist: Option<&[u8]>,
    ) -> Result<EngineApplyOutcome, EngineError> {
        // Commitment payload body.
        let preconf = &commitment.commitment.preconf;
        // Block number derived from the commitment.
        let block_number = uint256_to_u64(&preconf.block_number)?;

        if preconf.eop && txlist.is_none() && bytes32_is_zero(&preconf.raw_tx_list_hash) {
            return Ok(EngineApplyOutcome { block_number, block_hash: B256::ZERO });
        }

        // Built payload attributes + parent metadata for the commitment.
        let built = self.build_preconf_payload(commitment, txlist).await?;
        // Applied payload outcome from the execution engine.
        let applied = self
            .payload_applier
            .apply_payload(&built.payload, built.parent_hash, None)
            .await
            .map_err(map_submission_error)?;

        Ok(EngineApplyOutcome {
            block_number: applied.outcome.block_number(),
            block_hash: applied.outcome.block_hash(),
        })
    }

    /// Handle an L1 reorg affecting the given anchor block number.
    async fn handle_reorg(&self, _anchor_block_number: u64) -> Result<(), EngineError> {
        Ok(())
    }
}

/// Convert a preconfirmation `Uint256` into a `u64`, rejecting overflow.
pub(crate) fn uint256_to_u64(value: &preconfirmation_types::Uint256) -> Result<u64, EngineError> {
    let value_u256 = uint256_to_u256(value);
    let as_u64 = value_u256.to::<u64>();
    if U256::from(as_u64) != value_u256 {
        return Err(EngineError::Other("preconfirmation value exceeds u64 range".to_string()));
    }
    Ok(as_u64)
}

/// Convert an SSZ `Bytes20` address into an `Address`.
fn bytes20_to_address(value: &Bytes20) -> Address {
    Address::from_slice(value.as_ref())
}

/// Return true if the provided SSZ hash is all zeros.
fn bytes32_is_zero(value: &Bytes32) -> bool {
    value.iter().all(|byte| *byte == 0)
}

/// Ensure a compressed txlist matches the expected preconfirmation hash.
fn ensure_txlist_hash_matches(txlist: &[u8], expected: &Bytes32) -> Result<(), EngineError> {
    let computed = preconfirmation_types::keccak256_bytes(txlist);
    let expected_hash = bytes32_to_b256(expected);
    if computed != expected_hash {
        return Err(EngineError::Rejected("txlist hash mismatch".to_string()));
    }
    Ok(())
}

/// Decompress a zlib-compressed txlist into raw RLP bytes.
fn decompress_txlist(txlist: &[u8]) -> Result<Vec<u8>, EngineError> {
    let mut decoder = ZlibDecoder::new(txlist);
    let mut decoded = Vec::new();
    decoder
        .read_to_end(&mut decoded)
        .map_err(|err| EngineError::Rejected(format!("txlist decompression failed: {err}")))?;
    Ok(decoded)
}

/// Compute the next block base fee using the Shasta EIP-4396 rule set.
async fn compute_next_block_base_fee(
    backend: &dyn PreconfEngineBackend,
    parent_block: &RpcBlock<TxEnvelope>,
    _shasta_fork_timestamp: u64,
) -> Result<u64, EngineError> {
    if parent_block.header.number == 0 {
        return Ok(SHASTA_INITIAL_BASE_FEE);
    }

    let grandparent_number = parent_block
        .header
        .number
        .checked_sub(1)
        .ok_or_else(|| EngineError::Other("missing grandparent block".to_string()))?;
    let grandparent = backend.l2_block_by_number(grandparent_number).await?;
    let parent_block_time =
        parent_block.header.timestamp.saturating_sub(grandparent.header.timestamp);
    Ok(calculate_next_block_eip4396_base_fee(&parent_block.header.inner, parent_block_time))
}

/// Build a 65-byte signature field from the prover authorization bytes.
fn signature_from_prover_auth(prover_auth: &Bytes20) -> [u8; 65] {
    let mut signature = [0u8; 65];
    let prover_slice = prover_auth.as_ref();
    let copy_len = prover_slice.len().min(signature.len());
    signature[..copy_len].copy_from_slice(&prover_slice[..copy_len]);
    signature
}

/// Map engine submission errors into preconfirmation engine errors.
fn map_submission_error(error: EngineSubmissionError) -> EngineError {
    match error {
        EngineSubmissionError::Rpc(err) => EngineError::Unavailable(err.to_string()),
        EngineSubmissionError::Provider(message) => EngineError::Unavailable(message),
        EngineSubmissionError::EngineSyncing(block) => {
            EngineError::Rejected(format!("engine syncing at block {block}"))
        }
        EngineSubmissionError::InvalidBlock(block, reason) => {
            EngineError::Rejected(format!("invalid block {block}: {reason}"))
        }
        EngineSubmissionError::MissingParent => {
            EngineError::Other("missing parent block during payload submission".to_string())
        }
        EngineSubmissionError::MissingPayloadId => {
            EngineError::Other("engine did not return payload id".to_string())
        }
        EngineSubmissionError::MissingInsertedBlock(block) => {
            EngineError::Other(format!("inserted block {block} not found"))
        }
    }
}

#[async_trait]
impl<P> PayloadApplier for Client<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit the provided payload attributes to the execution engine, building canonical L2
    /// blocks.
    #[instrument(skip(self, payloads))]
    async fn attributes_to_blocks(
        &self,
        payloads: &[TaikoPayloadAttributes],
    ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError> {
        if payloads.is_empty() {
            return Ok(Vec::new());
        }

        let parent_block: RpcBlock<TxEnvelope> = self
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| EngineSubmissionError::Provider(err.to_string()))?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or(EngineSubmissionError::MissingParent)?;
        debug!(
            parent_number = parent_block.header.number,
            parent_hash = ?parent_block.hash(),
            "fetched latest parent block for payload submission"
        );

        let mut outcomes = Vec::with_capacity(payloads.len());
        let mut parent_hash = parent_block.hash();
        debug!(
            head = ?parent_hash,
            payload_count = payloads.len(),
            "submitting batched payloads"
        );

        for payload in payloads {
            let applied = apply_payload_internal(self, payload, parent_hash, None).await?;
            parent_hash = applied.outcome.block_hash();
            outcomes.push(applied.outcome);
        }

        info!(inserted_blocks = outcomes.len(), "successfully applied payload batch");
        Ok(outcomes)
    }

    /// Submit a single payload to the execution engine while internally managing forkchoice state.
    #[instrument(skip(self, payload), fields(payload_id = tracing::field::Empty))]
    async fn apply_payload(
        &self,
        payload: &TaikoPayloadAttributes,
        parent_hash: B256,
        finalized_block_hash: Option<B256>,
    ) -> Result<AppliedPayload, EngineSubmissionError> {
        let span = tracing::Span::current();
        let applied =
            apply_payload_internal(self, payload, parent_hash, finalized_block_hash).await?;
        span.record("payload_id", format_args!("{}", applied.outcome.payload_id));
        Ok(applied)
    }
}

#[async_trait]
impl<P> ExecutionPayloadInjector for Client<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Submit a fully built execution payload to the engine and materialise the corresponding
    /// block. Implementations should preserve the same engine interaction semantics used by
    /// [`PayloadApplier`].
    #[instrument(skip(self, payload))]
    async fn apply_execution_payload(
        &self,
        payload: &ExecutionPayloadInputV2,
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, EngineSubmissionError> {
        let parent_hash = payload.execution_payload.parent_hash;
        let block_hash = payload.execution_payload.block_hash;
        let block_number = payload.execution_payload.block_number;

        let outcome = submit_payload_to_engine(
            self,
            payload,
            block_hash,
            block_number,
            finalized_block_hash,
            // We keep the payload ID as zeroed since we won't check if it's known by the engine
            // later.
            PayloadId::new([0u8; 8]),
        )
        .await?;

        info!(
            block_number,
            block_hash = ?block_hash,
            parent_hash = ?parent_hash,
            "inserted l2 block via execution payload injector",
        );

        Ok(outcome)
    }
}

/// Description of a payload inserted into the execution engine, including the constructed
/// execution payload.
#[derive(Debug, Clone)]
pub struct AppliedPayload {
    /// Outcome metadata describing the inserted block.
    pub outcome: EngineBlockOutcome,
    /// The execution payload returned by the engine when building the block.
    pub payload: ExecutionPayloadInputV2,
}

/// Submit the provided payload attributes to the execution engine, building canonical L2
/// blocks.
#[instrument(skip(rpc, payload), fields(payload_id = tracing::field::Empty))]
async fn apply_payload_internal<P>(
    rpc: &Client<P>,
    payload: &TaikoPayloadAttributes,
    parent_hash: B256,
    finalized_block_hash: Option<B256>,
) -> Result<AppliedPayload, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    // Advertise the next payload attributes so the execution engine can build the block body.
    let forkchoice_state = ForkchoiceState {
        head_block_hash: parent_hash,
        safe_block_hash: parent_hash,
        finalized_block_hash: B256::ZERO,
    };
    let fc_response =
        rpc.engine_forkchoice_updated_v2(forkchoice_state, Some(payload.clone())).await?;

    let payload_id = fc_response.payload_id.ok_or(EngineSubmissionError::MissingPayloadId)?;
    tracing::Span::current().record("payload_id", format_args!("{}", payload_id));

    let expected_payload_id = PayloadId::new(payload.l1_origin.build_payload_args_id);
    if expected_payload_id != payload_id {
        warn!(
            expected = %expected_payload_id,
            received = %payload_id,
            "payload id mismatch between derivation and engine response",
        );
    }

    // Fetch the constructed payload and normalise it into the `engine_newPayloadV2` input shape.
    let envelope = rpc.engine_get_payload_v2(payload_id).await?;
    let (payload_input, block_hash, block_number) = envelope_into_submission(envelope);

    debug!(
        block_number,
        block_hash = ?block_hash,
        payload_id = %payload_id,
        "engine accepted execution payload"
    );

    let outcome = submit_payload_to_engine(
        rpc,
        &payload_input,
        block_hash,
        block_number,
        finalized_block_hash,
        payload_id,
    )
    .await?;

    info!(
        block_number,
        block_hash = ?outcome.block.hash(),
        payload_id = %outcome.payload_id,
        "inserted l2 block via payload applier",
    );

    Ok(AppliedPayload { outcome, payload: payload_input })
}

/// Build an execution payload input from payload attributes without submitting the payload.
pub(crate) async fn build_execution_payload_input<P>(
    rpc: &Client<P>,
    payload: &TaikoPayloadAttributes,
    parent_hash: B256,
) -> Result<ExecutionPayloadInputV2, EngineError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    // Forkchoice state pointing to the parent hash.
    let forkchoice_state = ForkchoiceState {
        head_block_hash: parent_hash,
        safe_block_hash: parent_hash,
        finalized_block_hash: B256::ZERO,
    };
    // Forkchoice update response with payload id.
    let fc_response = rpc
        .engine_forkchoice_updated_v2(forkchoice_state, Some(payload.clone()))
        .await
        .map_err(|err| EngineError::Unavailable(err.to_string()))?;
    // Payload id returned by the engine.
    let payload_id = fc_response
        .payload_id
        .ok_or_else(|| EngineError::Other("missing payload id".to_string()))?;
    // Expected payload id derived from attributes.
    let expected_payload_id = PayloadId::new(payload.l1_origin.build_payload_args_id);
    if expected_payload_id != payload_id {
        warn!(
            expected = %expected_payload_id,
            received = %payload_id,
            "payload id mismatch between derivation and engine response",
        );
    }
    // Engine payload envelope fetched from the payload id.
    let envelope = rpc
        .engine_get_payload_v2(payload_id)
        .await
        .map_err(|err| EngineError::Unavailable(err.to_string()))?;
    // Normalized payload input converted from the envelope.
    let (payload_input, _block_hash, _block_number) = envelope_into_submission(envelope);
    Ok(payload_input)
}

/// Derive the Taiko-specific execution data sidecar from the provided execution payload.
fn derive_payload_sidecar(payload: &ExecutionPayloadInputV2) -> TaikoExecutionDataSidecar {
    let tx_hash =
        ordered_trie_root_with_encoder(&payload.execution_payload.transactions, |tx, buf| {
            buf.put_slice(tx)
        });
    let withdrawals_hash =
        payload.withdrawals.as_ref().map(|withdrawals| calculate_withdrawals_root(withdrawals));

    TaikoExecutionDataSidecar { tx_hash, withdrawals_hash, taiko_block: Some(true) }
}

/// Convert an execution payload envelope into the submission format expected by the engine.
fn envelope_into_submission(
    envelope: ExecutionPayloadEnvelopeV2,
) -> (ExecutionPayloadInputV2, B256, u64) {
    match envelope.execution_payload {
        ExecutionPayloadFieldV2::V1(payload) => (
            ExecutionPayloadInputV2 { execution_payload: payload.clone(), withdrawals: None },
            payload.block_hash,
            payload.block_number,
        ),
        ExecutionPayloadFieldV2::V2(payload) => (
            ExecutionPayloadInputV2 {
                execution_payload: payload.payload_inner.clone(),
                withdrawals: Some(payload.withdrawals.clone()),
            },
            payload.payload_inner.block_hash,
            payload.payload_inner.block_number,
        ),
    }
}

/// Map engine payload status into submission errors, rejecting syncing/invalid statuses.
fn ensure_valid_payload_status(
    block_number: u64,
    status: PayloadStatusEnum,
) -> Result<(), EngineSubmissionError> {
    match status {
        PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => Ok(()),
        PayloadStatusEnum::Syncing => Err(EngineSubmissionError::EngineSyncing(block_number)),
        PayloadStatusEnum::Invalid { validation_error } => {
            Err(EngineSubmissionError::InvalidBlock(block_number, validation_error))
        }
    }
}

/// Build a forkchoice state pointing head/safe/finalized to the provided hashes.
fn promotion_forkchoice_state(
    block_hash: B256,
    finalized_block_hash: Option<B256>,
) -> ForkchoiceState {
    let resolved_finalized_hash = finalized_block_hash.unwrap_or(B256::ZERO);
    ForkchoiceState {
        head_block_hash: block_hash,
        safe_block_hash: resolved_finalized_hash,
        finalized_block_hash: resolved_finalized_hash,
    }
}

/// Fetch the inserted block by number and map provider errors into submission errors.
async fn fetch_block_by_number<P>(
    rpc: &Client<P>,
    block_number: u64,
) -> Result<RpcBlock<TxEnvelope>, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    rpc.l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(block_number))
        .await
        .map_err(|err| EngineSubmissionError::Provider(err.to_string()))?
        .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
        .ok_or(EngineSubmissionError::MissingInsertedBlock(block_number))
}

/// Common flow to submit a payload to the engine, promote forkchoice, and read back the block.
async fn submit_payload_to_engine<P>(
    rpc: &Client<P>,
    payload_input: &ExecutionPayloadInputV2,
    block_hash: B256,
    block_number: u64,
    finalized_block_hash: Option<B256>,
    payload_id: PayloadId,
) -> Result<EngineBlockOutcome, EngineSubmissionError>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let sidecar = derive_payload_sidecar(payload_input);
    let status = rpc.engine_new_payload_v2(payload_input, &sidecar).await?;
    ensure_valid_payload_status(block_number, status.status)?;

    let promoted_state = promotion_forkchoice_state(block_hash, finalized_block_hash);
    rpc.engine_forkchoice_updated_v2(promoted_state, None).await?;

    let block = fetch_block_by_number(rpc, block_number).await?;

    Ok(EngineBlockOutcome { block, payload_id })
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, B256, Bloom, Bytes, U256};
    use alloy_consensus::proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder};
    use alloy_eips::eip4895::Withdrawal;
    use alloy_primitives::bytes::BufMut;
    use alloy_rpc_types::{SyncStatus, eth::Header as RpcHeader};
    use async_trait::async_trait;
    use flate2::{Compression, write::ZlibEncoder};
    use preconfirmation_types::{
        Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
        keccak256_bytes,
    };
    use std::{
        collections::HashMap,
        io::Write,
        sync::{Arc, Mutex},
    };

    #[test]
    fn derive_payload_sidecar_matches_roots() {
        let transactions =
            vec![Bytes::from_static(&[0x01, 0x23]), Bytes::from_static(&[0x45, 0x67])];
        let withdrawals = vec![Withdrawal {
            index: 0,
            validator_index: 1,
            address: Address::from([2u8; 20]),
            amount: 3,
        }];

        let payload_v1 = ExecutionPayloadV1 {
            parent_hash: B256::from(U256::from(10u64)),
            fee_recipient: Address::from([1u8; 20]),
            state_root: B256::from(U256::from(2u64)),
            receipts_root: B256::from(U256::from(3u64)),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from(U256::from(4u64)),
            block_number: 7,
            gas_limit: 30_000_000,
            gas_used: 0,
            timestamp: 123,
            extra_data: Bytes::new(),
            base_fee_per_gas: U256::from(1u64),
            block_hash: B256::from(U256::from(42u64)),
            transactions: transactions.clone(),
        };

        let payload_input = ExecutionPayloadInputV2 {
            execution_payload: payload_v1,
            withdrawals: Some(withdrawals.clone()),
        };

        let sidecar = derive_payload_sidecar(&payload_input);

        let expected_tx_root =
            ordered_trie_root_with_encoder(&transactions, |item, buf| buf.put_slice(item));
        assert_eq!(sidecar.tx_hash, expected_tx_root);

        let expected_withdrawals_root = calculate_withdrawals_root(&withdrawals);
        assert_eq!(sidecar.withdrawals_hash, Some(expected_withdrawals_root));
        assert_eq!(sidecar.taiko_block, Some(true));
    }

    /// Gas limit used for mock L2 blocks in preconfirmation tests.
    const TEST_GAS_LIMIT: u64 = 30_000_000;

    /// Base fee used for mock L2 blocks in preconfirmation tests.
    const TEST_BASE_FEE: u64 = 25_000_000;

    /// Transaction list compression seed used in preconfirmation tests.
    const TEST_TXLIST_BYTE: u8 = 0xAB;

    /// Captured payload application request from the mock payload applier.
    #[derive(Clone, Debug)]
    struct MockPayloadCall {
        /// Payload attributes submitted by the preconfirmation engine.
        payload: TaikoPayloadAttributes,
        /// Parent hash used for the payload application.
        parent_hash: B256,
        /// Finalized hash provided by the engine adapter.
        finalized_block_hash: Option<B256>,
    }

    /// Mock payload applier that records payload submissions.
    #[derive(Clone, Default)]
    struct MockPayloadApplier {
        /// Captured payload submissions.
        calls: Arc<Mutex<Vec<MockPayloadCall>>>,
    }

    impl MockPayloadApplier {
        /// Return recorded payload submissions.
        fn calls(&self) -> Vec<MockPayloadCall> {
            self.calls.lock().expect("mock payload calls mutex poisoned").clone()
        }
    }

    #[async_trait]
    impl PayloadApplier for MockPayloadApplier {
        /// Record the batch submission and return an empty outcome list.
        async fn attributes_to_blocks(
            &self,
            _payloads: &[TaikoPayloadAttributes],
        ) -> Result<Vec<EngineBlockOutcome>, EngineSubmissionError> {
            Ok(Vec::new())
        }

        /// Record the payload submission and return a stubbed applied payload.
        async fn apply_payload(
            &self,
            payload: &TaikoPayloadAttributes,
            parent_hash: B256,
            finalized_block_hash: Option<B256>,
        ) -> Result<AppliedPayload, EngineSubmissionError> {
            self.calls.lock().expect("mock payload calls mutex poisoned").push(MockPayloadCall {
                payload: payload.clone(),
                parent_hash,
                finalized_block_hash,
            });

            let mut header = alloy_consensus::Header::default();
            header.number = payload.l1_origin.block_id.to::<u64>();
            let block = RpcBlock::<TxEnvelope>::empty(RpcHeader::new(header));
            let payload_id = PayloadId::new([0u8; 8]);
            let outcome = EngineBlockOutcome { block, payload_id };
            Ok(AppliedPayload { outcome, payload: sample_execution_payload_input(0) })
        }
    }

    /// Captured anchor transaction request from the mock anchor builder.
    #[derive(Clone, Debug)]
    struct MockAnchorCall {
        /// Parent hash used for the anchor transaction.
        parent_hash: B256,
        /// Anchor block number requested for the anchor transaction.
        anchor_block_number: u64,
    }

    /// Mock anchor transaction builder that returns a fixed transaction.
    #[derive(Clone)]
    struct MockAnchorBuilder {
        /// Anchor transaction returned by the builder.
        anchor_tx: TxEnvelope,
        /// Recorded anchor transaction build requests.
        calls: Arc<Mutex<Vec<MockAnchorCall>>>,
    }

    impl MockAnchorBuilder {
        /// Create a new mock builder returning the given anchor transaction.
        fn new(anchor_tx: TxEnvelope) -> Self {
            Self { anchor_tx, calls: Arc::new(Mutex::new(Vec::new())) }
        }

        /// Return recorded anchor build calls.
        fn calls(&self) -> Vec<MockAnchorCall> {
            self.calls.lock().expect("mock anchor calls mutex poisoned").clone()
        }
    }

    #[async_trait]
    impl PreconfAnchorBuilder for MockAnchorBuilder {
        /// Record the anchor build request and return the fixed transaction.
        async fn build_anchor_tx(
            &self,
            parent_hash: B256,
            input: crate::derivation::pipeline::shasta::anchor::AnchorV4Input,
        ) -> Result<TxEnvelope, EngineError> {
            self.calls.lock().expect("mock anchor calls mutex poisoned").push(MockAnchorCall {
                parent_hash,
                anchor_block_number: input.anchor_block_number,
            });
            Ok(self.anchor_tx.clone())
        }
    }

    /// Mock backend that serves predefined L1/L2 blocks and chain metadata.
    #[derive(Clone)]
    struct MockBackend {
        /// L1 blocks keyed by block number.
        l1_blocks: HashMap<u64, RpcBlock<TxEnvelope>>,
        /// L2 blocks keyed by block number.
        l2_blocks: HashMap<u64, RpcBlock<TxEnvelope>>,
        /// Latest L2 head block.
        l2_head: RpcBlock<TxEnvelope>,
        /// L2 chain ID returned by the backend.
        chain_id: u64,
        /// Sync status returned by the backend.
        sync_status: SyncStatus,
    }

    #[async_trait]
    impl PreconfEngineBackend for MockBackend {
        /// Return the configured L2 head block.
        async fn l2_head_block(&self) -> Result<RpcBlock<TxEnvelope>, EngineError> {
            Ok(self.l2_head.clone())
        }

        /// Fetch a configured L2 block by number.
        async fn l2_block_by_number(
            &self,
            number: u64,
        ) -> Result<RpcBlock<TxEnvelope>, EngineError> {
            self.l2_blocks
                .get(&number)
                .cloned()
                .ok_or_else(|| EngineError::Other(format!("missing l2 block {number}")))
        }

        /// Fetch a configured L1 block by number.
        async fn l1_block_by_number(
            &self,
            number: u64,
        ) -> Result<RpcBlock<TxEnvelope>, EngineError> {
            self.l1_blocks
                .get(&number)
                .cloned()
                .ok_or_else(|| EngineError::Other(format!("missing l1 block {number}")))
        }

        /// Return the configured L2 chain ID.
        async fn l2_chain_id(&self) -> Result<u64, EngineError> {
            Ok(self.chain_id)
        }

        /// Return the configured L2 sync status.
        async fn l2_sync_status(&self) -> Result<SyncStatus, EngineError> {
            Ok(self.sync_status.clone())
        }
    }

    /// Build a mock L2 block with the supplied header fields.
    fn sample_l2_block(number: u64, timestamp: u64) -> RpcBlock<TxEnvelope> {
        let mut header = alloy_consensus::Header::default();
        header.number = number;
        header.timestamp = timestamp;
        header.gas_limit = TEST_GAS_LIMIT;
        header.gas_used = TEST_GAS_LIMIT / 2;
        header.base_fee_per_gas = Some(TEST_BASE_FEE);
        header.difficulty = U256::from(1u64);
        let rpc_header = RpcHeader::new(header);
        RpcBlock::<TxEnvelope>::empty(rpc_header)
    }

    /// Build a mock L1 block with the supplied number and state root.
    fn sample_l1_block(number: u64, state_root: B256) -> RpcBlock<TxEnvelope> {
        let mut header = alloy_consensus::Header::default();
        header.number = number;
        header.state_root = state_root;
        let rpc_header = RpcHeader::new(header);
        RpcBlock::<TxEnvelope>::empty(rpc_header)
    }

    /// Build a deterministic signed commitment for testing.
    fn sample_signed_commitment(
        block_number: u64,
        anchor_block_number: u64,
        txlist_hash: B256,
    ) -> SignedCommitment {
        let commitment = PreconfCommitment {
            preconf: Preconfirmation {
                eop: false,
                block_number: Uint256::from(block_number),
                timestamp: Uint256::from(123u64),
                gas_limit: Uint256::from(TEST_GAS_LIMIT),
                coinbase: Bytes20::try_from(vec![TEST_TXLIST_BYTE; 20]).unwrap(),
                anchor_block_number: Uint256::from(anchor_block_number),
                raw_tx_list_hash: Bytes32::try_from(txlist_hash.as_slice().to_vec()).unwrap(),
                parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
                submission_window_end: Uint256::from(456u64),
                prover_auth: Bytes20::try_from(vec![0x11u8; 20]).unwrap(),
                proposal_id: Uint256::from(42u64),
            },
            slasher_address: Bytes20::try_from(vec![0x22u8; 20]).unwrap(),
        };
        SignedCommitment { commitment, signature: Bytes65::try_from(vec![0x33u8; 65]).unwrap() }
    }

    /// Build a deterministic transaction envelope for testing.
    fn sample_tx_envelope(nonce: u64) -> TxEnvelope {
        let mut tx = alloy_consensus::TxEip1559::default();
        tx.nonce = nonce;
        let signature = alloy_primitives::Signature::new(U256::from(1u64), U256::from(2u64), false);
        let envelope = TxEnvelope::Eip1559(alloy_consensus::Signed::new_unhashed(tx, signature));
        // Initialise the lazily-computed hash so test expectations remain stable after cloning.
        let _ = envelope.tx_hash();
        envelope
    }

    /// Build a compressed txlist byte vector containing the provided transactions.
    fn sample_txlist_bytes(transactions: &[TxEnvelope]) -> Vec<u8> {
        let tx_list =
            crate::derivation::pipeline::shasta::pipeline::util::encode_transactions(transactions);
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(tx_list.as_ref()).expect("txlist compression should succeed");
        encoder.finish().expect("txlist compression should finish")
    }

    /// Build a minimal execution payload input for mock responses.
    fn sample_execution_payload_input(block_number: u64) -> ExecutionPayloadInputV2 {
        ExecutionPayloadInputV2 {
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::ZERO,
                fee_recipient: Address::ZERO,
                state_root: B256::ZERO,
                receipts_root: B256::ZERO,
                logs_bloom: Bloom::default(),
                prev_randao: B256::ZERO,
                block_number,
                gas_limit: 0,
                gas_used: 0,
                timestamp: 0,
                extra_data: Bytes::new(),
                base_fee_per_gas: U256::ZERO,
                block_hash: B256::ZERO,
                transactions: Vec::new(),
            },
            withdrawals: None,
        }
    }

    /// Ensure the driver preconfirmation engine routes commitments through the payload applier.
    #[tokio::test]
    async fn driver_engine_applies_commitment_via_applier() {
        let anchor_tx = sample_tx_envelope(0);
        let txlist_transactions = vec![sample_tx_envelope(1), sample_tx_envelope(2)];
        let txlist_bytes = sample_txlist_bytes(&txlist_transactions);
        let txlist_hash = keccak256_bytes(&txlist_bytes);

        let commitment = sample_signed_commitment(2, 7, txlist_hash);
        let parent_block = sample_l2_block(1, 10);
        let grandparent_block = sample_l2_block(0, 8);
        let anchor_block = sample_l1_block(7, B256::from(U256::from(9u64)));

        assert_ne!(parent_block.header.hash, B256::ZERO, "sample parent block should carry a hash");
        assert_ne!(anchor_block.header.hash, B256::ZERO, "sample anchor block should carry a hash");

        let backend = MockBackend {
            l1_blocks: HashMap::from([(7, anchor_block.clone())]),
            l2_blocks: HashMap::from([(0, grandparent_block.clone()), (1, parent_block.clone())]),
            l2_head: parent_block.clone(),
            chain_id: 167_000,
            sync_status: SyncStatus::None,
        };
        let anchor_builder = MockAnchorBuilder::new(anchor_tx.clone());
        let applier = MockPayloadApplier::default();

        let engine = DriverPreconfEngine::from_parts(
            Arc::new(backend),
            Arc::new(anchor_builder.clone()),
            Arc::new(applier.clone()),
            PreconfEngineConfig::default(),
            0,
        );

        let outcome = engine.apply_commitment(&commitment, Some(&txlist_bytes)).await.unwrap();
        assert_eq!(outcome.block_number, 2);
        assert_eq!(applier.calls().len(), 1);

        let call = applier.calls().into_iter().next().expect("payload call should be recorded");
        assert_eq!(call.parent_hash, parent_block.header.hash);
        assert_eq!(call.finalized_block_hash, None);

        let tx_list_bytes = call.payload.block_metadata.tx_list.clone();
        let decoded = crate::derivation::pipeline::shasta::pipeline::util::decode_transactions(
            tx_list_bytes.as_ref(),
        )
        .expect("txlist should decode");
        assert_eq!(decoded.len(), 3);
        assert_eq!(decoded[0].tx_hash(), anchor_tx.tx_hash());

        let anchor_calls = anchor_builder.calls();
        assert_eq!(anchor_calls.len(), 1);
        assert_eq!(anchor_calls[0].parent_hash, parent_block.header.hash);
        assert_eq!(anchor_calls[0].anchor_block_number, 7);
    }

    /// Ensure base fee computation allows a pre-fork parent when deriving the first Shasta block.
    #[tokio::test]
    async fn base_fee_allows_pre_fork_parent() {
        let parent_block = sample_l2_block(10, 900);
        let grandparent_block = sample_l2_block(9, 800);

        let backend = MockBackend {
            l1_blocks: HashMap::new(),
            l2_blocks: HashMap::from([(9, grandparent_block.clone())]),
            l2_head: parent_block.clone(),
            chain_id: 167_000,
            sync_status: SyncStatus::None,
        };

        let expected = calculate_next_block_eip4396_base_fee(
            &parent_block.header.inner,
            parent_block.header.timestamp.saturating_sub(grandparent_block.header.timestamp),
        );

        let computed = compute_next_block_base_fee(&backend, &parent_block, 1_000)
            .await
            .expect("base fee should compute");

        assert_eq!(computed, expected, "pre-fork parent should still compute base fee");
    }
}
