//! The `abci-committee-record` builder: the `committeeRecordHash` an activation takes, computed
//! from the registry before the DAO proposal that activates Etna is written.

use alloy_primitives::{B256, U256};
use serde::{Serialize, Serializer};

use crate::{
    committee::{CommitteeError, record_hash, verify_committee_witness_at_cutoff},
    config::ChainParams,
    l1::{FetchError, L1Error, L1Source, build_committee_witness_at_cutoff, header_at},
    schedule::Schedule,
    types::{CommitteeRecord, Member},
};

/// The genesis committee an activation with a given `genesisCutoff` records, as
/// [`build_committee_record`] derives it.
///
/// Serializes with every `U256` (the record's `total_stake`, each member's `eff_stake`) as a
/// decimal string, as the plain-text report prints them; alloy's own `U256` serialization is `0x`
/// hex.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct GenesisCommitteeRecord {
    /// `committeeRecordHash`: the `committee[e_0]` value `activateEtna` takes
    /// ([`record_hash`] of `record`).
    pub record_hash: B256,
    /// The derived record: target epoch `e_0`, snapshot cutoff `genesisCutoff`, the snapshot's
    /// checkpoint index, set root and totals.
    #[serde(serialize_with = "serialize_record")]
    pub record: CommitteeRecord,
    /// The members, sorted by the MEM-08 key; their powers become the genesis validator set.
    #[serde(serialize_with = "serialize_members")]
    pub members: Vec<Member>,
    /// The L1 block the registry snapshot was read and proven at (the proving block).
    pub proving_block: u64,
    /// The smallest activation block `L1_0` after `genesisCutoff` whose lagged, gridded cutoff
    /// reaches `genesisCutoff`: `max(cutoff_lag + cutoff_grid · ceil(genesisCutoff /
    /// cutoff_grid), genesisCutoff + 1)`; `None` if it overflows `u64`. Informational: the node
    /// floors every later epoch's cutoff at `genesisCutoff`
    /// ([`snapshot_cutoff`](crate::committee::snapshot_cutoff)), so an earlier `L1_0` is safe
    /// too.
    pub min_l1_0: Option<u64>,
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
    /// [`CommitteeRecord::set_root`].
    set_root: B256,
    /// [`CommitteeRecord::total_stake`], in TAIKO base units, as a decimal string.
    #[serde(serialize_with = "serialize_decimal")]
    total_stake: U256,
    /// [`CommitteeRecord::total_power`].
    total_power: u64,
    /// [`CommitteeRecord::encoding_version`].
    encoding_version: u8,
}

/// The report's JSON shape of a [`Member`]: its fields, with `eff_stake` in decimal.
#[derive(Serialize)]
struct MemberJson {
    /// [`Member::pubkey`].
    pubkey: B256,
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
        set_root: record.set_root,
        total_stake: record.total_stake,
        total_power: record.total_power,
        encoding_version: record.encoding_version,
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

/// Why the activation's committee record could not be computed.
#[derive(Debug, thiserror::Error)]
pub enum CommitteeRecordError {
    /// An L1 read failed (the `finalized` number or the proving block's header).
    #[error(transparent)]
    L1(#[from] L1Error),
    /// The genesis cutoff is after the L1 `finalized` block. The activation fixes the cutoff
    /// irreversibly, so the registry snapshot there must already be final.
    #[error(
        "the genesis cutoff {genesis_cutoff} is after the L1 finalized block {finalized}; the \
         activation fixes it irreversibly, so pick a final L1 block"
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
    /// activation with this cutoff would leave the chain without validators.
    #[error(
        "no registry entry is eligible at the genesis cutoff {genesis_cutoff}: the registry has \
         no checkpoint at or before it, or no entry of that checkpoint is active at it \
         (activeFromL1 <= cutoff < exitEffectiveL1) with an effective stake of at least \
         {min_stake} (max(s_min, vp_unit)); an activation with this cutoff would halt the chain \
         at genesis"
    )]
    NoEligibleEntry {
        /// The requested `genesisCutoff`.
        genesis_cutoff: u64,
        /// The minimum effective stake of an eligible entry, `max(s_min, vp_unit)`, in TAIKO
        /// base units.
        min_stake: U256,
    },
    /// The committee witness could not be built from L1 (boxed, as the error is large).
    #[error("committee discovery failed: {0}")]
    Fetch(Box<FetchError>),
    /// The built committee witness does not verify against the proving block (boxed, as the
    /// error is large).
    #[error("committee witness rejected: {0}")]
    Committee(Box<CommitteeError>),
}

