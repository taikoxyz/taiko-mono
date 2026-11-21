//! The `abci-committee-record` builder: the `committeeRecordHash` an genesis takes, computed
//! from the registry before the DAO proposal that activates Etna is written.

use alloy_primitives::{Address, B256, U256};
use alloy_sol_types::SolCall;
use serde::{Serialize, Serializer};

use crate::{
    committee::{CommitteeError, record_hash, verify_committee_witness_at_cutoff},
    config::ChainParams,
    l1::{FetchError, L1Error, L1Source, build_committee_witness_at_cutoff, header_at},
    schedule::Schedule,
    types::{CommitteeRecord, Member},
};

/// The staking registry's immutable getters the record's derivation depends on (PARAM-11-11).
mod registry_abi {
    alloy_sol_types::sol! {
        /// The registration minimum and selection floor, the config hash's fifth word.
        function minStake() external view returns (uint256);
        /// The L2 chain the registry's bonds are for, bound by every set key and record hash.
        function l2ChainId() external view returns (uint64);
        /// The Inbox proxy the registry serves.
        function inbox() external view returns (address);
    }
}

/// The genesis committee an genesis with a given `genesisCutoff` records, as
/// [`build_committee_record`] derives it.
///
/// Serializes with every `U256` (selected effective stake and each member's `eff_stake`) as a
/// decimal string, as the plain-text report prints them; alloy's own `U256` serialization is `0x`
/// hex.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct GenesisCommitteeRecord {
    /// `committeeRecordHash`: the `genesisCommitteeRecordHash` value `EtnaInbox::init` takes
    /// ([`record_hash`] of `record`).
    pub record_hash: B256,
    /// Required genesis deployment input authenticating the local derivation parameters.
    pub committee_config_hash: B256,
    /// The derived record: target epoch `e_0`, snapshot cutoff `genesisCutoff`, the snapshot's
    /// checkpoint index, set hash and totals.
    #[serde(serialize_with = "serialize_record")]
    pub record: CommitteeRecord,
    /// The members, in set-key order; their powers become the genesis validator set.
    #[serde(serialize_with = "serialize_members")]
    pub members: Vec<Member>,
    /// Sum of selected effective stake in TAIKO base units, excluding pending and unselected
    /// principal. This supports off-chain launch acceptance; it is not a consensus threshold.
    #[serde(serialize_with = "serialize_decimal")]
    pub selected_eff_stake: U256,
    /// The L1 block the registry snapshot was read and proven at (the proving block).
    pub proving_block: u64,
}

impl GenesisCommitteeRecord {
    /// The report as pretty-printed JSON (no trailing newline).
    pub fn to_json_pretty(&self) -> String {
        serde_json::to_string_pretty(self).expect("a committee record report always serializes")
    }
}

/// The report's JSON shape of a [`CommitteeRecord`]: its fields, with `total_stake` in decimal.
#[derive(Serialize)]
struct RecordJson {
    /// [`CommitteeRecord::target_epoch`].
    target_epoch: u64,
    /// [`CommitteeRecord::cutoff_l1_block`].
    cutoff_l1_block: u64,
    /// [`CommitteeRecord::checkpoint_index`].
    checkpoint_index: u64,
    /// [`CommitteeRecord::set_hash`].
    set_hash: B256,
    /// [`CommitteeRecord::total_power`].
    total_power: u64,
}

/// The report's JSON shape of a [`Member`]: its fields, with `eff_stake` in decimal.
#[derive(Serialize)]
struct MemberJson {
    /// [`Member::pubkey`].
    pubkey: crate::key::ConsensusKey,
    /// [`Member::eff_stake`], in TAIKO base units, as a decimal string.
    #[serde(serialize_with = "serialize_decimal")]
    eff_stake: U256,
    /// [`Member::power`].
    power: u64,
}

