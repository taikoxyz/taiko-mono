//! Pure fixed-genesis authentication for offline checkpoint import.

use super::{
    BootstrapWitness, GenesisConsensusParams, GenesisDoc, GenesisError, GenesisValidator,
    decode_bootstrap_state, genesis_time, verify_committee, verify_context,
    verify_deployment_context,
};
use crate::{AnchorState, ChainParams, CommitteeState, GenesisRecord, RawL1Header};

/// Pure bootstrap facts; callers must independently check every retained header against own L1.
#[derive(Debug)]
pub struct VerifiedGenesis {
    /// Immutable deployment and epoch configuration.
    pub genesis: GenesisRecord,
    /// Initialization or recovery R anchor used as the new generation's floor.
    pub anchor: AnchorState,
    /// Independently derived initial committee.
    pub committee: CommitteeState,
    /// Fixed recovery origin; never a moving latest checkpoint.
    pub recovery: Option<crate::recovery::RecoveryOrigin>,
    /// Headers whose own-L1 canonicality/finality must be checked before installing state.
    pub l1_headers: Vec<RawL1Header>,
}

/// Reconstructs and compares the complete original stock genesis document from its witnesses.
/// This performs no I/O and grants no finality or authority; callers authenticate `l1_headers`.
pub fn verify_original_genesis(
    doc: &GenesisDoc,
    params: &ChainParams,
) -> Result<VerifiedGenesis, GenesisError> {
    let encoded = serde_json::to_vec(&doc.app_state).expect("genesis app state serializes");
    let invalid = |message: &str| GenesisError::UnsupportedRecovery(message.into());
    let (facts, expected) = match decode_bootstrap_state(&encoded)? {
        BootstrapWitness::Initial(w) => {
            let context = verify_context(&w.l1_header, &w.inbox, params)?;
            let committee = verify_committee(&context, &w.committee, params)?;
            let expected = GenesisDoc::assemble(
                &w,
                crate::rules::chain_id_for(params, 0).map_err(|e| invalid(&e.to_string()))?,
                &committee.members,
            )?;
            (
                VerifiedGenesis {
                    genesis: context.genesis,
                    anchor: context.anchor,
                    committee,
                    recovery: None,
                    l1_headers: vec![w.l1_header],
                },
                expected,
            )
        }
        BootstrapWitness::Recovery(w) => {
            let origin = crate::recovery::verify_recovery_witness(&w, params)
                .map_err(|e| invalid(&e.to_string()))?;
            if w.finalized_header != w.recovery_header || w.finalized_inbox != w.recovery_inbox {
                return Err(invalid("original recovery genesis must embed R"));
            }
            let context =
                verify_deployment_context(&w.genesis.l1_header, &w.genesis.inbox, params)?;
            let anchor = crate::l1::verify_anchor_witness(
                &crate::AnchorWitness {
                    l1_header: w.recovery_header.clone(),
                    inbox: crate::AccountWitness {
                        storage: w
                            .recovery_inbox
                            .storage
                            .iter()
                            .filter(|p| crate::l1::layout::inbox::anchor_slots().contains(&p.slot))
                            .cloned()
                            .collect(),
                        ..w.recovery_inbox.clone()
                    },
                },
                params.inbox,
            )?;
            let expected = GenesisDoc {
                genesis_time: genesis_time(origin.l1_timestamp)?.to_rfc3339(),
                chain_id: crate::rules::chain_id_for(params, origin.generation)
                    .map_err(|e| invalid(&e.to_string()))?,
                initial_height: (origin.height + 1).to_string(),
                consensus_params: GenesisConsensusParams::etna(),
                validators: origin
                    .committee
                    .members
                    .iter()
                    .map(GenesisValidator::from_member)
                    .collect(),
                app_hash: alloy_primitives::hex::encode_upper(origin.el_hash),
                app_state: super::AppStateJson::from(&w),
            };
            (
                VerifiedGenesis {
                    genesis: context.genesis,
                    anchor,
                    committee: origin.committee.clone(),
                    recovery: Some(origin),
                    l1_headers: vec![w.genesis.l1_header, w.recovery_header],
                },
                expected,
            )
        }
    };
    if *doc != expected {
        return Err(invalid("genesis document differs from authenticated original identity"));
    }
    Ok(facts)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn original_identity_cannot_be_rebased_to_checkpoint() {
        let fx = crate::test_utils::Fixture::genesis(1);
        let mut doc = super::super::GenesisDoc::assemble(
            &fx.witness,
            fx.request.chain_id.clone(),
            &fx.members,
        )
        .unwrap();
        doc.initial_height = "7".into();
        assert!(verify_original_genesis(&doc, &fx.params).is_err());
    }
}
