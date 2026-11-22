//! Unique recovery genesis, independent of a node's moving admission checkpoint.
use super::{
    RecoveryError, VerifiedRecovery, authenticate_recovery, verify::invalid, verify_recovery,
};
use crate::{
    ChainParams, Engine, GenesisDoc, L1Source,
    fallback::{FallbackKeys, fetch_fallback_keys},
    genesis::{AppStateJson, GenesisConsensusParams, GenesisValidator, genesis_time},
    l1::{OwnFinality, layout::inbox, own_finality},
    rules::chain_id_for,
};

/// The one [`RecoveryBootstrap`] sidecar schema; any other is refused.
pub const RECOVERY_BOOTSTRAP_VERSION: u32 = 2;

/// Builds the fixed generation genesis after authenticating its origin against own finalized L1.
/// The embedded observation is always R; later checkpoints only affect runtime admission.
/// Its validators are the keys of the list whose hash the origin record holds, each at power 1,
/// obtained by that hash from the own L1 at R. InitChain independently reauthenticates every
/// proof and current own-L1 generation. This reads EL headers only: usable state still requires
/// the fenced activation build probe.
pub async fn build_recovery_genesis<L: L1Source + ?Sized, E: Engine + ?Sized>(
    l1: &L,
    engine: &E,
    params: &ChainParams,
    generation: u64,
) -> Result<GenesisDoc, RecoveryError> {
    let mut witness = authenticate_recovery(l1, engine, params, generation).await?;
    witness.finalized_header = witness.recovery_header.clone();
    witness.finalized_inbox = witness.recovery_inbox.clone();
    let (_, VerifiedBootstrap { origin, fallback_keys, .. }) =
        recovery_bootstrap(l1, params, &witness).await?;
    Ok(GenesisDoc {
        genesis_time: genesis_time(origin.l1_timestamp).map_err(invalid)?.to_rfc3339(),
        chain_id: chain_id_for(params, generation).map_err(invalid)?,
        initial_height: (origin.height + 1).to_string(),
        consensus_params: GenesisConsensusParams::etna(),
        validators: fallback_keys.keys().iter().map(|key| GenesisValidator::new(*key, 1)).collect(),
        app_hash: crate::genesis::genesis_app_hash(
            origin.height,
            origin.el_hash,
            &fallback_keys.validator_set(),
        )
        .map_err(invalid)?,
        app_state: AppStateJson::from(&witness),
    })
}

/// Immutable local evidence retained before publishing recovery state; never a trust grant.
#[derive(Clone, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryBootstrap {
    /// Sidecar schema; only [`RECOVERY_BOOTSTRAP_VERSION`] is supported.
    pub(crate) version: u32,
    /// Canonical R-observation witness RLP, without the JSON wrapper or discriminator.
    pub(crate) witness: alloy_primitives::Bytes,
    /// Historical anchor RLP, absent only for the explicit c=S genesis context.
    pub(crate) anchor: Option<alloy_primitives::Bytes>,
    /// The fallback key list whose hash the origin record holds, obtained by that hash from the
    /// own L1 once, so a restart does not obtain it again.
    pub(crate) fallback_keys: FallbackKeys,
}

/// What [`RecoveryBootstrap::verify`] authenticates from a retained sidecar.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerifiedBootstrap {
    /// The canonical R-observation witness the sidecar retains.
    pub witness: super::RecoveryWitness,
    /// The anchor the origin EL block c inherited: its historical anchor, or the deployment's
    /// initialization anchor at c = S. Never R, which is only the new generation's floor.
    pub anchor: crate::types::AnchorState,
    /// The fixed recovery origin ([`verify_recovery_witness`](super::verify_recovery_witness)
    /// of `witness`).
    pub origin: super::RecoveryOrigin,
    /// The immutable deployment genesis record proven at `L1_0`.
    pub genesis: crate::types::GenesisRecord,
    /// The fallback key list whose hash is the origin's `fallbackKeysHash`: its keys sign c + 1
    /// and c + 2, each at power 1.
    pub fallback_keys: FallbackKeys,
}

