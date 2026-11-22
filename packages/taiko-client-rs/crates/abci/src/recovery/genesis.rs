//! Unique recovery genesis, independent of a node's moving admission checkpoint.
use super::{
    RecoveryError, VerifiedRecovery, authenticate_recovery, verify::invalid, verify_recovery,
    verify_recovery_witness,
};
use crate::{
    ChainParams, Engine, GenesisDoc, L1Source,
    genesis::{AppStateJson, GenesisConsensusParams, GenesisValidator, genesis_time},
    l1::{OwnFinality, own_finality},
    rules::chain_id_for,
};

/// Builds the fixed generation genesis after authenticating its origin against own finalized L1.
/// The embedded observation is always R; later checkpoints only affect runtime admission.
/// InitChain independently reauthenticates every proof and current own-L1 generation.
/// This reads EL headers only: usable state still requires the fenced activation build probe.
pub async fn build_recovery_genesis<L: L1Source + ?Sized, E: Engine + ?Sized>(
    l1: &L,
    engine: &E,
    params: &ChainParams,
    generation: u64,
) -> Result<GenesisDoc, RecoveryError> {
    let mut witness = authenticate_recovery(l1, engine, params, generation).await?;
    witness.finalized_header = witness.recovery_header.clone();
    witness.finalized_inbox = witness.recovery_inbox.clone();
    let origin = verify_recovery_witness(&witness, params)?;
    recovery_bootstrap(l1, params, &witness).await?;
    Ok(GenesisDoc {
        genesis_time: genesis_time(origin.l1_timestamp).map_err(invalid)?.to_rfc3339(),
        chain_id: chain_id_for(params, generation).map_err(invalid)?,
        initial_height: (origin.height + 1).to_string(),
        consensus_params: GenesisConsensusParams::etna(params.n_max),
        validators: origin.committee.members.iter().map(GenesisValidator::from_member).collect(),
        app_hash: crate::genesis::genesis_app_hash(
            origin.height,
            origin.el_hash,
            &origin.committee.members,
        )
        .map_err(invalid)?,
        app_state: AppStateJson::from(&witness),
    })
}

/// Immutable local evidence retained before publishing recovery state; never a trust grant.
#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryBootstrap {
    /// Sidecar schema; only version one is supported.
    pub(crate) version: u32,
    /// Canonical R-observation witness RLP, without the JSON wrapper or discriminator.
    pub(crate) witness: alloy_primitives::Bytes,
    /// Historical anchor RLP, absent only for the explicit c=S genesis context.
    pub(crate) anchor: Option<alloy_primitives::Bytes>,
}

/// What [`RecoveryBootstrap::verify`] authenticates from a retained sidecar.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerifiedBootstrap {
    /// The canonical R-observation witness the sidecar retains.
    pub witness: super::RecoveryWitness,
    /// The anchor the origin EL block c inherited: its historical anchor, or the deployment's
    /// initialization anchor at c = S. Never R, which is only the new generation's floor.
    pub anchor: crate::types::AnchorState,
    /// The fixed recovery origin ([`verify_recovery_witness`] of `witness`).
    pub origin: super::RecoveryOrigin,
    /// The immutable deployment genesis record proven at `L1_0`.
    pub genesis: crate::types::GenesisRecord,
}

impl RecoveryBootstrap {
    /// Authenticates stored proofs and their exact linkage to the retained origin header, with
    /// one witness verification (which checks the deployment context once).
    pub fn verify(&self, params: &ChainParams) -> Result<VerifiedBootstrap, RecoveryError> {
        use alloy_rlp::Decodable;
        if self.version != 1 {
            return Err(invalid("unsupported recovery bootstrap sidecar"));
        }
        let mut bytes = self.witness.as_ref();
        let witness = super::RecoveryWitness::decode(&mut bytes).map_err(invalid)?;
        if !bytes.is_empty() ||
            witness.finalized_header != witness.recovery_header ||
            witness.finalized_inbox != witness.recovery_inbox
        {
            return Err(invalid("bootstrap witness is not the canonical R observation"));
        }
        let VerifiedRecovery { origin, context, landing_generation } =
            verify_recovery(&witness, params)?;
        let anchor = match (&self.anchor, origin.height) {
            (None, height) if height == context.genesis.genesis_height => context.anchor,
            (Some(bytes), height) if height > context.genesis.genesis_height => {
                let mut bytes = bytes.as_ref();
                let evidence = crate::AnchorWitness::decode(&mut bytes).map_err(invalid)?;
                if !bytes.is_empty() {
                    return Err(invalid("trailing historical anchor bytes"));
                }
                let anchor =
                    crate::l1::verify_anchor_witness(&evidence, params.inbox).map_err(invalid)?;
                let crate::rules::ExtraData { generation: old_generation, anchor: number, .. } =
                    crate::rules::decode_extra_data(&witness.el_header.extra_data)
                        .map_err(invalid)?;
                if old_generation != landing_generation ||
                    anchor.inbox.recovery_generation != old_generation ||
                    anchor.number != number ||
                    anchor.number < context.genesis.l1_0 ||
                    anchor.number > origin.l1_number ||
                    witness.el_header.parent_beacon_block_root != Some(anchor.state_root)
                {
                    return Err(invalid(format!(
                        "historical c anchor contradicts authenticated EL header/landing: header generation={old_generation}, landing generation={landing_generation}, anchor generation={}, number={number}/{}, L1_0={}, R={}, root={:?}/{}",
                        anchor.inbox.recovery_generation,
                        anchor.number,
                        context.genesis.l1_0,
                        origin.l1_number,
                        witness.el_header.parent_beacon_block_root,
                        anchor.state_root
                    )));
                }
                anchor
            }
            _ => return Err(invalid("historical anchor presence contradicts origin height")),
        };
        Ok(VerifiedBootstrap { witness, anchor, origin, genesis: context.genesis })
    }
}