/// Serializes [`GenesisCommitteeRecord::record`] as a [`RecordJson`].
fn serialize_record<S: Serializer>(record: &CommitteeRecord, s: S) -> Result<S::Ok, S::Error> {
    RecordJson {
        target_epoch: record.target_epoch,
        cutoff_l1_block: record.cutoff_l1_block,
        checkpoint_index: record.checkpoint_index,
        set_hash: record.set_hash,
        total_power: record.total_power,
    }
    .serialize(s)
}

/// Serializes [`GenesisCommitteeRecord::members`] as a sequence of [`MemberJson`].
fn serialize_members<S: Serializer>(members: &[Member], s: S) -> Result<S::Ok, S::Error> {
    s.collect_seq(members.iter().map(|m| MemberJson {
        pubkey: m.pubkey,
        eff_stake: m.eff_stake,
        power: m.power,
    }))
}

/// Serializes a `U256` as a decimal string.
fn serialize_decimal<S: Serializer>(value: &U256, s: S) -> Result<S::Ok, S::Error> {
    s.collect_str(value)
}

/// Why the genesis's committee record could not be computed.
#[derive(Debug, thiserror::Error)]
pub enum CommitteeRecordError {
    /// An L1 read failed (the `finalized` number or the proving block's header).
    #[error(transparent)]
    L1(#[from] L1Error),
    /// The genesis cutoff is after the L1 `finalized` block. The genesis fixes the cutoff
    /// irreversibly, so the registry snapshot there must already be final.
    #[error(
        "the genesis cutoff {genesis_cutoff} is after the L1 finalized block {finalized}; the \
         genesis fixes it irreversibly, so pick a final L1 block"
    )]
    GenesisCutoffNotFinal {
        /// The requested `genesisCutoff`.
        genesis_cutoff: u64,
        /// The L1 node's `finalized` block number.
        finalized: u64,
    },
    /// The proving block is not after the genesis cutoff, so the snapshot at the cutoff is not
    /// final there: a checkpoint written later, at or before the cutoff, would change it.
    #[error(
        "the proving L1 block {at} must be after the genesis cutoff {genesis_cutoff}; pick a \
         past genesis cutoff or a later --at"
    )]
    ProvingBlockNotAfterCutoff {
        /// The proving block (`--at`, or the L1 `finalized` block).
        at: u64,
        /// The requested `genesisCutoff`.
        genesis_cutoff: u64,
    },
    /// No registry entry is eligible at the genesis cutoff, so no genesis committee exists: an
    /// genesis with this cutoff would leave the chain without validators.
    #[error(
        "no registry entry is eligible at the genesis cutoff {genesis_cutoff}: the registry has \
         no checkpoint at or before it, or no entry of that checkpoint is active at it \
         (activeFromL1 <= cutoff < exitEffectiveL1) with an effective stake of at least \
         {min_stake} (the registry's minStake); an genesis with this cutoff would halt the chain \
         at genesis"
    )]
    NoEligibleEntry {
        /// The requested `genesisCutoff`.
        genesis_cutoff: u64,
        /// The minimum effective stake of an eligible entry, the registry's `minStake`
        /// (COMM-4.3-3), in TAIKO base units.
        min_stake: U256,
    },
    /// The registry at `--l1.http` answers a configuration immutable the record depends on with
    /// another value than the chain parameters use: `minStake` (COMM-4.3-3, START-10-14,
    /// PARAM-11-7), `l2ChainId` or `inbox` (PARAM-11-11). Inbox initialization reads the
    /// registry's own values, so a record computed with these parameters would not be the one
    /// the deployment's nodes derive.
    #[error(
        "the staking registry {registry} answers {parameter}() = {on_l1}, but the chain \
         parameters use {configured}; fix --l2.chain-id or --chain-config, or point them at the \
         registry the Inbox is initialized with"
    )]
    RegistryConfigMismatch {
        /// The registry address the chain parameters name.
        registry: Address,
        /// The registry getter, e.g. `minStake`.
        parameter: &'static str,
        /// The registry's answer at the proving block.
        on_l1: String,
        /// The chain parameters' value.
        configured: String,
    },
    /// The registry's answer to a configuration getter is not its ABI return value.
    #[error("the staking registry {registry} answers {parameter}() with malformed ABI data")]
    RegistryConfigMalformed {
        /// The registry address the chain parameters name.
        registry: Address,
        /// The registry getter, e.g. `minStake`.
        parameter: &'static str,
    },
    /// The committee witness could not be built from L1 (boxed, as the error is large).
    #[error("committee discovery failed: {0}")]
    Fetch(Box<FetchError>),
    /// The built committee witness does not verify against the proving block (boxed, as the
    /// error is large).
    #[error("committee witness rejected: {0}")]
    Committee(Box<CommitteeError>),
}

