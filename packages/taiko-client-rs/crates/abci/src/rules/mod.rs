//! Header derivation and block-validity predicates (spec §4.2, §5.4). No I/O.
//!
//! [`expected_header`] derives every consensus-chosen field of the L2 block at height `H` from
//! the committed parent, the block's L1 anchor, the BFT time, the recovery generation and the
//! chain constants. `PrepareProposal` builds with [`payload_attributes`] of that header;
//! `ProcessProposal` and `FinalizeBlock` recompute it and compare with [`check_header`]. The
//! remaining predicates cover anchor progress, back-pressure (HALT-03), the generation triple
//! and the CometBFT `chain_id`.
//!
//! Execution results (state root, receipts root, transactions root, gas used and the zk gas in
//! `difficulty`) are not checked here: `engine_newPayload` validates them.

use std::fmt::Debug;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::{EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header};
use alloy_eips::eip7685::EMPTY_REQUESTS_HASH;
use alloy_primitives::{Address, B64, B256, Bytes, U256};
use protocol::shasta::{
    PayloadAttributesInput, ProtocolError, build_payload_attributes_with_id,
    calculate_shasta_mix_hash, constants::calculate_next_block_eip4396_base_fee_for_parent,
    encode_etna_extra_data,
};

use crate::{
    config::ChainParams,
    schedule::Schedule,
    types::{AnchorState, ParentInfo},
};

/// `basefeeSharingPctg` of every Etna PoS block: 100 routes the whole base fee to the coinbase
/// (the fee vault) under alethia-reth #248 (D10).
pub const BASEFEE_SHARING_PCTG: u8 = 100;

/// Length of an Etna `extraData`: `[pctg(1) | generation(6) | anchorNumber(6)]`.
pub const EXTRA_DATA_LEN: usize = 13;

/// CometBFT's `MaxChainIDLen`: the longest `chain_id` a genesis may carry, in bytes.
pub const MAX_CHAIN_ID_LEN: usize = 50;

/// Prefix of every Etna PoS CometBFT `chain_id` (`taiko-etna-<l2ChainId>-g<generation>`).
const CHAIN_ID_PREFIX: &str = "taiko-etna-";

/// Everything [`expected_header`] derives the header of height `height` from.
#[derive(Clone, Copy, Debug)]
pub struct HeaderInputs<'a> {
    /// CometBFT height `H` of the block, which is also its L2 block number (D8).
    pub height: u64,
    /// The committed parent block (`H - 1`).
    pub parent: &'a ParentInfo,
    /// The block's L1 anchor: the one its witness proves, or the parent's when it carries none.
    pub anchor: &'a AnchorState,
    /// `floor(time_H)`: the block's BFT time, in whole seconds since the Unix epoch.
    pub bft_time_secs: u64,
    /// Recovery generation of the running chain (the `chain_id` suffix).
    pub generation: u64,
    /// Chain constants (fee vault, block gas limit).
    pub params: &'a ChainParams,
    /// EIP-4396 minimum base fee clamp of the L2 chain, in wei
    /// (`protocol::shasta::constants::min_base_fee_for_chain`).
    pub min_base_fee: u64,
}

/// The consensus-chosen header fields of one block (spec §4.2).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExpectedHeader {
    /// L2 block number, equal to the CometBFT height.
    pub number: u64,
    /// EL hash of the committed parent block.
    pub parent_hash: B256,
    /// Block timestamp in seconds: `max(parent.timestamp + 1, floor(time_H), anchor.timestamp)`.
    pub timestamp: u64,
    /// Coinbase and suggested fee recipient: the chain's `L2FeeVault` (D11).
    pub beneficiary: Address,
    /// The 13-byte `[100 | generation | anchorNumber]` `extraData` (D10).
    pub extra_data: Bytes,
    /// The anchor's L1 state root.
    pub parent_beacon_block_root: B256,
    /// `L2_BLOCK_GAS_LIMIT`, in gas (D12).
    pub gas_limit: u64,
    /// EIP-4396 base fee per gas, in wei.
    pub base_fee: u64,
    /// Shasta mix hash (`prevRandao`) of the parent's `difficulty` and the height.
    pub mix_hash: B256,
}

/// Outcome of [`check_generation`] when the block's own generation fields agree.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GenerationCheck {
    /// The chain, the block and the Inbox all carry the same generation.
    Ok,
    /// The Inbox has moved to a later generation: this chain is superseded. The caller sets the
    /// `superseded` status and rejects every proposal from then on.
    Superseded,
}

