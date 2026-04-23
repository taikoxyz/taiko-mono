use std::sync::Arc;

use alethia_reth_consensus::anchor_constants::{anchorV3Call, anchorV4Call};
use alloy::{
    eips::{BlockId, BlockNumberOrTag, eip1898::RpcBlockHash},
    primitives::{Address, B256, U256},
    providers::Provider,
    rpc::types::Log,
    sol_types::{SolCall, SolEvent},
};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use anyhow::anyhow;
use async_trait::async_trait;
use bindings::inbox::{IInbox::DerivationSource, Inbox::Proposed};
use metrics::{counter, gauge};
use protocol::shasta::{
    constants::{
        MAINNET_ANCHOR_CHECK_SKIP_PROPOSAL_OFFSET, PROPOSAL_MAX_BLOB_BYTES, TAIKO_MAINNET_CHAIN_ID,
        min_base_fee_for_chain, shasta_fork_timestamp_for_chain,
    },
    manifest::DerivationSourceManifest,
};
use rpc::{blob::BlobDataSource, client::Client};
use tracing::{debug, info, instrument, warn};

use crate::{
    derivation::manifest::{ManifestFetcher, fetcher::shasta::ShastaSourceManifestFetcher},
    metrics::DriverMetrics,
    sync::engine::{EngineBlockOutcome, PayloadApplier},
};
use protocol::shasta::AnchorTxConstructor;

use super::super::{DerivationError, DerivationPipeline};

/// Decoded Shasta `Proposed` event enriched with the containing L1 block metadata.
#[derive(Debug, Clone)]
struct ProposedEventContext {
    /// Raw decoded `Proposed` event payload.
    event: Proposed,
    /// L1 block number that emitted the event.
    l1_block_number: u64,
    /// Hash of the L1 block that emitted the event.
    l1_block_hash: B256,
    /// Timestamp of the emitting L1 block (used as proposal timestamp).
    l1_timestamp: u64,
}

/// Bundle types extracted from proposal logs.
mod bundle;
/// Payload assembly and canonical verification helpers.
mod payload;
/// Parent-state tracking while deriving sequential blocks.
mod state;

use bundle::{BundleMeta, SourceManifestSegment};
use state::ParentState;

pub use bundle::ShastaProposalBundle;

/// Query inbox core state at the provided L1 block hash and return the finalized proposal id.
///
/// Failures are downgraded to `None` so proposal derivation can proceed without finalized
/// forkchoice hints.
async fn try_last_finalized_proposal_id_at_block<P>(
    rpc: &Client<P>,
    block_hash: B256,
) -> Option<u64>
where
    P: Provider + Clone + 'static,
{
    match rpc
        .shasta
        .inbox
        .getCoreState()
        .block(BlockId::Hash(RpcBlockHash { block_hash, require_canonical: Some(false) }))
        .call()
        .await
    {
        Ok(core_state) => Some(core_state.lastFinalizedProposalId.to::<u64>()),
        Err(err) => {
            warn!(
                l1_block_hash = ?block_hash,
                error = %err,
                "failed to query last finalized proposal id from inbox core state"
            );
            None
        }
    }
}

/// Build proposal-wide metadata shared across manifest segments and payload derivation.
fn build_bundle_meta(
    event: &ProposedEventContext,
    last_finalized_proposal_id: Option<u64>,
) -> BundleMeta {
    BundleMeta {
        proposal_id: event.event.id.to::<u64>(),
        last_finalized_proposal_id,
        proposal_timestamp: event.l1_timestamp,
        l1_block_number: event.l1_block_number,
        l1_block_hash: event.l1_block_hash,
        origin_block_number: event.l1_block_number.saturating_sub(1),
        proposer: event.event.proposer,
        basefee_sharing_pctg: event.event.basefeeSharingPctg,
    }
}

/// Convert a derivation source's blob slice into ordered blob hashes for manifest fetch.
fn derivation_source_to_blob_hashes(source: &DerivationSource) -> Vec<B256> {
    source.blobSlice.blobHashes.iter().map(|hash| B256::from_slice(hash.as_ref())).collect()
}

