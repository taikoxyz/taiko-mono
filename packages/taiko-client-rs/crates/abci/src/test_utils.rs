//! Shared test builders (compiled only under `cfg(test)`).
//!
//! [`TestState`] is an in-memory L1 state: it builds real storage tries and a real account trie
//! with `alloy_trie::HashBuilder`, so the [`AccountWitness`]es it hands out carry genuine
//! EIP-1186 proofs (inclusion proofs for non-zero slots, exclusion proofs for zero/absent ones).
//!
//! [`InboxStorage`] packs Inbox facts and forced inclusion queue entries into storage words
//! exactly as [`crate::l1::layout`] lays them out, and [`anchor_witness`] /
//! [`genesis_inbox_witness`] turn it into witnesses with real proofs.
//!
//! [`MockL1`] and [`MockEngine`] are in-memory
//! [`L1Source`](crate::l1::source::L1Source) and [`Engine`](crate::engine::Engine)
//! implementations with scripted answers and call
//! logs.
//! [`Fixture`] combines all of them into a complete genesis for app tests.

use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
};

use alloy_consensus::{Header, SignableTransaction, TxEip1559, TxEnvelope, TxLegacy};
use alloy_primitives::{Address, B256, Bytes, Signature, TxKind, U256, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};

use crate::{
    config::ChainParamsExt,
    envelope::AnchorWitness,
    forced::ForcedEntry,
    l1::{header::RawL1Header, layout::inbox},
    types::{AccountWitness, GenesisRecord, StorageProof},
};

/// A complete, consistent genesis (L1 state, witness, EL chain, `InitChain` request).
mod fixture;
/// In-memory L1 and execution-engine mocks.
mod mocks;
/// Manual regeneration of CLI recovery proofs from their complete, unchanged fixture states.
mod recovery_fixtures;
/// The Etna vectors shared with the contracts (`testdata/etna_vectors`).
pub(crate) mod vectors;

pub(crate) use fixture::{
    Fixture, GenesisSpec, abci_consensus_params, committed_block, init_chain_request,
    recovery_fallback_keys, recovery_fixture, recovery_fixture_at, test_options, validator_updates,
};
pub(crate) use mocks::{EngineCall, L1Call, MockEngine, MockL1, simple_block};

/// One account of a [`TestState`]: `(address, nonce, balance, code_hash, storage)`, where
/// `storage` lists `(slot, value)` pairs (zero values are the same as absent slots; on duplicate
/// slots the last pair wins).
pub(crate) type AccountSpec = (Address, u64, U256, B256, Vec<(B256, U256)>);

/// One account with its non-zero storage and the derived storage root.
#[derive(Clone, Debug)]
struct TestAccount {
    nonce: u64,
    balance: U256,
    code_hash: B256,
    storage: BTreeMap<B256, U256>,
    storage_root: B256,
}

impl TestAccount {
    fn trie_account(&self) -> TrieAccount {
        TrieAccount {
            nonce: self.nonce,
            balance: self.balance,
            storage_root: self.storage_root,
            code_hash: self.code_hash,
        }
    }

    /// Storage-trie leaves: `keccak256(slot) -> rlp(value)` for every non-zero slot.
    fn storage_leaves(&self) -> BTreeMap<B256, Vec<u8>> {
        self.storage
            .iter()
            .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
            .collect()
    }
}

/// An in-memory L1 state with real MPT roots and proofs.
#[derive(Clone, Debug)]
pub(crate) struct TestState {
    accounts: BTreeMap<Address, TestAccount>,
    state_root: B256,
}

impl TestState {
    /// Builds the storage tries and the account trie for `accounts`.
    pub(crate) fn new(accounts: Vec<AccountSpec>) -> Self {
        let accounts: BTreeMap<Address, TestAccount> = accounts
            .into_iter()
            .map(|(address, nonce, balance, code_hash, slots)| {
                let mut storage = BTreeMap::new();
                for (slot, value) in slots {
                    if value.is_zero() {
                        storage.remove(&slot);
                    } else {
                        storage.insert(slot, value);
                    }
                }
                let mut account =
                    TestAccount { nonce, balance, code_hash, storage, storage_root: B256::ZERO };
                account.storage_root = build_trie(&account.storage_leaves(), vec![]).0;
                (address, account)
            })
            .collect();
        let state_root = build_trie(&account_leaves(&accounts), vec![]).0;
        Self { accounts, state_root }
    }

    /// The state root over every account.
    pub(crate) fn state_root(&self) -> B256 {
        self.state_root
    }

