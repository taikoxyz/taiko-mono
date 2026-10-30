//! Etna client conformance: the Lean model's decisions on this client's block rules.
//!
//! The Etna formal PR (#22292) generates rule-level vectors from the model's executable
//! definitions (`Forced.step`, `Consensus.activeAt`/`ElectionValid`, `BlockValidity.HeaderValid`/
//! `AnchorValid`) and documents their schema (`etna-client-conformance-1`) in
//! `testdata/etna_conformance/README.md` there. This crate runs its own copy,
//! `tests/fixtures/etna_conformance/*.json`, which adds only `provenance.formalCommit`, the pushed
//! formal commit it was generated at. Refresh it from `formal/etna` of that commit with
//!
//! ```text
//! lake exe etna-vectors --write <this crate>/tests/fixtures/etna_conformance \
//!   --families forced_step,schedule,block_rules,block_size --provenance <formal commit>
//! ```
//!
//! and never edit the files by hand. They record only what the model decides. Each test runs
//! every vector of one family against this crate and compares the client's decision with the
//! model's. A vector in [`known_divergences`] is checked against the client decision recorded
//! there instead: each entry must name a vector of its family and must differ from the model's
//! decision, so a fixed divergence fails the suite until its entry is removed. Every mismatch of
//! a family is listed before the test fails, and so is every vector the harness cannot encode
//! (a rejection for a reason the vector does not vary is a harness fault, never a verdict).
//!
//! What runs, per family:
//! - `block_rules`, `block_size` and `forced_step` build a whole envelope on a committed chain and
//!   judge it with [`validate_block`], the deterministic validation `ProcessProposal`,
//!   `FinalizeBlock` and the lander share: real raw L1 headers, EIP-1186 proofs of the Inbox (and,
//!   at a switch height, of the registry) under them, the derived header fields and a committee
//!   holding the certified proposer. `forced_step` then completes the decision with
//!   [`verify_forced`] against an engine that builds the singleton from the attributes it is given,
//!   as both handlers do, and advances the cursor as `FinalizeBlock` does. The node-local checks
//!   (L1 finality, the local checkpoint fence, `newPayload`) are not run: the model's verdict
//!   leaves them out too (its `NodeValid` adds them).
//! - `schedule` places every registry checkpoint of a context in one L1 registry state, proves each
//!   checkpoint with a real witness, keeps the ones [`committee::verify_snapshot`] accepts at the
//!   cutoff (the latest checkpoint at or before it) and derives the committee with
//!   [`committee::derive`]: together the checks of `verify_committee_witness_at_cutoff`. The cutoff
//!   is the one the client uses: `genesisCutoff` for epoch 0 (genesis), otherwise the larger of
//!   D(t)'s committed anchor and `L1_0` (`validate_block`'s committee step).
//!
//! The harness maps the model's abstract values to concrete client inputs:
//! - transaction kinds to concrete, really signed bytes ([`tx_bytes`]), checked against the file's
//!   kind table; the model's "canonical" is the client's [`decode_eligible`];
//! - registry key atoms to valid secp256k1 consensus keys whose set-key order is the atoms' order;
//!   atom 0 is a released slot's all-zero entry;
//! - an anchor number above `uint48` has no `extraData` encoding, so such a header carries its low
//!   48 bits;
//! - the vectors' `staleHeartbeat` and `content` inputs, which the model ignores, are ignored here
//!   too: the client has no heartbeat rule and bounds the uncompressed block;
//! - some vectors set U = 1 and `vp_unit` = 1,000, outside the deployment bounds that
//!   `ChainParams::validate` enforces; the rules under test read the parameters directly, so the
//!   harness overrides them without validating.

use std::{collections::BTreeMap, sync::OnceLock};

use abci::{
    AccountWitness, AnchorState, AnchorWitness, ChainParams, CommitteeRecord, CommitteeState,
    CommitteeWitness, Engine, EngineError, EtnaEnvelope, ExecutionBlock, ForcedWitness,
    GenesisRecord, InboxFacts, ParentInfo, RawL1Header, RegistryEntry, Schedule, StorageProof,
    app::{ChainContext, Rejection, validate_block},
    committee::{self, CommitteeError, set_key},
    committee_config_hash,
    engine::{
        PayloadVerdict, PoolSelection,
        forced::{ForcedBuildContext, ForcedBuildError, verify_forced},
    },
    forced::{self, decode_eligible},
    key::ConsensusKey,
    l1::layout::{inbox, registry},
    rules::RuleViolation,
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::signers::{SignerSync, local::PrivateKeySigner};
use alloy_consensus::{
    EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header, SignableTransaction, TxEip1559, TxEnvelope,
    TxLegacy,
};
use alloy_eips::{eip2718::Encodable2718, eip7685::EMPTY_REQUESTS_HASH};
use alloy_primitives::{Address, B64, B256, Bytes, TxKind, U256, keccak256};
use alloy_rlp::Encodable;
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};
use k256::elliptic_curve::sec1::ToEncodedPoint;
use protocol::shasta::{
    calculate_shasta_mix_hash,
    constants::{
        TAIKO_DEVNET_CHAIN_ID, calculate_next_block_eip4396_base_fee_for_parent,
        min_base_fee_for_chain,
    },
};
use serde_json::{Value, json};

// ---------------------------------------------------------------------------------------------
// Known divergences.
// ---------------------------------------------------------------------------------------------

/// A vector on which this client is known to differ from the model: the vector id, the spec
/// lines involved, why they differ, and the client's recorded decision on a subset of the
/// vector's `expect` keys.
struct KnownDivergence {
    id: &'static str,
    spec: &'static str,
    reason: &'static str,
    client: Value,
}

/// Every known divergence of this client. Remove an entry once the spec, the model or the client
/// changes so that the two agree; the suite fails while a listed vector matches the model.
fn known_divergences() -> Vec<KnownDivergence> {
    vec![KnownDivergence {
        id: "block_rules.hw.height-2pow48",
        spec: "SPEC.md 3.4 [CONS-3.4-2]; 6.1 L287",
        reason: "Spec ambiguity, unreachable: the model's HeaderValid requires height < 2^48, a \
                 bound the spec states only for land (6.1, L287); 3.4 states none and \
                 validate_block checks none, so the client accepts block 2^48. A chain cannot \
                 reach that height (about 3.6e7 years at 4 s blocks), and such a block could \
                 never land.",
        client: json!({"valid": true}),
    }]
}

