//! Pure genesis verification shared by the document builder and ABCI initialization.

use alloy_primitives::B256;

use super::GenesisError;
use crate::{
    committee::{record_hash, verify_committee_witness_at_cutoff},
    config::ChainParams,
    envelope::CommitteeWitness,
    l1::{RawL1Header, verify_genesis_inbox, witness::anchor_state},
    schedule::Schedule,
    store::CommitteeState,
    types::{AccountWitness, AnchorState, GenesisRecord},
};

/// Authenticated bootstrap facts, before the epoch-0 committee has been verified.
pub(crate) struct GenesisContext {
    /// The initialized Inbox's genesis record, with L2 height zero.
    pub(crate) genesis: GenesisRecord,
    /// The L1 initialization header and its proven Inbox facts.
    pub(crate) anchor: AnchorState,
    /// The record hash the initialized Inbox stores at genesisCommitteeRecordHash.
    pub(crate) committee_hash: B256,
}

/// Verifies Inbox proofs, the initialization header's number and the epoch schedule.
///
/// The caller authenticates the header's canonicality and finality independently. No L1 or EL
/// operations occur here. Rejects nonzero L2 genesis heights through the Inbox witness verifier.
pub(crate) fn verify_context(
    header: &RawL1Header,
    inbox: &AccountWitness,
    params: &ChainParams,
) -> Result<GenesisContext, GenesisError> {
    let (genesis, facts, committee_hash) =
        verify_genesis_inbox(header.state_root(), inbox, params.inbox)?;
    if facts.recovery_generation != 0 {
        return Err(GenesisError::UnsupportedRecovery("generation must be zero".into()));
    }
    if header.number() != genesis.l1_0 {
        return Err(GenesisError::InitializationMismatch {
            l1_0: header.number(),
            proven: genesis.l1_0,
        });
    }
    let timestamp_slot = crate::l1::layout::inbox::origin_slots(0)[2];
    if inbox.storage.iter().find(|proof| proof.slot == timestamp_slot).map(|proof| proof.value) !=
        Some(alloy_primitives::U256::from(header.timestamp()))
    {
        return Err(GenesisError::Witness(Box::new(crate::l1::WitnessError::InvalidOrigin)));
    }
    let local = crate::committee::committee_config_hash(params);
    if local != genesis.committee_config_hash {
        return Err(GenesisError::ConfigMismatch { local, proven: genesis.committee_config_hash });
    }
    Schedule::from_genesis(&genesis).validate()?;
    Ok(GenesisContext { genesis, anchor: anchor_state(header, facts), committee_hash })
}

/// Verifies the registry snapshot, derives committee 0 and checks its recorded hash.
///
/// The explicit genesis cutoff applies independently of runtime parent-anchor selection. Both
/// genesis entry points call this independently; neither trusts a previously generated document.
pub(crate) fn verify_committee(
    context: &GenesisContext,
    witness: &CommitteeWitness,
    params: &ChainParams,
) -> Result<CommitteeState, GenesisError> {
    let (record, members) = verify_committee_witness_at_cutoff(
        context.anchor.state_root,
        context.genesis.genesis_cutoff,
        params,
        witness,
        Schedule::E0,
    )?;
    let derived = record_hash(params.l2_chain_id, &record);
    if derived != context.committee_hash {
        return Err(GenesisError::CommitteeRecordMismatch {
            derived,
            recorded: context.committee_hash,
        });
    }
    Ok(CommitteeState { record, members })
}