/// Why a block, header or `chain_id` breaks a consensus rule.
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum RuleViolation {
    /// The block height is not the parent's number plus one (D8).
    #[error("height {height} does not follow parent block {parent}")]
    HeightMismatch {
        /// The block's height.
        height: u64,
        /// The committed parent's block number.
        parent: u64,
    },
    /// A header field differs from its derived value; the first differing field is reported.
    #[error("header field {field} is {got}, expected {expected}")]
    HeaderField {
        /// The `alloy_consensus::Header` field name.
        field: &'static str,
        /// The derived value, `Debug`-formatted.
        expected: String,
        /// The header's value, `Debug`-formatted.
        got: String,
    },
    /// A number does not fit its 6-byte `uint48` `extraData` slot.
    #[error("extraData field {field} value {value} does not fit in uint48")]
    ExtraDataOverflow {
        /// The protocol field name: `proposal_id` (the slot carrying the generation) or
        /// `anchor_block_number`.
        field: &'static str,
        /// The rejected value.
        value: u64,
    },
    /// The `extraData` is not exactly [`EXTRA_DATA_LEN`] bytes.
    #[error("extraData is {len} bytes, expected {EXTRA_DATA_LEN}")]
    ExtraDataLength {
        /// The rejected length, in bytes.
        len: usize,
    },
    /// The EIP-4396 base fee cannot be derived from the parent.
    #[error("cannot derive the base fee from parent block {parent}")]
    BaseFeeUnavailable {
        /// The parent's block number.
        parent: u64,
    },
    /// The anchor L1 block is older than the parent's anchor (SYS-02(c)).
    #[error("anchor {anchor} is below the parent's anchor {parent}")]
    AnchorRegressed {
        /// The parent's anchor L1 block number.
        parent: u64,
        /// The block's anchor L1 block number.
        anchor: u64,
    },
    /// The anchor L1 block precedes the Etna activation block `L1_0`.
    #[error("anchor {anchor} is below the activation block L1_0 = {l1_0}")]
    AnchorBeforeActivation {
        /// The block's anchor L1 block number.
        anchor: u64,
        /// `L1_0`.
        l1_0: u64,
    },
    /// The anchor L1 block is below the block's epoch minimum `L1_first(epoch)` (CONS-13(2)).
    #[error("epoch {epoch} is not open on L1: the anchor must be >= {l1_first}")]
    EpochNotOpenOnL1 {
        /// The epoch of the block's height.
        epoch: u64,
        /// `L1_first(epoch)`, the minimum anchor L1 block number of that epoch.
        l1_first: u64,
    },
    /// The unsettled depth `H - lastCheckpoint.height` exceeds `D_MAX - MARGIN_V` (HALT-03).
    #[error("unsettled depth {depth} exceeds the cap {cap}")]
    BackPressure {
        /// `H - lastCheckpoint.height`, in L2 blocks (0 when the checkpoint is not behind).
        depth: u64,
        /// `D_MAX - MARGIN_V`, in L2 blocks.
        cap: u64,
    },
    /// The `extraData` generation differs from the `chain_id` generation.
    #[error("extraData generation {extra} differs from the chain generation {chain}")]
    GenerationMismatch {
        /// Generation in the `chain_id` suffix.
        chain: u64,
        /// Generation in the block's `extraData`.
        extra: u64,
    },
    /// The chain claims a generation the Inbox has not reached yet.
    #[error("chain generation {chain} is ahead of the Inbox recoveryGeneration {inbox}")]
    GenerationAhead {
        /// Generation in the `chain_id` suffix.
        chain: u64,
        /// The Inbox `recoveryGeneration` proven at the anchor.
        inbox: u64,
    },
    /// The CometBFT `chain_id` is not `taiko-etna-<l2ChainId>-g<generation>` for this chain.
    #[error("chain_id {chain_id:?} is not taiko-etna-{l2_chain_id}-g<generation>")]
    InvalidChainId {
        /// The rejected `chain_id`.
        chain_id: String,
        /// The L2 EVM chain id it must name.
        l2_chain_id: u64,
    },
}