impl RecoveryBootstrap {
    /// Authenticates stored proofs and their exact linkage to the retained origin header, with
    /// one witness verification (which checks the deployment context once), and the retained
    /// key list against the origin record's `fallbackKeysHash`.
    pub fn verify(&self, params: &ChainParams) -> Result<VerifiedBootstrap, RecoveryError> {
        use alloy_rlp::Decodable;
        if self.version != RECOVERY_BOOTSTRAP_VERSION {
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
        if self.fallback_keys.hash() != origin.fallback_keys_hash {
            return Err(invalid(format!(
                "bootstrap fallback key list hashes to {}, the origin record holds {}",
                self.fallback_keys.hash(),
                origin.fallback_keys_hash
            )));
        }
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
        Ok(VerifiedBootstrap {
            witness,
            anchor,
            origin,
            genesis: context.genesis,
            fallback_keys: self.fallback_keys.clone(),
        })
    }
}

/// Authenticate R's anchor facts from the recovery witness's R observation, whose proofs of the
/// anchor slots are taken in the anchor witness's order (the recovery witness proves them in
/// its own).
pub(crate) fn recovery_anchor(
    witness: &super::RecoveryWitness,
    params: &ChainParams,
) -> Result<crate::AnchorState, RecoveryError> {
    let proofs = &witness.recovery_inbox.storage;
    crate::l1::verify_anchor_witness(
        &crate::AnchorWitness {
            l1_header: witness.recovery_header.clone(),
            inbox: crate::AccountWitness {
                storage: crate::l1::layout::inbox::anchor_slots()
                    .iter()
                    .filter_map(|slot| proofs.iter().find(|p| p.slot == *slot))
                    .cloned()
                    .collect(),
                ..witness.recovery_inbox.clone()
            },
        },
        params.inbox,
    )
    .map_err(invalid)
}

/// Fetches historical c provenance without confusing it with the R floor for new blocks
/// ([`historical_anchor`]), and the fallback key list the origin record names
/// ([`origin_fallback_keys`]), and returns the sidecar with what its verification authenticates
/// ([`bootstrap_from`]).
pub(crate) async fn recovery_bootstrap<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    witness: &super::RecoveryWitness,
) -> Result<(RecoveryBootstrap, VerifiedBootstrap), RecoveryError> {
    let anchor = historical_anchor(l1, params, witness).await?;
    let fallback_keys = origin_fallback_keys(l1, params, witness).await?;
    bootstrap_from(params, witness, anchor, fallback_keys)
}

/// The anchor witness RLP of the historical anchor c inherited, final and canonical in the own
/// L1, or `None` at c = S, which has no Etna header anchor and uses the immutable deployment
/// context explicitly. A few reads, which a caller may bound together.
pub(crate) async fn historical_anchor<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    witness: &super::RecoveryWitness,
) -> Result<Option<alloy_primitives::Bytes>, RecoveryError> {
    let start = witness
        .genesis
        .inbox
        .storage
        .iter()
        .find(|proof| proof.slot == inbox::slot(inbox::GENESIS_PACKED))
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
        let inbox = l1.account_witness(params.inbox, &inbox::anchor_slots(), number).await?;
        Some(alloy_rlp::encode(crate::AnchorWitness { l1_header: header, inbox }).into())
    };
    Ok(anchor)
}

/// The fallback key list whose hash the origin record holds, obtained by that hash at R
/// ([`fetch_fallback_keys`]); one the own L1 cannot give, or a failed read, is unavailable
/// input. A list stored long before R, which a node without archive state at R gives only
/// from its logs, can take many log queries, so a caller bounds each read, never the whole
/// acquisition.
pub(crate) async fn origin_fallback_keys<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    witness: &super::RecoveryWitness,
) -> Result<FallbackKeys, RecoveryError> {
    // Discovery only: the sidecar's verification authenticates this word and requires the list
    // to hash to it ([`bootstrap_from`]).
    let hash_slot = inbox::origin_slots(witness.generation)[3];
    let hash = witness
        .recovery_inbox
        .storage
        .iter()
        .find(|proof| proof.slot == hash_slot)
        .map(|proof| alloy_primitives::B256::from(proof.value))
        .ok_or_else(|| invalid("missing origin fallbackKeysHash slot"))?;
    let r = &witness.recovery_header;
    fetch_fallback_keys(l1, params.inbox, hash, r.hash(), r.number(), 0)
        .await
        .map_err(|error| RecoveryError::Unavailable(error.to_string()))
}

