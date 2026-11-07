//! Nonmutating recovery discovery and retained-evidence reauthentication against own L1.

use super::{
    RecoveryError, RecoveryWitness,
    verify::{LIMIT, check_current_generation, check_generation, invalid, observation},
    verify_recovery_witness,
};
use crate::{
    ChainParams, Engine, FetchError, GenesisWitness, L1Source,
    l1::{
        build_committee_witness_at_cutoff, header_at,
        layout::{inbox, word_u48},
    },
};
use alloy_consensus::Header;
use alloy_primitives::U256;

/// Classifies registry acquisition errors without treating malformed discovery as unavailable.
fn fetch_error(error: FetchError) -> RecoveryError {
    match error {
        FetchError::L1(e) => e.into(),
        FetchError::Timeout(_) => RecoveryError::Unavailable(error.to_string()),
        _ => invalid(error),
    }
}

/// Reads an EL header without building, executing payloads or changing forkchoice.
async fn el_header<E: Engine + ?Sized>(engine: &E, height: u64) -> Result<Header, RecoveryError> {
    let header = engine
        .header_by_number(height)
        .await?
        .ok_or_else(|| RecoveryError::Unavailable(format!("EL header {height} missing")))?;
    if header.number != height {
        return Err(invalid("EL answered with another height"));
    }
    Ok(header)
}

/// Acquires and verifies the explicitly requested fixed recovery origin from the operator's L1.
///
/// Discovery reads never authorize: exact account/storage proofs bind every resulting fact.
/// All L1 headers are checked final/canonical, including a final current-generation recheck.
/// EL operations read headers only; usable execution state requires a separate fenced probe.
pub async fn authenticate_recovery<L: L1Source + ?Sized, E: Engine + ?Sized>(
    l1: &L,
    engine: &E,
    params: &ChainParams,
    generation: u64,
) -> Result<RecoveryWitness, RecoveryError> {
    authenticate_recovery_with_headers(l1, params, generation, |height| el_header(engine, height))
        .await
}

/// Authenticates recovery through read-only public execution headers instead of Engine access.
/// The reader must return the requested header or a classified error; this function verifies
/// the retained landing hash, ancestry and own-L1 finality exactly as the Engine entry point.
pub async fn authenticate_recovery_with_headers<L, F, Fut>(
    l1: &L,
    params: &ChainParams,
    generation: u64,
    header: F,
) -> Result<RecoveryWitness, RecoveryError>
where
    L: L1Source + ?Sized,
    F: Fn(u64) -> Fut,
    Fut: std::future::Future<Output = Result<Header, RecoveryError>>,
{
    check_generation(generation)?;
    let finalized = l1.finalized_number().await?;
    let finalized_header = header_at(l1, finalized).await?;
    let origin_slots = inbox::origin_slots(generation);
    let c = l1.storage_at(params.inbox, origin_slots[0], finalized).await?;
    if c >= U256::from(LIMIT) {
        return Err(invalid("discovered origin height exceeds uint48"));
    }
    let c = c.to::<u64>();
    let finalized_inbox =
        l1.account_witness(params.inbox, &inbox::recovery_slots(generation, c), finalized).await?;
    // Decode only after the proof verifies. Immutable words are checked against L1_0 below.
    if finalized_inbox.address != params.inbox {
        return Err(invalid("wrong discovery Inbox"));
    }
    let storage = crate::l1::mpt::verify_account_witness(
        finalized_header.state_root(),
        &finalized_inbox,
        &inbox::recovery_slots(generation, c),
    )
    .map_err(invalid)?;
    check_current_generation(
        storage.get(inbox::slot(inbox::RECOVERY_GENERATION)).expect("verified slot"),
        generation,
    )?;
    let l1_0 =
        word_u48(storage.get(inbox::slot(inbox::GENESIS_PACKED)).expect("verified slot"), 48);
    if l1_0 > finalized {
        return Err(RecoveryError::Unavailable("initialization is not final".into()));
    }
    let l1_header = header_at(l1, l1_0).await?;
    let genesis_inbox = l1.account_witness(params.inbox, &inbox::genesis_slots(), l1_0).await?;
    let context = crate::genesis::verify_deployment_context(&l1_header, &genesis_inbox, params)
        .map_err(|e| match e {
            crate::GenesisError::ConfigMismatch { local, proven } => {
                RecoveryError::ConfigMismatch { local, proven }
            }
            other => invalid(other),
        })?;
    let genesis_committee =
        build_committee_witness_at_cutoff(l1, params, l1_0, context.genesis.genesis_cutoff, 0)
            .await
            .map_err(fetch_error)?;
    let genesis = GenesisWitness { l1_header, inbox: genesis_inbox, committee: genesis_committee };
    // Authenticate current generation and fixed R before fetching its history or EL headers.
    let mut w = RecoveryWitness {
        version: 1,
        generation,
        recovery_inbox: finalized_inbox.clone(),
        committee: genesis.committee.clone(),
        genesis,
        finalized_header: finalized_header.clone(),
        finalized_inbox,
        recovery_header: finalized_header,
        el_header: Header { number: c, ..Header::default() },
        parent_headers: vec![],
    };
    let origin = observation(&w.finalized_header, &w.finalized_inbox, &w, params)?;
    if origin.number > finalized {
        return Err(RecoveryError::Unavailable(format!(
            "R {} is not final at {finalized}",
            origin.number
        )));
    }
    w.recovery_header = header_at(l1, origin.number).await?;
    w.recovery_inbox = l1
        .account_witness(params.inbox, &inbox::recovery_slots(generation, c), origin.number)
        .await?;
    w.committee = build_committee_witness_at_cutoff(
        l1,
        params,
        origin.number,
        origin.number,
        c / context.genesis.epoch_len,
    )
    .await
    .map_err(fetch_error)?;
    w.el_header = header(c).await?;
    if c > 0 {
        w.parent_headers.push(header(c - 1).await?);
    }
    check_recovery_canonicality(l1, params, &w).await?;
    Ok(w)
}

/// Reauthenticates retained evidence against current own-L1 finality, generation and fixed c/R.
///
/// Same-generation checkpoint advancement is allowed and never changes the origin. Any newer
/// generation invalidates the witness. This performs no Engine calls and writes no local state.
pub async fn check_recovery_canonicality<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    w: &RecoveryWitness,
) -> Result<(), RecoveryError> {
    verify_recovery_witness(w, params)?;
    let finalized = l1.finalized_number().await?;
    for header in [&w.genesis.l1_header, &w.recovery_header, &w.finalized_header] {
        if header.number() > finalized {
            return Err(RecoveryError::Unavailable(format!(
                "L1 header {} is not final at {finalized}",
                header.number()
            )));
        }
        if l1.canonical_hash(header.number()).await? != header.hash() {
            return Err(invalid("retained L1 header is not canonical"));
        }
    }
    let header = header_at(l1, finalized).await?;
    if l1.canonical_hash(finalized).await? != header.hash() {
        return Err(invalid("current finalized header is not canonical"));
    }
    let proof = l1
        .account_witness(
            params.inbox,
            &inbox::recovery_slots(w.generation, w.el_header.number),
            finalized,
        )
        .await?;
    let current = observation(&header, &proof, w, params)?;
    let retained = observation(&w.recovery_header, &w.recovery_inbox, w, params)?;
    if current != retained {
        return Err(invalid("current generation origin or landing changed"));
    }
    Ok(())
}