/// Computes the genesis committee record an activation with `genesis_cutoff` would record, from
/// the node's own L1.
///
/// In order: `genesis_cutoff` must be at or before the L1 `finalized` block
/// ([`CommitteeRecordError::GenesisCutoffNotFinal`]), as the activation fixes it irreversibly; the
/// proving block is `at`, or the `finalized` block when `None`, and must be after `genesis_cutoff`
/// ([`CommitteeRecordError::ProvingBlockNotAfterCutoff`]); builds the `e_0`
/// committee witness with the snapshot at `genesis_cutoff` itself (no cutoff lag or grid) and its
/// proofs at the proving block ([`build_committee_witness_at_cutoff`]), verifies it against that
/// block's canonical header ([`verify_committee_witness_at_cutoff`]), and derives the committee
/// as `InitChain` will: no heartbeat filter, the lowest `bondId` per pubkey, at most `n_max`
/// members by stake. No eligible entry is [`CommitteeRecordError::NoEligibleEntry`].
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
    let no_eligible_entry = || CommitteeRecordError::NoEligibleEntry {
        genesis_cutoff,
        min_stake: params.s_min.max(params.vp_unit),
    };

    let schedule = genesis_schedule(at, genesis_cutoff);
    let header = header_at(l1, at).await?;
    let witness =
        build_committee_witness_at_cutoff(l1, params, &schedule, at, genesis_cutoff, Schedule::E0)
            .await
            .map_err(|e| match e {
                FetchError::Committee(CommitteeError::Empty) => no_eligible_entry(),
                e => CommitteeRecordError::Fetch(Box::new(e)),
            })?;
    let (record, members) = verify_committee_witness_at_cutoff(
        header.state_root(),
        genesis_cutoff,
        &schedule,
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
        record,
        members,
        proving_block: at,
        min_l1_0: min_l1_0(genesis_cutoff, params),
    })
}

/// The schedule `e_0`'s derivation runs under before any activation exists: the proving block
/// stands in for `L1_0` and the epoch lengths are zero. `e_0` applies no heartbeat filter, so
/// [`derive`](crate::committee::derive) reads none of these fields for it, and the record does
/// not depend on them.
fn genesis_schedule(at: u64, genesis_cutoff: u64) -> Schedule {
    Schedule { genesis_height: 0, l1_0: at, epoch_len: 0, epoch_len_l1: 0, genesis_cutoff }
}