    /// This state with `edits` applied to the storage of `address` (a zero value clears the
    /// slot), its storage root and the state root recomputed.
    pub(crate) fn with_storage(&self, address: Address, edits: &[(B256, U256)]) -> Self {
        let mut accounts = self.accounts.clone();
        let account = accounts.get_mut(&address).expect("address is part of the test state");
        for (slot, value) in edits {
            if value.is_zero() {
                account.storage.remove(slot);
            } else {
                account.storage.insert(*slot, *value);
            }
        }
        account.storage_root = build_trie(&account.storage_leaves(), vec![]).0;
        let state_root = build_trie(&account_leaves(&accounts), vec![]).0;
        Self { accounts, state_root }
    }

    /// Whether `address` is part of the state.
    pub(crate) fn has_account(&self, address: Address) -> bool {
        self.accounts.contains_key(&address)
    }

    /// The storage word of `address` at `slot` (zero for an absent slot or account).
    pub(crate) fn storage(&self, address: Address, slot: B256) -> U256 {
        self.accounts
            .get(&address)
            .and_then(|account| account.storage.get(&slot).copied())
            .unwrap_or_default()
    }

    /// An EIP-1186 witness for `address` and `slots` (in the given order), as `eth_getProof`
    /// would return it. Panics if `address` is not part of the state.
    pub(crate) fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
        let account = self.accounts.get(&address).expect("address is part of the test state");

        let account_key = keccak256(address);
        let (state_root, account_nodes) =
            build_trie(&account_leaves(&self.accounts), vec![Nibbles::unpack(account_key)]);
        assert_eq!(state_root, self.state_root, "account trie rebuilds deterministically");

        let storage_keys = slots.iter().map(|slot| Nibbles::unpack(keccak256(slot))).collect();
        let (storage_root, storage_nodes) = build_trie(&account.storage_leaves(), storage_keys);
        assert_eq!(storage_root, account.storage_root, "storage trie rebuilds deterministically");

        AccountWitness {
            address,
            nonce: account.nonce,
            balance: account.balance,
            storage_root: account.storage_root,
            code_hash: account.code_hash,
            account_proof: proof_for(&account_nodes, account_key),
            storage: slots
                .iter()
                .map(|slot| StorageProof {
                    slot: *slot,
                    value: account.storage.get(slot).copied().unwrap_or_default(),
                    proof: proof_for(&storage_nodes, keccak256(slot)),
                })
                .collect(),
        }
    }
}

/// Account-trie leaves: `keccak256(address) -> rlp(TrieAccount)`.
fn account_leaves(accounts: &BTreeMap<Address, TestAccount>) -> BTreeMap<B256, Vec<u8>> {
    accounts
        .iter()
        .map(|(address, account)| (keccak256(address), alloy_rlp::encode(account.trie_account())))
        .collect()
}

/// Builds a trie over `leaves` (sorted by hashed key) and retains the proof nodes on the paths to
/// `targets`.
fn build_trie(leaves: &BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}

/// The proof nodes on the path to `key`, root first.
fn proof_for(nodes: &ProofNodes, key: B256) -> Vec<Bytes> {
    nodes.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
}

/// The Inbox's storage as [`crate::l1::layout::inbox`] lays it out, before packing into words.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct InboxStorage {
    /// Slot 258, `uint8` at bits 0–7.
    pub(crate) status: u8,
    /// Slot 268, `uint64` at bits 0–63.
    pub(crate) recovery_generation: u64,
    /// Slot 270, `uint64` at bits 0–63.
    pub(crate) last_checkpoint_height: u64,
    /// Slot 271, `bytes32`.
    pub(crate) last_checkpoint_hash: B256,
    /// Authenticated Comet block hash in the checkpoint landing record.
    pub(crate) last_checkpoint_comet_hash: B256,
    /// Slot 281, `uint48` at bits 0–47.
    pub(crate) forced_inclusion_head: u64,
    /// Slot 281, `uint48` at bits 48–95.
    pub(crate) forced_inclusion_tail: u64,
    /// Entries of the forced inclusion `queue` mapping (slot 280), each written at its own
    /// `index` with its transaction hash and packed metadata; independent of the tail.
    pub(crate) forced_inclusion_queue: Vec<ForcedEntry>,
    /// The configuration hash (slot 269), slots 272–274 and the forced inclusion delay and
    /// maximum anchor age in slot 282 (`uint48`s at bits 0–47 and 48–95), with generation 0's
    /// origin record (slot 290), whose fourth word is `origin_fallback_keys_hash`; `None` leaves
    /// them empty (not yet initialized).
    pub(crate) genesis: Option<GenesisRecord>,
    /// The fourth word of generation 0's origin record, written with `genesis`: the
    /// `fallbackKeysHash` slot 278 held at the start write.
    pub(crate) origin_fallback_keys_hash: B256,
    /// Slot 278, `fallbackKeysHash`, a whole `bytes32`.
    pub(crate) fallback_keys_hash: B256,
    /// Slot 279, `minTotalStake`, a whole `uint256`.
    pub(crate) min_total_stake: U256,
}