// ---------------------------------------------------------------------------------------------
// Vector files and the comparison shared by every family.
// ---------------------------------------------------------------------------------------------

/// The parsed vector file of `family`.
fn document(family: &str) -> &'static Value {
    static FILES: OnceLock<BTreeMap<&'static str, Value>> = OnceLock::new();
    let files = FILES.get_or_init(|| {
        [
            ("forced_step", include_str!("fixtures/etna_conformance/forced_step.json")),
            ("schedule", include_str!("fixtures/etna_conformance/schedule.json")),
            ("block_rules", include_str!("fixtures/etna_conformance/block_rules.json")),
            ("block_size", include_str!("fixtures/etna_conformance/block_size.json")),
        ]
        .into_iter()
        .map(|(name, text)| {
            (name, serde_json::from_str(text).expect("conformance vectors are JSON"))
        })
        .collect()
    });
    let doc = &files[family];
    assert_eq!(doc["schema"], "etna-client-conformance-1", "{family}: schema");
    assert_eq!(doc["family"], family);
    let commit = doc["provenance"]["formalCommit"].as_str().expect("provenance.formalCommit");
    assert!(
        commit.len() == 40 &&
            commit.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)),
        "{family}: provenance.formalCommit {commit} is not a 40-digit lowercase hex commit"
    );
    doc
}

/// `value` as a `u64`.
fn u64_of(value: &Value) -> u64 {
    value.as_u64().unwrap_or_else(|| panic!("{value} is not a u64"))
}

/// `value` restricted to `keys`.
fn project(value: &Value, keys: &[String]) -> Value {
    Value::Object(
        keys.iter().filter_map(|k| value.get(k).map(|v| (k.clone(), v.clone()))).collect(),
    )
}

/// The client's decision on one vector, or why the harness cannot encode it faithfully.
type Decision = Result<Value, String>;

/// Runs `client` on every vector of `family` (it receives the whole vector) and fails listing
/// every vector whose client decision differs from the model's (or, for a known divergence, from
/// the recorded client decision) and every vector the harness could not encode. `compared`
/// names the `expect` keys a decision is judged on.
fn run_family(
    family: &str,
    compared: impl Fn(&Value) -> Vec<String>,
    mut client: impl FnMut(&Value) -> Decision,
) {
    let doc = document(family);
    let vectors = doc["vectors"].as_array().expect("vectors");
    assert_eq!(u64_of(&doc["vectorCount"]) as usize, vectors.len(), "{family}: vectorCount");
    assert!(!vectors.is_empty(), "{family}: no vectors");
    let by_id: BTreeMap<&str, &Value> =
        vectors.iter().map(|v| (v["id"].as_str().expect("id"), v)).collect();
    assert_eq!(by_id.len(), vectors.len(), "{family}: duplicate vector ids");

    let mut known = BTreeMap::new();
    for d in known_divergences().into_iter().filter(|d| d.id.starts_with(&format!("{family}."))) {
        let v = by_id.get(d.id).unwrap_or_else(|| panic!("{}: listed but not in the file", d.id));
        let keys: Vec<String> =
            d.client.as_object().expect("client record").keys().cloned().collect();
        assert!(!keys.is_empty(), "{}: the record names no decision", d.id);
        for k in &keys {
            assert!(
                v["expect"].get(k).is_some(),
                "{}: the record names {k}, which the model does not decide",
                d.id
            );
        }
        assert_ne!(
            project(&v["expect"], &keys),
            d.client,
            "{}: the known divergence records the model's own decision",
            d.id
        );
        known.insert(d.id, d);
    }

    let (mut agreed, mut diverged, mut mismatches) = (0, Vec::new(), Vec::new());
    for v in vectors {
        let id = v["id"].as_str().expect("id");
        let got = match client(v) {
            Ok(got) => got,
            Err(fault) => {
                mismatches.push(format!("{id}: harness cannot encode the vector: {fault}"));
                continue;
            }
        };
        match known.get(id) {
            Some(d) => {
                let keys: Vec<String> = d.client.as_object().unwrap().keys().cloned().collect();
                if project(&got, &keys) == d.client {
                    diverged.push(format!("{id} ({}): {}", d.spec, d.reason));
                } else {
                    mismatches.push(format!(
                        "{id}: recorded client decision {} changed to {} (model {})",
                        d.client,
                        project(&got, &keys),
                        v["expect"]
                    ));
                }
            }
            None => {
                let keys = compared(&v["expect"]);
                let (want, have) = (project(&v["expect"], &keys), project(&got, &keys));
                if want == have {
                    agreed += 1;
                } else {
                    mismatches.push(format!("{id}: model {want}, client {have}"));
                }
            }
        }
    }
    eprintln!(
        "{family}: {} vectors, {agreed} agree, {} known divergences",
        vectors.len(),
        diverged.len()
    );
    for d in &diverged {
        eprintln!("  known divergence {d}");
    }
    assert!(
        mismatches.is_empty(),
        "{family}: {} mismatches\n{}",
        mismatches.len(),
        mismatches.join("\n")
    );
}

/// Every `expect` key.
fn all_keys(expect: &Value) -> Vec<String> {
    expect.as_object().expect("expect").keys().cloned().collect()
}

/// The devnet chain parameters every family starts from.
fn params() -> ChainParams {
    ChainParams::builtin(TAIKO_DEVNET_CHAIN_ID).expect("devnet parameters")
}

// ---------------------------------------------------------------------------------------------
// Synthetic L1 state: accounts, storage words and EIP-1186 witnesses under one state root.
// ---------------------------------------------------------------------------------------------

/// Builds a trie over `leaves` and keeps the proof nodes on the paths to `targets`.
fn build_trie(leaves: &BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}

