//! File-backed synthetic native evidence windows. Only the bounded source fixture creates frames.
//! The authenticator receives the original genesis, one EL and Comet boundary header and the
//! ascending immutable frame stream. Its only online source serves proven L1 facts.
use super::*;
use crate::{
    checkpoint_import::{ImportPackage, ImportValidator, WindowBlock, authenticate_import},
    test_utils::consensus::{BATCH_RECIPIENT, merkle, sign_commit, timed_pair},
};
use abci::{L1Error, L1Source};
use prost::Message;
use serde::{Deserialize, Serialize};
use std::{
    fs::File,
    io::{BufRead, BufReader, BufWriter, Write},
    path::Path,
    sync::Mutex,
};

const U: u64 = 65_532;

#[derive(Serialize, Deserialize)]
struct OwnFinality {
    headers: BTreeMap<u64, Bytes>,
    states: BTreeMap<u64, State>,
    #[serde(skip)]
    calls: Mutex<Vec<(String, u64, Vec<B256>)>>,
}

impl OwnFinality {
    fn record(&self, tag: &str, number: u64, slots: &[B256]) {
        self.calls.lock().unwrap().push((tag.into(), number, slots.to_vec()));
    }
}

#[async_trait]
impl L1Source for OwnFinality {
    async fn finalized_number(&self) -> std::result::Result<u64, L1Error> {
        let n = *self.headers.last_key_value().unwrap().0;
        self.record("finalized", n, &[]);
        Ok(n)
    }
    async fn canonical_hash(&self, n: u64) -> std::result::Result<B256, L1Error> {
        self.record("canonical", n, &[]);
        Ok(keccak256(&self.headers[&n]))
    }
    async fn header(&self, n: u64) -> std::result::Result<RawL1Header, L1Error> {
        self.record("header", n, &[]);
        Ok(RawL1Header::from_raw(self.headers[&n].clone()).unwrap())
    }
    async fn account_witness(
        &self,
        a: Address,
        slots: &[B256],
        n: u64,
    ) -> std::result::Result<AccountWitness, L1Error> {
        self.record("proof", n, slots);
        Ok(self.states[&n].witness(a, slots))
    }
    async fn forced_transaction(
        &self,
        _: Address,
        _: u64,
        _: u64,
    ) -> std::result::Result<Bytes, L1Error> {
        panic!("pre-import forced transaction request")
    }
    async fn storage_at(&self, _: Address, _: B256, _: u64) -> std::result::Result<U256, L1Error> {
        panic!("unproven storage lookup")
    }
}

