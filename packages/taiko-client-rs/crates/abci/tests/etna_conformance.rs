//! Etna client conformance: the client's block rules and signing-set decisions against vector
//! files.
//!
//! Five families, each a `tests/fixtures/etna_conformance/<family>.json` file in the
//! `etna-client-conformance-1` schema that the formal model's vector generator documents
//! (`testdata/etna_conformance/README.md` there):
//! - `forced_step`, `block_rules` and `block_size` were generated from the historical Lean model's
//!   executable definitions (`Forced.step`, `BlockValidity.HeaderValid`/`AnchorValid`) at
//!   `provenance.formalCommit`. They are kept as regressions, adapted by hand for the specification
//!   at `provenance.specCommit`: the block rules no longer carry an epoch length, and this harness
//!   gives every block a 29-byte `extraData`, a parent LastCommit in which every signer committed,
//!   and fallback keys as the set that signs it. The model's decisions are unchanged. They stay
//!   until the formal model generates current families, which then replace them byte for byte
//!   (`lake exe etna-vectors --write <this crate>/tests/fixtures/etna_conformance --families
//!   <families> --provenance <formal commit>`).
//! - `miss_bitmap` and `candidate` are written by hand from the specification's accept/reject
//!   vectors at `provenance.specCommit`. Each vector names the row it transcribes, and some rows
//!   have more than one vector.
//!
//! The fixture README records the sources and what each family leaves out. Each test runs every
//! vector of one family against this crate and compares the client's decision with the file's.
//! A vector in [`known_divergences`] is checked against the client decision recorded there
//! instead: each entry must name a vector of its family and must differ from the file's
//! decision, so a fixed divergence fails the suite until its entry is removed. Every mismatch of
//! a family is listed before the test fails, and so is every vector the harness cannot encode
//! (a rejection for a reason the vector does not vary is a harness fault, never a verdict).
//!
//! What runs, per family:
//! - every family builds a whole envelope on a committed chain and judges it with
//!   [`validate_block`], the deterministic validation `ProcessProposal`, `FinalizeBlock` and the
//!   lander share: real raw L1 headers, EIP-1186 proofs of the Inbox under them, the derived header
//!   fields, a set that signs the block holding the certified proposer, and the `missBitmap` the
//!   client derives for the block ([`BlockCase::derived_bitmap`]), as both handlers do: the
//!   validators of the set that signs the parent whose LastCommit flag is not a commit
//!   ([`missing_addresses`]), their live key-to-seat words read at the parent's hash through
//!   [`seat_words`] from an EL that holds the parent's and the block's own post-states, and
//!   [`miss_bitmap`] over them.
//! - `forced_step` then completes the decision with [`verify_forced`] against an engine that builds
//!   the singleton from the attributes it is given, as both handlers do, and advances the cursor as
//!   `FinalizeBlock` does. The node-local checks (L1 finality, the local checkpoint fence,
//!   `newPayload`) are not run: the model's verdict leaves them out too (its `NodeValid` adds
//!   them).
//! - `miss_bitmap` reports the derived bitmap and whether a block whose header carries the vector's
//!   bitmap, or its whole `extraData`, is valid.
//! - `candidate` decides the set that signs H + 2 as `FinalizeBlock(H)` does: H's anchor, new or
//!   inherited, comes from [`validate_block`] and proves the minimum total stake and the fallback
//!   keys hash; [`fetch_fallback_keys`] obtains the list from an L1 that answers
//!   `getFallbackKeys()` at the anchor hash and holds the Inbox's list logs; [`staking_words`]
//!   reads the candidate snapshot at H's hash; [`committee::decide`] picks the set.
//!
//! The harness maps the files' abstract values to concrete client inputs:
//! - transaction kinds to concrete, really signed bytes ([`tx_bytes`]), checked against the file's
//!   kind table; the model's "canonical" is the client's [`decode_eligible`];
//! - key names to keys ([`named_key`]), and sets to `name:power` items, a run of consecutively
//!   numbered names at one power written `first..last:power` ([`render`]);
//! - LastCommit flags by the rule's text, only a commit flag committing: the handlers' reading of a
//!   request's vote list, with its check against the replica's parent signers, is pinned by the
//!   crate's handler tests;
//! - an anchor number above `uint48` has no `extraData` encoding, so such a header carries its low
//!   48 bits;
//! - the vectors' `staleHeartbeat` and `content` inputs, which the model ignores, are ignored here
//!   too: the client has no heartbeat rule and bounds the uncompressed block;
//! - some vectors set U = 1, a value `ChainParams::validate` accepts; the rules under test read the
//!   parameters directly, so the harness overrides them without validating.

use std::{collections::BTreeMap, ops::RangeInclusive, sync::OnceLock};

