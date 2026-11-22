//! Bounded landed-checkpoint authentication without historical execution.
//!
//! The iterator supplies ascending native block frames exactly once. No consensus source or
//! execution engine is accepted, so verification cannot fetch a prefix or execute old blocks.

use abci::{ChainParams, GenesisDoc, L1Source, ParentInfo, store::AppState, valstate::ValState};
use alloy_consensus::Header;
use alloy_primitives::{B256, Bytes, U256, keccak256};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Own-L1 authentication, bounded reconstruction and native block verification.
mod authenticate;
/// Evidence age limits and the complete-window proof.
mod window;

pub use authenticate::{authenticate_import, select_export};
pub use window::evidence_expired;

/// Oldest canonical EL header needed for the next block's BLOCKHASH context and DATA-5.4-4's
/// U ancestry fence. The first retained header's parent hash authenticates a committed anchor
/// still at s - U when that checkpoint falls just below the range.
pub fn header_floor(origin: u64, height: u64, unsettled_limit: u64) -> u64 {
    height
        .saturating_sub(255)
        .min(origin.max(height.saturating_sub(unsettled_limit.saturating_sub(1))))
}

/// Import failures keep publisher faults distinct from authenticated contradictions.
#[derive(Clone, Debug, thiserror::Error, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "class", content = "detail", rename_all = "snake_case")]
pub enum ImportError {
    /// Invalid publisher bytes; reject this candidate without granting authority.
    #[error("invalid checkpoint candidate: {0}")]
    Candidate(String),
    /// Missing data or finality; retry without advancing installation.
    #[error("checkpoint material unavailable: {0}")]
    Unavailable(String),
    /// Contradictory authenticated facts; durably halt and alert, never publisher retry.
    #[error("authenticated checkpoint contradiction: {0}")]
    Safety(String),
}

/// The only supported [`ImportPackage::schema`]. Version 3 carries a genesis whose witness is the
/// `L1_0` header and Inbox proof alone and whose validators are the origin fallback keys at
/// power 1, with the validator-state preimage for s − 1; versions 1 and 2 are refused, with no
/// migration.
pub const IMPORT_SCHEMA: u32 = 3;

/// Version-two metadata; block payloads are supplied separately as a streaming iterator.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ImportPackage {
    /// Supported format version, exactly [`IMPORT_SCHEMA`].
    pub schema: u32,
    /// Immutable original stock genesis, including original InitialHeight and witness.
    pub genesis: GenesisDoc,
    /// Selected retained landing; may be older than the current admission target.
    pub checkpoint_height: u64,
    /// Fixed origin EL header, independently bound by genesis or the recovery witness.
    /// A later generation-zero import whose window starts above the origin can omit it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub origin_header: Option<Header>,
    /// Historical origin context needed across recovery restart; absent for generation zero.
    pub recovery_bootstrap: Option<abci::recovery::RecoveryBootstrap>,
    /// Predecessor header at w, authenticated by the first block's LastBlockID; absent at o.
    pub boundary_header: Option<tendermint::block::Header>,
    /// Exact appendix-A preimage of valStateHash(s − 1), which with ELHash(s − 1) gives
    /// header(s)'s app_hash (DATA-5.4-3); empty only for fixed-origin initialization.
    pub validator_state: Bytes,
    /// Ascending linked EL prefix from at least min(w, [`header_floor`]) through w. Empty is
    /// allowed when that range is only the separately supplied origin header. No execution state
    /// or trusted cache is accepted here.
    pub execution_headers: Vec<Header>,
}

/// One untrusted keys-and-powers entry; historical proposer priorities are intentionally absent.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ImportValidator {
    /// Canonical native compressed SEC1 public key.
    pub key: abci::key::ConsensusKey,
    /// Positive stock power, bounded together with the complete set.
    pub power: u64,
}

/// One original canonical native block and its own-height certificate.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WindowBlock {
    /// Original unmodified stock protobuf, including its evidence list, which must be empty
    /// (CONS-3.1-10), and LastCommit.
    pub block: Bytes,
    /// Original canonical own-height commit protobuf; nonterminal copies equal LastCommit.
    pub commit: Bytes,
    /// Complete keys/powers whose hash must equal this height's validators_hash.
    pub validators: Vec<ImportValidator>,
}

/// A slot-285 landing proven under the current own-finalized root.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Landing {
    /// Global landed EL/Comet height.
    pub height: u64,
    /// Previous landed checkpoint in the selected settled history.
    pub parent_height: u64,
    /// Generation that landed this checkpoint.
    pub generation: u64,
    /// FI cursor after this checkpoint, distinct from the latest queue head.
    pub forced_cursor: u64,
    /// Landed execution block hash.
    pub el_hash: B256,
    /// Landed consensus header hash.
    pub comet_hash: B256,
}

