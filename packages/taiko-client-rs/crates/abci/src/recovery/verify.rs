//! Pure cryptographic recovery evidence verification; canonicality is checked by the caller.

use super::{RECOVERY_WITNESS_VERSION, RecoveryError, RecoveryOrigin, RecoveryWitness};
use crate::{
    AccountWitness, ChainParams, GenesisError,
    genesis::{GenesisContext, verify_committee, verify_deployment_context},
    l1::{
        RawL1Header,
        layout::{inbox, word_u48},
        mpt::{VerifiedStorage, verify_account_witness},
    },
};
use alloy_primitives::{B256, U256};
use etna_core::types::OriginRecord;

/// Strict upper bound of every protocol origin field and packed generation.
pub(super) const LIMIT: u64 = 1 << 48;

/// Authenticated origin/landing words at one L1 root.
#[derive(PartialEq, Eq)]
pub(super) struct Observation {
    /// The generation's fixed origin record: c, R's number and timestamp and the
    /// `fallbackKeysHash` that signs c + 1 and c + 2.
    pub(super) record: OriginRecord,
    /// Original landing EL hash.
    pub(super) el_hash: B256,
    /// Original landing Comet hash.
    pub(super) comet_hash: B256,
    /// Actual previous checkpoint of the retained landing.
    pub(super) parent_height: u64,
    /// Generation that originally created the retained landing, possibly far older.
    pub(super) landing_generation: u64,
    /// Original landing queue head.
    pub(super) cursor: u64,
}

/// Converts proof or derivation failures into the invalid-evidence category.
pub(super) fn invalid(error: impl std::fmt::Display) -> RecoveryError {
    RecoveryError::Invalid(error.to_string())
}

/// Checks the explicit generation before using it for discovery or division.
pub(super) fn check_generation(generation: u64) -> Result<(), RecoveryError> {
    if generation == 0 || generation >= LIMIT {
        return Err(invalid("generation must be nonzero uint48"));
    }
    Ok(())
}

/// Rejects superseded or uncreated domains immediately after authenticating the generation slot.
pub(super) fn check_current_generation(
    generation: U256,
    requested: u64,
) -> Result<(), RecoveryError> {
    if generation >= U256::from(LIMIT) {
        return Err(invalid("reserved generation bits"));
    }
    let current = generation.to::<u64>();
    if current > requested {
        return Err(RecoveryError::Superseded { requested, current });
    }
    if current != requested {
        return Err(invalid("requested generation has not been created"));
    }
    Ok(())
}

/// Authenticates exact recovery slots and immutable deployment facts at one L1 header.
///
/// The caller has verified `w.genesis.inbox` against `L1_0` first. The generation and slots
/// 278 and 279 are not deployment facts: recovery advances the one, and `setFallbackKeys` and
/// `setMinTotalStake` replace the others at any time.
pub(super) fn observation(
    header: &RawL1Header,
    proof: &AccountWitness,
    w: &RecoveryWitness,
    params: &ChainParams,
) -> Result<Observation, RecoveryError> {
    crate::l1::witness::check_contract(proof, params.inbox).map_err(invalid)?;
    let c = w.el_header.number;
    let storage =
        verify_account_witness(header.state_root(), proof, &inbox::recovery_slots(w.generation, c))
            .map_err(invalid)?;
    let generation = word(&storage, inbox::slot(inbox::RECOVERY_GENERATION));
    check_current_generation(generation, w.generation)?;
    // Every word initialization fixes, the start included, must still equal its original
    // proof at L1_0.
    for slot in inbox::deployment_slots() {
        let original = w.genesis.inbox.storage.iter().find(|proof| proof.slot == slot);
        if original.map(|proof| proof.value) != Some(word(&storage, slot)) {
            return Err(invalid("immutable deployment facts changed"));
        }
    }
    let start = word_u48(word(&storage, inbox::slot(inbox::GENESIS_PACKED)), 0);
    let record =
        inbox::decode_origin_record(inbox::origin_slots(w.generation).map(|s| word(&storage, s)))
            .ok_or_else(|| invalid("origin exceeds uint48"))?;
    let rules = word(&storage, inbox::slot(inbox::RULES_SCHEDULE));
    if rules >> inbox::RulesSchedule::RESERVED_BIT != U256::ZERO {
        return Err(invalid("reserved rules schedule bits"));
    }
    if header.number() == record.l1_number {
        // R's origin is meaningful only under a ruleset this binary supports. Later schedule
        // writes are mutable and do not change this fixed recovery origin.
        crate::rules::check_supported_rules(rules, record.l1_timestamp)
            .map_err(|e| RecoveryError::Unavailable(e.to_string()))?;
    }
    // A missing record reads as zero words; `recover` always writes a nonzero
    // `fallbackKeysHash`, the hash of a list of at least one key.
    if record.l1_number == 0 ||
        record.l1_number < w.genesis.l1_header.number() ||
        record.l1_timestamp == 0 ||
        record.fallback_keys_hash.is_zero() ||
        record.start_height != c ||
        record.start_height < start
    {
        return Err(invalid("missing or inconsistent fixed origin"));
    }
    let inbox::LandingRecord {
        parent_height: parent,
        generation: landing_generation,
        forced_head: cursor,
        el_hash,
        comet_hash,
    } = inbox::LandingRecord::decode(inbox::landing_record_slots(c).map(|s| word(&storage, s)))
        .ok_or_else(|| invalid("reserved landing bits"))?;
    if el_hash.is_zero() ||
        landing_generation >= w.generation ||
        (c > start && (parent >= c || parent < start || comet_hash.is_zero()))
    {
        return Err(invalid("invalid retained landing"));
    }
    if c == start && (parent != start || cursor != 0 || !comet_hash.is_zero()) {
        return Err(invalid("invalid genesis landing"));
    }
    let checkpoint = word(&storage, inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT));
    let queue = word(&storage, inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL));
    if checkpoint >= U256::from(LIMIT) ||
        checkpoint < U256::from(c) ||
        queue >> 96 != U256::ZERO ||
        cursor > word_u48(queue, 0) ||
        word_u48(queue, 0) > word_u48(queue, 48)
    {
        return Err(invalid("invalid checkpoint or forced queue observation"));
    }
    if checkpoint == U256::from(c) &&
        (B256::from(word(&storage, inbox::slot(inbox::LAST_CHECKPOINT_HASH))) != el_hash ||
            word_u48(queue, 0) != cursor)
    {
        return Err(invalid("current checkpoint contradicts retained origin landing"));
    }
    Ok(Observation {
        record,
        el_hash,
        comet_hash,
        parent_height: parent,
        landing_generation,
        cursor,
    })
}