/// The sidecar of `witness` with the historical `anchor` and the origin `fallback_keys`, and
/// what its verification authenticates.
pub(crate) fn bootstrap_from(
    params: &ChainParams,
    witness: &super::RecoveryWitness,
    anchor: Option<alloy_primitives::Bytes>,
    fallback_keys: FallbackKeys,
) -> Result<(RecoveryBootstrap, VerifiedBootstrap), RecoveryError> {
    let bootstrap = RecoveryBootstrap {
        version: RECOVERY_BOOTSTRAP_VERSION,
        witness: alloy_rlp::encode(witness).into(),
        anchor,
        fallback_keys,
    };
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
    use crate::{
        L1Error,
        fallback::FALLBACK_KEYS_UPDATED,
        genesis::verify_deployment_context,
        recovery::verify_recovery_witness,
        test_utils::{
            L1Call, fallback_list, recovery_fallback_keys, recovery_fixture, serve_fallback_keys,
        },
    };

    /// The canonical R observation of `w`, as a recovery genesis embeds it.
    fn at_r(mut w: super::super::RecoveryWitness) -> super::super::RecoveryWitness {
        w.finalized_header = w.recovery_header.clone();
        w.finalized_inbox = w.recovery_inbox.clone();
        w
    }

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

    /// The sidecar keeps the list whose hash the origin record holds, obtained by that hash
    /// with `getFallbackKeys()` pinned to R's block hash; the recovery genesis lists its keys,
    /// in list order, each at power 1.
    #[tokio::test]
    async fn recovery_genesis_validators_are_the_origin_keys_at_power_one() {
        let (fx, l1, engine, w) = recovery_fixture(1, 6, 1);
        let keys = recovery_fallback_keys();
        let (sidecar, verified) =
            recovery_bootstrap(&l1, &fx.params, &at_r(w.clone())).await.unwrap();
        assert_eq!(sidecar.version, RECOVERY_BOOTSTRAP_VERSION);
        assert_eq!(sidecar.fallback_keys, keys);
        assert_eq!(verified.fallback_keys, keys);
        let r = w.recovery_header.hash();
        let read_at_r = l1.calls().iter().any(|call| {
            matches!(call, L1Call::CallAt { address, hash, .. }
                if *address == fx.params.inbox && *hash == r)
        });
        assert!(read_at_r, "the list is read at R");
        let doc = build_recovery_genesis(&l1, &engine, &fx.params, 1).await.unwrap();
        let validators: Vec<_> =
            doc.validators.iter().map(|v| (v.pub_key.0, v.power.as_str())).collect();
        assert_eq!(validators, keys.keys().iter().map(|key| (*key, "1")).collect::<Vec<_>>());
        assert_eq!(
            doc.app_hash,
            crate::genesis::genesis_app_hash(6, w.el_header.hash_slow(), &keys.validator_set())
                .unwrap()
        );
    }

    /// The Inbox may hold another list at R than the origin record's, as after a
    /// `setFallbackKeys` later in R: the list is then the one whose indexed
    /// `FallbackKeysUpdated` log carries the origin's hash.
    #[tokio::test]
    async fn bootstrap_finds_a_list_replaced_at_r_by_its_logs() {
        let (fx, l1, _, w) = recovery_fixture(1, 6, 1);
        let keys = recovery_fallback_keys();
        serve_fallback_keys(&l1, fx.params.inbox, &fallback_list(&[5]));
        l1.insert_log(
            90,
            fx.params.inbox,
            [FALLBACK_KEYS_UPDATED, keys.hash()],
            keys.abi_encode().into(),
        );
        let (sidecar, _) = recovery_bootstrap(&l1, &fx.params, &at_r(w)).await.unwrap();
        assert_eq!(sidecar.fallback_keys, keys);
    }

    /// An own L1 that gives no list with the origin's hash leaves the bootstrap unavailable, so
    /// InitChain waits and retries; it never refuses the recovery.
    #[tokio::test]
    async fn unavailable_origin_list_leaves_the_bootstrap_unavailable() {
        let (fx, l1, _, w) = recovery_fixture(1, 6, 1);
        l1.state().call_fail = Some(L1Error::Rpc("pruned".into()));
        assert!(matches!(
            recovery_bootstrap(&l1, &fx.params, &at_r(w.clone())).await,
            Err(RecoveryError::Unavailable(_))
        ));
        l1.state().log_fail = Some(L1Error::Rpc("log range".into()));
        assert!(matches!(
            recovery_bootstrap(&l1, &fx.params, &at_r(w)).await,
            Err(RecoveryError::Unavailable(_))
        ));
    }

    /// A sidecar is only the current schema, and its list must hash to the origin record's
    /// `fallbackKeysHash`.
    #[tokio::test]
    async fn bootstrap_refuses_another_version_or_list() {
        let (fx, l1, _, w) = recovery_fixture(1, 6, 1);
        let (sidecar, _) = recovery_bootstrap(&l1, &fx.params, &at_r(w)).await.unwrap();
        for version in [1, RECOVERY_BOOTSTRAP_VERSION + 1] {
            let old = RecoveryBootstrap { version, ..sidecar.clone() };
            assert!(matches!(old.verify(&fx.params), Err(RecoveryError::Invalid(_))), "{version}");
        }
        let other = RecoveryBootstrap { fallback_keys: fallback_list(&[1]), ..sidecar };
        assert!(matches!(
            other.verify(&fx.params),
            Err(RecoveryError::Invalid(message)) if message.contains("hashes to")
        ));
    }
}