impl RuleViolation {
    /// A stable snake_case label of the variant, for the rejection-reason metric.
    pub fn label(&self) -> &'static str {
        match self {
            Self::HeightMismatch { .. } => "height_mismatch",
            Self::HeaderField { .. } => "header_field",
            Self::ExtraDataOverflow { .. } => "extra_data_overflow",
            Self::ExtraDataLength { .. } => "extra_data_length",
            Self::BaseFeeUnavailable { .. } => "base_fee_unavailable",
            Self::AnchorRegressed { .. } => "anchor_regressed",
            Self::AnchorBeforeActivation { .. } => "anchor_before_activation",
            Self::EpochNotOpenOnL1 { .. } => "epoch_not_open_on_l1",
            Self::BackPressure { .. } => "back_pressure",
            Self::GenerationMismatch { .. } => "generation_mismatch",
            Self::GenerationAhead { .. } => "generation_ahead",
            Self::InvalidChainId { .. } => "invalid_chain_id",
        }
    }
}

/// D9: `max(parent_ts + 1, bft_secs, anchor_ts)`, all in seconds.
///
/// The parent bound keeps timestamps strictly increasing even when `floor(time_H)` does not
/// advance past the parent (strict equality with BFT time could deadlock a height). Saturates at
/// `u64::MAX`.
pub fn block_timestamp(parent_ts: u64, bft_secs: u64, anchor_ts: u64) -> u64 {
    parent_ts.saturating_add(1).max(bft_secs).max(anchor_ts)
}

/// Encodes the 13-byte Etna `extraData` `[100 | generation u48 BE | anchor u48 BE]` (D10).
///
/// Fails with [`RuleViolation::ExtraDataOverflow`] when `generation` or `anchor` exceeds
/// `uint48`.
pub fn encode_extra_data(generation: u64, anchor: u64) -> Result<Bytes, RuleViolation> {
    encode_etna_extra_data(BASEFEE_SHARING_PCTG, generation, anchor).map_err(|err| match err {
        ProtocolError::EtnaExtraDataFieldOverflow { field, value } => {
            RuleViolation::ExtraDataOverflow { field, value }
        }
        other => unreachable!("encode_etna_extra_data fails only on uint48 overflow: {other}"),
    })
}

/// Decodes an Etna `extraData` into `(basefeeSharingPctg, generation, anchorNumber)`.
///
/// The bytes must be exactly [`EXTRA_DATA_LEN`] long; the pctg byte is returned verbatim (the
/// caller compares the whole field against [`encode_extra_data`]).
pub fn decode_extra_data(b: &[u8]) -> Result<(u8, u64, u64), RuleViolation> {
    let b: &[u8; EXTRA_DATA_LEN] =
        b.try_into().map_err(|_| RuleViolation::ExtraDataLength { len: b.len() })?;
    Ok((b[0], uint48_be(&b[1..7]), uint48_be(&b[7..13])))
}

/// Reads a 6-byte big-endian `uint48`.
fn uint48_be(bytes: &[u8]) -> u64 {
    let mut word = [0u8; 8];
    word[2..].copy_from_slice(bytes);
    u64::from_be_bytes(word)
}

/// Derives the consensus-chosen header fields of height `i.height` (spec §4.2).
///
/// Fails when the height does not follow the parent ([`RuleViolation::HeightMismatch`]), when the
/// generation or anchor number exceeds `uint48`, or when the base fee cannot be derived.
pub fn expected_header(i: &HeaderInputs<'_>) -> Result<ExpectedHeader, RuleViolation> {
    let parent = i.parent;
    if parent.number.checked_add(1) != Some(i.height) {
        return Err(RuleViolation::HeightMismatch { height: i.height, parent: parent.number });
    }

    let base_fee = calculate_next_block_eip4396_base_fee_for_parent(
        parent.number,
        parent.gas_limit,
        parent.gas_used,
        parent.timestamp,
        Some(parent.base_fee),
        parent.grandparent_timestamp,
        i.min_base_fee,
    )
    .ok_or(RuleViolation::BaseFeeUnavailable { parent: parent.number })?;

    Ok(ExpectedHeader {
        number: i.height,
        parent_hash: parent.hash,
        timestamp: block_timestamp(parent.timestamp, i.bft_time_secs, i.anchor.timestamp),
        beneficiary: i.params.fee_vault,
        extra_data: encode_extra_data(i.generation, i.anchor.number)?,
        parent_beacon_block_root: i.anchor.state_root,
        gas_limit: i.params.block_gas_limit,
        base_fee,
        mix_hash: calculate_shasta_mix_hash(
            B256::from(parent.difficulty.to_be_bytes::<32>()),
            i.height,
        ),
    })
}

