//! Pure cryptographic recovery evidence verification; canonicality is checked by the caller.

use super::{RecoveryError, RecoveryOrigin, RecoveryWitness};
use crate::{
    AccountWitness, ChainParams, CommitteeState, GenesisError,
    committee::verify_committee_witness_at_cutoff,
    genesis::{GenesisContext, verify_committee, verify_deployment_context},
    l1::{
        RawL1Header,
        layout::{inbox, word_u48},
        mpt::{VerifiedStorage, verify_account_witness},
    },
};
use alloy_primitives::{B256, U256};

/// Strict upper bound of every protocol origin field and packed generation.
pub(super) const LIMIT: u64 = 1 << 48;

/// Authenticated origin/landing words at one L1 root.
#[derive(PartialEq, Eq)]
pub(super) struct Observation {
    /// Fixed height c.
    pub(super) height: u64,
    /// Recovery block R.
    pub(super) number: u64,
    /// R Unix timestamp.
    pub(super) timestamp: u64,
    /// Original landing EL hash.
    pub(super) el_hash: B256,
    /// Original landing Comet hash.
    pub(super) comet_hash: B256,
    /// Original landing validator-state hash (word 4): the original generation's state, never
    /// compared with this generation's.
    pub(super) val_state_hash: B256,
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
    // Every immutable initialization word must still equal its original proof at L1_0.
    for original in &w.genesis.inbox.storage {
        if original.slot != inbox::slot(inbox::RECOVERY_GENERATION) &&
            word(&storage, original.slot) != original.value
        {
            return Err(invalid("immutable deployment facts changed"));
        }
    }
    let [height, number, timestamp] = inbox::origin_slots(w.generation).map(|s| word(&storage, s));
    if [height, number, timestamp].iter().any(|v| *v >= U256::from(LIMIT)) {
        return Err(invalid("origin exceeds uint48"));
    }
    let (height, number, timestamp) =
        (height.to::<u64>(), number.to::<u64>(), timestamp.to::<u64>());
    let rules = word(&storage, inbox::slot(inbox::RULES_SCHEDULE));
    if rules >> 240 != U256::ZERO {
        return Err(invalid("reserved rules schedule bits"));
    }
    if header.number() == number {
        // The R-selected committee is meaningful only under a ruleset this binary supports.
        // Later schedule writes are mutable and do not change this fixed recovery origin.
        crate::rules::check_supported_rules(rules, timestamp)
            .map_err(|e| RecoveryError::Unavailable(e.to_string()))?;
    }
    if number == 0 ||
        number < w.genesis.l1_header.number() ||
        timestamp == 0 ||
        height != c ||
        !height.is_multiple_of(crate::GRID_INTERVAL)
    {
        return Err(invalid("missing or inconsistent fixed origin"));
    }
    let [packed, el_hash, comet_hash, val_state_hash] =
        inbox::landing_slots(c).map(|s| word(&storage, s));
    if packed >> 144 != U256::ZERO {
        return Err(invalid("reserved landing bits"));
    }
    let parent = word_u48(packed, 0);
    let landing_generation = word_u48(packed, 48);
    let cursor = word_u48(packed, 96);
    let el_hash = B256::from(el_hash);
    let comet_hash = B256::from(comet_hash);
    let val_state_hash = B256::from(val_state_hash);
    if el_hash.is_zero() ||
        landing_generation >= w.generation ||
        (c > 0 &&
            (parent >= c ||
                !parent.is_multiple_of(crate::GRID_INTERVAL) ||
                comet_hash.is_zero()))
    {
        return Err(invalid("invalid retained landing"));
    }
    if c == 0 && (packed != U256::ZERO || !comet_hash.is_zero() || !val_state_hash.is_zero()) {
        return Err(invalid("invalid genesis landing"));
    }
    let checkpoint = word(&storage, inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT));
    let queue = word(&storage, inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL));
    if checkpoint >= U256::from(LIMIT) ||
        checkpoint < U256::from(height) ||
        queue >> 96 != U256::ZERO ||
        cursor > word_u48(queue, 0) ||
        word_u48(queue, 0) > word_u48(queue, 48)
    {
        return Err(invalid("invalid checkpoint or forced queue observation"));
    }
    if checkpoint == U256::from(height) &&
        (B256::from(word(&storage, inbox::slot(inbox::LAST_CHECKPOINT_HASH))) != el_hash ||
            word_u48(queue, 0) != cursor)
    {
        return Err(invalid("current checkpoint contradicts retained origin landing"));
    }
    Ok(Observation {
        height,
        number,
        timestamp,
        el_hash,
        comet_hash,
        val_state_hash,
        parent_height: parent,
        landing_generation,
        cursor,
    })
}

/// Reads only a slot already authenticated by the exact-slot proof verifier.
fn word(storage: &VerifiedStorage, slot: B256) -> U256 {
    storage.get(slot).expect("slot belongs to the authenticated recovery set")
}

/// Verifies a version-one recovery witness without I/O or Engine mutation.
///
/// The caller MUST independently authenticate canonicality and finality of all three L1
/// headers against its own L1 node (and recheck the current generation before authorizing
/// startup). Proof verification alone does not establish Ethereum canonicality or finality.
/// The fixed c is never replaced by a later checkpoint. This does not establish usable EL state.
pub fn verify_recovery_witness(
    w: &RecoveryWitness,
    params: &ChainParams,
) -> Result<RecoveryOrigin, RecoveryError> {
    verify_recovery(w, params).map(|verified| verified.origin)
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
    if w.version != 1 {
        return Err(invalid("unsupported recovery witness version"));
    }
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
        origin.number != w.recovery_header.number() ||
        origin.timestamp != w.recovery_header.timestamp() ||
        origin.number > w.finalized_header.number()
    {
        return Err(invalid("fixed origin does not bind R and finalized observation"));
    }
    if w.el_header.hash_slow() != origin.el_hash ||
        (origin.height == 0 &&
            (origin.el_hash != context.genesis.genesis_hash ||
                w.el_header.state_root != context.genesis.genesis_state_root))
    {
        return Err(invalid("EL origin header does not match retained landing"));
    }
    match (origin.height, w.parent_headers.as_slice()) {
        (0, []) => {}
        (height, [parent])
            if height > 0 &&
                parent.number == height - 1 &&
                parent.hash_slow() == w.el_header.parent_hash &&
                parent.timestamp < w.el_header.timestamp => {}
        _ => return Err(invalid("missing or inconsistent EL parent header")),
    }
    let (record, members) = verify_committee_witness_at_cutoff(
        w.recovery_header.state_root(),
        origin.number,
        params,
        &w.committee,
        origin.height / context.genesis.epoch_len,
    )
    .map_err(invalid)?;
    Ok(VerifiedRecovery {
        origin: RecoveryOrigin {
            generation: w.generation,
            height: origin.height,
            l1_number: origin.number,
            l1_timestamp: origin.timestamp,
            el_hash: origin.el_hash,
            state_root: w.el_header.state_root,
            comet_hash: origin.comet_hash,
            val_state_hash: origin.val_state_hash,
            forced_cursor: origin.cursor,
            committee: CommitteeState { record, members },
        },
        context,
        landing_generation: origin.landing_generation,
    })
}
