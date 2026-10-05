//! Payload-level validation for preconfirmation import compatibility.

use alethia_reth_primitives::ETNA_EXTRA_DATA_LEN;
use alloy_consensus::TxEnvelope;
use alloy_eips::Decodable2718;
use alloy_primitives::{Address, B256};
use protocol::{
    codec::ZlibTxListCodec,
    shasta::{is_etna_at, unzen_active_for_chain_timestamp, validate_anchor_transaction},
};

use crate::{
    codec::{
        MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES,
        WhitelistExecutionPayloadEnvelope,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
};

/// Validate execution payload shape for preconfirmation import compatibility.
///
/// Shared by REST builds and P2P imports. The fork is decided by the payload's own timestamp
/// against `etna_fork_timestamp`, the chain's already-resolved Etna activation time (`None`
/// while Etna is not scheduled):
///
/// | Rule                       | Pre-Etna                              | Etna                      |
/// | -------------------------- | ------------------------------------- | ------------------------- |
/// | `parent_beacon_block_root` | absent or zero                        | present and nonzero       |
/// | `extra_data`               | non-empty                             | exactly 13 bytes          |
/// | transaction list           | non-empty, tx[0] is the anchor tx     | may be empty, tx[0] free  |
///
/// The gas limit only has to be nonzero in both forks and is passed through unchanged.
pub(crate) fn validate_execution_payload_for_preconf(
    payload: &alloy_rpc_types_engine::ExecutionPayloadV1,
    parent_beacon_block_root: Option<B256>,
    etna_fork_timestamp: Option<u64>,
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

    let is_etna = is_etna_at(etna_fork_timestamp, payload.timestamp);
    validate_fork_beacon_root(is_etna, payload.timestamp, parent_beacon_block_root)?;

    if is_etna {
        if payload.extra_data.len() != ETNA_EXTRA_DATA_LEN {
            return Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
                "Etna extra data must be exactly {ETNA_EXTRA_DATA_LEN} bytes, got {}",
                payload.extra_data.len()
            )));
        }
    } else if payload.extra_data.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload("empty extra data"));
    }

    if payload.transactions.len() != 1 {
        return Err(WhitelistPreconfirmationDriverError::invalid_payload(
            "only one transaction list is allowed",
        ));
    }

    let compressed_tx_list = &payload.transactions[0];
    let txs = ZlibTxListCodec::new_with_limits(
        MAX_COMPRESSED_TX_LIST_BYTES,
        MAX_DECOMPRESSED_TX_LIST_BYTES,
    )
    .decode(compressed_tx_list)
    .map_err(|err| {
        WhitelistPreconfirmationDriverError::invalid_payload_with_context(
            "invalid transactions list bytes",
            err,
        )
    })?;

    // An Etna block has no anchor transaction: its list may be empty and its first transaction
    // is an ordinary one.
    if is_etna {
        return Ok(());
    }

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

    validate_anchor_transaction(&first_tx, anchor_address, chain_id).map_err(|reason| {
        WhitelistPreconfirmationDriverError::invalid_payload_with_context(
            "invalid anchor transaction",
            reason,
        )
    })?;

    Ok(())
}

/// Enforce the fork's `parentBeaconBlockRoot` rule on a preconfirmation payload.
///
/// An Etna payload must carry a nonzero root (the L1 state root of its anchor block); a pre-Etna
/// payload must carry none or a zero one. A missing root counts as zero.
fn validate_fork_beacon_root(
    is_etna: bool,
    timestamp: u64,
    parent_beacon_block_root: Option<B256>,
) -> Result<()> {
    let root = parent_beacon_block_root.unwrap_or_default();
    match (is_etna, root.is_zero()) {
        (true, true) => Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "Etna payload at timestamp {timestamp} requires a nonzero parent beacon block root",
        ))),
        (false, false) => Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "pre-Etna payload at timestamp {timestamp} carries nonzero parent beacon block root \
             {root}",
        ))),
        _ => Ok(()),
    }
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

/// Reject envelopes whose `header_difficulty` presence contradicts the Unzen
/// status at the payload timestamp.
///
/// - Unzen active + `None` or zero                → error
/// - Unzen inactive + `Some(non_zero)`            → error
pub(crate) fn validate_envelope_header_difficulty(
    chain_id: u64,
    timestamp: u64,
    header_difficulty: Option<alloy_primitives::U256>,
) -> Result<()> {
    let unzen = unzen_active_for_chain_timestamp(chain_id, timestamp).map_err(|err| {
        WhitelistPreconfirmationDriverError::invalid_payload_with_context(
            &format!("unzen fork lookup failed for chain {chain_id} at timestamp {timestamp}"),
            err,
        )
    })?;
    let present = header_difficulty.map(|v| !v.is_zero()).unwrap_or(false);

    match (unzen, present) {
        (true, false) => Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "unzen active at timestamp {timestamp} but envelope is missing header difficulty",
        ))),
        (false, true) => Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
            "unzen inactive at timestamp {timestamp} but envelope carries non-zero header difficulty",
        ))),
        _ => Ok(()),
    }
}
