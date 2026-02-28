use alethia_reth_consensus::validation::ANCHOR_V4_SELECTOR;
use alethia_reth_evm::alloy::TAIKO_GOLDEN_TOUCH_ADDRESS;
use alloy_consensus::{
    TxEnvelope,
    transaction::{SignerRecoverable, Transaction as _},
};
use alloy_eips::Decodable2718;
use alloy_primitives::Address;
use protocol::codec::{TxListCodecError, ZlibTxListCodec};
use thiserror::Error;

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    error::{Result, WhitelistPreconfirmationDriverError},
};

use super::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES};

/// Validation failures for the first transaction that must be the Shasta anchor call.
#[derive(Debug, Error)]
enum AnchorTransactionValidationError {
    /// Anchor transaction omitted the recipient field.
    #[error("invalid anchor transaction recipient: <none> (expected {expected})")]
    MissingRecipient {
        /// Required anchor contract address.
        expected: Address,
    },
    /// Anchor transaction targeted the wrong contract.
    #[error("invalid anchor transaction recipient: {actual} (expected {expected})")]
    UnexpectedRecipient {
        /// Actual recipient address found in the transaction.
        actual: Address,
        /// Required anchor contract address.
        expected: Address,
    },
    /// Anchor transaction carried an unexpected chain id.
    #[error("failed to get anchor transaction sender: unexpected chain id {actual:?}")]
    UnexpectedChainId {
        /// Chain id observed on the transaction.
        actual: Option<u64>,
    },
    /// Sender recovery from signature failed.
    #[error("failed to get anchor transaction sender: {reason}")]
    SenderRecovery {
        /// Underlying recover-signature failure.
        reason: String,
    },
    /// Sender did not match the golden touch account.
    #[error("invalid anchor transaction sender: {sender}")]
    UnexpectedSender {
        /// Sender recovered from the transaction signature.
        sender: Address,
    },
    /// Anchor calldata is too short to include a 4-byte selector.
    #[error("failed to get anchor transaction method: missing selector")]
    MissingSelector,
    /// Anchor selector bytes did not match `ANCHOR_V4_SELECTOR`.
    #[error("invalid anchor transaction method: {selector:?}")]
    UnexpectedMethod {
        /// Four-byte function selector encoded in the anchor transaction calldata.
        selector: [u8; 4],
    },
}

/// Validate execution payload shape for preconfirmation import compatibility.
pub(crate) fn validate_execution_payload_for_preconf(
    payload: &alloy_rpc_types_engine::ExecutionPayloadV1,
    chain_id: u64,
    anchor_address: Address,
) -> Result<()> {
    if payload.timestamp == 0 {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "non-zero timestamp is required",
        ));
    }

    if payload.fee_recipient == Address::ZERO {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload("empty L2 fee recipient"));
    }

    if payload.gas_limit == 0 {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "non-zero gas limit is required",
        ));
    }

    if payload.base_fee_per_gas.is_zero() {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "non-zero base fee per gas is required",
        ));
    }

    if payload.extra_data.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload("empty extra data"));
    }

    if payload.transactions.len() != 1 {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "only one transaction list is allowed",
        ));
    }

    let compressed_tx_list = &payload.transactions[0];
    if compressed_tx_list.len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
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
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid zlib bytes for transactions",
                reason,
            )
        }
        TxListCodecError::RlpDecode(reason) => {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid RLP bytes for transactions",
                reason,
            )
        }
        TxListCodecError::CompressedTooLarge { .. } => {
            WhitelistPreconfirmationDriverError::invalid_payload(
                "compressed transactions size exceeds max blob data size".to_string(),
            )
        }
        TxListCodecError::DecompressedTooLarge { .. } => {
            WhitelistPreconfirmationDriverError::invalid_payload(
                "decompressed transactions size exceeds max tx list size".to_string(),
            )
        }
        TxListCodecError::ZlibEncode(reason) | TxListCodecError::ZlibFinish(reason) => {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid transactions list bytes",
                reason,
            )
        }
    })?;

    if txs.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "empty transactions list, missing anchor transaction",
        ));
    }

    let mut first_tx_bytes = txs[0].as_slice();
    let first_tx = TxEnvelope::decode_2718(&mut first_tx_bytes).map_err(|err| {
        WhitelistPreconfirmationDriverError::invalid_payload_with_context(
            "invalid RLP bytes for transactions",
            err,
        )
    })?;

    validate_anchor_transaction_for_preconf(&first_tx, anchor_address, chain_id).map_err(
        |reason| {
            WhitelistPreconfirmationDriverError::invalid_payload_with_context(
                "invalid anchor transaction",
                reason,
            )
        },
    )?;

    Ok(())
}

/// Validate the first transaction in a preconfirmation tx-list as the expected Shasta anchor tx.
fn validate_anchor_transaction_for_preconf(
    tx: &TxEnvelope,
    anchor_address: Address,
    chain_id: u64,
) -> std::result::Result<(), AnchorTransactionValidationError> {
    let to = tx
        .to()
        .ok_or(AnchorTransactionValidationError::MissingRecipient { expected: anchor_address })?;

    if to != anchor_address {
        return Err(AnchorTransactionValidationError::UnexpectedRecipient {
            actual: to,
            expected: anchor_address,
        });
    }

    let actual_chain_id = tx.chain_id();
    if actual_chain_id != Some(chain_id) {
        return Err(AnchorTransactionValidationError::UnexpectedChainId { actual: actual_chain_id });
    }

    let sender = tx.recover_signer().map_err(|err| {
        AnchorTransactionValidationError::SenderRecovery { reason: err.to_string() }
    })?;

    let golden_touch_address = Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS);
    if sender != golden_touch_address {
        return Err(AnchorTransactionValidationError::UnexpectedSender { sender });
    }

    let calldata = tx.input();
    if calldata.len() < ANCHOR_V4_SELECTOR.len() {
        return Err(AnchorTransactionValidationError::MissingSelector);
    }

    let mut selector = [0u8; 4];
    selector.copy_from_slice(&calldata[..4]);
    if selector != *ANCHOR_V4_SELECTOR {
        return Err(AnchorTransactionValidationError::UnexpectedMethod { selector });
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