/// Check if a derivation source has a valid blob offset.
/// Returns true if the source has non-empty blob hashes and the offset is within bounds.
fn is_source_offset_valid(source: &DerivationSource) -> bool {
    !source.blobSlice.blobHashes.is_empty()
        && source.blobSlice.offset.to::<usize>() <= PROPOSAL_MAX_BLOB_BYTES - 64
}

/// Return whether parent-anchor recovery should decode the parent block's `anchorV4` / `anchorV3`
/// transaction instead of consulting the anchor contract state.
fn should_decode_parent_anchor_from_tx(chain_id: u64, proposal_id: u64) -> bool {
    chain_id == TAIKO_MAINNET_CHAIN_ID && proposal_id <= MAINNET_ANCHOR_CHECK_SKIP_PROPOSAL_OFFSET
}

/// Decode the parent block's advertised anchor block number from its first `anchorV4`
/// transaction.
fn decode_parent_anchor_block_number(
    parent_block: &RpcBlock<TxEnvelope>,
    anchor_address: Address,
) -> Result<u64, DerivationError> {
    let block_number = parent_block.header.number;
    let txs = parent_block.transactions.as_transactions().ok_or_else(|| {
        DerivationError::Other(anyhow!(
            "parent block {block_number} returned only transaction hashes"
        ))
    })?;
    let first_tx = txs.first().ok_or_else(|| {
        DerivationError::Other(anyhow!("parent block {block_number} contains no transactions"))
    })?;
    let destination = first_tx.to().ok_or_else(|| {
        DerivationError::Other(anyhow!(
            "unable to determine anchor transaction recipient for parent block {block_number}"
        ))
    })?;
    if destination != anchor_address {
        return Err(DerivationError::Other(anyhow!(
            "parent block {block_number} first transaction is not the anchor contract"
        )));
    }

    let input = first_tx.input();
    if let Ok(call) = anchorV4Call::abi_decode(input) {
        return Ok(call.0.0.to::<u64>());
    }
    if let Ok(call) = anchorV3Call::abi_decode(input) {
        return Ok(call._0);
    }

    Err(DerivationError::Other(anyhow!(
        "failed to decode anchorV3/anchorV4 calldata in parent block {block_number}"
    )))
}

/// Ensure forced-inclusion manifests adhere to protocol rules (single block) or default them.
fn validate_forced_inclusion_manifest(
    proposal_id: u64,
    source: &DerivationSource,
    manifest: DerivationSourceManifest,
) -> DerivationSourceManifest {
    if source.isForcedInclusion && manifest.blocks.len() != 1 {
        info!(
            proposal_id,
            blocks = manifest.blocks.len(),
            blob_hashes = source.blobSlice.blobHashes.len(),
            "invalid blocks count in forced-inclusion source manifest, using default payload instead"
        );
        DerivationSourceManifest::default()
    } else {
        manifest
    }
}

