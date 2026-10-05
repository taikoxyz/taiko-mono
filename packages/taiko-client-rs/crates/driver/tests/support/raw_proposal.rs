//! Proposals whose blob carries caller-chosen bytes instead of the proposer's manifest, shared by
//! the scenarios that need sources the proposer never builds.

use super::*;
use alloy::{
    consensus::SidecarBuilder,
    network::TransactionBuilder4844,
    rpc::types::{TransactionInput, TransactionRequest},
};
use alloy_eips::eip7594::BlobTransactionSidecarVariant;
use alloy_primitives::Address;
use protocol::shasta::BlobCoder;

/// Rebuilds the `base` proposal with a blob that encodes `payload` instead of its manifest.
///
/// The calldata is kept as is: it references blobs by index, so it stays valid as long as the
/// blob count does not change. Returns the request and the sidecar the beacon stub must serve.
pub(super) fn with_blob_payload(
    base: &BuiltProposalTx,
    payload: &[u8],
) -> Result<(TransactionRequest, BlobTransactionSidecarVariant)> {
    let BlobTransactionSidecarVariant::Eip4844(original) = base.blob_sidecar() else {
        anyhow::bail!("unexpected proposal sidecar variant");
    };
    let sidecar: alloy_consensus::BlobTransactionSidecar =
        SidecarBuilder::<BlobCoder>::from_slice(payload).build()?;
    ensure!(sidecar.blobs.len() == original.blobs.len(), "template blob reference changed");
    let original_request = base.to_transaction_request();
    let request = TransactionRequest {
        to: original_request.to,
        input: TransactionInput::both(
            original_request.input.into_input().context("missing proposal calldata")?,
        ),
        value: Some(U256::ZERO),
        ..Default::default()
    }
    .with_blob_sidecar(sidecar.clone());
    Ok((request, BlobTransactionSidecarVariant::Eip4844(sidecar)))
}

/// Submits a raw proposal request through a wallet-backed L1 provider and returns the proposal
/// ID and the sender.
pub(super) async fn submit_raw_proposal(
    env: &ShastaEnv,
    request: TransactionRequest,
) -> Result<(u64, Address)> {
    let wallet = env
        .client_config
        .l1_provider_source
        .to_provider_with_wallet(env.l1_proposer_private_key)
        .await?;
    let receipt = wallet.send_transaction(request).await?.get_receipt().await?;
    ensure!(receipt.status(), "proposal reverted");
    let log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == env.inbox_address)
        .context("missing proposal event")?;
    Ok((decode_proposal_id(log)?, receipt.from))
}