/// The retained proof of `key` (an inclusion or an exclusion proof), root first.
fn proof_for(nodes: &ProofNodes, key: B256) -> Vec<Bytes> {
    nodes.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
}

/// An L1 state: each account's storage words (zero words are absent from its trie).
struct L1State(BTreeMap<Address, BTreeMap<B256, U256>>);

impl L1State {
    /// The storage root of `address` and the proofs of `slots` under it.
    fn storage(&self, address: Address, slots: &[B256]) -> (B256, Vec<StorageProof>) {
        let words = &self.0[&address];
        let leaves = words
            .iter()
            .filter(|(_, value)| !value.is_zero())
            .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
            .collect();
        let targets = slots.iter().map(|slot| Nibbles::unpack(keccak256(slot))).collect();
        let (root, nodes) = build_trie(&leaves, targets);
        let proofs = slots
            .iter()
            .map(|slot| StorageProof {
                slot: *slot,
                value: words.get(slot).copied().unwrap_or_default(),
                proof: proof_for(&nodes, keccak256(slot)),
            })
            .collect();
        (root, proofs)
    }

    /// The account record of `address`.
    fn account(&self, address: Address) -> TrieAccount {
        TrieAccount {
            nonce: 1,
            balance: U256::ZERO,
            storage_root: self.storage(address, &[]).0,
            code_hash: keccak256(address),
        }
    }

    /// The state root and the account proof of `target`.
    fn state(&self, target: Address) -> (B256, Vec<Bytes>) {
        let leaves = self
            .0
            .keys()
            .map(|address| (keccak256(address), alloy_rlp::encode(self.account(*address))))
            .collect();
        let (root, nodes) = build_trie(&leaves, vec![Nibbles::unpack(keccak256(target))]);
        (root, proof_for(&nodes, keccak256(target)))
    }

    /// The state root.
    fn root(&self) -> B256 {
        let any = *self.0.keys().next().expect("a state with an account");
        self.state(any).0
    }

    /// The EIP-1186 witness of `address` and exactly `slots`, in that order.
    fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
        let account = self.account(address);
        let (storage_root, storage) = self.storage(address, slots);
        AccountWitness {
            address,
            nonce: account.nonce,
            balance: account.balance,
            storage_root,
            code_hash: account.code_hash,
            account_proof: self.state(address).1,
            storage,
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Blocks on a committed chain, judged by `validate_block`.
// ---------------------------------------------------------------------------------------------

/// `2^48 - 1`: the registry's "no exit" and the widest `uint48`.
const NO_EXIT: u64 = (1 << 48) - 1;

/// What an anchor L1 block holds: its header facts and the Inbox words it proves.
#[derive(Clone)]
struct AnchorFacts {
    number: u64,
    timestamp: u64,
    checkpoint_height: u64,
    generation: u64,
    tail: u64,
    /// Forced inclusion queue entries by index: `(txHash, L1 timestamp, L1 block)`.
    queue: BTreeMap<u64, (B256, u64, u64)>,
}

impl AnchorFacts {
    /// An anchor with an empty forced inclusion queue.
    fn new(number: u64, timestamp: u64, checkpoint_height: u64, generation: u64) -> Self {
        Self { number, timestamp, checkpoint_height, generation, tail: 0, queue: BTreeMap::new() }
    }

    /// The L1 state at this anchor: the Inbox's anchor slots and queue, and the registry with
    /// the proposer's single checkpoint ([`proposer_registry`]).
    fn l1_state(&self) -> L1State {
        let mut words = BTreeMap::from([
            (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(self.generation)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(self.checkpoint_height)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HASH), U256::from_be_bytes([0x0c; 32])),
            (inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL), U256::from(self.tail) << 48),
        ]);
        for (index, (hash, timestamp, l1_block)) in &self.queue {
            let [hash_slot, metadata_slot] = inbox::forced_inclusion_entry_slots(*index);
            words.insert(hash_slot, U256::from_be_bytes(hash.0));
            words.insert(metadata_slot, U256::from(*timestamp) | (U256::from(*l1_block) << 48));
        }
        let p = params();
        L1State(BTreeMap::from([(p.inbox, words), (p.registry, proposer_registry().0)]))
    }

    /// The raw L1 header of this anchor over `state_root`.
    fn header(&self, state_root: B256) -> RawL1Header {
        RawL1Header::from(&Header {
            parent_hash: B256::repeat_byte(0x0a),
            number: self.number,
            timestamp: self.timestamp,
            state_root,
            ..Header::default()
        })
    }

    /// The anchor witness a block moving to this anchor carries.
    fn witness(&self) -> AnchorWitness {
        let state = self.l1_state();
        AnchorWitness {
            l1_header: self.header(state.root()),
            inbox: state.witness(params().inbox, &inbox::anchor_slots()),
        }
    }

    /// The anchor a verified witness of this anchor yields, as the committed chain holds it.
    fn anchor_state(&self) -> AnchorState {
        let header = self.header(self.l1_state().root());
        AnchorState {
            number: header.number(),
            hash: header.hash(),
            state_root: header.state_root(),
            timestamp: header.timestamp(),
            inbox: InboxFacts {
                recovery_generation: self.generation,
                last_checkpoint_height: self.checkpoint_height,
                last_checkpoint_hash: B256::repeat_byte(0x0c),
                forced_inclusion_head: 0,
                forced_inclusion_tail: self.tail,
            },
        }
    }
}

/// The certified proposer's consensus key.
fn proposer_key() -> ConsensusKey {
    let secret = k256::SecretKey::from_slice(&[0x0b; 32]).expect("private key");
    ConsensusKey::from_slice(secret.public_key().to_encoded_point(true).as_bytes()).expect("key")
}

/// The registry every anchor state holds: one checkpoint (at L1 block 1) with the proposer's
/// entry, at the minimum stake and never exiting. Returns its storage words and the entries.
fn proposer_registry() -> (BTreeMap<B256, U256>, Vec<RegistryEntry>) {
    let key = proposer_key();
    let entries = vec![RegistryEntry {
        ck_prefix: key.prefix(),
        ck_x: key.x(),
        eff_stake: params().s_min,
        active_from_l1: 0,
        exit_effective_l1: NO_EXIT,
    }];
    (registry_words(&[(1, entries.clone())]), entries)
}