/// Authenticate R's anchor facts from the recovery witness's R observation.
pub(crate) fn recovery_anchor(
    witness: &super::RecoveryWitness,
    params: &ChainParams,
) -> Result<crate::AnchorState, RecoveryError> {
    let slots = crate::l1::layout::inbox::anchor_slots();
    crate::l1::verify_anchor_witness(
        &crate::AnchorWitness {
            l1_header: witness.recovery_header.clone(),
            inbox: crate::AccountWitness {
                storage: witness
                    .recovery_inbox
                    .storage
                    .iter()
                    .filter(|p| slots.contains(&p.slot))
                    .cloned()
                    .collect(),
                ..witness.recovery_inbox.clone()
            },
        },
        params.inbox,
    )
    .map_err(invalid)
}

/// Fetches historical c provenance without confusing it with the R floor for new blocks, and
/// returns the sidecar with what its verification authenticates.
/// c=S has no Etna header anchor and uses the immutable deployment context explicitly.
pub(crate) async fn recovery_bootstrap<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    witness: &super::RecoveryWitness,
) -> Result<(RecoveryBootstrap, VerifiedBootstrap), RecoveryError> {
    let start = witness
        .genesis
        .inbox
        .storage
        .iter()
        .find(|proof| {
            proof.slot == crate::l1::layout::inbox::slot(crate::l1::layout::inbox::GENESIS_PACKED)
        })
        .map(|proof| crate::l1::layout::word_u48(proof.value, 0))
        .ok_or_else(|| invalid("missing deployment start slot"))?;
    let anchor = if witness.el_header.number == start {
        None
    } else {
        let number =
            crate::rules::decode_extra_data(&witness.el_header.extra_data).map_err(invalid)?.anchor;
        let header = crate::l1::header_at(l1, number).await?;
        match own_finality(l1, number, header.hash()).await? {
            OwnFinality::Canonical => {}
            OwnFinality::NotFinal { .. } => {
                return Err(RecoveryError::Unavailable("historical c anchor is not final".into()));
            }
            OwnFinality::OffChain { .. } => {
                return Err(invalid("historical c anchor is not canonical"));
            }
        }
        let inbox = l1
            .account_witness(params.inbox, &crate::l1::layout::inbox::anchor_slots(), number)
            .await?;
        Some(alloy_rlp::encode(crate::AnchorWitness { l1_header: header, inbox }).into())
    };
    let bootstrap =
        RecoveryBootstrap { version: 1, witness: alloy_rlp::encode(witness).into(), anchor };
    let verified = bootstrap.verify(params)?;
    Ok((bootstrap, verified))
}

/// Reconstructs the parent summary exclusively from the authenticated origin and its parent.
pub fn recovery_parent(w: &super::RecoveryWitness) -> crate::types::ParentInfo {
    let header = &w.el_header;
    crate::types::ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee: header.base_fee_per_gas.unwrap_or(0),
        difficulty: header.difficulty,
        grandparent_timestamp: w.parent_headers.first().map_or(0, |parent| parent.timestamp),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{genesis::verify_deployment_context, test_utils::recovery_fixture};

    /// One verification of the sidecar returns what its callers used to re-derive with a second
    /// `verify_recovery_witness` and deployment-context check: the fixed origin, the deployment
    /// genesis record and the authenticated witness, with the historical anchor (the deployment
    /// anchor at c = 0).
    #[tokio::test]
    async fn bootstrap_verify_returns_origin_and_genesis() {
        for c in [0, 6] {
            let (fx, l1, _, mut w) = recovery_fixture(1, c, 1);
            w.finalized_header = w.recovery_header.clone();
            w.finalized_inbox = w.recovery_inbox.clone();
            let (sidecar, fetched) = recovery_bootstrap(&l1, &fx.params, &w).await.unwrap();
            let verified = sidecar.verify(&fx.params).unwrap();
            assert_eq!(verified, fetched, "c = {c}");
            assert_eq!(verified.witness, w);
            assert_eq!(verified.origin, verify_recovery_witness(&w, &fx.params).unwrap());
            let context =
                verify_deployment_context(&w.genesis.l1_header, &w.genesis.inbox, &fx.params)
                    .unwrap();
            assert_eq!(verified.genesis, context.genesis);
            assert_eq!(verified.genesis, fx.genesis);
            if c == 0 {
                assert_eq!(verified.anchor, context.anchor);
            } else {
                assert_eq!(verified.anchor, fx.anchor_state(&l1, fx.genesis.l1_0));
            }
        }
    }
}