/// Reads only a slot already authenticated by the exact-slot proof verifier.
fn word(storage: &VerifiedStorage, slot: B256) -> U256 {
    storage.get(slot).expect("slot belongs to the authenticated recovery set")
}

/// Verifies a recovery witness without I/O or Engine mutation.
///
/// The caller MUST independently authenticate canonicality and finality of all three L1
/// headers against its own L1 node (and recheck the current generation before authorizing
/// startup). Proof verification alone does not establish Ethereum canonicality or finality.
/// The fixed c is never replaced by a later checkpoint. This does not establish usable EL state,
/// and it authenticates only the origin's `fallbackKeysHash`, never a key list.
pub fn verify_recovery_witness(
    w: &RecoveryWitness,
    params: &ChainParams,
) -> Result<RecoveryOrigin, RecoveryError> {
    verify_recovery(w, params).map(|verified| verified.origin)
}

/// Authenticate the recovery origin and the immutable deployment genesis from the same proofs.
pub fn verify_recovery_deployment(
    w: &RecoveryWitness,
    params: &ChainParams,
) -> Result<(RecoveryOrigin, crate::GenesisRecord), RecoveryError> {
    verify_recovery(w, params).map(|v| (v.origin, v.context.genesis))
}

/// What one [`verify_recovery`] authenticates, with the facts it derived them from, so callers
/// need not derive them again.
pub(crate) struct VerifiedRecovery {
    /// The fixed recovery origin, as [`verify_recovery_witness`] returns it.
    pub(crate) origin: RecoveryOrigin,
    /// The immutable deployment context proven at `L1_0`, checked once.
    pub(crate) context: GenesisContext,
    /// The generation that originally created the retained landing at c.
    pub(super) landing_generation: u64,
}

/// [`verify_recovery_witness`], also returning the deployment context and the retained
/// landing's generation it authenticated on the way.
pub(crate) fn verify_recovery(
    w: &RecoveryWitness,
    params: &ChainParams,
) -> Result<VerifiedRecovery, RecoveryError> {
    check_generation(w.generation)?;
    if w.version != RECOVERY_WITNESS_VERSION {
        return Err(invalid("unsupported recovery witness version"));
    }
    // The proof at L1_0 may already show a later generation: `recover` can run in the same L1
    // block as the start write. Its immutable words are the deployment's either way.
    let context = verify_deployment_context(&w.genesis.l1_header, &w.genesis.inbox, params)
        .map_err(|e| match e {
            GenesisError::ConfigMismatch { local, proven } => {
                RecoveryError::ConfigMismatch { local, proven }
            }
            other => invalid(other),
        })?;
    verify_committee(&context, &w.genesis.committee, params).map_err(invalid)?;
    let final_origin = observation(&w.finalized_header, &w.finalized_inbox, w, params)?;
    let origin = observation(&w.recovery_header, &w.recovery_inbox, w, params)?;
    if origin != final_origin ||
        origin.record.l1_number != w.recovery_header.number() ||
        origin.record.l1_timestamp != w.recovery_header.timestamp() ||
        origin.record.l1_number > w.finalized_header.number()
    {
        return Err(invalid("fixed origin does not bind R and finalized observation"));
    }
    if w.el_header.hash_slow() != origin.el_hash ||
        (origin.record.start_height == context.genesis.genesis_height &&
            (origin.el_hash != context.genesis.genesis_hash ||
                w.el_header.state_root != context.genesis.genesis_state_root))
    {
        return Err(invalid("EL origin header does not match retained landing"));
    }
    match (origin.record.start_height, w.parent_headers.as_slice()) {
        (0, []) => {}
        (height, [parent])
            if height > 0 &&
                parent.number == height - 1 &&
                parent.hash_slow() == w.el_header.parent_hash &&
                parent.timestamp < w.el_header.timestamp => {}
        _ => return Err(invalid("missing or inconsistent EL parent header")),
    }
    Ok(VerifiedRecovery {
        origin: RecoveryOrigin {
            generation: w.generation,
            height: origin.record.start_height,
            l1_number: origin.record.l1_number,
            l1_timestamp: origin.record.l1_timestamp,
            el_hash: origin.el_hash,
            state_root: w.el_header.state_root,
            comet_hash: origin.comet_hash,
            forced_cursor: origin.cursor,
            fallback_keys_hash: origin.record.fallback_keys_hash,
        },
        context,
        landing_generation: origin.landing_generation,
    })
}