/// The registry storage words of `checkpoints` (`(l1Block, entries)`, oldest first).
fn registry_words(checkpoints: &[(u64, Vec<RegistryEntry>)]) -> BTreeMap<B256, U256> {
    let mut words = BTreeMap::from([(registry::length_slot(), U256::from(checkpoints.len()))]);
    for (i, (l1_block, entries)) in checkpoints.iter().enumerate() {
        let [head, root] = registry::checkpoint_slots(i as u64);
        words.insert(head, U256::from(*l1_block) | (U256::from(entries.len()) << 48));
        words.insert(root, U256::from_be_bytes(committee::entries_root(entries).0));
    }
    words
}

/// The 13-byte `extraData` `[fee share | generation (uint48) | anchor (uint48)]`; a value above
/// `uint48` keeps its low 48 bits (no header can encode it).
fn extra_data(fee_share: u8, generation: u64, anchor: u64) -> Bytes {
    let mut out = vec![fee_share];
    out.extend_from_slice(&generation.to_be_bytes()[2..]);
    out.extend_from_slice(&anchor.to_be_bytes()[2..]);
    out.into()
}

/// One L2 block on its committed parent: every input [`validate_block`] reads.
struct BlockCase {
    /// The chain's recovery generation.
    generation: u64,
    epoch_len: u64,
    /// `L1_0`, the generation's L1 origin.
    l1_0: u64,
    max_anchor_age: u64,
    /// The forced inclusion delay `D`, in seconds.
    delay: u64,
    /// U, the unsettled-block limit.
    unsettled: u64,
    parent_height: u64,
    parent_timestamp: u64,
    /// The committed parent's anchor (the whole anchor when the block inherits it).
    parent_anchor: AnchorFacts,
    /// The block's anchor.
    anchor: AnchorFacts,
    height: u64,
    /// `floor(time_H)`, the BFT time in seconds.
    bft: u64,
    /// The header's timestamp.
    timestamp: u64,
    /// `extraData[0]`.
    fee_share: u8,
    /// The `extraData` generation.
    extra_generation: u64,
    /// The forced inclusion cursor after the parent.
    cursor: u64,
    forced: Option<ForcedWitness>,
    transactions: Vec<Bytes>,
}

impl BlockCase {
    /// An ordinary valid block 5 on parent 4 that moves the anchor from 110 to 111, whose
    /// timestamp is `anchor_timestamp` (so the anchor is not older than the block).
    fn ordinary(anchor_timestamp: u64) -> Self {
        Self {
            generation: 0,
            epoch_len: 10,
            l1_0: 100,
            max_anchor_age: 7200,
            delay: 3600,
            unsettled: params().unsettled_cap(),
            parent_height: 4,
            parent_timestamp: anchor_timestamp - 2,
            parent_anchor: AnchorFacts::new(110, anchor_timestamp - 100, 2, 0),
            anchor: AnchorFacts::new(111, anchor_timestamp, 2, 0),
            height: 5,
            bft: anchor_timestamp - 1,
            timestamp: anchor_timestamp,
            fee_share: 100,
            extra_generation: 0,
            cursor: 0,
            forced: None,
            transactions: Vec::new(),
        }
    }

    /// The devnet parameters with this case's U.
    fn params(&self) -> ChainParams {
        ChainParams { unsettled_limit: self.unsettled, ..params() }
    }

    /// The committed parent block, whose hash, timestamps and gas feed the derived header.
    fn parent(&self) -> ParentInfo {
        let p = params();
        ParentInfo {
            number: self.parent_height,
            hash: B256::repeat_byte(0x01),
            timestamp: self.parent_timestamp,
            gas_limit: p.block_gas_limit,
            gas_used: p.block_gas_limit / 2,
            base_fee: 10_000_000,
            difficulty: U256::ZERO,
            grandparent_timestamp: self.parent_timestamp.saturating_sub(4),
        }
    }

    /// Whether the block carries an anchor witness: the first block of the generation and every
    /// block that moves the anchor (3.3), as the model's `AnchorValid` requires.
    fn carries_anchor(&self) -> bool {
        self.parent_height == 0 || self.anchor.number != self.parent_anchor.number
    }

