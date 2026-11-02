//! Unique recovery genesis, independent of a node's moving admission checkpoint.
use super::{RecoveryError, authenticate_recovery, verify::invalid, verify_recovery_witness};
use crate::{
    ChainParams, Engine, GenesisDoc, L1Source,
    genesis::{AppStateJson, GenesisConsensusParams, GenesisValidator, genesis_time},
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
        consensus_params: GenesisConsensusParams::etna(),
        validators: origin.committee.members.iter().map(GenesisValidator::from_member).collect(),
        app_hash: alloy_primitives::hex::encode_upper(origin.el_hash),
        app_state: AppStateJson::from(&witness),
    })
}

/// Immutable local evidence retained before publishing recovery state; never a trust grant.
#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct RecoveryBootstrap {
    /// Sidecar schema; only version one is supported.
    pub(crate) version: u32,
    /// Canonical R-observation witness RLP, without the JSON wrapper or discriminator.
    pub(crate) witness: alloy_primitives::Bytes,
    /// Historical anchor RLP, absent only for the explicit c=0 genesis context.
    pub(crate) anchor: Option<alloy_primitives::Bytes>,
}

impl RecoveryBootstrap {
    /// Authenticates stored proofs and their exact linkage to the retained origin header.
    pub(crate) fn verify(
        &self,
        params: &ChainParams,
    ) -> Result<(super::RecoveryWitness, crate::types::AnchorState), RecoveryError> {
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
        let origin = verify_recovery_witness(&witness, params)?;
        let context = crate::genesis::verify_deployment_context(
            &witness.genesis.l1_header,
            &witness.genesis.inbox,
            params,
        )
        .map_err(invalid)?;
        let anchor = match (&self.anchor, origin.height) {
            (None, 0) => context.anchor,
            (Some(bytes), height) if height > 0 => {
                let mut bytes = bytes.as_ref();
                let evidence = crate::AnchorWitness::decode(&mut bytes).map_err(invalid)?;
                if !bytes.is_empty() {
                    return Err(invalid("trailing historical anchor bytes"));
                }
                let anchor =
                    crate::l1::verify_anchor_witness(&evidence, params.inbox).map_err(invalid)?;
                let (pctg, old_generation, number) =
                    crate::rules::decode_extra_data(&witness.el_header.extra_data)
                        .map_err(invalid)?;
                let retained = super::verify::observation(
                    &witness.recovery_header,
                    &witness.recovery_inbox,
                    &witness,
                    params,
                )?;
                if pctg != crate::rules::BASEFEE_SHARING_PCTG ||
                    old_generation != retained.landing_generation ||
                    anchor.inbox.recovery_generation != old_generation ||
                    anchor.number != number ||
                    anchor.number < context.genesis.l1_0 ||
                    anchor.number > origin.l1_number ||
                    witness.el_header.parent_beacon_block_root != Some(anchor.state_root)
                {
                    return Err(invalid(format!(
                        "historical c anchor contradicts authenticated EL header/landing: pctg={pctg}, header generation={old_generation}, landing generation={}, anchor generation={}, number={number}/{}, L1_0={}, R={}, root={:?}/{}",
                        retained.landing_generation,
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
        Ok((witness, anchor))
    }
}

/// Fetches historical c provenance without confusing it with the R floor for new blocks.
/// c=0 has no Etna header anchor and uses the immutable deployment context explicitly.
pub(crate) async fn recovery_bootstrap<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    witness: &super::RecoveryWitness,
) -> Result<RecoveryBootstrap, RecoveryError> {
    let anchor = if witness.el_header.number == 0 {
        None
    } else {
        let (_, _, number) =
            crate::rules::decode_extra_data(&witness.el_header.extra_data).map_err(invalid)?;
        let header = crate::l1::header_at(l1, number).await?;
        if number > l1.finalized_number().await? {
            return Err(RecoveryError::Unavailable("historical c anchor is not final".into()));
        }
        if l1.canonical_hash(number).await? != header.hash() {
            return Err(invalid("historical c anchor is not canonical"));
        }
        let inbox = l1
            .account_witness(params.inbox, &crate::l1::layout::inbox::anchor_slots(), number)
            .await?;
        Some(alloy_rlp::encode(crate::AnchorWitness { l1_header: header, inbox }).into())
    };
    let bootstrap =
        RecoveryBootstrap { version: 1, witness: alloy_rlp::encode(witness).into(), anchor };
    bootstrap.verify(params)?;
    Ok(bootstrap)
}

/// Reconstructs the parent summary exclusively from the authenticated origin and its parent.
pub(crate) fn recovery_parent(w: &super::RecoveryWitness) -> crate::types::ParentInfo {
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