fn write_json(path: &Path, value: &impl Serialize) {
    serde_json::to_writer(File::create_new(path).unwrap(), value).unwrap();
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> T {
    serde_json::from_reader(BufReader::new(File::open(path).unwrap())).unwrap()
}

// Build one real MPT observation and connect its header to the preceding observation.
fn observe(fx: &mut Fixture, n: u64, time: u64, endpoint: (u64, B256, B256, B256)) -> AnchorState {
    let queue = Queue { head: 0, tail: 0, entries: vec![] };
    let state = state_with_queue(
        &fx.params,
        &fx.registry_entries(),
        endpoint,
        &fx.committees,
        &fx.snapshot.genesis,
        &queue,
    );
    // Include the prior grid landing in the slot-285 record. Its history is represented
    // by the own-finalized MPT observation, outside this bounded consensus fixture.
    let mut accounts =
        state.accounts.into_iter().map(|(a, (slots, _))| (a, slots)).collect::<BTreeMap<_, _>>();
    accounts
        .get_mut(&fx.params.inbox)
        .unwrap()
        .insert(inbox::landing_slots(endpoint.0)[0], U256::from(endpoint.0.saturating_sub(6)));
    let state =
        State::new(accounts.into_iter().map(|(a, s)| (a, s.into_iter().collect())).collect());
    let parent = fx.l1_headers.get(&(n - 1)).map_or(B256::repeat_byte(9), RawL1Header::hash);
    let raw = RawL1Header::from_raw(
        alloy_rlp::encode(Header {
            number: n,
            timestamp: time,
            parent_hash: parent,
            state_root: state.root,
            ..Default::default()
        })
        .into(),
    )
    .unwrap();
    let a = anchor(&raw, endpoint.0, endpoint.1, &queue);
    fx.states.insert(n, state);
    fx.l1_headers.insert(n, raw);
    a
}

async fn generate(dir: &Path, s: u64, period: u64) {
    let count = if period == 4 { 100_001 } else { 172_801 };
    let w = s - count;
    let q0 = (w - 1) / 6 * 6;
    let terminal_q = s - U;
    let mut fx = Fixture::with_epoch(0, 0, 0, 600_000);
    fx.params.unsettled_limit = U;
    // This synthetic window binds a locally materializable terminal account state. It measures
    // actual MDBX verification and sparse indexes without executing the source prefix.
    let original = test_harness::EtnaGenesis::build().unwrap();
    std::fs::write(dir.join("el-genesis.json"), &original.json).unwrap();
    fx.headers.insert(0, original.header);
    fx.snapshot.genesis.genesis_hash = original.hash;
    fx.snapshot.genesis.genesis_state_root = original.state_root;
    fx.snapshot.genesis.committee_config_hash = committee_config_hash(&fx.params);
    fx.snapshot.genesis.max_anchor_age = 3_000_000;
    fx.l1_headers.clear();
    fx.states.clear();
    let genesis = fx.headers[&0].hash_slow();
    let time = |h: u64| 100 + period * h;
    let origin = observe(&mut fx, 10, 10, (0, genesis, B256::ZERO, B256::ZERO));
    fx.anchors.insert(0, origin);
    let mut vs = fx.val_states[&0].clone();
    assert_eq!(vs.current, vs.next);
    assert_eq!(vs.current.entries.len(), 1);
    vs.height = q0;
    // The prefix is settled and its checkpoint is proved on L1. No historical EL or Comet
    // acquisition API is provided for it.
    let prefix_comet = |h: u64| keccak256([b"comet:".as_slice(), &h.to_be_bytes()].concat());
    let mut a = observe(
        &mut fx,
        11,
        time(q0),
        (q0, keccak256(q0.to_be_bytes()), prefix_comet(q0), vs.hash()),
    );
    vs.height = s;
    fx.val_states.insert(s, vs.clone());
    let mut pkg = import_package(&fx, s).await;
    let mut stock = BufWriter::new(File::create_new(dir.join("stock.json")).unwrap());
    stock.write_all(br#"{"schema":1,"genesis":"#).unwrap();
    serde_json::to_writer(&mut stock, &pkg.genesis).unwrap();
    stock.write_all(br#","blocks":["#).unwrap();
    let mut frames = BufWriter::new(File::create_new(dir.join("blocks.jsonl")).unwrap());
    let keys = [SigningKey::from_slice(&[1; 32]).unwrap()];
    let validators = fx.committees[&0]
        .state
        .members
        .iter()
        .map(|m| ImportValidator { key: m.pubkey, power: m.power })
        .collect::<Vec<_>>();

    let native_time = |h| tendermint::Time::from_unix_timestamp(time(h) as i64, 0).unwrap();
    // The unopened prefix is represented by an opaque full BlockID. In particular header(w)
    // at a nonzero height carries a real last block ID/commit hash. Only header(w) is handed
    // to the verifier. Neither a prefix block nor its part bytes are read or written.
    let predecessor_hash = keccak256((w - 1).to_be_bytes());
    let mut prior = crate::native::Commit {
        height: (w - 1).try_into().unwrap(),
        round: 0u16.into(),
        block_id: tendermint::block::Id {
            hash: tendermint::Hash::Sha256(prefix_comet(w - 1).0),
            part_set_header: tendermint::block::parts::Header::new(
                1,
                merkle(&[predecessor_hash.to_vec()]),
            )
            .unwrap(),
        },
        signatures: vec![],
    };
    sign_commit(
        &mut prior,
        &pkg.genesis.chain_id.parse().unwrap(),
        &fx.committees[&0],
        &keys,
        native_time(w),
    );
    let mut parent = ParentInfo {
        number: w - 1,
        hash: predecessor_hash,
        timestamp: time(w - 1),
        gas_limit: fx.params.block_gas_limit,
        gas_used: 0,
        base_fee: 1_000_000,
        difficulty: U256::ZERO,
        grandparent_timestamp: time(w - 2),
    };
    let last_results = merkle(&[vec![]]);
    for h in w..=s {
        let q = h - 1;
        let changed = q == terminal_q || (period == 1 && q == s - 110_004);
        let witness = if changed {
            vs.height = q;
            let comet = B256::from_slice(prior.block_id.hash.as_bytes());
            a = observe(&mut fx, a.number + 1, time(q), (q, parent.hash, comet, vs.hash()));
            Some(AnchorWitness {
                l1_header: fx.l1_headers[&a.number].clone(),
                inbox: fx.states[&a.number].witness(fx.params.inbox, &inbox::anchor_slots()),
            })
        } else {
            None
        };
        let e = rules::expected_header(&HeaderInputs {
            height: h,
            beneficiary: BATCH_RECIPIENT,
            parent: &parent,
            anchor: &a,
            bft_time_secs: time(h),
            generation: 0,
            params: &fx.params,
            min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(
                fx.params.l2_chain_id,
            ),
        })
        .unwrap();
        let el = Header {
            number: h,
            parent_hash: e.parent_hash,
            state_root: original.state_root,
            timestamp: e.timestamp,
            beneficiary: e.beneficiary,
            extra_data: e.extra_data,
            parent_beacon_block_root: Some(e.parent_beacon_block_root),
            gas_limit: e.gas_limit,
            base_fee_per_gas: Some(e.base_fee),
            mix_hash: e.mix_hash,
            transactions_root: EMPTY_ROOT_HASH,
            withdrawals_root: Some(EMPTY_ROOT_HASH),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            requests_hash: Some(EMPTY_REQUESTS_HASH),
            ommers_hash: EMPTY_OMMER_ROOT_HASH,
            ..Default::default()
        };
        let pair = timed_pair(
            EtnaEnvelope {
                block: ExecutionBlock { header: el.clone(), transactions: vec![] },
                anchor: witness,
                committee: None,
                forced: None,
            },
            &fx.committees[&0],
            &keys,
            Some(&prior),
            native_time(h),
            native_time(h + 1),
            Some(last_results),
        );
        if h == w {
            pkg.boundary_header = Some(pair.block.header.clone());
            pkg.execution_headers = vec![el.clone()];
        } else {
            let frame = WindowBlock {
                block: pair.raw_block.clone(),
                commit: tendermint_proto::v0_38::types::Commit::from(pair.commit.clone())
                    .encode_to_vec()
                    .into(),
                validators: validators.clone(),
            };
            let bytes = serde_json::to_vec(&frame).unwrap();
            frames.write_all(&bytes).unwrap();
            frames.write_all(b"\n").unwrap();
            if h > w + 1 {
                stock.write_all(b",").unwrap();
            }
            stock.write_all(&bytes).unwrap();
        }
        parent = ParentInfo {
            number: h,
            hash: el.hash_slow(),
            timestamp: el.timestamp,
            gas_limit: el.gas_limit,
            gas_used: el.gas_used,
            base_fee: e.base_fee,
            difficulty: el.difficulty,
            grandparent_timestamp: parent.timestamp,
        };
        prior = pair.commit;
    }
    vs.height = s;
    let comet = B256::from_slice(prior.block_id.hash.as_bytes());
    observe(&mut fx, a.number + 1, time(s), (s, parent.hash, comet, vs.hash()));
    stock.write_all(br#"],"validator_state":"#).unwrap();
    serde_json::to_writer(&mut stock, &pkg.validator_state).unwrap();
    stock.write_all(b"}").unwrap();
    stock.flush().unwrap();
    frames.flush().unwrap();
    write_json(&dir.join("package.json"), &pkg);
    write_json(
        &dir.join("own-l1.json"),
        &OwnFinality {
            headers: fx.l1_headers.into_iter().map(|(n, h)| (n, h.raw().clone())).collect(),
            states: fx.states,
            calls: Mutex::default(),
        },
    );
}

// Serialization order is the official helper manifest's durable digest contract.
#[derive(Serialize)]
struct HeaderManifest<'a> {
    schema: u32,
    installation_id: B256,
    chain_id: u64,
    origin: u64,
    unsettled_limit: u64,
    finalized_height: u64,
    finalized_hash: B256,
    headers: &'a [Header],
}

async fn verify(dir: &Path, s: u64, period: u64) {
    let own: OwnFinality = read_json(&dir.join("own-l1.json"));
    let params = parameters();
    let pkg: ImportPackage = read_json(&dir.join("package.json"));
    let w = s - if period == 4 { 100_001 } else { 172_801 };
    assert_eq!(pkg.execution_headers.len(), 1);
    assert_eq!(pkg.execution_headers[0].number, w);
    let mut count = 0;
    let frames =
        BufReader::new(File::open(dir.join("blocks.jsonl")).unwrap()).lines().map(|line| {
            count += 1;
            assert!(count <= s - w, "successor frame requested");
            Ok(serde_json::from_str(&line.unwrap()).unwrap())
        });
    let v = authenticate_import(&pkg, frames, &params, &own).await.unwrap();
    assert_eq!(count, s - w);
    assert_eq!(v.first_height(), Some(w + 1));
    let headers = v.execution_headers();
    assert_eq!(headers.first().unwrap().number, s - U);
    assert_eq!(headers.first().unwrap().hash_slow(), v.state().anchor.inbox.last_checkpoint_hash);
    assert_eq!(headers.last().unwrap().hash_slow(), v.landing().el_hash);
    assert!(
        headers
            .windows(2)
            .all(|h| h[0].number + 1 == h[1].number && h[0].hash_slow() == h[1].parent_hash)
    );
    assert_eq!(v.state().val_state.hash(), v.landing().val_state_hash);
    let calls = own.calls.lock().unwrap();
    assert!(
        calls
            .iter()
            .any(|(tag, n, slots)| tag == "proof" && *n == 11 && *slots == inbox::anchor_slots())
    );
    write_json(&dir.join("l1-requests.json"), &*calls);
    let id = B256::repeat_byte(0x6f);
    let manifest = HeaderManifest {
        schema: 1,
        installation_id: id,
        chain_id: params.l2_chain_id,
        origin: 0,
        unsettled_limit: U,
        finalized_height: s - U,
        finalized_hash: headers[0].hash_slow(),
        headers,
    };
    let encoded = serde_json::to_vec(&manifest).unwrap();
    let manifest_hash = keccak256(&encoded);
    std::fs::write(dir.join("headers.json"), encoded).unwrap();
    let set_hash = abci::wire::validators_hash(&v.state().committees[&0].members).unwrap();
    let parts = v.block_id().unwrap().part_set_header;
    write_json(
        &dir.join("verified.json"),
        &serde_json::json!({
            "first_height": w+1,
            "last_height": s,
            "el_hash": v.landing().el_hash,
            "comet_hash": v.landing().comet_hash,
            "val_state_hash": v.landing().val_state_hash,
            "chain_id": pkg.genesis.chain_id,
            "part_hash": parts.hash.to_string(),
            "part_total": parts.total,
            "set_hash": set_hash,
            "state_root": headers.last().unwrap().state_root,
            "genesis_hash": pkg.origin_header.hash_slow(),
            "manifest_hash": manifest_hash,
            "installation_id": id,
            "finalized_hash": headers[0].hash_slow(),
            "l1_calls": calls.len(),
            "frames": count,
            "el_prefix_headers": 1,
            "terminal_q": s-U,
        }),
    );
}

/// Both failures are decidable at w+1. A verifier reading ahead would panic.
async fn boundary_failures(dir: &Path) {
    use crate::checkpoint_import::ImportError;
    let own: OwnFinality = read_json(&dir.join("own-l1.json"));
    let pkg: ImportPackage = read_json(&dir.join("package.json"));
    let line = BufReader::new(File::open(dir.join("blocks.jsonl")).unwrap())
        .lines()
        .next()
        .unwrap()
        .unwrap();
    let first: WindowBlock = serde_json::from_str(&line).unwrap();
    let input = || {
        std::iter::once(Ok(first.clone()))
            .chain(std::iter::from_fn(|| panic!("read beyond the authenticated boundary failure")))
    };
    let mut missing = pkg.clone();
    missing.boundary_header = None;
    assert!(matches!(authenticate_import(&missing,input(),&parameters(),&own).await,
        Err(ImportError::Unavailable(message)) if message.contains("predecessor header")));
    let mut wrong = pkg;
    wrong.execution_headers[0].state_root = B256::ZERO;
    // The prefix hash can be rejected before the ordinary AppHash check. Its
    // category and bounded read are the contract, rather than diagnostic wording.
    let result = authenticate_import(&wrong, input(), &parameters(), &own).await;
    assert!(matches!(result, Err(ImportError::Candidate(_))), "{result:?}");
}

#[tokio::test]
#[ignore = "resource acceptance; run just checkpoint-import-resources"]
async fn signed_checkpoint_resource_phase() {
    let dir = std::env::var_os("ETNA_RESOURCE_DIR").unwrap();
    let s: u64 = std::env::var("ETNA_RESOURCE_HEIGHT").unwrap().parse().unwrap();
    let period: u64 = std::env::var("ETNA_RESOURCE_PERIOD").unwrap().parse().unwrap();
    assert!([200_004, 400_008].contains(&s) && [1, 4].contains(&period));
    match std::env::var("ETNA_RESOURCE_PHASE").unwrap().as_str() {
        "generate" => generate(Path::new(&dir), s, period).await,
        "verify" => verify(Path::new(&dir), s, period).await,
        "boundary-failures" => boundary_failures(Path::new(&dir)).await,
        _ => panic!("unknown resource phase"),
    }
}
