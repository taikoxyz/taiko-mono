use alethia_reth_consensus::validation::ANCHOR_V4_SELECTOR;
use alethia_reth_evm::alloy::TAIKO_GOLDEN_TOUCH_ADDRESS;
use alloy_consensus::{
    TxEnvelope,
    transaction::{SignerRecoverable, Transaction as _},
};
use alloy_eips::Decodable2718;
use alloy_primitives::Address;
use protocol::codec::{TxListCodecError, ZlibTxListCodec};

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    error::{Result, WhitelistPreconfirmationDriverError},
};

use super::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES};

/// Validate execution payload shape for preconfirmation import compatibility.
pub(crate) fn validate_execution_payload_for_preconf(
    payload: &alloy_rpc_types_engine::ExecutionPayloadV1,
    chain_id: u64,
    anchor_address: Address,
) -> Result<()> {
    if payload.timestamp == 0 {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "non-zero timestamp is required".to_string(),
        ));
    }

    if payload.fee_recipient == Address::ZERO {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "empty L2 fee recipient".to_string(),
        ));
    }

    if payload.gas_limit == 0 {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "non-zero gas limit is required".to_string(),
        ));
    }

    if payload.base_fee_per_gas.is_zero() {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "non-zero base fee per gas is required".to_string(),
        ));
    }

    if payload.extra_data.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "empty extra data".to_string(),
        ));
    }

    if payload.transactions.len() != 1 {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "only one transaction list is allowed".to_string(),
        ));
    }

    let compressed_tx_list = &payload.transactions[0];
    if compressed_tx_list.len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "compressed transactions size exceeds max blob data size".to_string(),
        ));
    }

    let txs = ZlibTxListCodec::new_with_limits(
        MAX_COMPRESSED_TX_LIST_BYTES,
        MAX_DECOMPRESSED_TX_LIST_BYTES,
    )
    .decode(compressed_tx_list)
    .map_err(|err| match err {
        TxListCodecError::ZlibDecode(reason) => {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "invalid zlib bytes for transactions: {reason}"
            ))
        }
        TxListCodecError::RlpDecode(reason) => WhitelistPreconfirmationDriverError::InvalidPayload(
            format!("invalid RLP bytes for transactions: {reason}"),
        ),
        TxListCodecError::CompressedTooLarge { .. } => {
            WhitelistPreconfirmationDriverError::InvalidPayload(
                "compressed transactions size exceeds max blob data size".to_string(),
            )
        }
        TxListCodecError::DecompressedTooLarge { .. } => {
            WhitelistPreconfirmationDriverError::InvalidPayload(
                "decompressed transactions size exceeds max tx list size".to_string(),
            )
        }
        TxListCodecError::ZlibEncode(reason) | TxListCodecError::ZlibFinish(reason) => {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "invalid transactions list bytes: {reason}"
            ))
        }
    })?;

    if txs.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "empty transactions list, missing anchor transaction".to_string(),
        ));
    }

    let mut first_tx_bytes = txs[0].as_slice();
    let first_tx = TxEnvelope::decode_2718(&mut first_tx_bytes).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "invalid RLP bytes for transactions: {err}"
        ))
    })?;

    validate_anchor_transaction_for_preconf(&first_tx, anchor_address, chain_id).map_err(
        |reason| {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "invalid anchor transaction: {reason}"
            ))
        },
    )?;

    Ok(())
}

/// Validate the first transaction in a preconfirmation tx-list as the expected Shasta anchor tx.
fn validate_anchor_transaction_for_preconf(
    tx: &TxEnvelope,
    anchor_address: Address,
    chain_id: u64,
) -> std::result::Result<(), String> {
    let to = tx.to().ok_or_else(|| {
        format!("invalid anchor transaction recipient: <none> (expected {anchor_address})")
    })?;

    if to != anchor_address {
        return Err(format!(
            "invalid anchor transaction recipient: {to} (expected {anchor_address})"
        ));
    }

    let actual_chain_id = tx.chain_id();
    if actual_chain_id != Some(chain_id) {
        return Err(format!(
            "failed to get anchor transaction sender: unexpected chain id {actual_chain_id:?}"
        ));
    }

    let sender = tx
        .recover_signer()
        .map_err(|err| format!("failed to get anchor transaction sender: {err}"))?;

    let golden_touch_address = Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS);
    if sender != golden_touch_address {
        return Err(format!("invalid anchor transaction sender: {sender}"));
    }

    let calldata = tx.input();
    if calldata.len() < ANCHOR_V4_SELECTOR.len() {
        return Err("failed to get anchor transaction method: missing selector".to_string());
    }

    let mut selector = [0u8; 4];
    selector.copy_from_slice(&calldata[..4]);
    if selector != *ANCHOR_V4_SELECTOR {
        return Err(format!(
            "invalid anchor transaction method: 0x{:02x}{:02x}{:02x}{:02x}",
            selector[0], selector[1], selector[2], selector[3]
        ));
    }

    Ok(())
}

/// Ensure unsafe payload envelopes carry an embedded signature for response-topic compatibility.
pub(super) fn normalize_unsafe_payload_envelope(
    mut envelope: WhitelistExecutionPayloadEnvelope,
    wire_signature: [u8; 65],
) -> WhitelistExecutionPayloadEnvelope {
    if envelope.signature.is_none() {
        envelope.signature = Some(wire_signature);
    }
    envelope
}
