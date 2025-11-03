//! Transaction builder for constructing proposal transactions.

use std::{sync::Arc, time::SystemTime};

use alloy::{
    consensus::SidecarBuilder,
    primitives::{
        Address, Bytes,
        aliases::{U24, U48},
    },
    providers::Provider,
    rpc::types::TransactionRequest,
};
use alloy_network::TransactionBuilder4844;
use bindings::codec_optimized::{IInbox::ProposeInput, LibBlobs::BlobReference};
use event_indexer::{indexer::ShastaEventIndexer, interface::ShastaProposeInputReader};
use protocol::shasta::{
    BlobCoder,
    constants::MIN_ANCHOR_OFFSET,
    manifest::{BlockManifest, DerivationSourceManifest},
};
use rpc::client::ClientWithWallet;
use tracing::info;

use crate::{
    error::{ProposerError, Result},
    proposer::TransactionsLists,
};

/// A transaction builder for Shasta `propose` transactions.
pub struct ShastaProposalTransactionBuilder {
    /// The RPC provider with wallet.
    pub rpc_provider: ClientWithWallet,
    /// The address of the suggested fee recipient for the proposed L2 block.
    pub l2_suggested_fee_recipient: Address,
    /// The event indexer to read cached propose input params.
    pub event_indexer: Arc<ShastaEventIndexer>,
}

impl ShastaProposalTransactionBuilder {
    /// Creates a new `ShastaProposalTransactionBuilder`.
    pub fn new(
        rpc_provider: ClientWithWallet,
        event_indexer: Arc<ShastaEventIndexer>,
        l2_suggested_fee_recipient: Address,
    ) -> Self {
        Self { rpc_provider, event_indexer, l2_suggested_fee_recipient }
    }

    /// Build a Shasta `propose` transaction with the given L2 transactions.
    pub async fn build(&self, txs_lists: TransactionsLists) -> Result<TransactionRequest> {
        let config = self.rpc_provider.shasta.inbox.getConfig().call().await?;

        // Read cached propose input params from the event indexer.
        let cached_input_params = self
            .event_indexer
            .read_shasta_propose_input()
            .ok_or(ProposerError::ProposeInputUnavailable)?;

        info!(
            core_state = ?cached_input_params.core_state,
            proposals_count = cached_input_params.proposals.len(),
            transition_records_count = cached_input_params.transition_records.len(),
            checkpoint = ?cached_input_params.checkpoint,
            "cached propose input params"
        );

        // Ensure the current L1 head is sufficiently advanced.
        let current_l1_head = self.rpc_provider.l1_provider.get_block_number().await?;
        if current_l1_head <= MIN_ANCHOR_OFFSET {
            return Err(ProposerError::L1HeadTooLow {
                current: current_l1_head,
                minimum: MIN_ANCHOR_OFFSET,
            });
        }

        // Build the block manifests.
        let block_manifests = txs_lists
            .iter()
            .map(|txs| BlockManifest {
                timestamp: SystemTime::now()
                    .duration_since(SystemTime::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs(),
                coinbase: self.l2_suggested_fee_recipient,
                anchor_block_number: current_l1_head - (MIN_ANCHOR_OFFSET + 1),
                gas_limit: 0, /* Use 0 for gas limit as it will be set as its parent's gas
                               * limit during derivation. */
                transactions: txs.iter().map(|tx| tx.clone().into()).collect(),
            })
            .collect::<Vec<BlockManifest>>();

        // Build the proposal manifest.
        let manifest =
            DerivationSourceManifest { prover_auth_bytes: Bytes::new(), blocks: block_manifests };

        // Build the blob sidecar from the proposal manifest.
        let sidecar = SidecarBuilder::<BlobCoder>::from_slice(&manifest.encode_and_compress()?)
            .build()
            .map_err(|e| ProposerError::Sidecar(e.to_string()))?;

        // Build the propose input.
        let input = ProposeInput {
            deadline: U48::ZERO,
            coreState: cached_input_params.core_state,
            parentProposals: cached_input_params.proposals,
            blobReference: BlobReference {
                blobStartIndex: 0,
                numBlobs: sidecar.blobs.len() as u16,
                offset: U24::ZERO,
            },
            transitionRecords: cached_input_params.transition_records,
            checkpoint: cached_input_params.checkpoint,
            numForcedInclusions: config.minForcedInclusionCount.to(),
        };

        // Build the transaction request with blob sidecar.
        let request = self
            .rpc_provider
            .shasta
            .inbox
            .propose(
                Bytes::new(),
                self.rpc_provider.shasta.codec.encodeProposeInput(input).call().await?,
            )
            .into_transaction_request()
            .with_blob_sidecar(sidecar);

        Ok(request)
    }
}