/// The smallest `L1_0 > genesis_cutoff` whose lagged, gridded cutoff
/// ([`cutoff`](crate::committee::cutoff)) reaches `genesis_cutoff`: `cutoff(n) >= C` iff
/// `n >= LAG + G · ceil(C / G)`; `None` if that overflows `u64` (a zero grid, which
/// [`ChainParams::validate`] rejects, gives `None` too).
fn min_l1_0(genesis_cutoff: u64, params: &ChainParams) -> Option<u64> {
    let first = genesis_cutoff
        .checked_next_multiple_of(params.cutoff_grid)?
        .checked_add(params.cutoff_lag)?;
    Some(first.max(genesis_cutoff.checked_add(1)?))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        committee,
        test_utils::{Fixture, GenesisSpec, L1Call, MockL1, RegistryStorage, sample_entries},
        types::RegistryEntry,
    };

    /// Before the activation, the record computed at the fixture's genesis cutoff with proofs at
    /// a later block is exactly the one the fixture's Inbox records at activation: the record
    /// hash of [`committee::derive`] at the cutoff.
    #[tokio::test]
    async fn computes_the_record_hash_of_the_derived_genesis_committee() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let cutoff = fx.activation.genesis_cutoff;
        let report = build_committee_record(&l1, &fx.params, cutoff, None)
            .await
            .expect("the fixture registry yields a committee");
        assert_eq!(report.proving_block, fx.activation.l1_0, "the finalized block by default");
        assert_eq!(report.record, fx.record);
        assert_eq!(report.members, fx.members);
        assert_eq!(report.record_hash, record_hash(fx.params.l2_chain_id, &fx.record));
        assert_eq!(report.record_hash, fx.inbox.committee[0].1, "the recorded committee[e_0]");
        assert_eq!(report.record.cutoff_l1_block, cutoff);
        assert_eq!(report.min_l1_0, Some(cutoff + 1), "lag 0, grid 1");
        assert_eq!(l1.calls()[0], L1Call::Finalized);
        let json: serde_json::Value = serde_json::from_str(&report.to_json_pretty()).unwrap();
        assert_eq!(json["record_hash"], report.record_hash.to_string());
        assert_eq!(json["record"]["cutoff_l1_block"], cutoff);
        assert_eq!(json["record"]["total_stake"], report.record.total_stake.to_string());
        assert_eq!(json["members"].as_array().map(Vec::len), Some(3));
        for (member, value) in report.members.iter().zip(json["members"].as_array().unwrap()) {
            assert_eq!(value["pubkey"], member.pubkey.to_string());
            assert_eq!(value["eff_stake"], member.eff_stake.to_string(), "decimal, not hex");
            assert_eq!(value["power"], member.power);
        }
        assert_eq!(json["proving_block"], report.proving_block);
        assert_eq!(json["min_l1_0"], cutoff + 1);

        // An explicit proving block, even one past the finalized block, gives the same record;
        // the finalized block is still read, to check that the cutoff is final.
        let later = fx.activation.l1_0 + 6;
        fx.plant_l1_block(&l1, later, &fx.inbox, &fx.registry);
        l1.state().calls.clear();
        let at_later = build_committee_record(&l1, &fx.params, cutoff, Some(later))
            .await
            .expect("the snapshot is final at the later block too");
        assert_eq!(at_later.proving_block, later);
        assert_eq!(at_later.record_hash, report.record_hash);
        assert_eq!(l1.calls()[0], L1Call::Finalized);
    }

    /// The JSON report prints every `U256` as a decimal string, as the plain-text report does.
    #[test]
    fn json_report_prints_u256_values_in_decimal() {
        let stake = U256::from(10u64).pow(U256::from(30u64));
        let report = GenesisCommitteeRecord {
            record_hash: B256::repeat_byte(0xab),
            record: CommitteeRecord {
                target_epoch: 0,
                cutoff_l1_block: 63,
                checkpoint_index: 2,
                set_root: B256::repeat_byte(0x5e),
                total_stake: stake,
                total_power: 7,
                encoding_version: 1,
            },
            members: vec![Member { pubkey: B256::repeat_byte(0x11), eff_stake: stake, power: 7 }],
            proving_block: 64,
            min_l1_0: None,
        };
        let json: serde_json::Value = serde_json::from_str(&report.to_json_pretty()).unwrap();
        let decimal = "1000000000000000000000000000000";
        assert_eq!(
            json,
            serde_json::json!({
                "record_hash": B256::repeat_byte(0xab).to_string(),
                "record": {
                    "target_epoch": 0,
                    "cutoff_l1_block": 63,
                    "checkpoint_index": 2,
                    "set_root": B256::repeat_byte(0x5e).to_string(),
                    "total_stake": decimal,
                    "total_power": 7,
                    "encoding_version": 1,
                },
                "members": [
                    { "pubkey": B256::repeat_byte(0x11).to_string(), "eff_stake": decimal, "power": 7 },
                ],
                "proving_block": 64,
                "min_l1_0": null,
            })
        );
        let text = report.to_json_pretty();
        let order = ["record_hash", "record", "members", "proving_block", "min_l1_0"]
            .map(|key| text.find(&format!("\"{key}\"")).expect("every field is printed"));
        assert!(order.is_sorted(), "fields in declaration order: {text}");
    }

    /// The record applies no heartbeat filter, as `e_0` never does: entries that never sent a
    /// heartbeat are members.
    #[tokio::test]
    async fn applies_no_heartbeat_filter() {
        let entries = sample_entries(2)
            .into_iter()
            .map(|e| RegistryEntry { last_heartbeat_at: 0, last_heartbeat_seq: 0, ..e })
            .collect();
        let fx = Fixture::build(GenesisSpec { entries: Some(entries), ..GenesisSpec::new(2) });
        let report =
            build_committee_record(&fx.l1(), &fx.params, fx.activation.genesis_cutoff, None)
                .await
                .expect("a committee without heartbeats");
        assert_eq!(report.members.len(), 2);
        assert_eq!(report.record, fx.record);
    }

    /// An empty registry, or one whose entries are not yet active at the cutoff, has no genesis
    /// committee.
    #[tokio::test]
    async fn no_eligible_entry_is_explained() {
        let fx = Fixture::genesis(2);
        let at = fx.activation.l1_0 + 1;
        let l1 = MockL1::new(at);
        fx.plant_l1_block(&l1, at, &fx.inbox, &RegistryStorage { checkpoints: vec![] });
        let err = build_committee_record(&l1, &fx.params, fx.activation.genesis_cutoff, None)
            .await
            .expect_err("an empty registry");
        assert!(
            matches!(
                err,
                CommitteeRecordError::NoEligibleEntry { genesis_cutoff, min_stake }
                    if genesis_cutoff == fx.activation.genesis_cutoff
                        && min_stake == fx.params.s_min.max(fx.params.vp_unit)
            ),
            "{err:?}"
        );
        assert!(err.to_string().contains("would halt the chain at genesis"), "{err}");

        // Entries active from L1 block 62 are not eligible at cutoff 59.
        let fx = Fixture::build(GenesisSpec::active_after_lagged_l1_0_cutoff(2));
        let err = build_committee_record(&fx.l1(), &fx.params, 59, None)
            .await
            .expect_err("no entry is active yet");
        assert!(
            matches!(err, CommitteeRecordError::NoEligibleEntry { genesis_cutoff: 59, .. }),
            "{err:?}"
        );
    }

    /// The proving block must be after the cutoff; nothing but the finalized block is read when
    /// `--at` already fails.
    #[tokio::test]
    async fn a_proving_block_not_after_the_cutoff_is_refused() {
        let fx = Fixture::genesis(2);
        let cutoff = fx.activation.genesis_cutoff;
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
        let finalized = fx.activation.l1_0;
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

    #[test]
    fn min_l1_0_is_the_first_block_whose_cutoff_reaches_the_genesis_cutoff() {
        let params = |cutoff_grid, cutoff_lag| ChainParams {
            cutoff_grid,
            cutoff_lag,
            ..ChainParams::builtin(protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID).unwrap()
        };
        for (cutoff, grid, lag, expected) in
            [(63, 1, 0, 64), (63, 1, 5, 68), (63, 4, 5, 69), (64, 4, 5, 69), (60, 4, 0, 61)]
        {
            let p = params(grid, lag);
            let n = min_l1_0(cutoff, &p).expect("fits");
            assert_eq!(n, expected, "C={cutoff} G={grid} LAG={lag}");
            assert!(committee::cutoff(n, grid, lag).unwrap() >= cutoff);
            assert!(n == cutoff + 1 || committee::cutoff(n - 1, grid, lag).unwrap() < cutoff);
        }
        assert_eq!(min_l1_0(u64::MAX - 1, &params(4, 0)), None);
        assert_eq!(min_l1_0(u64::MAX, &params(1, 0)), None);
    }
}