    /// The header: the vector's height, timestamp and `extraData`, and every other field at the
    /// value 3.2 derives (the base fee and mix hash by the protocol formulas, the anchor's state
    /// root, the chain's gas limit and the fixed Etna fields).
    fn header(&self) -> Header {
        let parent = self.parent();
        let p = self.params();
        let base_fee = calculate_next_block_eip4396_base_fee_for_parent(
            parent.number,
            parent.gas_limit,
            parent.gas_used,
            parent.timestamp,
            Some(parent.base_fee),
            parent.grandparent_timestamp,
            min_base_fee_for_chain(p.l2_chain_id),
        )
        .expect("the parent carries a base fee");
        Header {
            parent_hash: parent.hash,
            number: self.height,
            timestamp: self.timestamp,
            beneficiary: Address::repeat_byte(0x04),
            extra_data: extra_data(self.fee_share, self.extra_generation, self.anchor.number),
            parent_beacon_block_root: Some(self.anchor.l1_state().root()),
            gas_limit: p.block_gas_limit,
            base_fee_per_gas: Some(base_fee),
            mix_hash: calculate_shasta_mix_hash(B256::from(parent.difficulty), self.height),
            withdrawals_root: Some(EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            requests_hash: Some(EMPTY_REQUESTS_HASH),
            ommers_hash: EMPTY_OMMER_ROOT_HASH,
            nonce: B64::ZERO,
            ..Header::default()
        }
    }

    /// The proposer's committee for `epoch` with its record at `cutoff`.
    fn committee(&self, epoch: u64, cutoff: u64) -> CommitteeState {
        let snapshot = committee::Snapshot {
            checkpoint_index: 0,
            l1_block: 1,
            entries: proposer_registry().1,
        };
        let (record, members) = committee::derive(&snapshot, cutoff, epoch, &self.params())
            .expect("the proposer's committee");
        CommitteeState { record, members }
    }

    /// Judges the block with [`validate_block`] on the committed chain the case describes.
    #[allow(clippy::result_large_err, reason = "validate_block's own result")]
    fn judge(&self) -> Result<abci::app::Validated, Rejection> {
        let params = self.params();
        let genesis = GenesisRecord {
            committee_config_hash: committee_config_hash(&params),
            genesis_height: 0,
            l1_0: self.l1_0,
            epoch_len: self.epoch_len,
            genesis_hash: B256::repeat_byte(0x0e),
            genesis_state_root: B256::repeat_byte(0x0f),
            genesis_cutoff: self.l1_0.saturating_sub(1),
            forced_inclusion_delay: self.delay,
            max_anchor_age: self.max_anchor_age,
        };
        let schedule = Schedule::from_genesis(&genesis);
        let (parent, parent_anchor) = (self.parent(), self.parent_anchor.anchor_state());
        // The committee of the block's epoch holds the proposer; a switch height also derives
        // the incoming committee at `max(parent anchor, L1_0)` under its own anchor's root.
        let epoch = schedule.epoch_of(self.height);
        let mut committees = BTreeMap::from([(epoch, self.committee(epoch, self.l1_0))]);
        let committee = schedule.switch_target(self.height).map(|target| {
            committees.entry(target - 1).or_insert_with(|| self.committee(target - 1, self.l1_0));
            let cutoff = parent_anchor.number.max(self.l1_0);
            let state = self.anchor.l1_state();
            CommitteeWitness {
                record: self.committee(target, cutoff).record,
                registry: state.witness(params.registry, &committee::snapshot_slots(0, false)),
                entries: proposer_registry().1,
            }
        });
        let chain = ChainContext {
            genesis: &genesis,
            generation: self.generation,
            parent: &parent,
            anchor: &parent_anchor,
            forced_cursor: self.cursor,
            committees: &committees,
        };
        let env = EtnaEnvelope {
            block: ExecutionBlock {
                header: self.header(),
                transactions: self.transactions.clone(),
            },
            anchor: self.carries_anchor().then(|| self.anchor.witness()),
            committee,
            forced: self.forced.clone(),
        };
        let proposer = tendermint::account::Id::new(proposer_key().address().into_array());
        validate_block(&chain, &params, &env, self.height, self.bft, proposer)
    }
}

/// `Err` naming the rejection when it is not one the vector varies: the harness then failed to
/// make every other input valid.
fn unexpected(rejection: &Rejection) -> String {
    format!("rejected for a reason the vector does not vary: {rejection}")
}

// ---------------------------------------------------------------------------------------------
// forced_step: `validate_block`'s forced inclusion step and `verify_forced` against
// `Forced.step`.
// ---------------------------------------------------------------------------------------------

/// The key that signs every forced transaction of the vectors.
fn tx_signer() -> PrivateKeySigner {
    PrivateKeySigner::from_bytes(&B256::repeat_byte(0x42)).expect("signing key")
}

/// A signed legacy transaction for this chain carrying `input`.
fn legacy(input: Vec<u8>) -> Bytes {
    let tx = TxLegacy {
        chain_id: Some(TAIKO_DEVNET_CHAIN_ID),
        nonce: 3,
        gas_price: 1_000_000_000,
        gas_limit: 2_000_000,
        to: TxKind::Call(Address::repeat_byte(0x11)),
        value: U256::from(5),
        input: input.into(),
    };
    let signature = tx_signer().sign_hash_sync(&tx.signature_hash()).expect("sign");
    TxEnvelope::Legacy(tx.into_signed(signature)).encoded_2718().into()
}

/// The concrete bytes of a transaction kind of the vector file.
fn tx_bytes(kind: &str) -> Bytes {
    match kind {
        "empty" => Bytes::new(),
        "txA" => legacy(vec![]),
        "txB" => {
            let tx = TxEip1559 {
                chain_id: TAIKO_DEVNET_CHAIN_ID,
                nonce: 4,
                gas_limit: 50_000,
                max_fee_per_gas: 2_000_000_000,
                max_priority_fee_per_gas: 1_000_000,
                to: TxKind::Call(Address::repeat_byte(0x22)),
                value: U256::ZERO,
                access_list: Default::default(),
                input: Bytes::from_static(&[0xde, 0xad, 0xbe, 0xef]),
            };
            let signature = tx_signer().sign_hash_sync(&tx.signature_hash()).expect("sign");
            TxEnvelope::Eip1559(tx.into_signed(signature)).encoded_2718().into()
        }
        "junk" => vec![0xff; 32].into(),
        "junkMax" => vec![0xff; forced::MAX_FORCED_TX_BYTES].into(),
        "junkOver" => vec![0xff; forced::MAX_FORCED_TX_BYTES + 1].into(),
        "txBig" => legacy(vec![0x5b; 8300]),
        other => panic!("unknown transaction kind {other}"),
    }
}

/// The file's kind table holds for the concrete bytes: emptiness, the 8,192-byte class,
/// canonicity (the client's eligibility), and the exact length of every non-canonical kind.
#[test]
fn forced_step_transaction_kinds_match_their_bytes() {
    let p = params();
    let kinds = document("forced_step")["txKinds"].as_array().expect("txKinds");
    assert_eq!(kinds.len(), 7);
    let mut hashes = Vec::new();
    for k in kinds {
        let bytes = tx_bytes(k["name"].as_str().unwrap());
        let (len, canonical) = (u64_of(&k["bytes"]) as usize, k["canonical"].as_bool().unwrap());
        assert_eq!(bytes.is_empty(), len == 0, "{k}");
        assert_eq!(
            bytes.len() > forced::MAX_FORCED_TX_BYTES,
            len > forced::MAX_FORCED_TX_BYTES,
            "{k}"
        );
        assert_eq!(
            decode_eligible(&bytes, p.l2_chain_id, p.block_gas_limit).is_some(),
            canonical,
            "{k}"
        );
        if !canonical {
            assert_eq!(bytes.len(), len, "{k}");
        }
        hashes.push(keccak256(&bytes));
    }
    hashes.sort();
    hashes.dedup();
    assert_eq!(hashes.len(), kinds.len(), "kinds must have distinct hashes");
}

/// An execution engine whose singleton build gives the vector's result. It builds from the
/// attributes it is given, as alethia-reth does: an empty block with the requested header, a
/// block retaining the transaction, an empty block for another context (a later timestamp), or
/// a transport failure (no result yet). Every other engine call is an error.
struct SingletonEngine {
    result: String,
}

#[async_trait::async_trait]
impl Engine for SingletonEngine {
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        Err(EngineError::BadReply("unexpected check_capabilities".into()))
    }