use abci::{
    AccountWitness, AnchorState, AnchorWitness, ChainParams, ChainParamsExt, Engine, EngineError,
    EtnaEnvelope, ExecutionBlock, ForcedWitness, GenesisRecord, InboxFacts, L1Error, L1Source,
    ParentInfo, RawL1Header, StorageProof,
    app::{ChainContext, Rejection, Validated, validate_block},
    committee,
    engine::{
        PayloadVerdict, PoolSelection,
        forced::{ForcedBuildContext, ForcedBuildError, verify_forced},
        staking::{seat_words, staking_words},
    },
    fallback::{FALLBACK_KEYS_UPDATED, FallbackKeys, fetch_fallback_keys, getFallbackKeysCall},
    forced::{self, decode_eligible},
    key::ConsensusKey,
    l1::layout::inbox,
    rules::RuleViolation,
    valstate::{ValEntry, comet_order},
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::signers::{SignerSync, local::PrivateKeySigner};
use alloy_consensus::{
    EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header, SignableTransaction, TxEip1559, TxEnvelope,
    TxLegacy,
};
use alloy_eips::{eip2718::Encodable2718, eip7685::EMPTY_REQUESTS_HASH};
use alloy_primitives::{Address, B64, B256, Bytes, TxKind, U256, hex, keccak256};
use alloy_rlp::Encodable;
use alloy_sol_types::SolCall;
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};
use etna_core::{
    miss::{miss_bitmap, missing_addresses},
    staking::{RECORD_COUNT, key_to_seat_slot, record_slots, snapshot_slots},
};
use k256::elliptic_curve::sec1::ToEncodedPoint;
use protocol::shasta::{
    calculate_shasta_mix_hash,
    constants::{
        TAIKO_DEVNET_CHAIN_ID, calculate_next_etna_block_eip4396_base_fee_for_parent,
        min_base_fee_for_chain,
    },
};
use serde_json::{Value, json};
use tendermint::block::BlockIdFlag;

// ---------------------------------------------------------------------------------------------
// Known divergences.
// ---------------------------------------------------------------------------------------------

/// A vector on which this client is known to differ from the file: the vector id, the spec
/// lines involved, why they differ, and the client's recorded decision on a subset of the
/// vector's `expect` keys.
struct KnownDivergence {
    id: &'static str,
    spec: &'static str,
    reason: &'static str,
    client: Value,
}