/// Checks a proposed header against its derived fields and the Etna body commitments.
///
/// Compares, in order, the nine [`ExpectedHeader`] fields, then `withdrawals_root ==
/// EMPTY_ROOT_HASH`, `blob_gas_used == 0`, `excess_blob_gas == 0`, `requests_hash ==
/// EMPTY_REQUESTS_HASH`, `ommers_hash == EMPTY_OMMER_ROOT_HASH` and `nonce == 0`, and reports the
/// first mismatch as [`RuleViolation::HeaderField`]. Execution results are left to the EL.
pub fn check_header(h: &Header, e: &ExpectedHeader) -> Result<(), RuleViolation> {
    field_eq("number", e.number, h.number)?;
    field_eq("parent_hash", e.parent_hash, h.parent_hash)?;
    field_eq("timestamp", e.timestamp, h.timestamp)?;
    field_eq("beneficiary", e.beneficiary, h.beneficiary)?;
    field_eq("extra_data", &e.extra_data, &h.extra_data)?;
    field_eq(
        "parent_beacon_block_root",
        Some(e.parent_beacon_block_root),
        h.parent_beacon_block_root,
    )?;
    field_eq("gas_limit", e.gas_limit, h.gas_limit)?;
    field_eq("base_fee_per_gas", Some(e.base_fee), h.base_fee_per_gas)?;
    field_eq("mix_hash", e.mix_hash, h.mix_hash)?;

    field_eq("withdrawals_root", Some(EMPTY_ROOT_HASH), h.withdrawals_root)?;
    field_eq("blob_gas_used", Some(0), h.blob_gas_used)?;
    field_eq("excess_blob_gas", Some(0), h.excess_blob_gas)?;
    field_eq("requests_hash", Some(EMPTY_REQUESTS_HASH), h.requests_hash)?;
    field_eq("ommers_hash", EMPTY_OMMER_ROOT_HASH, h.ommers_hash)?;
    field_eq("nonce", B64::ZERO, h.nonce)
}

/// `Ok` iff `expected == got`, else a [`RuleViolation::HeaderField`] naming `field`.
fn field_eq<T: PartialEq + Debug>(
    field: &'static str,
    expected: T,
    got: T,
) -> Result<(), RuleViolation> {
    if expected == got {
        return Ok(());
    }
    Err(RuleViolation::HeaderField {
        field,
        expected: format!("{expected:?}"),
        got: format!("{got:?}"),
    })
}

/// Builds the `engine_forkchoiceUpdated` payload attributes for `e` (spec §4.2).
///
/// `txList` is `None`, so the EL builds from its own txpool (D16); withdrawals are present but
/// empty; the L1 origin records the anchor number (from `e.extra_data`) and `anchor_hash`, is not
/// forced and carries a zero signature. The payload id is stamped from `e.parent_hash`.
///
/// # Panics
///
/// If `e.extra_data` is not the 13-byte Etna layout, which [`expected_header`] guarantees.
pub fn payload_attributes(e: &ExpectedHeader, anchor_hash: B256) -> TaikoPayloadAttributes {
    let (_, _, anchor_number) = decode_extra_data(&e.extra_data)
        .expect("ExpectedHeader::extra_data is the 13-byte Etna layout");
    build_payload_attributes_with_id(
        PayloadAttributesInput {
            beneficiary: e.beneficiary,
            timestamp: e.timestamp,
            mix_hash: e.mix_hash,
            gas_limit: e.gas_limit,
            tx_list: None,
            extra_data: e.extra_data.clone(),
            base_fee_per_gas: U256::from(e.base_fee),
            block_number: e.number,
            l1_block_height: Some(U256::from(anchor_number)),
            l1_block_hash: Some(anchor_hash),
            is_forced_inclusion: false,
            signature: [0; 65],
            parent_beacon_block_root: Some(e.parent_beacon_block_root),
            anchor_transaction: None,
        },
        &e.parent_hash,
    )
}