    async fn pool_transactions(&self, _: PoolSelection) -> Result<Vec<TxEnvelope>, EngineError> {
        Err(EngineError::BadReply("unexpected pool_transactions".into()))
    }

    async fn build_block(
        &self,
        parent_hash: B256,
        attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        let eth = &attrs.payload_attributes;
        let mut header = Header {
            parent_hash,
            number: attrs.l1_origin.block_id.to::<u64>(),
            timestamp: eth.timestamp,
            beneficiary: eth.suggested_fee_recipient,
            extra_data: attrs.block_metadata.extra_data.clone(),
            parent_beacon_block_root: eth.parent_beacon_block_root,
            gas_limit: attrs.block_metadata.gas_limit,
            base_fee_per_gas: Some(attrs.base_fee_per_gas.to::<u64>()),
            mix_hash: eth.prev_randao,
            withdrawals_root: Some(EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            requests_hash: Some(EMPTY_REQUESTS_HASH),
            ommers_hash: EMPTY_OMMER_ROOT_HASH,
            nonce: B64::ZERO,
            ..Header::default()
        };
        let given = attrs.block_metadata.tx_list.clone().expect("a singleton build gives its list");
        let given: Vec<TxEnvelope> = alloy_rlp::decode_exact(given).expect("the given list");
        assert_eq!(given.len(), 1, "a singleton build gives exactly [tx]");
        match self.result.as_str() {
            "completedEmpty" => Ok(ExecutionBlock { header, transactions: vec![] }),
            "completedRetained" => {
                Ok(ExecutionBlock { header, transactions: vec![given[0].encoded_2718().into()] })
            }
            "inconsistent" => {
                header.timestamp += 1;
                Ok(ExecutionBlock { header, transactions: vec![] })
            }
            "unavailable" => Err(EngineError::Transport("the EL is not reachable".into())),
            other => panic!("unknown singleton result {other}"),
        }
    }

    async fn new_payload(&self, _: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        Err(EngineError::BadReply("unexpected new_payload".into()))
    }

    async fn forkchoice(&self, _: B256, _: B256, _: B256) -> Result<PayloadVerdict, EngineError> {
        Err(EngineError::BadReply("unexpected forkchoice".into()))
    }

    async fn header_by_number(&self, _: u64) -> Result<Option<Header>, EngineError> {
        Err(EngineError::BadReply("unexpected header_by_number".into()))
    }
}

/// The client's decision on one `forced_step` input. The block is an ordinary valid block whose
/// anchor proves the vector's queue tail and timestamp and, when the vector has a witness, the
/// entry it names; it carries the witness (with a proof of that entry under the anchor's root,
/// or under another root when unauthenticated) and the first transaction. [`validate_block`]
/// classifies it; [`verify_forced`] completes the decision with the singleton result; the cursor
/// advances as `FinalizeBlock` advances it. A retryable build error is `waiting`:
/// `ProcessProposal` and `FinalizeBlock` both wait and retry it (no build result exists yet).
async fn forced_step_client(input: &Value) -> Decision {
    let cursor = u64_of(&input["cursor"]);
    let mut case = BlockCase::ordinary(u64_of(&input["anchorTimestamp"]));
    case.delay = u64_of(&input["delay"]);
    case.cursor = cursor;
    case.anchor.tail = u64_of(&input["tail"]);
    case.transactions = input["firstTx"].as_str().map(tx_bytes).into_iter().collect();
    if let Some(w) = input["witness"].as_object() {
        let index = u64_of(&w["index"]);
        let entry = (
            keccak256(tx_bytes(w["entry"].as_str().unwrap())),
            u64_of(&w["entryTimestamp"]),
            u64_of(&w["entryBlock"]),
        );
        case.anchor.queue.insert(index, entry);
        let mut state = case.anchor.l1_state();
        if !w["authenticated"].as_bool().unwrap() {
            // The same entry under another state root, which the anchor does not commit to.
            state.0.get_mut(&params().inbox).unwrap().insert(B256::repeat_byte(0xee), U256::ONE);
        }
        case.forced = Some(ForcedWitness {
            index,
            entry: state.witness(params().inbox, &inbox::forced_inclusion_entry_slots(index)),
            tx: tx_bytes(w["tx"].as_str().unwrap()),
        });
    }
    let validated = match case.judge() {
        Ok(validated) => validated,
        Err(Rejection::Forced(_)) => return Ok(json!({"result": "rejected"})),
        Err(other) => return Err(unexpected(&other)),
    };
    let engine = SingletonEngine { result: input["singleton"].as_str().unwrap().into() };
    let context =
        ForcedBuildContext { expected: &validated.expected, anchor_hash: validated.anchor.hash };
    match verify_forced(&engine, context, &validated.decision).await {
        Ok(None) => Ok(json!({"result": "accepted", "cursor": cursor})),
        Ok(Some(index)) if index == cursor => {
            Ok(json!({"result": "accepted", "cursor": cursor + 1}))
        }
        Ok(Some(index)) => Err(format!("consumed entry {index}, not the cursor {cursor}")),
        Err(ForcedBuildError::Engine(e)) if e.is_retryable_build() => {
            Ok(json!({"result": "waiting"}))
        }
        Err(ForcedBuildError::Engine(e)) => Err(format!("unexpected engine error {e}")),
        Err(_) => Ok(json!({"result": "rejected"})),
    }
}

#[tokio::test]
async fn forced_step_vectors() {
    // The decisions are asynchronous (the singleton build), so they are computed first.
    let mut decisions = BTreeMap::new();
    for v in document("forced_step")["vectors"].as_array().unwrap() {
        decisions
            .insert(v["id"].as_str().unwrap().to_string(), forced_step_client(&v["input"]).await);
    }
    run_family("forced_step", all_keys, |v| decisions[v["id"].as_str().unwrap()].clone());
}

// ---------------------------------------------------------------------------------------------
// schedule: `Schedule`, `committee::verify_snapshot` and `committee::derive` against
// `Consensus.activeAt`/`ElectionValid`.
// ---------------------------------------------------------------------------------------------

/// Key atoms 1..=63 map to valid consensus keys (of private keys 1..=63) in ascending set-key
/// order, so the client's set-key order is the model's key order.
fn key_table() -> &'static (BTreeMap<u64, ConsensusKey>, BTreeMap<ConsensusKey, u64>) {
    static TABLE: OnceLock<(BTreeMap<u64, ConsensusKey>, BTreeMap<ConsensusKey, u64>)> =
        OnceLock::new();
    TABLE.get_or_init(|| {
        let mut keys: Vec<ConsensusKey> = (1..=63u64)
            .map(|i| {
                let secret = k256::SecretKey::from_slice(B256::from(U256::from(i)).as_slice())
                    .expect("private key");
                ConsensusKey::from_slice(secret.public_key().to_encoded_point(true).as_bytes())
                    .expect("consensus key")
            })
            .collect();
        keys.sort_by_key(|k| set_key(TAIKO_DEVNET_CHAIN_ID, *k));
        let forward: BTreeMap<u64, ConsensusKey> =
            keys.into_iter().enumerate().map(|(i, k)| (i as u64 + 1, k)).collect();
        let back = forward.iter().map(|(a, k)| (*k, *a)).collect();
        (forward, back)
    })
}