/// Every known divergence of this client. Remove an entry once the spec, the model or the client
/// changes so that the two agree; the suite fails while a listed vector matches the file.
fn known_divergences() -> Vec<KnownDivergence> {
    vec![KnownDivergence {
        id: "block_rules.hw.height-2pow48",
        spec: "historical SPEC.md 3.4 [CONS-3.4-2]; 6.1 L287",
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

/// The revision of the Etna specification every family follows.
const SPEC_COMMIT: &str = "5cd86f0e6623ecb9fbbe3f06df099408325d087f";

/// The families generated by the formal model, each with its `provenance.formalCommit`.
const GENERATED: [&str; 3] = ["forced_step", "block_rules", "block_size"];

/// The parsed vector file of `family`.
fn document(family: &str) -> &'static Value {
    static FILES: OnceLock<BTreeMap<&'static str, Value>> = OnceLock::new();
    let files = FILES.get_or_init(|| {
        [
            ("forced_step", include_str!("fixtures/etna_conformance/forced_step.json")),
            ("block_rules", include_str!("fixtures/etna_conformance/block_rules.json")),
            ("block_size", include_str!("fixtures/etna_conformance/block_size.json")),
            ("miss_bitmap", include_str!("fixtures/etna_conformance/miss_bitmap.json")),
            ("candidate", include_str!("fixtures/etna_conformance/candidate.json")),
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
    let provenance = &doc["provenance"];
    assert_eq!(provenance["specCommit"], SPEC_COMMIT, "{family}: provenance.specCommit");
    match provenance["formalCommit"].as_str() {
        Some(commit) => assert!(
            GENERATED.contains(&family) &&
                commit.len() == 40 &&
                commit.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b)),
            "{family}: provenance.formalCommit {commit} is not a 40-digit lowercase hex commit \
             of a generated family"
        ),
        None => assert!(!GENERATED.contains(&family), "{family}: no provenance.formalCommit"),
    }
    doc
}

/// `value` as a `u64`.
fn u64_of(value: &Value) -> u64 {
    value.as_u64().unwrap_or_else(|| panic!("{value} is not a u64"))
}

/// The `0x`-prefixed hex string `value` as a word.
fn u256_of(value: &Value) -> U256 {
    let text = value.as_str().unwrap_or_else(|| panic!("{value} is not a hex string"));
    text.parse().unwrap_or_else(|_| panic!("{text} is not a word"))
}

/// The `0x`-prefixed hex string `value` as a `u128`.
fn u128_of(value: &Value) -> u128 {
    let text = value.as_str().unwrap_or_else(|| panic!("{value} is not a hex string"));
    let digits = text.strip_prefix("0x").unwrap_or_else(|| panic!("{text} has no 0x prefix"));
    u128::from_str_radix(digits, 16).unwrap_or_else(|_| panic!("{text} is not a u128"))
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
/// every vector whose client decision differs from the file's (or, for a known divergence, from
/// the recorded client decision) and every vector the harness could not encode. `compared`
/// names the `expect` keys a decision is judged on.
async fn run_family(
    family: &str,
    compared: impl Fn(&Value) -> Vec<String>,
    mut client: impl AsyncFnMut(&Value) -> Decision,
) {
    let doc = document(family);
    let vectors = doc["vectors"].as_array().expect("vectors");
    assert_eq!(u64_of(&doc["vectorCount"]) as usize, vectors.len(), "{family}: vectorCount");
    assert!(!vectors.is_empty(), "{family}: no vectors");
    let by_id: BTreeMap<&str, &Value> =
        vectors.iter().map(|v| (v["id"].as_str().expect("id"), v)).collect();
    assert_eq!(by_id.len(), vectors.len(), "{family}: duplicate vector ids");
    for id in by_id.keys() {
        assert!(id.starts_with(&format!("{family}.")), "{id}: not an id of {family}");
    }

    let mut known = BTreeMap::new();
    for d in known_divergences().into_iter().filter(|d| d.id.starts_with(&format!("{family}."))) {
        let v = by_id.get(d.id).unwrap_or_else(|| panic!("{}: listed but not in the file", d.id));
        let keys: Vec<String> =
            d.client.as_object().expect("client record").keys().cloned().collect();
        assert!(!keys.is_empty(), "{}: the record names no decision", d.id);
        for k in &keys {
            assert!(
                v["expect"].get(k).is_some(),
                "{}: the record names {k}, which the file does not decide",
                d.id
            );
        }
        assert_ne!(
            project(&v["expect"], &keys),
            d.client,
            "{}: the known divergence records the file's own decision",
            d.id
        );
        known.insert(d.id, d);
    }

    let (mut agreed, mut diverged, mut mismatches) = (0, Vec::new(), Vec::new());
    for v in vectors {
        let id = v["id"].as_str().expect("id");
        let got = match client(v).await {
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
                        "{id}: recorded client decision {} changed to {} (file {})",
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
                    mismatches.push(format!("{id}: file {want}, client {have}"));
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
// Named keys and sets.
// ---------------------------------------------------------------------------------------------

/// The consensus key a vector names: the public key of the secret
/// `keccak256("etna conformance key " ‖ name)`.
fn named_key(name: &str) -> ConsensusKey {
    let secret = keccak256(format!("etna conformance key {name}"));
    let secret = k256::SecretKey::from_slice(secret.as_slice()).expect("a valid secret");
    ConsensusKey::from_slice(secret.public_key().to_encoded_point(true).as_bytes()).expect("key")
}

/// A name's letters and number: `C12` is `("C", 12)`.
fn split_name(name: &str) -> (&str, u64) {
    let at = name.find(|c: char| c.is_ascii_digit()).unwrap_or_else(|| panic!("{name}: no number"));
    (&name[..at], name[at..].parse().unwrap_or_else(|_| panic!("{name}: not a number")))
}

/// The numbers `a..b` of a span, both included.
fn span(text: &str) -> RangeInclusive<u64> {
    let (a, b) = text.split_once("..").unwrap_or((text, text));
    a.parse().expect("a span start")..=b.parse().expect("a span end")
}

/// The names of `list`: space-separated names, or runs `C0..C3` of the consecutively numbered
/// names from the first to the last.
fn names(list: &str) -> Vec<String> {
    list.split_whitespace()
        .flat_map(|item| match item.split_once("..") {
            Some((first, last)) => {
                let ((letters, a), (other, b)) = (split_name(first), split_name(last));
                assert_eq!(letters, other, "{item}: one run of one letter");
                (a..=b).map(|n| format!("{letters}{n}")).collect()
            }
            None => vec![item.to_string()],
        })
        .collect()
}

/// The fallback key list of the named keys `list` ([`names`]).
fn fallback_list(list: &str) -> FallbackKeys {
    let mut keys: Vec<_> = names(list).iter().map(|name| named_key(name)).collect();
    keys.sort();
    FallbackKeys::new(keys).expect("a valid fallback key list")
}

/// The fallback keys an anchor proves unless a vector says otherwise; with the minimum total
/// stake of all ones the anchors prove, they also sign every block the harness judges.
fn default_fallback() -> FallbackKeys {
    fallback_list("F1..F4")
}

/// The keys and powers of a vector's `{name: power}` set.
fn members(value: &Value) -> Vec<(ConsensusKey, u64)> {
    let set = value.as_object().unwrap_or_else(|| panic!("{value} is not a set"));
    set.iter().map(|(name, power)| (named_key(name), u64_of(power))).collect()
}

/// `members` as the vectors write a set: `name:power` items in name order, each run of names
/// with consecutive numbers and one power written `first..last:power`. Keys are named over the
/// names `C0` to `C255` and `F0` to `F255`; any other key is `?`.
fn render(members: &[(ConsensusKey, u64)]) -> String {
    static NAMES: OnceLock<BTreeMap<ConsensusKey, (char, u64)>> = OnceLock::new();
    let table = NAMES.get_or_init(|| {
        ['C', 'F']
            .into_iter()
            .flat_map(|letter| (0..256).map(move |n| (letter, n)))
            .map(|(letter, n)| (named_key(&format!("{letter}{n}")), (letter, n)))
            .collect()
    });
    let mut named: Vec<(char, u64, u64)> = members
        .iter()
        .map(|(key, power)| {
            let (letter, n) = table.get(key).copied().unwrap_or(('?', 0));
            (letter, n, *power)
        })
        .collect();
    named.sort_unstable();
    let mut runs: Vec<(char, u64, u64, u64)> = Vec::new();
    for (letter, n, power) in named {
        match runs.last_mut() {
            Some(run) if run.0 == letter && run.2 + 1 == n && run.3 == power => run.2 = n,
            _ => runs.push((letter, n, n, power)),
        }
    }
    runs.iter()
        .map(|&(letter, first, last, power)| {
            if first == last {
                format!("{letter}{first}:{power}")
            } else {
                format!("{letter}{first}..{letter}{last}:{power}")
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// The two words of a snapshot seat record holding `key` at `power`: `ckX`, then
/// `ckPrefix | power << 8`.
fn record_words(key: ConsensusKey, power: u64) -> [U256; 2] {
    [U256::from_be_bytes(key.x().0), U256::from(key.prefix()) | (U256::from(power) << 8usize)]
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

/// The node's own L1 as the fallback key lists need it: the Inbox's `getFallbackKeys()` at each
/// anchor hash in `served` answers the list held there, and its `FallbackKeysUpdated` logs hold
/// the lists in `logged`. Every other read is an error.
struct ListL1 {
    served: BTreeMap<B256, FallbackKeys>,
    logged: Vec<FallbackKeys>,
}

/// The error of an L1 read [`ListL1`] does not serve.
fn no_l1_read(name: &str) -> L1Error {
    L1Error::Rpc(format!("unexpected L1 read {name}"))
}

#[async_trait::async_trait]
impl L1Source for ListL1 {
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        Err(no_l1_read("finalized_number"))
    }

    async fn canonical_hash(&self, _: u64) -> Result<B256, L1Error> {
        Err(no_l1_read("canonical_hash"))
    }

    async fn header(&self, _: u64) -> Result<RawL1Header, L1Error> {
        Err(no_l1_read("header"))
    }

    async fn account_witness(
        &self,
        _: Address,
        _: &[B256],
        _: u64,
    ) -> Result<AccountWitness, L1Error> {
        Err(no_l1_read("account_witness"))
    }

    async fn call_at(&self, address: Address, input: Bytes, hash: B256) -> Result<Bytes, L1Error> {
        if address != params().inbox || input[..] != (getFallbackKeysCall {}).abi_encode()[..] {
            return Err(no_l1_read("call_at"));
        }
        let keys = self.served.get(&hash).ok_or_else(|| no_l1_read("call_at another hash"))?;
        Ok(keys.abi_encode().into())
    }

    async fn inbox_logs(
        &self,
        inbox: Address,
        topic0: B256,
        topic1: B256,
        _: u64,
        _: u64,
    ) -> Result<Vec<Bytes>, L1Error> {
        if inbox != params().inbox || topic0 != FALLBACK_KEYS_UPDATED {
            return Err(no_l1_read("inbox_logs"));
        }
        let logs = self.logged.iter().filter(|keys| keys.hash() == topic1);
        Ok(logs.map(|keys| keys.abi_encode().into()).collect())
    }

    async fn forced_transaction(&self, _: Address, _: u64, _: u64) -> Result<Bytes, L1Error> {
        Err(no_l1_read("forced_transaction"))
    }

    async fn storage_at(&self, _: Address, _: B256, _: u64) -> Result<U256, L1Error> {
        Err(no_l1_read("storage_at"))
    }
}

// ---------------------------------------------------------------------------------------------
// Blocks on a committed chain, judged by `validate_block`.
// ---------------------------------------------------------------------------------------------

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
    /// The fallback key list whose hash the Inbox stores.
    fallback_keys: FallbackKeys,
    /// The minimum total stake, in all 256 bits.
    min_total_stake: U256,
}

impl AnchorFacts {
    /// An anchor with an empty forced inclusion queue, the default fallback keys and a minimum
    /// total stake of all ones.
    fn new(number: u64, timestamp: u64, checkpoint_height: u64, generation: u64) -> Self {
        Self {
            number,
            timestamp,
            checkpoint_height,
            generation,
            tail: 0,
            queue: BTreeMap::new(),
            fallback_keys: default_fallback(),
            min_total_stake: U256::MAX,
        }
    }

    /// The L1 state at this anchor: the Inbox's anchor slots and queue.
    fn l1_state(&self) -> L1State {
        let mut words = BTreeMap::from([
            (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(self.generation)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(self.checkpoint_height)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HASH), U256::from_be_bytes([0x0c; 32])),
            (
                inbox::slot(inbox::FALLBACK_KEYS_HASH),
                U256::from_be_bytes(self.fallback_keys.hash().0),
            ),
            (inbox::slot(inbox::MIN_TOTAL_STAKE), self.min_total_stake),
            (inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL), U256::from(self.tail) << 48),
        ]);
        for (index, (hash, timestamp, l1_block)) in &self.queue {
            let [hash_slot, metadata_slot] = inbox::forced_inclusion_entry_slots(*index);
            words.insert(hash_slot, U256::from_be_bytes(hash.0));
            words.insert(metadata_slot, U256::from(*timestamp) | (U256::from(*l1_block) << 48));
        }
        L1State(BTreeMap::from([(params().inbox, words)]))
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
                rules_schedule: alloy_primitives::U256::ZERO,
                recovery_generation: self.generation,
                last_checkpoint_height: self.checkpoint_height,
                last_checkpoint_hash: B256::repeat_byte(0x0c),
                forced_inclusion_head: 0,
                forced_inclusion_tail: self.tail,
                fallback_keys_hash: self.fallback_keys.hash(),
                min_total_stake: self.min_total_stake,
            },
        }
    }
}

/// The 29-byte `extraData` `[fee share | generation (uint48) | anchor (uint48) | missBitmap
/// (uint128)]`; a value above `uint48` keeps its low 48 bits (no header can encode it).
fn extra_data(fee_share: u8, generation: u64, anchor: u64, miss_bitmap: u128) -> Bytes {
    let mut out = vec![fee_share];
    out.extend_from_slice(&generation.to_be_bytes()[2..]);
    out.extend_from_slice(&anchor.to_be_bytes()[2..]);
    out.extend_from_slice(&miss_bitmap.to_be_bytes());
    out.into()
}

/// One L2 block on its committed parent: every input [`validate_block`] reads.
struct BlockCase {
    /// The chain's recovery generation.
    generation: u64,
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
    /// The set that signs the block; it holds the certified proposer.
    signers: Vec<(ConsensusKey, u64)>,
    /// The certified proposer.
    proposer: ConsensusKey,
    /// The set that signs the parent, for every parent but the generation's origin.
    parent_signers: Vec<(ConsensusKey, u64)>,
    /// The LastCommit flag of a parent signer whose vote is not a commit; every other committed.
    flags: BTreeMap<ConsensusKey, BlockIdFlag>,
    /// The staking contract's words in the parent's post-state; every other slot is zero.
    parent_post_state: BTreeMap<B256, U256>,
    /// The staking contract's words in the block's own post-state; every other slot is zero.
    block_post_state: BTreeMap<B256, U256>,
    /// The header's `missBitmap`.
    miss_bitmap: u128,
    /// The header's whole `extraData`, in place of the one the fields above encode.
    raw_extra_data: Option<Bytes>,
}

impl BlockCase {
    /// An ordinary valid block 5 on parent 4 that moves the anchor from 110 to 111, whose
    /// timestamp is `anchor_timestamp` (so the anchor is not older than the block). The default
    /// fallback keys sign the block and its parent, every one of them committed the parent, and
    /// the header's `missBitmap` is 0.
    fn ordinary(anchor_timestamp: u64) -> Self {
        let fallback = default_fallback().validator_set();
        Self {
            generation: 0,
            l1_0: 100,
            max_anchor_age: 7200,
            delay: 3600,
            unsettled: params().unsettled_limit,
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
            proposer: fallback[0].0,
            signers: fallback.clone(),
            parent_signers: fallback,
            flags: BTreeMap::new(),
            parent_post_state: BTreeMap::new(),
            block_post_state: BTreeMap::new(),
            miss_bitmap: 0,
            raw_extra_data: None,
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

    /// The set that signs the parent, in CometBFT order: the validators the block's LastCommit
    /// lists. The generation's first block, on the origin at height 0, has no LastCommit.
    fn parent_set(&self) -> Vec<ValEntry> {
        if self.parent_height == 0 {
            return Vec::new();
        }
        comet_order(&self.parent_signers).expect("a valid parent signing set")
    }

    /// Whether the block carries an anchor witness: the first block of the generation and every
    /// block that moves the anchor (3.3), as the model's `AnchorValid` requires.
    fn carries_anchor(&self) -> bool {
        self.parent_height == 0 || self.anchor.number != self.parent_anchor.number
    }

    /// The header: the case's height, timestamp and `extraData`, and every other field at the
    /// value 3.2 derives (the base fee and mix hash by the protocol formulas, the anchor's state
    /// root, the chain's gas limit and the fixed Etna fields).
    fn header(&self) -> Header {
        let parent = self.parent();
        let p = self.params();
        let base_fee = calculate_next_etna_block_eip4396_base_fee_for_parent(
            parent.number,
            parent.gas_limit,
            parent.gas_used,
            parent.timestamp,
            Some(parent.base_fee),
            parent.grandparent_timestamp,
            min_base_fee_for_chain(p.l2_chain_id),
        )
        .expect("the parent carries a base fee");
        let extra = self.raw_extra_data.clone().unwrap_or_else(|| {
            extra_data(self.fee_share, self.extra_generation, self.anchor.number, self.miss_bitmap)
        });
        Header {
            parent_hash: parent.hash,
            number: self.height,
            timestamp: self.timestamp,
            beneficiary: Address::repeat_byte(0x04),
            extra_data: extra,
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

    /// An EL that holds the parent's and the block's post-states and builds singletons with
    /// `singleton`.
    fn engine(&self, singleton: Option<&str>) -> FixtureEngine {
        FixtureEngine {
            singleton: singleton.map(str::to_string),
            post_states: BTreeMap::from([
                (self.parent().hash, self.parent_post_state.clone()),
                (self.header().hash_slow(), self.block_post_state.clone()),
            ]),
        }
    }

    /// The `missBitmap` the client derives for the block, as `ProcessProposal` and
    /// `FinalizeBlock` do: the parent signers whose LastCommit flag is not a commit
    /// ([`missing_addresses`]), each one's live key-to-seat word read at the parent's hash
    /// ([`seat_words`]), and the bitmap of their seats ([`miss_bitmap`]). `Err` when the EL
    /// could not serve a read.
    async fn derived_bitmap(&self) -> Result<u128, String> {
        let signers = self.parent_set();
        let addresses: Vec<Address> = signers.iter().map(|entry| entry.key.address()).collect();
        let committed: Vec<bool> = signers
            .iter()
            .map(|entry| self.flags.get(&entry.key).is_none_or(|f| *f == BlockIdFlag::Commit))
            .collect();
        let missing =
            missing_addresses(&addresses, &committed).expect("one flag per parent signer");
        let words = seat_words(&self.engine(None), params().staking, self.parent().hash, &missing)
            .await
            .map_err(|error| format!("the seat words cannot be read: {error}"))?;
        Ok(miss_bitmap(&missing, |address| words[&address]))
    }

    /// Judges the block with [`validate_block`] on the committed chain the case describes, given
    /// the derived `missBitmap` ([`BlockCase::derived_bitmap`]); `Err` when the EL could not
    /// serve a read.
    #[allow(clippy::result_large_err, reason = "validate_block's own result")]
    async fn judge(&self) -> Result<Result<Validated, Rejection>, String> {
        let bitmap = self.derived_bitmap().await?;
        Ok(self.validate(bitmap))
    }

    /// Judges the block with [`validate_block`] on the committed chain the case describes, given
    /// the `missBitmap` `miss_bitmap` the block must carry.
    #[allow(clippy::result_large_err, reason = "validate_block's own result")]
    fn validate(&self, miss_bitmap: u128) -> Result<Validated, Rejection> {
        let params = self.params();
        let genesis = GenesisRecord {
            config_hash: params.config_hash(),
            genesis_height: 0,
            l1_0: self.l1_0,
            genesis_hash: B256::repeat_byte(0x0e),
            genesis_state_root: B256::repeat_byte(0x0f),
            forced_inclusion_delay: self.delay,
            max_anchor_age: self.max_anchor_age,
        };
        let (parent, parent_anchor) = (self.parent(), self.parent_anchor.anchor_state());
        let signers = comet_order(&self.signers).expect("a valid signing set");
        let parent_signers = self.parent_set();
        let chain = ChainContext {
            recovery: None,
            genesis: &genesis,
            generation: self.generation,
            parent: &parent,
            anchor: &parent_anchor,
            forced_cursor: self.cursor,
            signers: &signers,
            parent_signers: &parent_signers,
        };
        let env = EtnaEnvelope {
            block: ExecutionBlock {
                header: self.header(),
                transactions: self.transactions.clone(),
            },
            anchor: self.carries_anchor().then(|| self.anchor.witness()),
            forced: self.forced.clone(),
        };
        let proposer = tendermint::account::Id::new(self.proposer.address().into_array());
        validate_block(&chain, &params, &env, self.height, self.bft, proposer, miss_bitmap)
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

/// An execution engine of fixed answers. Its singleton build gives the vector's result, building
/// from the attributes it is given as alethia-reth does: an empty block with the requested
/// header, a block retaining the transaction, an empty block for another context (a later
/// timestamp), or a transport failure (no result yet). Its storage reads answer the staking
/// contract's words in the post-state of each block it holds. Every other engine call is an
/// error.
struct FixtureEngine {
    /// The singleton build's result; `None` when nothing may build.
    singleton: Option<String>,
    /// The staking contract's words in the post-state of each block, by block hash; every slot
    /// absent there is zero.
    post_states: BTreeMap<B256, BTreeMap<B256, U256>>,
}

#[async_trait::async_trait]
impl Engine for FixtureEngine {
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
        let Some(result) = self.singleton.as_deref() else {
            return Err(EngineError::BadReply("unexpected build_block".into()));
        };
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
        match result {
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

    async fn finalized_header(&self) -> Result<Option<Header>, EngineError> {
        Err(EngineError::Setup("fixture has no finalized boundary".into()))
    }
    async fn historical_state_available(&self, _: B256) -> Result<bool, EngineError> {
        Err(EngineError::Setup("fixture has no historical state".into()))
    }
    async fn storage_at(
        &self,
        address: Address,
        slots: &[B256],
        hash: B256,
    ) -> Result<Vec<U256>, EngineError> {
        if address != params().staking {
            return Err(EngineError::BadReply(format!("unexpected storage read of {address}")));
        }
        let words = self.post_states.get(&hash).ok_or_else(|| {
            EngineError::BadReply(format!("no post-state of block {hash} in the fixture"))
        })?;
        Ok(slots.iter().map(|slot| words.get(slot).copied().unwrap_or_default()).collect())
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
    let validated = match case.judge().await? {
        Ok(validated) => validated,
        Err(Rejection::Forced(_)) => return Ok(json!({"result": "rejected"})),
        Err(other) => return Err(unexpected(&other)),
    };
    let engine = case.engine(input["singleton"].as_str());
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
    run_family("forced_step", all_keys, async |v| forced_step_client(&v["input"]).await).await;
}

// ---------------------------------------------------------------------------------------------
// block_rules: `validate_block` against `HeaderValid ∧ AnchorValid`.
// ---------------------------------------------------------------------------------------------

/// The client's verdict on one block: [`validate_block`] on the vector's parent, anchor and
/// header. A block that keeps its parent's anchor number inherits the whole anchor, as in the
/// model. A rejection must come from a rule the vectors vary: height linkage, the derived
/// timestamp, the `extraData` (base-fee sharing byte, generation, anchor range), the generation
/// triple, anchor progress, freshness or back-pressure.
async fn block_rules_client(input: &Value) -> Decision {
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
    match case.judge().await? {
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

#[tokio::test]
async fn block_rules_vectors() {
    run_family("block_rules", all_keys, async |v| block_rules_client(&v["input"]).await).await;
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
async fn block_size_client(input: &Value) -> Decision {
    let bytes = u64_of(&input["blockBytes"]) as usize;
    let incompressible = match input["content"].as_str() {
        Some("incompressible") => true,
        Some("zeros") => false,
        other => panic!("unknown content {other:?}"),
    };
    let mut case = BlockCase::ordinary(1_700_000_000);
    case.transactions = vec![sized_filler(&case.header(), bytes, incompressible)];
    match case.judge().await? {
        Ok(_) => Ok(json!({"valid": true})),
        Err(Rejection::BlockSizeBound { .. }) => Ok(json!({"valid": false})),
        Err(other) => Err(unexpected(&other)),
    }
}

#[tokio::test]
async fn block_size_vectors() {
    run_family("block_size", all_keys, async |v| block_size_client(&v["input"]).await).await;
}

// ---------------------------------------------------------------------------------------------
// miss_bitmap: the `missBitmap` a block must carry and the 29-byte `extraData` that holds it.
// ---------------------------------------------------------------------------------------------

/// The staking contract's words a vector's post-state names: the live key-to-seat word of each
/// named key (`keyToSeat`), and each snapshot seat record that holds a named key at power 1
/// (`records`, by seat).
fn post_state(value: &Value) -> BTreeMap<B256, U256> {
    let mut words = BTreeMap::new();
    for (name, word) in value["keyToSeat"].as_object().expect("keyToSeat") {
        words.insert(key_to_seat_slot(named_key(name).address()), u256_of(word));
    }
    for (seat, name) in value.get("records").and_then(Value::as_object).into_iter().flatten() {
        let key = named_key(name.as_str().expect("a key name"));
        let seat = seat.parse().expect("a seat number");
        words.extend(record_slots(seat).into_iter().zip(record_words(key, 1)));
    }
    words
}

/// The LastCommit flag a vector names.
fn block_id_flag(value: &Value) -> BlockIdFlag {
    match value.as_str() {
        Some("commit") => BlockIdFlag::Commit,
        Some("absent") => BlockIdFlag::Absent,
        Some("nil") => BlockIdFlag::Nil,
        other => panic!("unknown LastCommit flag {other:?}"),
    }
}

/// The client's decision on one block of an ordinary chain: the `missBitmap` it derives
/// ([`BlockCase::derived_bitmap`]) from the vector's parent signers, their LastCommit flags and
/// the parent's post-state (the block's own post-state also held by the EL), and whether a
/// block whose header carries the vector's `missBitmap`, or its whole `extraData`, then passes
/// [`validate_block`]. A first block of the generation sits on the origin, with no LastCommit.
/// A rejection must come from the `missBitmap` comparison or, for a whole `extraData`, from its
/// layout.
async fn miss_bitmap_client(input: &Value) -> Decision {
    let mut case = BlockCase::ordinary(1_700_000_000);
    case.parent_signers = members(&input["parentSigners"]);
    if input["firstBlock"] == true {
        if !case.parent_signers.is_empty() {
            return Err("the origin has no signers".into());
        }
        (case.parent_height, case.height) = (0, 1);
    }
    case.signers = match input.get("signers") {
        Some(signers) => members(signers),
        None => case.parent_signers.clone(),
    };
    case.proposer = case.signers.first().ok_or("no set signs the block")?.0;
    let last_commit = input["lastCommit"].as_object().expect("lastCommit");
    let listed: Vec<ConsensusKey> = last_commit.keys().map(|name| named_key(name)).collect();
    if listed != case.parent_signers.iter().map(|(key, _)| *key).collect::<Vec<_>>() {
        return Err("the LastCommit does not list exactly the parent signers".into());
    }
    case.flags = last_commit
        .iter()
        .map(|(name, flag)| (named_key(name), block_id_flag(flag)))
        .filter(|(_, flag)| *flag != BlockIdFlag::Commit)
        .collect();
    case.parent_post_state = post_state(&input["parentPostState"]);
    case.block_post_state = input.get("blockPostState").map(post_state).unwrap_or_default();
    match (input.get("missBitmap"), input.get("extraData")) {
        (Some(bitmap), None) => case.miss_bitmap = u128_of(bitmap),
        (None, Some(raw)) => {
            let raw = hex::decode(raw.as_str().expect("extraData hex")).expect("extraData hex");
            case.raw_extra_data = Some(raw.into());
        }
        _ => return Err("the header needs exactly one of missBitmap and extraData".into()),
    }
    let derived = case.derived_bitmap().await?;
    let raw = case.raw_extra_data.is_some();
    let valid = match case.validate(derived) {
        Ok(_) => true,
        Err(Rejection::Rule(RuleViolation::MissBitmap { .. })) => false,
        Err(Rejection::Rule(RuleViolation::ExtraDataLength { .. })) if raw => false,
        Err(Rejection::Rule(RuleViolation::HeaderField { field, .. }))
            if raw && field == "extra_data" =>
        {
            false
        }
        Err(other) => return Err(unexpected(&other)),
    };
    Ok(json!({"missBitmap": format!("{derived:#x}"), "valid": valid}))
}

#[tokio::test]
async fn miss_bitmap_vectors() {
    run_family("miss_bitmap", all_keys, async |v| miss_bitmap_client(&v["input"]).await).await;
}

// ---------------------------------------------------------------------------------------------
// candidate: the set that signs H + 2, decided at H from H's candidate snapshot and anchor.
// ---------------------------------------------------------------------------------------------

/// The staking contract's words of a vector's candidate snapshot: `snapshotHeight`,
/// `snapshotTotalStake` and the listed seat records, every other record empty. A record lists
/// `seats`, a span of seats each holding the key named `C` and its seat number; or one `seat`
/// with its two `words`; or one `seat` holding the named `key`, optionally with another
/// `prefix` byte and with `orPacked` bits set in its second word. Each record but a raw one has
/// a `power`.
fn snapshot_state(snapshot: &Value) -> BTreeMap<B256, U256> {
    let mut records = [[U256::ZERO; 2]; RECORD_COUNT];
    for record in snapshot["records"].as_array().expect("records") {
        if let Some(seats) = record["seats"].as_str() {
            for seat in span(seats) {
                records[seat as usize] =
                    record_words(named_key(&format!("C{seat}")), u64_of(&record["power"]));
            }
            continue;
        }
        let seat = u64_of(&record["seat"]) as usize;
        records[seat] = match record.get("words") {
            Some(words) => [u256_of(&words[0]), u256_of(&words[1])],
            None => {
                let key = named_key(record["key"].as_str().expect("a key name"));
                let [x, mut packed] = record_words(key, u64_of(&record["power"]));
                if let Some(prefix) = record.get("prefix") {
                    packed = (packed & !U256::from(0xff)) | U256::from(u64_of(prefix));
                }
                if let Some(bits) = record.get("orPacked") {
                    packed |= u256_of(bits);
                }
                [x, packed]
            }
        };
    }
    let header = [u256_of(&snapshot["snapshotHeight"]), u256_of(&snapshot["totalStake"])];
    let values = header.into_iter().chain(records.into_iter().flatten());
    snapshot_slots().into_iter().zip(values).collect()
}

/// The anchor `base` proving a vector's `minTotalStake` and `fallbackKeys`.
fn anchor_proving(value: &Value, base: AnchorFacts) -> AnchorFacts {
    AnchorFacts {
        min_total_stake: u256_of(&value["minTotalStake"]),
        fallback_keys: fallback_list(value["fallbackKeys"].as_str().expect("fallbackKeys")),
        ..base
    }
}

/// The client's decision on the sets that sign H + 2, H + 3, …: one block per snapshot from
/// height H on, each moving from the parent's anchor to H's (or inheriting the parent's), with
/// that snapshot in its own post-state. Each block is judged with [`validate_block`], whose
/// anchor gives the minimum total stake and the fallback keys hash; [`fetch_fallback_keys`]
/// obtains the list from an L1 that answers `getFallbackKeys()` at each anchor hash with that
/// anchor's list (H's with `servedList` when the vector gives one) and holds both anchors' lists
/// in its logs; [`staking_words`] reads the snapshot at the block's hash; [`committee::decide`]
/// picks the set.
async fn candidate_client(input: &Value) -> Decision {
    let height = u64_of(&input["height"]);
    let ordinary = BlockCase::ordinary(1_700_000_000);
    let anchor = anchor_proving(&input["anchor"], ordinary.anchor.clone());
    let parent_anchor = match input.get("parentAnchor") {
        _ if input["inheritsAnchor"] == true => anchor.clone(),
        Some(parent) => anchor_proving(parent, ordinary.parent_anchor.clone()),
        None => AnchorFacts {
            fallback_keys: anchor.fallback_keys.clone(),
            min_total_stake: anchor.min_total_stake,
            ..ordinary.parent_anchor.clone()
        },
    };
    let mut served = BTreeMap::new();
    for facts in [&parent_anchor, &anchor] {
        served.insert(facts.anchor_state().hash, facts.fallback_keys.clone());
    }
    if let Some(list) = input.get("servedList") {
        let list = fallback_list(list.as_str().expect("servedList"));
        served.insert(anchor.anchor_state().hash, list);
    }
    let l1 = ListL1 {
        served,
        logged: vec![parent_anchor.fallback_keys.clone(), anchor.fallback_keys.clone()],
    };

    let mut signs = Vec::new();
    for (offset, snapshot) in (0..).zip(input["snapshots"].as_array().expect("snapshots")) {
        let h = height + offset;
        let case = BlockCase {
            height: h,
            parent_height: h - 1,
            parent_anchor: parent_anchor.clone(),
            anchor: anchor.clone(),
            block_post_state: snapshot_state(snapshot),
            ..BlockCase::ordinary(1_700_000_000)
        };
        let validated = case.judge().await?.map_err(|rejection| unexpected(&rejection))?;
        let facts = &validated.anchor;
        let (min_total_stake, list) = (facts.inbox.min_total_stake, facts.inbox.fallback_keys_hash);
        let keys = fetch_fallback_keys(&l1, params().inbox, list, facts.hash, facts.number, 0)
            .await
            .map_err(|error| format!("no fallback key list: {error}"))?;
        let hash = validated.block.header.hash_slow();
        let words = staking_words(&case.engine(None), params().staking, hash, h, min_total_stake)
            .await
            .map_err(|error| format!("the snapshot cannot be read: {error}"))?;
        let set = committee::decide(h, &words, min_total_stake, &keys);
        signs.push(json!({"source": set.source, "members": render(&set.members)}));
    }
    Ok(json!({"signs": signs}))
}

#[tokio::test]
async fn candidate_vectors() {
    run_family("candidate", all_keys, async |v| candidate_client(&v["input"]).await).await;
}

// ---------------------------------------------------------------------------------------------
// Appendix A encodings the spec fixes by value.
// ---------------------------------------------------------------------------------------------

/// ENC-A-29b.g: appHash(6) of the block hash `0x11…11` and 29a.l's valStateHash(6), a 96-byte
/// preimage.
#[test]
fn app_hash_matches_29b_g() {
    let block_hash = B256::repeat_byte(0x11);
    let val_state_hash =
        alloy_primitives::b256!("368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b");
    assert_eq!(
        abci::valstate::app_hash(block_hash, val_state_hash),
        alloy_primitives::b256!("381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451")
    );
}