/// Shasta-specific derivation pipeline.
///
/// The pipeline consumes proposal logs emitted by the Shasta inbox, resolves the
/// referenced manifests, and converts them into execution payloads that materialise new
/// blocks in the execution engine.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// RPC client bundle used for L1/L2 queries and engine calls.
    rpc: Client<P>,
    /// Builder for Shasta anchor transactions.
    anchor_constructor: AnchorTxConstructor<RootProvider>,
    /// Manifest fetcher used to resolve derivation-source blobs.
    derivation_source_manifest_fetcher:
        Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>>,
    /// Activation timestamp for the Shasta fork on this chain.
    shasta_fork_timestamp: u64,
    /// Minimum base-fee clamp to use for EIP-4396 calculations on this chain.
    min_base_fee_to_clamp: u64,
    /// L2 chain ID for chain-aware derivation and validation rules.
    chain_id: u64,
    /// Initial proposal id used when bootstrapping event sync.
    initial_proposal_id: U256,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Create a new derivation pipeline instance.
    ///
    /// Manifests are fetched via the supplied blob source while the driver client is
    /// reused to query both L1 contracts and L2 execution state.
    #[instrument(skip(rpc, blob_source), name = "shasta_derivation_new")]
    pub async fn new(
        rpc: Client<P>,
        blob_source: Arc<BlobDataSource>,
        initial_proposal_id: U256,
    ) -> Result<Self, DerivationError> {
        let chain_id = rpc.l2_provider.get_chain_id().await?;
        let source_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>> =
            Arc::new(ShastaSourceManifestFetcher::new(blob_source.clone(), chain_id));
        let anchor_address = *rpc.shasta.anchor.address();
        let anchor_constructor =
            AnchorTxConstructor::new(rpc.l2_provider.clone(), anchor_address).await?;
        let shasta_fork_timestamp = shasta_fork_timestamp_for_chain(chain_id)
            .map_err(|err| DerivationError::Other(err.into()))?;
        // Clamp differs by chain; keep derivation-side base-fee math chain-aware.
        let min_base_fee_to_clamp = min_base_fee_for_chain(chain_id);
        info!(
            chain_id,
            shasta_fork_timestamp, min_base_fee_to_clamp, "initialised shasta derivation pipeline"
        );
        Ok(Self {
            rpc,
            anchor_constructor,
            derivation_source_manifest_fetcher: source_manifest_fetcher,
            shasta_fork_timestamp,
            min_base_fee_to_clamp,
            chain_id,
            initial_proposal_id,
        })
    }

    /// Load the parent L2 block used as context when constructing payload attributes.
    ///
    /// Preference is given to the execution engine's cached origin pointer for the proposal.
    /// If unavailable, fall back to the latest canonical block.
    #[instrument(skip(self), fields(proposal_id), level = "debug")]
    async fn load_parent_block(
        &self,
        proposal_id: u64,
    ) -> Result<RpcBlock<TxEnvelope>, DerivationError> {
        tracing::Span::current().record("proposal_id", proposal_id);
        let parent_proposal_id = proposal_id.saturating_sub(1);
        if parent_proposal_id == 0 {
            info!(proposal_id, "using genesis block as parent for first proposal");
            return self
                .rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(0))
                .await?
                .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
                .ok_or(DerivationError::BlockUnavailable(0));
        }
        if let Some(origin) =
            self.rpc.last_l1_origin_by_batch_id(U256::from(parent_proposal_id)).await?
        {
            // Prefer the concrete block referenced by the cached origin hash.
            if origin.l2_block_hash != B256::ZERO
                && let Some(block) =
                    self.rpc.l2_provider.get_block_by_hash(origin.l2_block_hash).await?
            {
                info!(
                    proposal_id,
                    parent_block_number = block.number(),
                    parent_hash = ?origin.l2_block_hash,
                    "using cached origin pointer for parent block"
                );
                return Ok(block.map_transactions(|tx: RpcTransaction| tx.into()));
            }
        }

        // Derive the parent block via the batch-to-block mapping so we always anchor to the last
        // execution block produced for the preceding proposal.
        info!(proposal_id, parent_proposal_id, "loading parent block via batch-to-block mapping");

        let block_number = self
            .rpc
            .last_block_id_by_batch_id(U256::from(parent_proposal_id))
            .await?
            .ok_or(DerivationError::MissingBatchLastBlock { proposal_id: parent_proposal_id })?
            .to::<u64>();
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or(DerivationError::BlockUnavailable(block_number))
    }

    /// Decode a proposal log into the event payload and enrich it with L1 block metadata.
    #[instrument(skip(self, log), level = "debug")]
    async fn decode_log_to_event_context(
        &self,
        log: &Log,
    ) -> Result<ProposedEventContext, DerivationError> {
        let event = Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())?;

        let l1_block_hash = log.block_hash.ok_or(DerivationError::MissingL1BlockHash)?;
        let l1_block_number = log.block_number.ok_or(DerivationError::MissingL1BlockNumber)?;

        let l1_block = self
            .rpc
            .l1_provider
            .get_block_by_hash(l1_block_hash)
            .await?
            .ok_or(DerivationError::BlockUnavailable(l1_block_number))?;

        let l1_timestamp = l1_block.header.timestamp;

        debug!(
            proposal_id = event.id.to::<u64>(),
            l1_block_number = l1_block_number,
            l1_block_hash = ?l1_block_hash,
            source_count = event.sources.len(),
            "decoded proposed event"
        );

        Ok(ProposedEventContext { event, l1_block_number, l1_block_hash, l1_timestamp })
    }

    /// Fetch and decode a single manifest from the blob store.
    ///
    /// The caller is responsible for providing the correct fetcher implementation for
    /// the manifest type.
    async fn fetch_and_decode_manifest<M>(
        &self,
        fetcher: &dyn ManifestFetcher<Manifest = M>,
        source: &DerivationSource,
    ) -> Result<M, DerivationError>
    where
        M: Send,
    {
        let hashes = derivation_source_to_blob_hashes(source);
        let offset = source.blobSlice.offset.to::<u64>() as usize;
        let timestamp = source.blobSlice.timestamp.to::<u64>();
        debug!(hash_count = hashes.len(), offset, timestamp, "fetching manifest sidecars");
        let manifest = fetcher.fetch_and_decode_manifest(timestamp, &hashes, offset).await?;
        Ok(manifest)
    }

    /// Build a proposal bundle from a decoded event payload.
    ///
    /// Sources are processed sequentially in the order they appear, with the proposer's
    /// source appended last per the protocol spec. Each source's `isForcedInclusion` flag
    /// determines validation behavior.
    async fn build_manifest_from_event(
        &self,
        event: &ProposedEventContext,
        last_finalized_proposal_id: Option<u64>,
    ) -> Result<ShastaProposalBundle, DerivationError> {
        let sources = &event.event.sources;
        let proposal_id = event.event.id.to::<u64>();
        info!(proposal_id, source_count = sources.len(), "decoded proposal payload");

        if sources.is_empty() {
            warn!(proposal_id, "proposal contained no derivation sources");
            return Err(DerivationError::EmptyDerivationSources(proposal_id));
        }

        // Fetch and validate all source manifests sequentially in order.
        let mut manifest_segments = Vec::with_capacity(sources.len());
        for source in sources {
            // If source has no blob hashes or invalid offset, use default manifest.
            let manifest = if !is_source_offset_valid(source) {
                DerivationSourceManifest::default()
            } else {
                let manifest = self
                    .fetch_and_decode_manifest(
                        self.derivation_source_manifest_fetcher.as_ref(),
                        source,
                    )
                    .await?;
                validate_forced_inclusion_manifest(proposal_id, source, manifest)
            };
            manifest_segments.push(SourceManifestSegment {
                manifest,
                is_forced_inclusion: source.isForcedInclusion,
            });
        }

        // Assemble the full Shasta protocol proposal bundle.
        let bundle = ShastaProposalBundle {
            meta: build_bundle_meta(event, last_finalized_proposal_id),
            sources: manifest_segments,
        };

        if let Some(last_finalized_proposal_id) = bundle.meta.last_finalized_proposal_id {
            gauge!(DriverMetrics::DERIVATION_LAST_FINALIZED_PROPOSAL_ID)
                .set(last_finalized_proposal_id as f64);
        }

        info!(proposal_id, segment_count = bundle.sources.len(), "assembled proposal bundle");
        Ok(bundle)
    }

    /// Initialize the rolling parent state used while constructing payload attributes.
    #[instrument(skip(self, parent_block), level = "debug")]
    async fn initialize_parent_state(
        &self,
        parent_block: &RpcBlock<TxEnvelope>,
        proposal_id: u64,
    ) -> Result<ParentState, DerivationError> {
        let parent_header = parent_block.header.inner.clone();
        let anchor_block_number = if should_decode_parent_anchor_from_tx(self.chain_id, proposal_id)
        {
            decode_parent_anchor_block_number(parent_block, *self.rpc.shasta.anchor.address())?
        } else {
            self.rpc.shasta_anchor_state_by_hash(parent_block.hash()).await?.anchor_block_number
        };

        let grandparent_timestamp = if parent_header.number == 0 {
            parent_header.timestamp
        } else {
            let grandparent_block = self
                .rpc
                .l2_provider
                .get_block_by_hash(parent_header.parent_hash)
                .await?
                .ok_or_else(|| {
                    DerivationError::BlockUnavailable(parent_header.number.saturating_sub(1))
                })?;

            grandparent_block.header.timestamp
        };

        let state = ParentState {
            parent_block_time_delta_secs: parent_header
                .timestamp
                .saturating_sub(grandparent_timestamp),
            header: parent_header,
            anchor_block_number,
            shasta_fork_timestamp: self.shasta_fork_timestamp,
            min_base_fee_to_clamp: self.min_base_fee_to_clamp,
            chain_id: self.chain_id,
        };
        debug!(
            parent_number = state.header.number,
            parent_hash = ?state.header.hash_slow(),
            anchor_block = state.anchor_block_number,
            "initialised parent state for proposal derivation"
        );

        Ok(state)
    }
}

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    type Manifest = ShastaProposalBundle;

    // Convert a proposal log into a manifest for processing.
    #[instrument(skip(self, log), name = "shasta_manifest_from_log")]
    async fn log_to_manifest(&self, log: &Log) -> Result<Self::Manifest, DerivationError> {
        let event = self.decode_log_to_event_context(log).await?;
        self.build_manifest_from_event(
            &event,
            try_last_finalized_proposal_id_at_block(&self.rpc, event.l1_block_hash).await,
        )
        .await
    }

    // Convert a manifest into execution engine blocks for block production.
    #[instrument(skip(self, manifest, applier), name = "shasta_manifest_to_blocks")]
    async fn manifest_to_engine_blocks(
        &self,
        manifest: Self::Manifest,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let ShastaProposalBundle { meta, sources, .. } = manifest;
        if meta.proposal_id < self.initial_proposal_id.to() {
            info!(
                proposal_id = meta.proposal_id,
                initial_proposal_id = ?self.initial_proposal_id,
                "skipping proposal below initial proposal id"
            );
            counter!(DriverMetrics::EVENT_PROPOSALS_SKIPPED_TOTAL).increment(1);
            return Ok(Vec::new());
        }
        info!(
            proposal_id = meta.proposal_id,
            origin_block = meta.origin_block_number,
            segment_count = sources.len(),
            "deriving execution blocks from bundle"
        );

        let parent_block = self.load_parent_block(meta.proposal_id).await?;
        let mut parent_state =
            self.initialize_parent_state(&parent_block, meta.proposal_id).await?;

        // If every block already sits in the canonical chain we skip payload submission and only
        // refresh L1 origins.
        if let Some(known_blocks) =
            self.detect_known_canonical_proposal(&meta, &sources, &parent_state).await?
        {
            let outcomes =
                known_blocks.iter().map(|block| block.outcome.clone()).collect::<Vec<_>>();
            counter!(DriverMetrics::DERIVATION_CANONICAL_HITS_TOTAL).increment(1);
            self.update_canonical_proposal_origins(&meta, &known_blocks).await?;
            return Ok(outcomes);
        }

        let outcomes =
            self.build_payloads_from_sources(sources, &meta, &mut parent_state, applier).await?;
        info!(
            proposal_id = meta.proposal_id,
            block_count = outcomes.len(),
            "proposal derivation produced execution blocks"
        );
        Ok(outcomes)
    }

    #[instrument(skip(self, log, applier), name = "shasta_process_proposal")]
    async fn process_proposal(
        &self,
        log: &Log,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let event = self.decode_log_to_event_context(log).await?;
        let proposal_id = event.event.id.to::<u64>();
        let last_finalized_proposal_id =
            try_last_finalized_proposal_id_at_block(&self.rpc, event.l1_block_hash).await;

        if proposal_id == 0 {
            info!(proposal_id, "skipping proposal with zero id");
            counter!(DriverMetrics::EVENT_PROPOSALS_SKIPPED_TOTAL).increment(1);
            return Ok(Vec::new());
        }

        let manifest = self.build_manifest_from_event(&event, last_finalized_proposal_id).await?;
        let outcomes = self.manifest_to_engine_blocks(manifest, applier).await?;

        if let Some(last) = outcomes.last() {
            let last_block_number = last.block_number();
            let last_block_hash = last.block_hash();
            info!(
                proposal_id,
                last_l2_block_number = last_block_number,
                last_l2_block_hash = ?last_block_hash,
                "recorded final l2 block derived from proposal",
            );
        } else {
            info!(
                proposal_id,
                "proposal derivation produced no execution blocks; nothing to record",
            );
        }

        Ok(outcomes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::{
        consensus::{EthereumTypedTransaction, SignableTransaction, TxEip1559},
        eips::eip2930::AccessList,
        primitives::{
            Address, B256, Bytes, FixedBytes, TxKind,
            aliases::{U24, U48},
        },
        rpc::types::eth::BlockTransactions,
        sol_types::SolCall,
    };
    use alloy_provider::{ProviderBuilder, RootProvider};
    use alloy_transport::mock::Asserter;
    use bindings::{
        anchor::{Anchor::AnchorInstance, ICheckpointStore::Checkpoint},
        inbox::{
            IInbox,
            Inbox::{InboxInstance, getCoreStateCall},
            LibBlobs::BlobSlice,
        },
    };
    use protocol::{
        FixedKSigner,
        shasta::{
            AnchorTxConstructor,
            constants::{TAIKO_MAINNET_CHAIN_ID, min_base_fee_for_chain},
            manifest::{BlockManifest, DerivationSourceManifest},
        },
    };
    use rpc::{
        blob::BlobDataSource,
        client::{Client, ShastaProtocolInstance},
    };

    fn sample_derivation_source(
        blob_hashes: Vec<FixedBytes<32>>,
        is_forced: bool,
    ) -> DerivationSource {
        DerivationSource {
            isForcedInclusion: is_forced,
            blobSlice: BlobSlice {
                blobHashes: blob_hashes,
                offset: U24::from(0u32),
                timestamp: U48::from(0u64),
            },
        }
    }

    fn sample_event_context() -> ProposedEventContext {
        ProposedEventContext {
            event: Proposed {
                id: U48::from(11u64),
                proposer: Address::from([2u8; 20]),
                parentProposalHash: FixedBytes::from([3u8; 32]),
                endOfSubmissionWindowTimestamp: U48::from(4u64),
                basefeeSharingPctg: 5,
                sources: vec![sample_derivation_source(vec![], false)],
            },
            l1_block_number: 10,
            l1_block_hash: B256::from([6u8; 32]),
            l1_timestamp: 7,
        }
    }

    fn mock_client_with_l1_asserter(l1_asserter: Asserter) -> Client<RootProvider> {
        mock_client_with_asserters(l1_asserter, Asserter::new(), Asserter::new(), Address::ZERO)
    }

    fn mock_client_with_asserters(
        l1_asserter: Asserter,
        l2_asserter: Asserter,
        l2_auth_asserter: Asserter,
        anchor_address: Address,
    ) -> Client<RootProvider> {
        let l1_provider =
            ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l1_asserter);
        let l2_provider =
            ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l2_asserter);
        let l2_auth_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(l2_auth_asserter);
        let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
        let anchor = AnchorInstance::new(anchor_address, l2_auth_provider.clone());
        let shasta = ShastaProtocolInstance { inbox, anchor };

        Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
    }

    fn sign_test_anchor_tx(anchor_address: Address, input: Bytes) -> TxEnvelope {
        let signer = FixedKSigner::golden_touch().expect("golden touch signer should load");
        let tx = TxEip1559 {
            chain_id: TAIKO_MAINNET_CHAIN_ID,
            nonce: 0,
            max_fee_per_gas: 1_000_000_000,
            max_priority_fee_per_gas: 0,
            gas_limit: 250_000,
            to: TxKind::Call(anchor_address),
            value: U256::ZERO,
            access_list: AccessList::default(),
            input,
        };
        let sighash = tx.signature_hash();
        let mut hash_bytes = [0u8; 32];
        hash_bytes.copy_from_slice(sighash.as_slice());
        let signature =
            signer.sign_with_predefined_k(&hash_bytes).expect("test anchor tx should sign");

        TxEnvelope::new_unchecked(
            EthereumTypedTransaction::Eip1559(tx),
            signature.signature,
            sighash,
        )
    }

    fn sample_anchor_transaction(anchor_address: Address, anchor_block_number: u64) -> TxEnvelope {
        let checkpoint = Checkpoint {
            blockNumber: U48::from(anchor_block_number),
            blockHash: B256::from([0x22; 32]),
            stateRoot: B256::from([0x33; 32]),
        };
        sign_test_anchor_tx(
            anchor_address,
            Bytes::from(anchorV4Call(checkpoint.into()).abi_encode()),
        )
    }

    fn sample_anchor_v3_transaction(
        anchor_address: Address,
        anchor_block_number: u64,
    ) -> TxEnvelope {
        sign_test_anchor_tx(
            anchor_address,
            Bytes::from(
                anchorV3Call {
                    _0: anchor_block_number,
                    _1: B256::from([0x33; 32]),
                    _2: 0,
                    _3: (1, 0, 1, 0, 1),
                    _4: Vec::new(),
                }
                .abi_encode(),
            ),
        )
    }

    #[test]
    fn derivation_source_to_blob_hashes_preserves_order() {
        let source = sample_derivation_source(
            vec![FixedBytes::from([1u8; 32]), FixedBytes::from([2u8; 32])],
            false,
        );
        let hashes = derivation_source_to_blob_hashes(&source);
        assert_eq!(hashes.len(), 2);
        assert_eq!(hashes[0], B256::from([1u8; 32]));
        assert_eq!(hashes[1], B256::from([2u8; 32]));
    }

    #[test]
    fn forced_inclusion_manifest_defaults_when_block_count_invalid() {
        let source = sample_derivation_source(vec![FixedBytes::from([0u8; 32])], true);
        let manifest = DerivationSourceManifest {
            blocks: vec![BlockManifest::default(), BlockManifest::default()],
        };

        let validated = validate_forced_inclusion_manifest(1, &source, manifest);

        assert_eq!(validated.blocks.len(), 1);
    }

    #[test]
    fn bundle_meta_preserves_absent_finalized_proposal_id() {
        let event = sample_event_context();

        let meta = build_bundle_meta(&event, None);

        assert_eq!(meta.proposal_id, 11);
        assert_eq!(meta.last_finalized_proposal_id, None);
        assert_eq!(meta.origin_block_number, 9);
    }

    #[test]
    fn mainnet_bootstrap_proposals_skip_anchor_state_lookup() {
        assert!(should_decode_parent_anchor_from_tx(TAIKO_MAINNET_CHAIN_ID, 1));
        assert!(should_decode_parent_anchor_from_tx(TAIKO_MAINNET_CHAIN_ID, 7));
        assert!(!should_decode_parent_anchor_from_tx(TAIKO_MAINNET_CHAIN_ID, 8));
        assert!(!should_decode_parent_anchor_from_tx(167_013, 7));
    }

    #[test]
    fn decode_parent_anchor_block_number_accepts_anchor_v3() {
        let anchor_address = Address::repeat_byte(0x44);
        let anchor_block_number = 55u64;
        let mut parent_block = RpcBlock::<TxEnvelope>::default();
        parent_block.header.number = 1;
        parent_block.transactions = BlockTransactions::Full(vec![sample_anchor_v3_transaction(
            anchor_address,
            anchor_block_number,
        )]);

        let decoded = decode_parent_anchor_block_number(&parent_block, anchor_address)
            .expect("anchorV3 calldata should decode");

        assert_eq!(decoded, anchor_block_number);
    }

    #[tokio::test]
    async fn initialize_parent_state_decodes_anchor_from_parent_tx_on_mainnet_bootstrap() {
        let l2_asserter = Asserter::new();
        let anchor_address = Address::repeat_byte(0x44);
        let parent_anchor_block_number = 55u64;
        l2_asserter.push_success(&TAIKO_MAINNET_CHAIN_ID);
        let mut grandparent_block = RpcBlock::<TxEnvelope>::default();
        grandparent_block.header.number = 0;
        grandparent_block.header.timestamp = 100;
        l2_asserter.push_success(&Some(grandparent_block));

        let client = mock_client_with_asserters(
            Asserter::new(),
            l2_asserter,
            Asserter::new(),
            anchor_address,
        );
        let blob_source = Arc::new(
            BlobDataSource::new(None, None, true)
                .await
                .expect("blob data source should initialise"),
        );
        let anchor_constructor =
            AnchorTxConstructor::new(client.l2_provider.clone(), anchor_address)
                .await
                .expect("anchor constructor should initialise");
        let pipeline = ShastaDerivationPipeline {
            rpc: client,
            anchor_constructor,
            derivation_source_manifest_fetcher: Arc::new(ShastaSourceManifestFetcher::new(
                blob_source,
                TAIKO_MAINNET_CHAIN_ID,
            )),
            shasta_fork_timestamp: 0,
            min_base_fee_to_clamp: min_base_fee_for_chain(TAIKO_MAINNET_CHAIN_ID),
            chain_id: TAIKO_MAINNET_CHAIN_ID,
            initial_proposal_id: U256::ZERO,
        };

        let mut parent_block = RpcBlock::<TxEnvelope>::default();
        parent_block.header.number = 1;
        parent_block.header.timestamp = 112;
        parent_block.header.parent_hash = B256::from([0x11; 32]);
        parent_block.transactions = BlockTransactions::Full(vec![sample_anchor_transaction(
            anchor_address,
            parent_anchor_block_number,
        )]);

        let state = pipeline
            .initialize_parent_state(&parent_block, 7)
            .await
            .expect("mainnet bootstrap should decode parent anchor from tx");

        assert_eq!(state.anchor_block_number, parent_anchor_block_number);
        assert_eq!(state.parent_block_time_delta_secs, 12);
    }

    #[tokio::test]
    async fn finalized_proposal_id_at_block_returns_some_on_success() {
        let asserter = Asserter::new();
        let client = mock_client_with_l1_asserter(asserter.clone());
        let core_state = IInbox::CoreState {
            nextProposalId: U48::from(9u64),
            lastProposalBlockId: U48::from(8u64),
            lastFinalizedProposalId: U48::from(7u64),
            lastFinalizedTimestamp: U48::from(6u64),
            lastCheckpointTimestamp: U48::from(5u64),
            lastFinalizedBlockHash: FixedBytes::from([4u8; 32]),
        };
        let encoded = Bytes::from(getCoreStateCall::abi_encode_returns(&core_state));
        asserter.push_success(&encoded);

        let proposal_id =
            try_last_finalized_proposal_id_at_block(&client, B256::from([1u8; 32])).await;

        assert_eq!(proposal_id, Some(7));
    }

    #[tokio::test]
    async fn finalized_proposal_id_at_block_returns_none_on_rpc_error() {
        let asserter = Asserter::new();
        let client = mock_client_with_l1_asserter(asserter.clone());
        asserter.push_failure_msg("boom");

        let proposal_id =
            try_last_finalized_proposal_id_at_block(&client, B256::from([1u8; 32])).await;

        assert_eq!(proposal_id, None);
    }
}