impl InboxStorage {
    /// An Inbox right after genesis: `ETNA_ACTIVE`, generation 0, last checkpoint = the
    /// Etna start block (S, the start hash), an empty forced inclusion queue, slot 278 and the
    /// origin record's fourth word both `fallback_keys_hash`, and a minimum total stake of
    /// 2^256 − 1, which makes no candidate usable.
    pub(crate) fn genesis(genesis: GenesisRecord, fallback_keys_hash: B256) -> Self {
        Self {
            status: inbox::ETNA_ACTIVE,
            recovery_generation: 0,
            last_checkpoint_height: genesis.genesis_height,
            last_checkpoint_hash: genesis.genesis_hash,
            last_checkpoint_comet_hash: B256::ZERO,
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
            forced_inclusion_queue: vec![],
            genesis: Some(genesis),
            origin_fallback_keys_hash: fallback_keys_hash,
            fallback_keys_hash,
            min_total_stake: U256::MAX,
        }
    }

    /// The `(slot, word)` pairs of this storage, packed low-order-first like Solidity. Zero words
    /// are included (the trie drops them, so they read back through exclusion proofs).
    pub(crate) fn slots(&self) -> Vec<(B256, U256)> {
        let mut slots = vec![
            (inbox::slot(inbox::STATUS), U256::from(self.status)),
            (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(self.recovery_generation)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(self.last_checkpoint_height)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HASH), self.last_checkpoint_hash.into()),
            (
                inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL),
                U256::from(self.forced_inclusion_head) |
                    (U256::from(self.forced_inclusion_tail) << 48),
            ),
            (inbox::slot(inbox::FALLBACK_KEYS_HASH), self.fallback_keys_hash.into()),
            (inbox::slot(inbox::MIN_TOTAL_STAKE), self.min_total_stake),
        ];
        let landing = inbox::landing_record_slots(self.last_checkpoint_height);
        slots.extend([
            (
                landing[0],
                U256::from(self.last_checkpoint_height.saturating_sub(6)) |
                    (U256::from(self.recovery_generation) << 48) |
                    (U256::from(self.forced_inclusion_head) << 96),
            ),
            (landing[1], self.last_checkpoint_hash.into()),
            (landing[2], self.last_checkpoint_comet_hash.into()),
        ]);
        if let Some(a) = &self.genesis {
            let origins = inbox::origin_slots(0);
            slots.extend([
                (origins[0], U256::from(a.genesis_height)),
                (origins[1], U256::from(a.l1_0)),
                (origins[2], U256::from(1_760_000_000u64 + 12 * a.l1_0)),
                (origins[3], self.origin_fallback_keys_hash.into()),
            ]);

            let packed = U256::from(a.genesis_height) | (U256::from(a.l1_0) << 48);
            slots.extend([
                (inbox::slot(inbox::GENESIS_PACKED), packed),
                (inbox::slot(inbox::START_BLOCK_HASH), a.genesis_hash.into()),
                (inbox::slot(inbox::START_STATE_ROOT), a.genesis_state_root.into()),
                (inbox::slot(inbox::CONFIG_HASH), a.config_hash.into()),
                (
                    inbox::slot(inbox::FORCED_INCLUSION_CONFIG),
                    U256::from(a.forced_inclusion_delay) | (U256::from(a.max_anchor_age) << 48),
                ),
            ]);
        }
        // Each queue entry: its `txHash` word and the `timestamp | l1Block << 48` metadata word.
        for entry in &self.forced_inclusion_queue {
            let [hash, metadata] = inbox::forced_inclusion_entry_slots(entry.index);
            slots.extend([
                (hash, entry.tx_hash.into()),
                (metadata, U256::from(entry.timestamp) | (U256::from(entry.l1_block) << 48)),
            ]);
        }
        slots
    }
}

/// The 29-byte `extraData` of an Etna block of `generation` anchored at L1 block `anchor`, with
/// no missing signers.
pub(crate) fn extra_data(generation: u64, anchor: u64) -> Bytes {
    crate::rules::encode_extra_data(&crate::rules::ExtraData {
        basefee_sharing_pctg: crate::rules::BASEFEE_SHARING_PCTG,
        generation,
        anchor,
        miss_bitmap: 0,
    })
    .expect("fits uint48")
}