/// Computes the genesis committee record an genesis with `genesis_cutoff` would record, from
/// the node's own L1.
///
/// In order: `genesis_cutoff` must be at or before the L1 `finalized` block
/// ([`CommitteeRecordError::GenesisCutoffNotFinal`]), as the genesis fixes it irreversibly; the
/// proving block is `at`, or the `finalized` block when `None`, and must be after `genesis_cutoff`
/// ([`CommitteeRecordError::ProvingBlockNotAfterCutoff`]); builds the `e_0` committee witness with
/// the snapshot at `genesis_cutoff` itself (no cutoff lag or grid) and its proofs at the proving
/// block ([`build_committee_witness_at_cutoff`]), verifies it against that block's canonical
/// header ([`verify_committee_witness_at_cutoff`]), and derives the committee as `InitChain` will:
/// unique eligible compressed keys, at most `n_max` members by stake and set-key ordering. No
/// eligible entry is [`CommitteeRecordError::NoEligibleEntry`]. Before the snapshot is read, the
/// registry's `minStake()`, `l2ChainId()` and `inbox()` at the proving block must equal the chain
/// parameters' ([`check_registry_config`]).
///
/// The snapshot is the same at any proving block after the cutoff, so the record equals the one
/// `abci-genesis` later derives at `L1_0`. Like `abci-genesis`, this reads the registry entries at
/// the newest block that still holds the snapshot, which can be as old as `genesis_cutoff`.
pub async fn build_committee_record<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    genesis_cutoff: u64,
    at: Option<u64>,
) -> Result<GenesisCommitteeRecord, CommitteeRecordError> {
    let finalized = l1.finalized_number().await?;
    if genesis_cutoff > finalized {
        return Err(CommitteeRecordError::GenesisCutoffNotFinal { genesis_cutoff, finalized });
    }
    let at = at.unwrap_or(finalized);
    if at <= genesis_cutoff {
        return Err(CommitteeRecordError::ProvingBlockNotAfterCutoff { at, genesis_cutoff });
    }
    let no_eligible_entry =
        || CommitteeRecordError::NoEligibleEntry { genesis_cutoff, min_stake: params.min_stake };

    let header = header_at(l1, at).await?;
    check_registry_config(l1, params, header.hash()).await?;
    let witness = build_committee_witness_at_cutoff(l1, params, at, genesis_cutoff, Schedule::E0)
        .await
        .map_err(|e| match e {
            FetchError::Committee(CommitteeError::Empty) => no_eligible_entry(),
            e => CommitteeRecordError::Fetch(Box::new(e)),
        })?;
    let (record, members) = verify_committee_witness_at_cutoff(
        header.state_root(),
        genesis_cutoff,
        params,
        &witness,
        Schedule::E0,
    )
    .map_err(|e| match e {
        CommitteeError::Empty => no_eligible_entry(),
        e => CommitteeRecordError::Committee(Box::new(e)),
    })?;

    Ok(GenesisCommitteeRecord {
        record_hash: record_hash(params.l2_chain_id, &record),
        committee_config_hash: crate::committee::committee_config_hash(params),
        record,
        selected_eff_stake: crate::committee::member_totals(&members)
            .map_err(|e| CommitteeRecordError::Committee(Box::new(e)))?
            .1,
        members,
        proving_block: at,
    })
}