/// The registry entry of a context's entry: key atom 0 is a released slot (all zero).
fn registry_entry(e: &Value) -> RegistryEntry {
    let (ck_prefix, ck_x) = match u64_of(&e["key"]) {
        0 => (0, B256::ZERO),
        atom => {
            let key = key_table().0[&atom];
            (key.prefix(), key.x())
        }
    };
    RegistryEntry {
        ck_prefix,
        ck_x,
        eff_stake: U256::from(u64_of(&e["stake"])),
        active_from_l1: u64_of(&e["activeFrom"]),
        exit_effective_l1: u64_of(&e["exitAt"]),
    }
}

/// The client's committee for block `height` of context `c`: the epoch and switch arithmetic of
/// `Schedule`, the cutoff the client uses for that epoch, the one registry checkpoint whose
/// witness `verify_snapshot` accepts at that cutoff, and `committee::derive`. The `targetEpoch`
/// and `cutoff` of a failed election are the epoch and cutoff it was derived for.
fn schedule_client(c: &Value, height: u64) -> Decision {
    let schedule = Schedule {
        l1_0: u64_of(&c["originBlock"]),
        epoch_len: u64_of(&c["epochLen"]),
        genesis_cutoff: u64_of(&c["genesisCutoff"]),
    };
    let params = ChainParams {
        vp_unit: U256::from(u64_of(&c["unit"])),
        s_min: U256::from(u64_of(&c["minimum"])),
        n_max: u64_of(&c["nMax"]) as usize,
        ..params()
    };
    let epoch = schedule.epoch_of(height);
    let cutoff = match schedule.derivation_parent_height(epoch) {
        None => schedule.genesis_cutoff,
        Some(parent) => u64_of(&c["archive"][parent as usize]).max(schedule.l1_0),
    };
    let checkpoints: Vec<(u64, Vec<RegistryEntry>)> = c["snapshots"]
        .as_array()
        .unwrap()
        .iter()
        .map(|s| {
            let entries = s["entries"].as_array().unwrap().iter().map(registry_entry).collect();
            (u64_of(&s["block"]), entries)
        })
        .collect();
    let state = L1State(BTreeMap::from([(params.registry, registry_words(&checkpoints))]));
    let root = state.root();
    let mut accepted = Vec::new();
    for (i, (_, entries)) in checkpoints.iter().enumerate() {
        let has_next = i + 1 < checkpoints.len();
        let witness = CommitteeWitness {
            record: CommitteeRecord {
                target_epoch: epoch,
                cutoff_l1_block: cutoff,
                checkpoint_index: i as u64,
                set_root: B256::ZERO,
                total_power: 0,
            },
            registry: state
                .witness(params.registry, &committee::snapshot_slots(i as u64, has_next)),
            entries: entries.clone(),
        };
        match committee::verify_snapshot(root, params.registry, &witness, cutoff) {
            Ok(snapshot) => accepted.push(snapshot),
            Err(
                CommitteeError::CheckpointAfterCutoff { .. } |
                CommitteeError::NextCheckpointNotAfterCutoff { .. },
            ) => {}
            Err(other) => return Err(format!("checkpoint {i} witness rejected: {other}")),
        }
    }
    if accepted.len() > 1 {
        return Err(format!("{} checkpoints verify at cutoff {cutoff}", accepted.len()));
    }
    let switch = schedule.switch_target(height).map_or(Value::Null, Value::from);
    let derived =
        accepted.first().map(|snapshot| committee::derive(snapshot, cutoff, epoch, &params));
    Ok(match derived {
        Some(Ok((record, members))) => json!({
            "targetEpoch": record.target_epoch,
            "cutoff": record.cutoff_l1_block,
            "valid": true,
            "members": members
                .iter()
                .map(|m| json!({
                    "key": key_table().1[&m.pubkey],
                    "stake": m.eff_stake.to::<u64>(),
                    "power": m.power,
                }))
                .collect::<Vec<_>>(),
            "switchTarget": switch,
        }),
        _ => json!({
            "targetEpoch": epoch,
            "cutoff": cutoff,
            "valid": false,
            "members": [],
            "switchTarget": switch,
        }),
    })
}