/// Two distinct signed transactions (a legacy and an EIP-1559 one) with a fixed, non-recoverable
/// test signature: the manifest decoder does not recover senders.
pub(crate) fn sample_transactions() -> Vec<TxEnvelope> {
    let signature = Signature::new(U256::from(1), U256::from(1), false);
    let legacy = TxLegacy {
        chain_id: Some(167_001),
        nonce: 3,
        gas_price: 1_000_000_000,
        gas_limit: 21_000,
        to: TxKind::Call(Address::repeat_byte(0x11)),
        value: U256::from(5),
        input: Bytes::new(),
    };
    let dynamic = TxEip1559 {
        chain_id: 167_001,
        nonce: 4,
        gas_limit: 50_000,
        max_fee_per_gas: 2_000_000_000,
        max_priority_fee_per_gas: 1_000_000,
        to: TxKind::Call(Address::repeat_byte(0x22)),
        value: U256::ZERO,
        access_list: Default::default(),
        input: Bytes::from_static(&[0xde, 0xad, 0xbe, 0xef]),
    };
    vec![
        TxEnvelope::Legacy(legacy.into_signed(signature)),
        TxEnvelope::Eip1559(dynamic.into_signed(signature)),
    ]
}

/// The secp256k1 key that signs test transactions whose sender is recovered (the same key as the
/// Etna conformance vectors' forced transactions).
pub(crate) fn tx_signer() -> alloy::signers::local::PrivateKeySigner {
    alloy::signers::local::PrivateKeySigner::from_bytes(&B256::repeat_byte(0x42))
        .expect("signing key")
}

/// A sample genesis record with the devnet configuration hash and every other field distinct
/// and non-zero but the start height (forced inclusion delay 1 h, maximum anchor age 2 h).
pub(crate) fn sample_genesis_record() -> GenesisRecord {
    GenesisRecord {
        config_hash: crate::config::ChainParams::builtin(
            protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID,
        )
        .unwrap()
        .config_hash(),
        genesis_height: 0,
        l1_0: 64,
        genesis_hash: B256::repeat_byte(0x48),
        genesis_state_root: B256::repeat_byte(0x53),
        forced_inclusion_delay: 3_600,
        max_anchor_age: 7_200,
    }
}

/// An L1 header template with distinct non-default fields; its `state_root` is overwritten by
/// the witness builders.
pub(crate) fn l1_header(number: u64, timestamp: u64) -> Header {
    Header {
        parent_hash: B256::repeat_byte(0x01),
        beneficiary: Address::repeat_byte(0x02),
        number,
        timestamp,
        gas_limit: 36_000_000,
        gas_used: 21_000,
        base_fee_per_gas: Some(7),
        ..Header::default()
    }
}

/// `header`'s RLP with two fields of an L1 fork newer than alloy's header appended (a 32-byte
/// hash and a slot number), as a node of such a fork serves it.
pub(crate) fn raw_with_future_fields(header: &Header) -> Bytes {
    let encoded = alloy_rlp::encode(header);
    let mut payload =
        alloy_rlp::Header::decode_bytes(&mut encoded.as_slice(), true).expect("a list").to_vec();
    payload.extend(
        [vec![0xa0], vec![0xba; 32], alloy_rlp::encode(0x0102_0304u64), vec![0xc0]].concat(),
    );
    let mut raw = Vec::new();
    alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut raw);
    raw.extend(payload);
    raw.into()
}

/// `raw` with the alloy header it encodes changed by `edit` (re-encoded, so `raw` must hold no
/// fields alloy's header does not know).
pub(crate) fn edit_l1_header(raw: &RawL1Header, edit: impl FnOnce(&mut Header)) -> RawL1Header {
    let mut header: Header =
        alloy_rlp::Decodable::decode(&mut raw.raw().as_ref()).expect("an alloy header");
    edit(&mut header);
    RawL1Header::from(&header)
}

/// The [`AccountSpec`] of an Inbox at `address` holding `storage`.
pub(crate) fn inbox_account(address: Address, storage: &InboxStorage) -> AccountSpec {
    (address, 1, U256::ZERO, keccak256(b"etna inbox code"), storage.slots())
}

/// Filler accounts so account proofs walk through branch nodes.
pub(crate) fn filler_accounts() -> Vec<AccountSpec> {
    (1..=16u8)
        .map(|i| {
            (
                Address::repeat_byte(0xf0 ^ i),
                u64::from(i),
                U256::from(i),
                keccak256([i]),
                vec![(B256::from(U256::from(i)), U256::from(i))],
            )
        })
        .collect()
}

/// An anchor witness for the Inbox at `inbox_address` in `state`: `header` with its `state_root`
/// set to `state`'s root, and proofs of `layout::inbox::anchor_slots()`.
pub(crate) fn anchor_witness_in(
    state: &TestState,
    inbox_address: Address,
    mut header: Header,
) -> AnchorWitness {
    header.state_root = state.state_root();
    AnchorWitness {
        l1_header: RawL1Header::from(&header),
        inbox: state.witness(inbox_address, &inbox::anchor_slots()),
    }
}

