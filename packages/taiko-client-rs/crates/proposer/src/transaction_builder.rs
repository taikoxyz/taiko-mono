//! Transaction builder for constructing proposal transactions.

use std::time::SystemTime;

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
    proposer::TransactionsLists,
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
    pub async fn build(&self, txs_lists: TransactionsLists) -> Result<TransactionRequest> {
        let config = self.rpc_provider.shasta.inbox.getConfig().call().await?;

        let current_l1_head = self.rpc_provider.l1_provider.get_block_number().await?;
        let anchor_block_number = current_l1_head;
        let timestamp =
            SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap_or_default().as_secs();

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
                    gas_limit = MAX_BLOCK_GAS_LIMIT,
                    coinbase = ?self.l2_suggested_fee_recipient,
                    "setting up derivation source manifest block"
                );
                BlockManifest {
                    timestamp,
                    coinbase: self.l2_suggested_fee_recipient,
                    anchor_block_number,
                    gas_limit: MAX_BLOCK_GAS_LIMIT,
                    transactions: txs.iter().map(|tx| tx.clone().into()).collect(),
                }
            })
            .collect::<Vec<BlockManifest>>();

        // Build the proposal manifest.
        let manifest = DerivationSourceManifest { blocks: block_manifests };

        // Build the blob sidecar from the proposal manifest.
        let sidecar = SidecarBuilder::<BlobCoder>::from_slice(&manifest.encode_and_compress()?)
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
            numForcedInclusions: config.minForcedInclusionCount.to(),
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