/// A valid committee is judged on everything; an invalid one has no members to compare.
fn schedule_keys(expect: &Value) -> Vec<String> {
    let keys = all_keys(expect);
    if expect["valid"] == true {
        keys
    } else {
        keys.into_iter().filter(|k| k != "members").collect()
    }
}

#[test]
fn schedule_vectors() {
    let doc = document("schedule");
    let contexts: BTreeMap<&str, &Value> = doc["contexts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|c| (c["name"].as_str().unwrap(), c))
        .collect();
    run_family("schedule", schedule_keys, |v| {
        let input = &v["input"];
        schedule_client(contexts[input["context"].as_str().unwrap()], u64_of(&input["height"]))
    });
}

// ---------------------------------------------------------------------------------------------
// block_rules: `validate_block` against `HeaderValid ∧ AnchorValid`.
// ---------------------------------------------------------------------------------------------

/// The client's verdict on one block: [`validate_block`] on the vector's parent, anchor and
/// header. A block that keeps its parent's anchor number inherits the whole anchor, as in the
/// model. A rejection must come from a rule the vectors vary: height linkage, the derived
/// timestamp, the `extraData` (base-fee sharing byte, generation, anchor range), the generation
/// triple, anchor progress, freshness or back-pressure.
fn block_rules_client(input: &Value) -> Decision {
    let (p, b, a) = (&input["parent"], &input["block"], &input["anchor"]);
    let anchor = AnchorFacts::new(
        u64_of(&a["number"]),
        u64_of(&a["timestamp"]),
        u64_of(&a["checkpointHeight"]),
        u64_of(&a["generation"]),
    );
    let parent_anchor = AnchorFacts {
        number: u64_of(&p["anchor"]),
        timestamp: u64_of(&p["anchorTimestamp"]),
        ..anchor.clone()
    };
    let case = BlockCase {
        generation: u64_of(&input["chainGeneration"]),
        epoch_len: u64_of(&input["epochLen"]),
        l1_0: u64_of(&input["origin"]),
        max_anchor_age: u64_of(&input["maxAnchorAge"]),
        unsettled: u64_of(&input["unsettled"]),
        parent_height: u64_of(&p["height"]),
        parent_timestamp: u64_of(&p["timestamp"]),
        parent_anchor,
        anchor,
        height: u64_of(&b["height"]),
        bft: u64_of(&b["bftTime"]),
        timestamp: u64_of(&b["timestamp"]),
        fee_share: u8::try_from(u64_of(&b["feeShare"])).expect("a byte"),
        extra_generation: u64_of(&b["generation"]),
        ..BlockCase::ordinary(1_700_000_000)
    };
    match case.judge() {
        Ok(_) => Ok(json!({"valid": true})),
        Err(
            Rejection::Superseded { .. } |
            Rejection::Rule(
                RuleViolation::HeightMismatch { .. } |
                RuleViolation::ExtraDataOverflow { .. } |
                RuleViolation::AnchorRegressed { .. } |
                RuleViolation::AnchorBeforeActivation { .. } |
                RuleViolation::AnchorTooOld { .. } |
                RuleViolation::BackPressure { .. } |
                RuleViolation::GenerationMismatch { .. } |
                RuleViolation::GenerationAhead { .. },
            ),
        ) => Ok(json!({"valid": false})),
        Err(Rejection::Rule(RuleViolation::HeaderField { field, .. }))
            if field == "timestamp" || field == "extra_data" =>
        {
            Ok(json!({"valid": false}))
        }
        Err(other) => Err(unexpected(&other)),
    }
}

#[test]
fn block_rules_vectors() {
    run_family("block_rules", all_keys, |v| block_rules_client(&v["input"]));
}

// ---------------------------------------------------------------------------------------------
// block_size: `validate_block`'s size bound against the `blockBytes ≤ 124,000` conjunct of
// `HeaderValid`.
// ---------------------------------------------------------------------------------------------

/// `n` deterministic bytes that zlib cannot compress (xorshift64).
fn noise(n: usize) -> Vec<u8> {
    let mut state = 0x9e37_79b9_7f4a_7c15_u64;
    (0..n)
        .map(|_| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            (state >> 32) as u8
        })
        .collect()
}

/// The block of `header` and one opaque transaction of `len` bytes.
fn filler_block(header: &Header, len: usize, incompressible: bool) -> ExecutionBlock {
    let tx = if incompressible { noise(len) } else { vec![0; len] };
    ExecutionBlock { header: header.clone(), transactions: vec![Bytes::from(tx)] }
}

/// One filler transaction whose block item `[header, transactions]`, with its list header, is
/// exactly `bytes` long.
fn sized_filler(header: &Header, bytes: usize, incompressible: bool) -> Bytes {
    let mut len = bytes - filler_block(header, 0, false).length();
    for _ in 0..8 {
        let got = filler_block(header, len, false).length();
        if got == bytes {
            break;
        }
        len = (len + bytes).saturating_sub(got);
    }
    let block = filler_block(header, len, incompressible);
    assert_eq!(block.length(), bytes, "block item length");
    block.transactions[0].clone()
}

/// The client's decision: whether an otherwise valid block of exactly `blockBytes` passes
/// [`validate_block`], whose first check is the block size bound.
fn block_size_client(input: &Value) -> Decision {
    let bytes = u64_of(&input["blockBytes"]) as usize;
    let incompressible = match input["content"].as_str() {
        Some("incompressible") => true,
        Some("zeros") => false,
        other => panic!("unknown content {other:?}"),
    };
    let mut case = BlockCase::ordinary(1_700_000_000);
    case.transactions = vec![sized_filler(&case.header(), bytes, incompressible)];
    match case.judge() {
        Ok(_) => Ok(json!({"valid": true})),
        Err(Rejection::LandingCapacity { .. }) => Ok(json!({"valid": false})),
        Err(other) => Err(unexpected(&other)),
    }
}

#[test]
fn block_size_vectors() {
    run_family("block_size", all_keys, |v| block_size_client(&v["input"]));
}