/// Authenticated reconstruction. Serialization is a report, never a deserializable trust token.
#[derive(Debug, Serialize)]
pub struct VerifiedImport {
    /// Exact post-checkpoint application metadata, with the validator state derived for s.
    state: AppState,
    /// The validator state after s − 1 that header(s)'s app_hash commits (DATA-5.4-3), absent
    /// on the fixed-genesis path.
    val_state_before: Option<ValState>,
    /// Original generation genesis, never normalized to s+1.
    genesis: GenesisDoc,
    /// Selected retained landing.
    landing: Landing,
    /// Full terminal native ID, absent on the fixed-genesis path.
    block_id: Option<tendermint::block::Id>,
    /// First retained consensus height, absent at the fixed origin.
    first_height: Option<u64>,
    /// Parent-linked canonical EL installation range from [`header_floor`], in ascending order.
    execution_headers: Vec<Header>,
    /// Recovery evidence that must be persisted before AppState.
    recovery_bootstrap: Option<abci::recovery::RecoveryBootstrap>,
}
impl VerifiedImport {
    /// Verified state to stage; completion alone never grants trust or signing authority.
    pub fn state(&self) -> &AppState {
        &self.state
    }
    /// The authenticated validator state after s − 1, the package's preimage; None means
    /// fixed-genesis startup.
    pub fn val_state_before(&self) -> Option<&ValState> {
        self.val_state_before.as_ref()
    }
    /// The post-s AppHash, which the stock stores install and the app's Info reports
    /// (DATA-5.4-4, CONS-3.1-8): appHash of ELHash(s) and the validator state derived for s.
    pub fn app_hash(&self) -> B256 {
        abci::valstate::app_hash(self.state.parent.hash, self.state.val_state.hash())
    }
    /// Original fixed genesis to install unchanged.
    pub fn genesis(&self) -> &GenesisDoc {
        &self.genesis
    }
    /// The own-L1 landing at s that the stock and EL install receipts are checked against.
    pub fn landing(&self) -> &Landing {
        &self.landing
    }
    /// Full terminal ID the stock install receipt must name; None means fixed-genesis startup.
    pub fn block_id(&self) -> Option<tendermint::block::Id> {
        self.block_id
    }
    /// First consensus height the stock package must contain.
    pub fn first_height(&self) -> Option<u64> {
        self.first_height
    }
    /// Canonical headers the EL helper must install into its own database indexes.
    pub fn execution_headers(&self) -> &[Header] {
        &self.execution_headers
    }
    /// Required recovery sidecar, absent for generation zero.
    pub fn recovery_bootstrap(&self) -> Option<&abci::recovery::RecoveryBootstrap> {
        self.recovery_bootstrap.as_ref()
    }
}

/// Reject a selected height that cannot belong to this generation's retained settled history.
/// A landing may end at any height above its parent.
fn validate_selected_landing(
    record: &Landing,
    generation: u64,
    origin: u64,
    latest: u64,
) -> Result<(), ImportError> {
    // An absent future record cannot yet be distinguished from a landing awaiting finality.
    // A populated historical record above the rolled-back frontier is already disqualified.
    if record.height > latest &&
        record.height <= abci::UINT48_MAX &&
        record.parent_height == 0 &&
        record.generation == 0 &&
        record.forced_cursor == 0 &&
        record.el_hash.is_zero() &&
        record.comet_hash.is_zero()
    {
        return Err(unavailable("selected landing has not reached the own finalized frontier"));
    }
    if record.height < origin ||
        record.height > latest ||
        record.el_hash.is_zero() ||
        (record.height > origin &&
            (record.generation != generation ||
                record.parent_height >= record.height ||
                record.parent_height < origin ||
                record.comet_hash.is_zero()))
    {
        return Err(ImportError::Candidate(
            "selected height has no retained current-generation landing".into(),
        ));
    }
    Ok(())
}

/// Authenticate the publisher's validator-state preimage for s − 1 against header(s)
/// (DATA-5.4-3, DATA-5.4-5): with `parent_el_hash`, ELHash(s − 1), its hash must give
/// header(s)'s `app_hash`, else it is an invalid candidate. Once it does, the header commits
/// it, so a preimage that does not decode, holds a set stock CometBFT refuses, names another
/// height or whose sets differ from header(s)'s `validators_hash` and `next_validators_hash` is
/// an authenticated contradiction.
fn authenticate_preimage(
    bytes: &[u8],
    header: &tendermint::block::Header,
    parent_el_hash: B256,
) -> Result<ValState, ImportError> {
    let committed = abci::valstate::app_hash(parent_el_hash, keccak256(bytes));
    if header.app_hash.as_bytes() != committed.as_slice() {
        return Err(candidate("validator-state preimage does not give header(s)'s app_hash"));
    }
    let state = ValState::decode(bytes).map_err(safety)?;
    for set in [&state.current, &state.next] {
        ValState::genesis(
            state.height,
            &set.entries.iter().map(|e| (e.key, e.power as u64)).collect::<Vec<_>>(),
        )
        .map_err(safety)?;
    }
    if header.height.value().checked_sub(1) != Some(state.height) {
        return Err(safety("committed validator-state height is not s - 1"));
    }
    let hashes =
        |set: &abci::valstate::ValSet| set.validators_hash().map(|hash| hash.0).map_err(safety);
    if hashes(&state.current)? != header.validators_hash.as_bytes() ||
        hashes(&state.next)? != header.next_validators_hash.as_bytes()
    {
        return Err(safety(
            "committed validator state contradicts header(s)'s validators_hash or \
             next_validators_hash",
        ));
    }
    Ok(state)
}

/// Publisher input error without authenticated contradictory facts.
fn candidate(error: impl std::fmt::Display) -> ImportError {
    ImportError::Candidate(error.to_string())
}
/// Missing input or source cannot authorize a partial import.
fn unavailable(error: impl std::fmt::Display) -> ImportError {
    ImportError::Unavailable(error.to_string())
}
/// Contradictory facts already bound by trusted L1 or landed consensus bytes.
fn safety(error: impl std::fmt::Display) -> ImportError {
    ImportError::Safety(error.to_string())
}
/// Preserve the own-L1 adapter's integrity distinction.
fn own_error(error: abci::L1Error) -> ImportError {
    if error.is_integrity_failure() { safety(error) } else { unavailable(error) }
}
/// Derive the application parent summary from linked authenticated headers.
fn parent_info(header: &Header, preceding_time: u64) -> Result<ParentInfo, ImportError> {
    Ok(ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee: header.base_fee_per_gas.ok_or_else(|| candidate("missing execution base fee"))?,
        difficulty: header.difficulty,
        grandparent_timestamp: preceding_time,
    })
}

#[cfg(test)]
mod tests;