/// Builds an L1 state holding the Inbox (`storage`) plus filler accounts, and returns an anchor
/// witness against it (see [`anchor_witness_in`]) together with the state.
pub(crate) fn anchor_witness(
    inbox_address: Address,
    storage: &InboxStorage,
    header: Header,
) -> (AnchorWitness, TestState) {
    let state = inbox_state(inbox_address, storage);
    (anchor_witness_in(&state, inbox_address, header), state)
}

/// Builds an L1 state holding the Inbox (`storage`) plus filler accounts, and returns the
/// genesis Inbox witness (proofs of `layout::inbox::genesis_slots()`) together with the state
/// (whose root the witness verifies against).
pub(crate) fn genesis_inbox_witness(
    inbox_address: Address,
    storage: &InboxStorage,
) -> (AccountWitness, TestState) {
    let state = inbox_state(inbox_address, storage);
    (state.witness(inbox_address, &inbox::genesis_slots()), state)
}

/// An L1 state holding the Inbox (`storage`) at `inbox_address` plus the filler accounts.
fn inbox_state(inbox_address: Address, storage: &InboxStorage) -> TestState {
    let mut accounts = filler_accounts();
    accounts.push(inbox_account(inbox_address, storage));
    TestState::new(accounts)
}

/// Captures every log line emitted on the current thread while alive (a `#[tokio::test]` runs its
/// futures on the test thread), formatted without colours: `<time> <LEVEL> <target>: ...`.
pub(crate) struct LogCapture {
    /// The formatted lines so far.
    lines: Arc<Mutex<Vec<u8>>>,
    /// Keeps the capturing subscriber the thread's default.
    _guard: tracing::subscriber::DefaultGuard,
}

impl LogCapture {
    /// Starts capturing at every level.
    pub(crate) fn start() -> Self {
        let lines = Arc::new(Mutex::new(Vec::new()));
        let sink = Arc::clone(&lines);
        let subscriber = tracing_subscriber::fmt()
            .with_ansi(false)
            .with_max_level(tracing::Level::TRACE)
            .with_writer(move || LogSink(Arc::clone(&sink)))
            .finish();
        Self { lines, _guard: tracing::subscriber::set_default(subscriber) }
    }

    /// The lines captured so far.
    pub(crate) fn text(&self) -> String {
        String::from_utf8_lossy(&self.lines.lock().expect("log capture lock")).into_owned()
    }

    /// The captured lines logged at `level` (e.g. `"ERROR"`).
    pub(crate) fn at(&self, level: &str) -> Vec<String> {
        let marker = format!(" {level} ");
        self.text().lines().filter(|line| line.contains(&marker)).map(str::to_owned).collect()
    }
}

/// The writer [`LogCapture`]'s subscriber formats into.
struct LogSink(Arc<Mutex<Vec<u8>>>);