/// Checks the anchor L1 block number of the block at `height` (spec §4.2, §5.4 step 6).
///
/// In order: `anchor >= parent_anchor` ([`RuleViolation::AnchorRegressed`]), `anchor >= L1_0`
/// ([`RuleViolation::AnchorBeforeActivation`]) and `anchor >= L1_first(epoch_of(height))`
/// ([`RuleViolation::EpochNotOpenOnL1`]). `height` must be `>= H_0`.
///
/// # Panics
///
/// As [`Schedule::epoch_of`] and [`Schedule::l1_first`] (a schedule that failed
/// [`Schedule::validate`], or an L1 block number overflowing `u64`).
pub fn check_anchor_progress(
    parent_anchor: u64,
    anchor: u64,
    schedule: &Schedule,
    height: u64,
) -> Result<(), RuleViolation> {
    if anchor < parent_anchor {
        return Err(RuleViolation::AnchorRegressed { parent: parent_anchor, anchor });
    }
    if anchor < schedule.l1_0 {
        return Err(RuleViolation::AnchorBeforeActivation { anchor, l1_0: schedule.l1_0 });
    }
    let epoch = schedule.epoch_of(height);
    let l1_first = schedule.l1_first(epoch);
    if anchor < l1_first {
        return Err(RuleViolation::EpochNotOpenOnL1 { epoch, l1_first });
    }
    Ok(())
}

/// HALT-03 back-pressure: `height - last_checkpoint_height <= cap`, with the depth saturating at
/// 0 when the checkpoint is not behind `height`. `cap` is `D_MAX - MARGIN_V`.
pub fn check_back_pressure(
    height: u64,
    last_checkpoint_height: u64,
    cap: u64,
) -> Result<(), RuleViolation> {
    let depth = height.saturating_sub(last_checkpoint_height);
    if depth > cap {
        return Err(RuleViolation::BackPressure { depth, cap });
    }
    Ok(())
}

/// Checks the generation triple of a block (spec §5.4 step 5).
///
/// `chain` is the `chain_id` suffix, `extra` the block's `extraData` generation and `inbox` the
/// Inbox `recoveryGeneration` proven at the anchor. `chain != extra` is a
/// [`RuleViolation::GenerationMismatch`]; otherwise an Inbox ahead of the chain yields
/// [`GenerationCheck::Superseded`] and an Inbox behind it a [`RuleViolation::GenerationAhead`].
pub fn check_generation(
    chain: u64,
    extra: u64,
    inbox: u64,
) -> Result<GenerationCheck, RuleViolation> {
    if chain != extra {
        return Err(RuleViolation::GenerationMismatch { chain, extra });
    }
    match inbox.cmp(&chain) {
        std::cmp::Ordering::Greater => Ok(GenerationCheck::Superseded),
        std::cmp::Ordering::Less => Err(RuleViolation::GenerationAhead { chain, inbox }),
        std::cmp::Ordering::Equal => Ok(GenerationCheck::Ok),
    }
}

/// The CometBFT `chain_id` of `generation` on L2 chain `l2_chain_id`:
/// `taiko-etna-<l2_chain_id>-g<generation>`, both in canonical decimal.
///
/// At most 39 bytes for a 6-digit L2 chain id, within [`MAX_CHAIN_ID_LEN`].
pub fn chain_id_for(l2_chain_id: u64, generation: u64) -> String {
    format!("{CHAIN_ID_PREFIX}{l2_chain_id}-g{generation}")
}

/// Parses the generation out of a `chain_id` made by [`chain_id_for`] for `l2_chain_id`.
///
/// Strict: the prefix and L2 chain id must match exactly, and the generation must be non-empty
/// ASCII decimal without a sign or leading zeros (except `"0"`) that fits `u64`. Anything else is
/// a [`RuleViolation::InvalidChainId`].
pub fn generation_from_chain_id(chain_id: &str, l2_chain_id: u64) -> Result<u64, RuleViolation> {
    let invalid = || RuleViolation::InvalidChainId { chain_id: chain_id.to_string(), l2_chain_id };
    let digits = chain_id
        .strip_prefix(CHAIN_ID_PREFIX)
        .and_then(|rest| rest.strip_prefix(l2_chain_id.to_string().as_str()))
        .and_then(|rest| rest.strip_prefix("-g"))
        .ok_or_else(invalid)?;
    let canonical = !digits.is_empty() &&
        digits.bytes().all(|b| b.is_ascii_digit()) &&
        (digits == "0" || !digits.starts_with('0'));
    if !canonical {
        return Err(invalid());
    }
    digits.parse().map_err(|_| invalid())
}

#[cfg(test)]
mod tests;