/// Requires the staking registry's configuration immutables the record depends on, read by
/// `eth_call` at the proving block `hash` (the registry is a proxy, so its implementation's
/// immutables could change across an upgrade), to equal `params`': `minStake()` the selection
/// minimum and the config hash's fifth word (COMM-4.3-3, START-10-14, PARAM-11-7), `l2ChainId()`
/// the chain every set key and record hash binds, and `inbox()` the Inbox `params` initialize
/// (PARAM-11-11). The Inbox reads the same registry at initialization, so a mismatch means the
/// record would differ from the one the deployment's nodes derive.
async fn check_registry_config<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    hash: B256,
) -> Result<(), CommitteeRecordError> {
    let registry = params.registry;
    async fn call<L: L1Source + ?Sized, C: SolCall>(
        l1: &L,
        registry: Address,
        hash: B256,
        parameter: &'static str,
        call: C,
    ) -> Result<C::Return, CommitteeRecordError> {
        let answer = l1.call_at(registry, call.abi_encode().into(), hash).await?;
        C::abi_decode_returns_validate(&answer)
            .map_err(|_| CommitteeRecordError::RegistryConfigMalformed { registry, parameter })
    }
    let mismatch = |parameter, on_l1: String, configured: String| {
        Err(CommitteeRecordError::RegistryConfigMismatch { registry, parameter, on_l1, configured })
    };
    let min_stake = call(l1, registry, hash, "minStake", registry_abi::minStakeCall {}).await?;
    if min_stake != params.min_stake {
        return mismatch("minStake", min_stake.to_string(), params.min_stake.to_string());
    }
    let l2_chain_id = call(l1, registry, hash, "l2ChainId", registry_abi::l2ChainIdCall {}).await?;
    if l2_chain_id != params.l2_chain_id {
        return mismatch("l2ChainId", l2_chain_id.to_string(), params.l2_chain_id.to_string());
    }
    let inbox = call(l1, registry, hash, "inbox", registry_abi::inboxCall {}).await?;
    if inbox != params.inbox {
        return mismatch("inbox", inbox.to_string(), params.inbox.to_string());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{Fixture, GenesisSpec, L1Call, MockL1, RegistryStorage};

    /// Before the genesis, the record computed at the fixture's genesis cutoff with proofs at
    /// a later block is exactly the one the fixture's Inbox records at genesis: the record
    /// hash of [`committee::derive`] at the cutoff.
    #[tokio::test]
    async fn computes_the_record_hash_of_the_derived_genesis_committee() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let cutoff = fx.genesis.genesis_cutoff;
        let report = build_committee_record(&l1, &fx.params, cutoff, None)
            .await
            .expect("the fixture registry yields a committee");
        assert_eq!(report.proving_block, fx.genesis.l1_0, "the finalized block by default");
        assert_eq!(report.record, fx.record);
        assert_eq!(report.members, fx.members);
        assert_eq!(report.record_hash, record_hash(fx.params.l2_chain_id, &fx.record));
        assert_eq!(
            report.record_hash,
            fx.inbox.genesis_committee_hash.unwrap(),
            "the recorded committee[e_0]"
        );
        assert_eq!(report.record.cutoff_l1_block, cutoff);
        assert_eq!(report.selected_eff_stake, U256::from(6) * crate::test_utils::stake_unit());
        assert_eq!(l1.calls()[0], L1Call::Finalized);
        let json: serde_json::Value = serde_json::from_str(&report.to_json_pretty()).unwrap();
        assert_eq!(json["record_hash"], report.record_hash.to_string());
        assert_eq!(
            json["committee_config_hash"],
            crate::committee::committee_config_hash(&fx.params).to_string()
        );
        assert_eq!(json["record"]["cutoff_l1_block"], cutoff);
        assert!(json["record"].get("total_stake").is_none());
        assert_eq!(json["members"].as_array().map(Vec::len), Some(3));
        for (member, value) in report.members.iter().zip(json["members"].as_array().unwrap()) {
            assert_eq!(value["pubkey"], member.pubkey.to_string());
            assert_eq!(value["eff_stake"], member.eff_stake.to_string(), "decimal, not hex");
            assert_eq!(value["power"], member.power);
        }
        assert_eq!(json["proving_block"], report.proving_block);

        // An explicit proving block, even one past the finalized block, gives the same record;
        // the finalized block is still read, to check that the cutoff is final.
        let later = fx.genesis.l1_0 + 6;
        fx.plant_l1_block(&l1, later, &fx.inbox, &fx.registry);
        l1.state().calls.clear();
        let at_later = build_committee_record(&l1, &fx.params, cutoff, Some(later))
            .await
            .expect("the snapshot is final at the later block too");
        assert_eq!(at_later.proving_block, later);
        assert_eq!(at_later.record_hash, report.record_hash);
        assert_eq!(l1.calls()[0], L1Call::Finalized);
    }

    /// Launch reporting counts only the highest-stake entries actually selected by n_max.
    #[tokio::test]
    async fn selected_stake_excludes_unselected_registry_principal() {
        let mut fx = Fixture::genesis(3);
        fx.params.n_max = 1;
        let report = build_committee_record(&fx.l1(), &fx.params, fx.genesis.genesis_cutoff, None)
            .await
            .unwrap();
        assert_eq!(report.members.len(), 1);
        assert_eq!(report.selected_eff_stake, U256::from(3) * crate::test_utils::stake_unit());
        assert_eq!(report.record.total_power, 3_000_000_000);
    }

    /// The report describes the chosen snapshot without suggesting a later initialization gate.
    #[tokio::test]
    async fn report_omits_an_initialization_minimum() {
        let fx = Fixture::genesis(1);
        let report = build_committee_record(&fx.l1(), &fx.params, fx.genesis.genesis_cutoff, None)
            .await
            .unwrap();
        let json: serde_json::Value = serde_json::from_str(&report.to_json_pretty()).unwrap();
        assert!(json.get("min_l1_0").is_none());
        assert_eq!(json["record"]["cutoff_l1_block"], fx.genesis.genesis_cutoff);
    }

    /// The JSON report prints every `U256` as a decimal string, as the plain-text report does.
    #[test]
    fn json_report_prints_u256_values_in_decimal() {
        let stake = U256::from(10u64).pow(U256::from(30u64));
        let report = GenesisCommitteeRecord {
            record_hash: B256::repeat_byte(0xab),
            committee_config_hash: B256::repeat_byte(0xcd),
            record: CommitteeRecord {
                target_epoch: 0,
                cutoff_l1_block: 63,
                checkpoint_index: 2,
                set_hash: B256::repeat_byte(0x5e),
                total_power: 7,
            },
            members: vec![Member {
                pubkey: crate::test_utils::key_from_seed(B256::repeat_byte(0x11)),
                eff_stake: stake,
                power: 7,
            }],
            proving_block: 64,
            selected_eff_stake: stake,
        };
        let json: serde_json::Value = serde_json::from_str(&report.to_json_pretty()).unwrap();
        let decimal = "1000000000000000000000000000000";
        assert_eq!(
            json,
            serde_json::json!({
                "record_hash": B256::repeat_byte(0xab).to_string(),
                "committee_config_hash": B256::repeat_byte(0xcd).to_string(),
                "record": {
                    "target_epoch": 0,
                    "cutoff_l1_block": 63,
                    "checkpoint_index": 2,
                    "set_hash": B256::repeat_byte(0x5e).to_string(),
                    "total_power": 7,
                },
                "members": [{
                    "pubkey": report.members[0].pubkey.to_string(),
                    "eff_stake": decimal,
                    "power": 7,
                }],
                "proving_block": 64,
                "selected_eff_stake": decimal,
            })
        );
        let text = report.to_json_pretty();
        let order = ["record_hash", "committee_config_hash", "record", "members", "proving_block"]
            .map(|key| text.find(&format!("\"{key}\"")).expect("every field is printed"));
        assert!(order.is_sorted(), "fields in declaration order: {text}");
    }

    /// An empty registry, or one whose entries are not yet active at the cutoff, has no genesis
    /// committee.
    #[tokio::test]
    async fn no_eligible_entry_is_explained() {
        let fx = Fixture::genesis(2);
        let at = fx.genesis.l1_0 + 1;
        let l1 = MockL1::new(at);
        crate::test_utils::answer_registry_config(&l1, &fx.params);
        fx.plant_l1_block(&l1, at, &fx.inbox, &RegistryStorage { checkpoints: vec![] });
        let err = build_committee_record(&l1, &fx.params, fx.genesis.genesis_cutoff, None)
            .await
            .expect_err("an empty registry");
        assert!(
            matches!(
                err,
                CommitteeRecordError::NoEligibleEntry { genesis_cutoff, min_stake }
                    if genesis_cutoff == fx.genesis.genesis_cutoff
                        && min_stake == fx.params.min_stake
            ),
            "{err:?}"
        );
        assert!(err.to_string().contains("would halt the chain at genesis"), "{err}");

        // Entries active from L1 block 62 are not eligible at cutoff 59.
        let fx = Fixture::build(GenesisSpec::eligible_at_explicit_genesis_snapshot(2));
        let err = build_committee_record(&fx.l1(), &fx.params, 59, None)
            .await
            .expect_err("no entry is active yet");
        assert!(
            matches!(err, CommitteeRecordError::NoEligibleEntry { genesis_cutoff: 59, .. }),
            "{err:?}"
        );
    }

    /// START-10-14, PARAM-11-7/11: the record is computed only with the registry's own
    /// `minStake`, `l2ChainId` and `inbox`, read at the proving block's hash; parameters naming
    /// another value (a stale built-in `min_stake`, a `--chain-config` override, another chain or
    /// Inbox) fail with an error naming both values, before the snapshot is read. A registry
    /// that cannot answer is an L1 error, and a malformed answer is refused.
    #[tokio::test]
    async fn the_registry_config_must_match_the_chain_parameters() {
        let fx = Fixture::genesis(3);
        let cutoff = fx.genesis.genesis_cutoff;
        let l1 = fx.l1();
        build_committee_record(&l1, &fx.params, cutoff, None).await.expect("matching registry");
        let hash = l1.state().headers[&fx.genesis.l1_0].hash();
        let calls = l1.calls();
        for selector in [
            registry_abi::minStakeCall::SELECTOR,
            registry_abi::l2ChainIdCall::SELECTOR,
            registry_abi::inboxCall::SELECTOR,
        ] {
            assert!(
                calls.iter().any(|call| matches!(call, L1Call::CallAt { address, input, hash: h }
                    if *address == fx.params.registry && input[..] == selector[..] && *h == hash)),
                "{calls:?}"
            );
        }

        let stale = U256::from(1u64) + fx.params.min_stake;
        let wrong = [
            ("minStake", ChainParams { min_stake: stale, ..fx.params.clone() }),
            ("l2ChainId", ChainParams { l2_chain_id: 7, ..fx.params.clone() }),
            (
                "inbox",
                ChainParams {
                    inbox: alloy_primitives::Address::repeat_byte(9),
                    ..fx.params.clone()
                },
            ),
        ];
        for (parameter, params) in wrong {
            let l1 = fx.l1();
            let err = build_committee_record(&l1, &params, cutoff, None)
                .await
                .expect_err("the registry disagrees");
            assert!(
                matches!(&err, CommitteeRecordError::RegistryConfigMismatch { parameter: p, registry, .. }
                    if *p == parameter && *registry == fx.params.registry),
                "{err:?}"
            );
            assert!(err.to_string().contains(&format!("{parameter}()")), "{err}");
            assert!(
                l1.calls().iter().all(|call| !matches!(call, L1Call::AccountWitness { .. })),
                "{parameter}: the snapshot is not read"
            );
        }
        let err = build_committee_record(
            &fx.l1(),
            &ChainParams { min_stake: stale, ..fx.params.clone() },
            cutoff,
            None,
        )
        .await
        .unwrap_err();
        assert!(err.to_string().contains(&stale.to_string()), "{err}");
        assert!(err.to_string().contains(&fx.params.min_stake.to_string()), "{err}");

        let silent = fx.l1();
        silent.state().call_answers.clear();
        assert!(matches!(
            build_committee_record(&silent, &fx.params, cutoff, None).await,
            Err(CommitteeRecordError::L1(L1Error::Rpc(_)))
        ));
        let malformed = fx.l1();
        for answer in malformed.state().call_answers.values_mut() {
            *answer = alloy_primitives::Bytes::from_static(&[1]);
        }
        assert!(matches!(
            build_committee_record(&malformed, &fx.params, cutoff, None).await,
            Err(CommitteeRecordError::RegistryConfigMalformed { parameter: "minStake", .. })
        ));
    }

    /// The proving block must be after the cutoff; nothing but the finalized block is read when
    /// `--at` already fails.
    #[tokio::test]
    async fn a_proving_block_not_after_the_cutoff_is_refused() {
        let fx = Fixture::genesis(2);
        let cutoff = fx.genesis.genesis_cutoff;
        for at in [cutoff, cutoff - 1] {
            let l1 = fx.l1();
            let err = build_committee_record(&l1, &fx.params, cutoff, Some(at))
                .await
                .expect_err("--at <= cutoff");
            assert!(
                matches!(
                    err,
                    CommitteeRecordError::ProvingBlockNotAfterCutoff { at: a, genesis_cutoff }
                        if a == at && genesis_cutoff == cutoff
                ),
                "{err:?}"
            );
            assert_eq!(l1.calls(), vec![L1Call::Finalized]);
        }

        // The default proving block, the finalized one, must be after the cutoff too.
        let l1 = fx.l1();
        let finalized = fx.genesis.l1_0;
        let err = build_committee_record(&l1, &fx.params, finalized, None)
            .await
            .expect_err("finalized <= cutoff");
        assert!(
            matches!(err, CommitteeRecordError::ProvingBlockNotAfterCutoff { at, .. } if at == finalized),
            "{err:?}"
        );
    }

    /// A cutoff after the L1 finalized block is refused, even with a later explicit proving
    /// block, before anything but the finalized block is read; a cutoff at the finalized block
    /// is final and passes that check.
    #[tokio::test]
    async fn a_genesis_cutoff_after_the_finalized_block_is_refused() {
        let fx = Fixture::genesis(2);
        let l1 = fx.l1();
        let finalized = l1.state().finalized;
        for cutoff in [finalized + 1, u64::MAX] {
            l1.state().calls.clear();
            let at = cutoff.saturating_add(5);
            let err = build_committee_record(&l1, &fx.params, cutoff, Some(at))
                .await
                .expect_err("cutoff > finalized");
            assert!(
                matches!(
                    err,
                    CommitteeRecordError::GenesisCutoffNotFinal { genesis_cutoff, finalized: f }
                        if genesis_cutoff == cutoff && f == finalized
                ),
                "{err:?}"
            );
            assert!(err.to_string().contains("pick a final L1 block"), "{err}");
            assert_eq!(l1.calls(), vec![L1Call::Finalized]);
        }

        // A cutoff at the finalized block is final: it is accepted with a later proving block.
        let later = finalized + 6;
        fx.plant_l1_block(&l1, later, &fx.inbox, &fx.registry);
        let report = build_committee_record(&l1, &fx.params, finalized, Some(later))
            .await
            .expect("a cutoff at the finalized block is final");
        assert_eq!(report.record.cutoff_l1_block, finalized);
    }
}
