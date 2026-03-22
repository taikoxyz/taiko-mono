//! Transaction builder for constructing proposal transactions.

use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alloy::{
    consensus::{BlobTransactionSidecar, SidecarBuilder},
    eips::BlockNumberOrTag,
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
    manifest::{BlockManifest, DerivationSourceManifest},
};
use rpc::client::ClientWithWallet;
use tracing::info;

use crate::{
    error::{ProposerError, Result},
    proposer::{EngineBuildContext, TransactionLists, current_unix_timestamp},
};

/// Derive the gas limit encoded into a Shasta manifest block.
///
/// Engine-mode manifests use the payload gas limit minus the reserved anchor budget. Non-engine
/// manifests mirror the latest L2 parent block's effective gas limit so they satisfy derivation
/// validation instead of defaulting to the protocol fallback payload.
fn manifest_gas_limit(
    engine_params: Option<EngineBuildContext>,
    parent_block_number: u64,
    parent_gas_limit: u64,
) -> u64 {
    match engine_params {
        Some(params) => params.gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT),
        None if parent_block_number == 0 => parent_gas_limit,
        None => parent_gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT),
    }
}

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
    /// Otherwise, the current L1 head, current timestamp, and latest L2 parent gas limit are
    /// used to derive the manifest payload.
    pub async fn build(
        &self,
        txs_lists: TransactionLists,
        engine_params: Option<EngineBuildContext>,
    ) -> Result<TransactionRequest> {
        // Use provided engine params or derive defaults from the latest canonical L2 block.
        let (anchor_block_number, timestamp, gas_limit) = match engine_params {
            Some(params) => (
                params.anchor_block_number,
                params.timestamp,
                manifest_gas_limit(Some(params), 0, 0),
            ),
            None => {
                let parent = self
                    .rpc_provider
                    .l2_provider
                    .get_block_by_number(BlockNumberOrTag::Latest)
                    .await?
                    .ok_or(ProposerError::LatestBlockNotFound)?;

                (
                    self.rpc_provider.l1_provider.get_block_number().await?,
                    current_unix_timestamp(),
                    manifest_gas_limit(None, parent.header.number, parent.header.gas_limit),
                )
            }
        };

        // Build the proposal manifest.
        let manifest = DerivationSourceManifest {
            blocks: txs_lists
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
                .collect::<Vec<BlockManifest>>(),
        };

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn manifest_gas_limit_uses_effective_parent_limit_in_non_engine_mode() {
        assert_eq!(manifest_gas_limit(None, 42, 45_000_000), 44_000_000);
    }

    #[test]
    fn manifest_gas_limit_keeps_genesis_parent_limit_in_non_engine_mode() {
        assert_eq!(manifest_gas_limit(None, 0, 45_000_000), 45_000_000);
    }

    #[test]
    fn manifest_gas_limit_uses_engine_params_with_anchor_discount() {
        let engine_params =
            EngineBuildContext { anchor_block_number: 1, timestamp: 2, gas_limit: 45_000_000 };

        assert_eq!(manifest_gas_limit(Some(engine_params), 42, 30_000_000), 44_000_000);
    }
}
