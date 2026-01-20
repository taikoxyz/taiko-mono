//! Transaction builder for constructing proposal transactions.

use alloy::{
    consensus::{BlobTransactionSidecar, SidecarBuilder},
    primitives::{
        Address, Bytes,
        aliases::{U24, U48},
    },
    providers::Provider,
    rpc::types::TransactionRequest,
};
use alloy_network::TransactionBuilder4844;
use bindings::inbox::{IInbox::ProposeInput, LibBlobs::BlobReference};
use protocol::shasta::{
    BlobCoder,
    constants::MAX_BLOCK_GAS_LIMIT,
    manifest::{BlockManifest, DerivationSourceManifest},
};
use rpc::client::ClientWithWallet;
use tracing::info;

use crate::{
    error::{ProposerError, Result},
    proposer::{EnginePayloadParams, TransactionsLists, current_unix_timestamp},
};

/// A transaction builder for Shasta `propose` transactions.
pub struct ShastaProposalTransactionBuilder {
    /// The RPC provider with wallet.
    pub rpc_provider: ClientWithWallet,
    /// The address of the suggested fee recipient for the proposed L2 block.
    pub l2_suggested_fee_recipient: Address,
}

impl ShastaProposalTransactionBuilder {
    /// Creates a new `ShastaProposalTransactionBuilder`.
    pub fn new(rpc_provider: ClientWithWallet, l2_suggested_fee_recipient: Address) -> Self {
        Self { rpc_provider, l2_suggested_fee_recipient }
    }

    /// Build a Shasta `propose` transaction with the given L2 transactions.
    ///
    /// If `engine_params` is provided (engine mode), those parameters will be used directly.
    /// Otherwise, the current L1 head, current timestamp, and MAX_BLOCK_GAS_LIMIT are used.
    pub async fn build(
        &self,
        txs_lists: TransactionsLists,
        engine_params: Option<EnginePayloadParams>,
    ) -> Result<TransactionRequest> {
        // Use provided engine params or derive defaults.
        let (anchor_block_number, timestamp, gas_limit) = match engine_params {
            Some(params) => (params.anchor_block_number, params.timestamp, params.gas_limit),
            None => (
                self.rpc_provider.l1_provider.get_block_number().await?,
                current_unix_timestamp(),
                MAX_BLOCK_GAS_LIMIT,
            ),
        };

        // Build the block manifests.
        let block_manifests = txs_lists
            .iter()
            .enumerate()
            .map(|(index, txs)| {
                info!(
                    block_index = index,
                    tx_count = txs.len(),
                    timestamp,
                    anchor_block_number,
                    gas_limit,
                    coinbase = ?self.l2_suggested_fee_recipient,
                    "setting up derivation source manifest block"
                );
                BlockManifest {
                    timestamp,
                    coinbase: self.l2_suggested_fee_recipient,
                    anchor_block_number,
                    gas_limit,
                    transactions: txs.iter().cloned().map(Into::into).collect(),
                }
            })
            .collect::<Vec<BlockManifest>>();

        // Build the proposal manifest.
        let manifest = DerivationSourceManifest { blocks: block_manifests };

        // Build the blob sidecar from the proposal manifest.
        let sidecar: BlobTransactionSidecar =
            SidecarBuilder::<BlobCoder>::from_slice(&manifest.encode_and_compress()?)
                .build()
                .map_err(|e| ProposerError::Sidecar(e.to_string()))?;

        // Build the propose input.
        let input = ProposeInput {
            deadline: U48::ZERO,
            blobReference: BlobReference {
                blobStartIndex: 0,
                numBlobs: sidecar.blobs.len() as u16,
                offset: U24::ZERO,
            },
            // Include all forced inclusions in the source manifest.
            numForcedInclusions: u16::MAX,
        };

        // Build the transaction request with blob sidecar.
        let request = self
            .rpc_provider
            .shasta
            .inbox
            .propose(
                Bytes::new(),
                self.rpc_provider.shasta.inbox.encodeProposeInput(input).call().await?,
            )
            .into_transaction_request()
            .with_blob_sidecar(sidecar);

        Ok(request)
    }
}