impl std::io::Write for LogSink {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.0.lock().expect("log capture lock").extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

/// Set in the child process [`in_own_process`] re-runs a test in.
const OWN_PROCESS_ENV: &str = "ABCI_TEST_OWN_PROCESS";

/// Whether the calling test runs alone in its process, so process-wide state (the Prometheus
/// collectors) sees no other test: true under nextest (one process per test) and in the child
/// this spawns. Otherwise re-runs the test `test` of `module` (pass `module_path!()`) alone in a
/// child process, asserts that it passed, and returns false: the caller then returns at once.
pub(crate) fn in_own_process(module: &str, test: &str) -> bool {
    let nextest = std::env::var("NEXTEST_EXECUTION_MODE").is_ok_and(|m| m == "process-per-test");
    if nextest || std::env::var_os(OWN_PROCESS_ENV).is_some() {
        return true;
    }
    let path = module.split_once("::").map_or(module, |(_, path)| path);
    let name = format!("{path}::{test}");
    let output = std::process::Command::new(std::env::current_exe().expect("test binary path"))
        .args(["--exact", &name, "--nocapture"])
        .env(OWN_PROCESS_ENV, "1")
        .output()
        .expect("the child test process spawns");
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(
        output.status.success(),
        "{name} failed in its own process\nstdout:\n{stdout}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stderr)
    );
    // libtest exits 0 when the filter matches nothing, so check that the child ran the test.
    assert!(stdout.contains("1 passed"), "the child did not run {name}\nstdout:\n{stdout}");
    false
}

/// Deterministic valid consensus key derived from a nonzero test scalar.
pub(crate) fn test_key(seed: u64) -> crate::key::ConsensusKey {
    let scalar = U256::from(seed.saturating_add(1)).to_be_bytes::<32>();
    let key = k256::SecretKey::from_slice(&scalar).unwrap();
    use k256::elliptic_curve::sec1::ToEncodedPoint;
    crate::key::ConsensusKey::from_slice(key.public_key().to_encoded_point(true).as_bytes())
        .unwrap()
}

/// The fallback key list of the [`test_key`]s of `seeds`, in ascending order.
pub(crate) fn fallback_list(seeds: &[u64]) -> crate::fallback::FallbackKeys {
    let mut keys: Vec<_> = seeds.iter().map(|seed| test_key(*seed)).collect();
    keys.sort();
    crate::fallback::FallbackKeys::new(keys).expect("distinct test keys form a list")
}

/// Makes the Inbox `inbox` of `l1` answer `getFallbackKeys()` with `keys` at every block hash.
pub(crate) fn serve_fallback_keys(
    l1: &MockL1,
    inbox: Address,
    keys: &crate::fallback::FallbackKeys,
) {
    use alloy_sol_types::SolCall;
    l1.state().call_answers.insert(
        (inbox, crate::fallback::getFallbackKeysCall {}.abi_encode().into()),
        keys.abi_encode().into(),
    );
}

/// An [`RpcL1Source`](crate::l1::RpcL1Source) whose L1 node answers one JSON-RPC request with
/// the members of `result` (`result` or `error`); the handle yields the request it received.
pub(crate) async fn json_rpc_server(
    result: serde_json::Value,
) -> (crate::l1::RpcL1Source, tokio::task::JoinHandle<serde_json::Value>) {
    use alloy_provider::ProviderBuilder;
    use serde_json::{Value, json};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap()).parse().unwrap();
    let handle = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut request = Vec::new();
        let body = loop {
            let mut buf = [0u8; 4096];
            let n = socket.read(&mut buf).await.unwrap();
            assert_ne!(n, 0);
            request.extend_from_slice(&buf[..n]);
            if let Some(end) = request.windows(4).position(|w| w == b"\r\n\r\n") {
                let head = String::from_utf8_lossy(&request[..end]).to_lowercase();
                let len = head
                    .lines()
                    .find_map(|l| l.strip_prefix("content-length:"))
                    .unwrap()
                    .trim()
                    .parse::<usize>()
                    .unwrap();
                if request.len() >= end + 4 + len {
                    break serde_json::from_slice::<Value>(&request[end + 4..end + 4 + len])
                        .unwrap();
                }
            }
        };
        let mut response = json!({"jsonrpc":"2.0", "id":body["id"]});
        response.as_object_mut().unwrap().extend(result.as_object().unwrap().clone());
        let response = response.to_string();
        socket.write_all(format!("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}", response.len(), response).as_bytes()).await.unwrap();
        body
    });
    (crate::l1::RpcL1Source::new(ProviderBuilder::default().connect_http(url)), handle)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::l1::layout::{word_u8, word_u48, word_u64};
    use alloy_primitives::{U256, b256};

    fn word(slots: &[(B256, U256)], slot: B256) -> U256 {
        slots.iter().find(|(s, _)| *s == slot).map(|(_, v)| *v).expect("slot is packed")
    }

    /// Pack, then decode with the layout readers: every field comes back.
    #[test]
    fn inbox_storage_packing_decodes_back() {
        let genesis = GenesisRecord {
            config_hash: B256::repeat_byte(0xa5),
            genesis_height: ((1u64 << 48) - 1),
            l1_0: 0x0304_0506_0708,
            genesis_hash: B256::repeat_byte(0xa1),
            genesis_state_root: B256::repeat_byte(0xa2),
            forced_inclusion_delay: ((1u64 << 48) - 1) - 3,
            max_anchor_age: ((1u64 << 48) - 1) - 4,
        };
        let storage = InboxStorage {
            status: u8::MAX,
            recovery_generation: ((1u64 << 48) - 1),
            last_checkpoint_height: ((1u64 << 48) - 1) - 7,
            last_checkpoint_hash: B256::repeat_byte(0xa3),
            last_checkpoint_comet_hash: B256::ZERO,
            forced_inclusion_head: (1 << 48) - 2,
            forced_inclusion_tail: (1 << 48) - 1,
            forced_inclusion_queue: vec![],
            genesis: Some(genesis.clone()),
            origin_fallback_keys_hash: B256::repeat_byte(0xa4),
            fallback_keys_hash: B256::repeat_byte(0xa6),
            min_total_stake: U256::MAX - U256::from(1),
        };
        let slots = storage.slots();
        let at = |n| word(&slots, inbox::slot(n));

        assert_eq!(word_u8(at(inbox::STATUS), 0), u8::MAX);
        assert_eq!(at(inbox::STATUS) >> 8, U256::ZERO);
        assert_eq!(word_u64(at(inbox::RECOVERY_GENERATION), 0), ((1u64 << 48) - 1));
        assert_eq!(word_u64(at(inbox::LAST_CHECKPOINT_HEIGHT), 0), ((1u64 << 48) - 1) - 7);
        assert_eq!(B256::from(at(inbox::LAST_CHECKPOINT_HASH)), B256::repeat_byte(0xa3));
        let head_tail = at(inbox::FORCED_INCLUSION_HEAD_TAIL);
        assert_eq!(word_u48(head_tail, 0), (1 << 48) - 2);
        assert_eq!(word_u48(head_tail, 48), (1 << 48) - 1);
        assert_eq!(head_tail >> 96, U256::ZERO);
        assert_eq!(B256::from(at(inbox::FALLBACK_KEYS_HASH)), B256::repeat_byte(0xa6));
        assert_eq!(at(inbox::MIN_TOTAL_STAKE), U256::MAX - U256::from(1));

        let packed = at(inbox::GENESIS_PACKED);
        assert_eq!(word_u48(packed, 0), genesis.genesis_height);
        assert_eq!(word_u48(packed, 48), genesis.l1_0);
        assert_eq!(packed >> 96, U256::ZERO);
        assert_eq!(B256::from(at(inbox::START_BLOCK_HASH)), genesis.genesis_hash);
        assert_eq!(B256::from(at(inbox::START_STATE_ROOT)), genesis.genesis_state_root);
        assert_eq!(B256::from(at(inbox::CONFIG_HASH)), genesis.config_hash);
        let forced_config = at(inbox::FORCED_INCLUSION_CONFIG);
        assert_eq!(word_u48(forced_config, 0), genesis.forced_inclusion_delay);
        assert_eq!(word_u48(forced_config, 48), genesis.max_anchor_age);
        assert_eq!(forced_config >> 96, U256::ZERO);

        let origin = inbox::origin_slots(0).map(|slot| word(&slots, slot));
        assert_eq!(
            inbox::decode_origin_record(origin).map(|record| record.fallback_keys_hash),
            Some(B256::repeat_byte(0xa4))
        );
        assert_eq!(slots.len(), 7 + 3 + 4 + 5);
    }

    /// Hand-written storage words (as a Solidity contract would write them) equal the packing.
    #[test]
    fn inbox_storage_packing_matches_hand_written_words() {
        let genesis = GenesisRecord {
            config_hash: B256::repeat_byte(0x44),
            genesis_height: 0x11,
            l1_0: 0x2222,
            genesis_hash: B256::repeat_byte(0x55),
            genesis_state_root: B256::repeat_byte(0x66),
            forced_inclusion_delay: 0x0e10,
            max_anchor_age: 0x1c20,
        };
        let storage = InboxStorage {
            status: 3,
            recovery_generation: 0x0102,
            last_checkpoint_height: 0x0a0b_0c0d,
            last_checkpoint_hash: B256::repeat_byte(0x77),
            last_checkpoint_comet_hash: B256::ZERO,
            forced_inclusion_head: 0x03,
            forced_inclusion_tail: 0x09,
            forced_inclusion_queue: vec![],
            ..InboxStorage::genesis(genesis, B256::repeat_byte(0x99))
        };
        let slots = storage.slots();
        let at = |n| B256::from(word(&slots, inbox::slot(n)));

        assert_eq!(
            at(inbox::STATUS),
            b256!("0000000000000000000000000000000000000000000000000000000000000003")
        );
        assert_eq!(
            at(inbox::RECOVERY_GENERATION),
            b256!("0000000000000000000000000000000000000000000000000000000000000102")
        );
        assert_eq!(
            at(inbox::LAST_CHECKPOINT_HEIGHT),
            b256!("000000000000000000000000000000000000000000000000000000000a0b0c0d")
        );
        assert_eq!(
            at(inbox::GENESIS_PACKED),
            b256!("0000000000000000000000000000000000000000000000002222000000000011")
        );
        assert_eq!(
            at(inbox::FORCED_INCLUSION_HEAD_TAIL),
            b256!("0000000000000000000000000000000000000000000000000009000000000003")
        );
        assert_eq!(
            at(inbox::FORCED_INCLUSION_CONFIG),
            b256!("0000000000000000000000000000000000000000000000001c20000000000e10")
        );
        assert_eq!(at(inbox::FALLBACK_KEYS_HASH), B256::repeat_byte(0x99));
        assert_eq!(at(inbox::MIN_TOTAL_STAKE), B256::repeat_byte(0xff));
        assert_eq!(slots.len(), 7 + 3 + 4 + 5);
    }

    /// A queue entry packs into its two slots like Solidity writes `queue[i]`.
    #[test]
    fn inbox_storage_packs_forced_inclusion_entries() {
        let entry = ForcedEntry {
            index: 7,
            tx_hash: B256::repeat_byte(0x0b),
            timestamp: 0xabcdef,
            l1_block: 456,
        };
        let storage = InboxStorage {
            forced_inclusion_queue: vec![entry],
            ..InboxStorage::genesis(sample_genesis_record(), B256::repeat_byte(9))
        };
        let slots = storage.slots();
        let [hash, metadata] = inbox::forced_inclusion_entry_slots(7);
        assert!(slots.contains(&(hash, entry.tx_hash.into())));
        assert!(slots.contains(&(
            metadata,
            U256::from(entry.timestamp) | (U256::from(entry.l1_block) << 48)
        )));
    }

    #[test]
    fn inbox_storage_without_genesis_leaves_genesis_slots_out() {
        let storage = InboxStorage {
            genesis: None,
            ..InboxStorage::genesis(sample_genesis_record(), B256::ZERO)
        };
        let slots: Vec<B256> = storage.slots().into_iter().map(|(s, _)| s).collect();
        assert_eq!(
            slots,
            [258u64, 268, 270, 271, 281, 278, 279]
                .map(inbox::slot)
                .into_iter()
                .chain(inbox::landing_record_slots(0))
                .collect::<Vec<_>>()
        );
    }

    #[test]
    fn genesis_storage_points_the_last_checkpoint_at_the_genesis_anchor() {
        let genesis = sample_genesis_record();
        let storage = InboxStorage::genesis(genesis.clone(), B256::repeat_byte(0x99));
        assert_eq!(storage.status, inbox::ETNA_ACTIVE);
        assert_eq!(storage.recovery_generation, 0);
        assert_eq!(storage.last_checkpoint_height, genesis.genesis_height);
        assert_eq!(storage.last_checkpoint_hash, genesis.genesis_hash);
        assert_eq!((storage.forced_inclusion_head, storage.forced_inclusion_tail), (0, 0));
        assert_eq!(storage.origin_fallback_keys_hash, B256::repeat_byte(0x99));
        assert_eq!(storage.fallback_keys_hash, B256::repeat_byte(0x99));
        assert_eq!(storage.min_total_stake, U256::MAX);
    }

    /// The planter writes the forced inclusion queue words at the slots, offsets and widths of
    /// the shared layout vectors (`testdata/etna_vectors`), which the contracts check against
    /// their own storage. The node's queue reader is tested against this planter, so it decodes
    /// the contracts' layout.
    #[test]
    fn planters_write_the_shared_layout() {
        let queued = ForcedEntry {
            index: 7,
            tx_hash: B256::repeat_byte(0x77),
            timestamp: (1 << 48) - 2,
            l1_block: ((1u64 << 48) - 1) - 9,
        };
        let inbox = InboxStorage {
            forced_inclusion_queue: vec![queued],
            ..InboxStorage::genesis(sample_genesis_record(), B256::ZERO)
        };
        let slots = inbox.slots();
        let case = (0..vectors::len_at("/layout/inbox/forced_inclusion_entry_slots"))
            .map(|k| format!("/layout/inbox/forced_inclusion_entry_slots/{k}"))
            .find(|p| vectors::u64_at(&format!("{p}/index")) == queued.index)
            .expect("a queue slot vector of entry 7");
        let [hash, metadata] = [0, 1].map(|w| vectors::b256_at(&format!("{case}/slots/{w}")));
        assert_eq!(B256::from(word(&slots, hash)), queued.tx_hash);
        assert_eq!(
            word(&slots, metadata),
            vectors::pack(
                "/layout/inbox/packing/forced_inclusion_entry_word2",
                &[
                    ("timestamp", U256::from(queued.timestamp)),
                    ("l1_block", U256::from(queued.l1_block)),
                ]
            )
        );
    }

    #[test]
    fn anchor_witness_sets_the_header_state_root() {
        let address = Address::repeat_byte(0xe7);
        let storage = InboxStorage::genesis(sample_genesis_record(), B256::repeat_byte(0x99));
        let (witness, state) = anchor_witness(address, &storage, l1_header(70, 1_000));
        assert_eq!(witness.l1_header.state_root(), state.state_root());
        assert_eq!(witness.l1_header.number(), 70);
        assert_eq!(witness.inbox.address, address);
        let slots: Vec<B256> = witness.inbox.storage.iter().map(|p| p.slot).collect();
        assert_eq!(slots, inbox::anchor_slots());
    }
}
