use crate::{
    LanderError,
    l1::{LandingSource, RpcLandingSource},
    types::LandingSnapshot,
};
use abci::{
    AnchorState, ChainParams, ChainParamsExt, GenesisRecord, InboxFacts, l1::header::RawL1Header,
};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, U256};
use serde_json::{Value, json};
use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};

#[test]
fn public_rpc_and_wrapped_anchor_errors_never_render_endpoint_credentials() {
    use alloy::transports::{RpcError, TransportErrorKind};
    let sensitive = "https://alice:password@example.invalid/private-key-path?api_key=secret";
    let decoding = serde_json::from_str::<serde_json::Value>("<html>").unwrap_err();
    let mut errors = [
        TransportErrorKind::custom_str(sensitive),
        TransportErrorKind::http_error(503, sensitive.into()),
        RpcError::deser_err(decoding, sensitive),
    ]
    .into_iter()
    .map(crate::l1::rpc_error)
    .collect::<Vec<_>>();
    errors.push(crate::l1::anchor_error(abci::l1::source::L1Error::Rpc(sensitive.into())));
    errors.push(crate::l1::recovery_error(abci::recovery::RecoveryError::Unavailable(
        sensitive.into(),
    )));
    for error in errors {
        assert!(error.is_retryable());
        for secret in ["alice", "password", "private-key-path", "api_key", "secret"] {
            assert!(!error.to_string().contains(secret), "L1 error exposed {secret}");
        }
    }
}

/// A fallback key list the L1 endpoint cannot give, as `getFallbackKeys()` fails on pruned
/// state and no log holds it or the log query fails, is the node's own L1 fault:
/// [`LanderError::Temporary`], never `Safety`, and it renders no endpoint detail.
#[tokio::test]
async fn unavailable_origin_list_is_temporary() {
    let secret = "https://alice:password@example.invalid/api_key=secret";
    for logs in [json!([]), json!({"__rpc_error":{"code":-32005,"message":secret}})] {
        let provider = rpc(move |request| match request["method"].as_str().unwrap() {
            "eth_call" => json!({"__rpc_error":{"code":-32000,"message":secret}}),
            "eth_getLogs" => logs.clone(),
            other => panic!("unexpected {other}"),
        })
        .await;
        let fixture = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
        let source = RpcLandingSource::new(
            provider.provider.clone(),
            provider.provider.clone(),
            fixture.params,
        );
        let error = source
            .fallback_keys(B256::repeat_byte(7), B256::repeat_byte(8), 100, 0)
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Temporary(_)), "{error}");
        assert!(!error.to_string().contains("password"), "{error}");
        let methods: Vec<_> = provider
            .requests
            .lock()
            .unwrap()
            .iter()
            .map(|request| request["method"].as_str().unwrap().to_owned())
            .collect();
        assert_eq!(methods, ["eth_call", "eth_getLogs"]);
    }
}

pub(crate) struct RpcFixture {
    pub(crate) provider: alloy_provider::RootProvider,
    pub(crate) requests: Arc<Mutex<Vec<Value>>>,
    task: tokio::task::JoinHandle<()>,
}
impl Drop for RpcFixture {
    fn drop(&mut self) {
        self.task.abort();
    }
}
pub(crate) async fn rpc(handler: impl Fn(&Value) -> Value + Send + Sync + 'static) -> RpcFixture {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let requests = Arc::new(Mutex::new(vec![]));
    let recorded = requests.clone();
    let handler = Arc::new(handler);
    let task = tokio::spawn(async move {
        loop {
            let (mut stream, _) = listener.accept().await.unwrap();
            let handler = handler.clone();
            let recorded = recorded.clone();
            tokio::spawn(async move {
                let mut wire = vec![];
                let mut block = [0u8; 4096];
                let body;
                loop {
                    let read = stream.read(&mut block).await.unwrap();
                    if read == 0 {
                        return;
                    }
                    wire.extend_from_slice(&block[..read]);
                    if let Some(end) = wire.windows(4).position(|bytes| bytes == b"\r\n\r\n") {
                        let headers = std::str::from_utf8(&wire[..end]).unwrap();
                        let length = headers
                            .lines()
                            .find_map(|line| {
                                line.split_once(':')
                                    .filter(|(key, _)| key.eq_ignore_ascii_case("content-length"))
                                    .map(|(_, value)| value.trim().parse::<usize>().unwrap())
                            })
                            .unwrap();
                        if wire.len() >= end + 4 + length {
                            body = wire[end + 4..end + 4 + length].to_vec();
                            break;
                        }
                    }
                }
                let request: Value = serde_json::from_slice(&body).unwrap();
                recorded.lock().unwrap().push(request.clone());
                let result = handler(&request);
                let response = if let Some(error) = result.get("__rpc_error") {
                    json!({"jsonrpc":"2.0","id":request["id"],"error":error})
                } else {
                    json!({"jsonrpc":"2.0","id":request["id"],"result":result})
                }
                .to_string();
                let header = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    response.len()
                );
                stream.write_all(header.as_bytes()).await.unwrap();
                stream.write_all(response.as_bytes()).await.unwrap();
            });
        }
    });
    let provider = rpc::client::connect_http_with_timeout(
        format!("http://{address}").parse().unwrap(),
        Duration::from_secs(2),
    );
    RpcFixture { provider, requests, task }
}
fn header_chain() -> BTreeMap<u64, RawL1Header> {
    let mut previous = B256::ZERO;
    (0..=20)
        .map(|number| {
            let header = RawL1Header::from(&Header {
                number,
                parent_hash: previous,
                state_root: B256::repeat_byte(number as u8),
                timestamp: number * 12,
                ..Default::default()
            });
            previous = header.hash();
            (number, header)
        })
        .collect()
}
fn json_header(header: &RawL1Header) -> Value {
    let el: Header = alloy_rlp::decode_exact(header.raw()).unwrap();
    let mut value = serde_json::to_value(el).unwrap();
    value["hash"] = json!(header.hash());
    value
}
fn anchor(header: &RawL1Header) -> AnchorState {
    AnchorState {
        number: header.number(),
        hash: header.hash(),
        state_root: header.state_root(),
        timestamp: header.timestamp(),
        inbox: InboxFacts {
            rules_schedule: alloy_primitives::U256::ZERO,
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::repeat_byte(1),
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
            fallback_keys_hash: B256::ZERO,
            min_total_stake: alloy_primitives::U256::ZERO,
        },
    }
}
fn snapshot(headers: &BTreeMap<u64, RawL1Header>) -> LandingSnapshot {
    let params = ChainParams::builtin(167001).unwrap();
    LandingSnapshot {
        l1_block_hash: headers[&20].hash(),
        l1_block_number: 20,
        l1_chain_id: U256::from(1),
        l2_chain_id: 167001,
        inbox: params.inbox,
        recovery: None,
        recovery_witness: None,
        generation: 0,
        checkpoint_height: 0,
        checkpoint_hash: B256::repeat_byte(1),
        checkpoint_comet_hash: B256::ZERO,
        forced_inclusion_head: 0,
        forced_inclusion_tail: 0,
        genesis: GenesisRecord {
            config_hash: B256::repeat_byte(3),
            genesis_height: 0,
            l1_0: 10,
            genesis_hash: B256::repeat_byte(1),
            genesis_state_root: B256::repeat_byte(2),
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        },
        config_hash: B256::repeat_byte(3),
        l1_header: headers[&20].clone(),
        inbox_witness: abci::AccountWitness {
            address: params.inbox,
            nonce: 0,
            balance: U256::ZERO,
            storage_root: B256::ZERO,
            code_hash: B256::ZERO,
            account_proof: vec![],
            storage: vec![],
        },
    }
}
async fn source(
    finalized: u64,
    wrong_parent: bool,
) -> (RpcLandingSource, RpcFixture, RpcFixture, BTreeMap<u64, RawL1Header>) {
    source_with_chain_id(finalized, wrong_parent, U256::from(1)).await
}

async fn source_with_chain_id(
    finalized: u64,
    wrong_parent: bool,
    chain_id: U256,
) -> (RpcLandingSource, RpcFixture, RpcFixture, BTreeMap<u64, RawL1Header>) {
    let mut headers = header_chain();
    if wrong_parent {
        headers.insert(
            14,
            RawL1Header::from(&Header {
                number: 14,
                parent_hash: B256::repeat_byte(99),
                state_root: B256::repeat_byte(14),
                timestamp: 168,
                ..Default::default()
            }),
        );
    }
    let answers = headers.clone();
    let proof_fixture = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
    let mut proof_snapshot = proof_fixture.snapshot.clone();
    let mut raw: Header = alloy_rlp::decode_exact(proof_snapshot.l1_header.raw()).unwrap();
    raw.number = 20;
    raw.parent_hash = answers[&19].hash();
    proof_snapshot.l1_header = RawL1Header::from(&raw);
    proof_snapshot.l1_block_number = 20;
    proof_snapshot.l1_block_hash = raw.hash_slow();
    let expected_proof = proof_snapshot.inbox_witness.clone();
    let mut answers = answers;
    answers.insert(20, proof_snapshot.l1_header.clone());
    let l1 = rpc(move |request| match request["method"].as_str().unwrap() {
        "eth_chainId" => json!(chain_id),
        "eth_blockNumber" => json!("0x14"),
        "eth_getBlockByNumber" => {
            let tag = request["params"][0].as_str().unwrap();
            let number = if tag == "finalized" {
                finalized
            } else {
                u64::from_str_radix(tag.trim_start_matches("0x"), 16).unwrap()
            };
            json_header(&answers[&number])
        }
        "debug_getRawHeader" => {
            let selector = request["params"][0].as_str().unwrap();
            let header = answers.values().find(|header| json!(header.hash()) == json!(selector));
            let header = header.unwrap_or_else(|| {
                let number = u64::from_str_radix(selector.trim_start_matches("0x"), 16).unwrap();
                &answers[&number]
            });
            json!(header.raw())
        }
        "eth_getProof" => {
            assert_eq!(request["params"][2], json!({"blockHash": proof_snapshot.l1_block_hash, "requireCanonical": true}));
            json!({ "address": expected_proof.address, "nonce": format!("0x{:x}", expected_proof.nonce),
                "balance": expected_proof.balance, "storageHash": expected_proof.storage_root,
                "codeHash": expected_proof.code_hash, "accountProof": expected_proof.account_proof,
                "storageProof": expected_proof.storage.iter().filter(|s| request["params"][1].as_array().unwrap().contains(&json!(s.slot))).map(|s| json!({"key": s.slot, "value": s.value, "proof": s.proof})).collect::<Vec<_>>() })
        }
        other => panic!("unexpected L1 method {other}"),
    })
    .await;
    let l2 = rpc(|request| {
        assert_eq!(request["method"], "eth_chainId");
        json!("0x28c59")
    })
    .await;
    let mut params = proof_fixture.params;
    params.l1_chain_id = chain_id;
    let source = RpcLandingSource::new(l1.provider.clone(), l2.provider.clone(), params);
    (source, l1, l2, headers)
}

/// Two genuine Inbox tries at the same height, with a deterministic canonical-head change.
pub(crate) struct SnapshotRpc {
    pub(crate) source: Arc<RpcLandingSource>,
    pub(crate) l1: RpcFixture,
    pub(crate) a: LandingSnapshot,
    pub(crate) b: LandingSnapshot,
    _l2: RpcFixture,
}

fn proof_json(witness: &abci::AccountWitness) -> Value {
    json!({"address": witness.address, "nonce": format!("0x{:x}", witness.nonce),
        "balance": witness.balance, "storageHash": witness.storage_root,
        "codeHash": witness.code_hash, "accountProof": witness.account_proof,
        "storageProof": witness.storage.iter().map(|s| json!({"key": s.slot, "value": s.value, "proof": s.proof})).collect::<Vec<_>>()})
}

/// Grace given to the test sources' head-proof re-reads.
const TEST_HEAD_PROOF_GRACE: Duration = Duration::from_millis(500);

pub(crate) async fn snapshot_rpc(reorg: bool, before_raw: bool, malformed: bool) -> SnapshotRpc {
    snapshot_rpc_with(reorg, before_raw, malformed, 0).await
}

/// As [`snapshot_rpc`], but the first `stale_proofs` head proofs carry a storage value that does
/// not verify under the head's header, as an endpoint answers while the next block is still
/// extending the head's state.
pub(crate) async fn snapshot_rpc_with(
    reorg: bool,
    before_raw: bool,
    malformed: bool,
    stale_proofs: usize,
) -> SnapshotRpc {
    snapshot_rpc_with_delay(reorg, before_raw, malformed, 0..stale_proofs, Duration::ZERO).await
}

/// A source whose `eth_getProof` answers with an index in `stale_calls` carry a storage value the
/// head's header does not prove, and whose first proof response arrives after a controlled latency.
async fn snapshot_rpc_with_delay(
    reorg: bool,
    before_raw: bool,
    malformed: bool,
    stale_calls: std::ops::Range<usize>,
    first_proof_delay: Duration,
) -> SnapshotRpc {
    let fixture_a = crate::test_utils::consensus_mpt::Fixture::new(0, 2);
    let fixture_b = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
    let pin = |mut snapshot: LandingSnapshot| {
        let mut header: Header = alloy_rlp::decode_exact(snapshot.l1_header.raw()).unwrap();
        header.number = 20;
        snapshot.l1_header = RawL1Header::from(&header);
        snapshot.l1_block_hash = snapshot.l1_header.hash();
        snapshot.l1_block_number = 20;
        snapshot
    };
    let a = pin(fixture_a.snapshot);
    let b = pin(fixture_b.snapshot);
    assert_ne!(a.l1_header.state_root(), b.l1_header.state_root());
    let (answer_a, answer_b) = (a.clone(), b.clone());
    let switched = Mutex::new(false);
    let proof_calls = Mutex::new(0usize);
    let first_proof_delay = Mutex::new(Some(first_proof_delay));
    let l1 = rpc(move |request| {
        let mut switched = switched.lock().unwrap();
        match request["method"].as_str().unwrap() {
            "eth_chainId" => json!("0x1"),
            "eth_blockNumber" => json!("0x14"),
            "eth_getBlockByNumber" => {
                let result = json_header(if *switched { &answer_b.l1_header } else { &answer_a.l1_header });
                if reorg && before_raw { *switched = true; }
                result
            }
            "debug_getRawHeader" => {
                let selector = &request["params"][0];
                let header = if selector == &json!(answer_a.l1_block_hash) {
                    &answer_a.l1_header
                } else if selector == &json!(answer_b.l1_block_hash) || *switched {
                    &answer_b.l1_header
                } else { &answer_a.l1_header };
                let result = json!(header.raw());
                if reorg { *switched = true; }
                result
            }
            "eth_getProof" => {
                if let Some(delay) = first_proof_delay.lock().unwrap().take() {
                    std::thread::sleep(delay);
                }
                let selector = &request["params"][2];
                if *switched && selector == &json!({"blockHash": answer_a.l1_block_hash, "requireCanonical": true}) {
                    return json!({"__rpc_error": {"code": -32000, "message": "block is not canonical"}});
                }
                let mut call = proof_calls.lock().unwrap();
                let stale = stale_calls.contains(&*call);
                *call += 1;
                let mut witness = if *switched { answer_b.inbox_witness.clone() } else { answer_a.inbox_witness.clone() };
                witness.storage.retain(|s| request["params"][1].as_array().unwrap().contains(&json!(s.slot)));
                if stale { witness.storage[0].value += U256::from(1); }
                if malformed { witness.account_proof.clear(); }
                proof_json(&witness)
            }
            other => panic!("unexpected snapshot RPC method {other}"),
        }
    }).await;
    let chain_id = fixture_a.params.l2_chain_id;
    let l2 = rpc(move |request| {
        assert_eq!(request["method"], "eth_chainId");
        json!(format!("0x{chain_id:x}"))
    })
    .await;
    let source = Arc::new(
        RpcLandingSource::new(l1.provider.clone(), l2.provider.clone(), fixture_a.params)
            .with_head_proof_grace(TEST_HEAD_PROOF_GRACE),
    );
    SnapshotRpc { source, l1, a, b, _l2: l2 }
}

#[tokio::test]
async fn snapshot_reorg_retries_with_coherent_hash_pinned_header_and_proof() {
    for before_raw in [false, true] {
        let rpc = snapshot_rpc(true, before_raw, false).await;
        let error = rpc.source.snapshot().await.unwrap_err();
        assert!(error.is_retryable(), "ordinary head reorg must retry: {error}");
        assert!(matches!(error, LanderError::Temporary(_)));
        assert_eq!(rpc.source.snapshot().await.unwrap(), rpc.b);
        let calls = rpc.l1.requests.lock().unwrap();
        let proofs =
            calls.iter().filter(|call| call["method"] == "eth_getProof").collect::<Vec<_>>();
        assert_eq!(proofs.len(), 3);
        for (call, snapshot) in proofs.iter().zip([&rpc.a, &rpc.b, &rpc.b]) {
            assert_eq!(
                call["params"][2],
                json!({"blockHash": snapshot.l1_block_hash, "requireCanonical": true})
            );
            // The fixed slots alone, or with the checkpoint's three-word landing record.
            let fixed = crate::l1::snapshot_slots().len();
            assert_eq!(fixed, 17);
            assert!([fixed, fixed + 3].contains(&call["params"][1].as_array().unwrap().len()));
        }
        let raw =
            calls.iter().filter(|call| call["method"] == "debug_getRawHeader").collect::<Vec<_>>();
        assert_eq!(raw.len(), 2);
        assert_eq!(raw[0]["params"][0], json!(rpc.a.l1_block_hash));
        assert_eq!(raw[1]["params"][0], json!(rpc.b.l1_block_hash));
    }
}

#[tokio::test]
async fn snapshot_malformed_proof_at_canonical_pinned_hash_is_safety() {
    let rpc = snapshot_rpc(false, false, true).await;
    let error = rpc.source.snapshot().await.unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
    assert!(!error.is_retryable());
    let calls = rpc.l1.requests.lock().unwrap();
    let proof = calls.iter().find(|call| call["method"] == "eth_getProof").unwrap();
    assert_eq!(
        proof["params"][2],
        json!({"blockHash": rpc.a.l1_block_hash, "requireCanonical": true})
    );
}

#[tokio::test]
async fn snapshot_rereads_a_head_proof_served_from_state_still_being_extended() {
    let rpc = snapshot_rpc_with(false, false, false, 1).await;
    assert_eq!(rpc.source.snapshot().await.unwrap(), rpc.a);
    let calls = rpc.l1.requests.lock().unwrap();
    assert_eq!(calls.iter().filter(|call| call["method"] == "eth_getProof").count(), 3);
    assert_eq!(calls.iter().filter(|call| call["method"] == "debug_getRawHeader").count(), 2);
}

#[tokio::test]
async fn snapshot_grace_starts_when_a_slow_first_proof_is_observed_inconsistent() {
    let rpc = snapshot_rpc_with_delay(false, false, false, 0..1, Duration::from_millis(50)).await;
    let source = rpc.source.as_ref().clone().with_head_proof_grace(Duration::from_millis(20));
    assert_eq!(source.snapshot().await.unwrap(), rpc.a);
    let calls = rpc.l1.requests.lock().unwrap();
    assert_eq!(calls.iter().filter(|call| call["method"] == "eth_getProof").count(), 3);
}

#[tokio::test]
async fn zero_head_proof_grace_reports_the_first_invalid_proof_without_rereading() {
    let rpc = snapshot_rpc_with(false, false, false, 1).await;
    let source = rpc.source.as_ref().clone().with_head_proof_grace(Duration::ZERO);
    assert!(matches!(source.snapshot().await, Err(LanderError::Safety(_))));
    let calls = rpc.l1.requests.lock().unwrap();
    assert_eq!(calls.iter().filter(|call| call["method"] == "eth_getProof").count(), 1);
}

#[tokio::test]
async fn snapshot_rereads_when_only_the_landing_slot_proof_sees_state_still_being_extended() {
    // The head's first proof verifies; the landing-slot proof that follows it does not.
    let rpc = snapshot_rpc_with_delay(false, false, false, 1..2, Duration::ZERO).await;
    assert_eq!(rpc.source.snapshot().await.unwrap(), rpc.a);
    let calls = rpc.l1.requests.lock().unwrap();
    assert_eq!(calls.iter().filter(|call| call["method"] == "eth_getProof").count(), 4);
    assert_eq!(calls.iter().filter(|call| call["method"] == "debug_getRawHeader").count(), 2);
}

#[tokio::test]
async fn zero_head_proof_grace_reports_an_invalid_landing_slot_proof_without_rereading() {
    let rpc = snapshot_rpc_with_delay(false, false, false, 1..2, Duration::ZERO).await;
    let source = rpc.source.as_ref().clone().with_head_proof_grace(Duration::ZERO);
    let error = source.snapshot().await.unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
    assert!(error.to_string().contains("Inbox snapshot proof"), "{error}");
    let calls = rpc.l1.requests.lock().unwrap();
    assert_eq!(calls.iter().filter(|call| call["method"] == "eth_getProof").count(), 2);
}

#[tokio::test]
async fn snapshot_head_proof_that_never_verifies_is_safety_after_the_grace() {
    let rpc = snapshot_rpc_with(false, false, false, usize::MAX).await;
    let started = std::time::Instant::now();
    let error = rpc.source.snapshot().await.unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
    assert!(error.to_string().contains("Inbox snapshot proof"), "{error}");
    assert!(started.elapsed() >= TEST_HEAD_PROOF_GRACE);
    let calls = rpc.l1.requests.lock().unwrap();
    assert!(calls.iter().filter(|call| call["method"] == "eth_getProof").count() > 1);
}

#[test]
fn snapshot_decoding_returns_the_planted_forced_inclusion_head_and_tail() {
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(6, 12);
    assert_eq!(
        (fixture.snapshot.forced_inclusion_head, fixture.snapshot.forced_inclusion_tail),
        (0, 0)
    );
    let planted = fixture.snapshot_with_forced_queue(fixture.snapshot.genesis.clone(), 3, 9);
    let decoded = super::decode_snapshot(
        planted.l1_header.clone(),
        planted.inbox_witness.clone(),
        planted.l1_chain_id,
        planted.l2_chain_id,
        &fixture.params,
    )
    .unwrap();
    assert_eq!((decoded.forced_inclusion_head, decoded.forced_inclusion_tail), (3, 9));
    assert_eq!(decoded.genesis, fixture.snapshot.genesis);
    assert_eq!(
        (decoded.genesis.forced_inclusion_delay, decoded.genesis.max_anchor_age),
        (3_600, 7_200)
    );
    assert_eq!(decoded, planted);
    super::authenticate_snapshot(&planted, &fixture.params).unwrap();

    // A head or tail claimed beside the proof is a contradiction, not a hint.
    for (head, tail) in [(4, 9), (3, 8)] {
        let claimed = LandingSnapshot {
            forced_inclusion_head: head,
            forced_inclusion_tail: tail,
            ..planted.clone()
        };
        let error = super::authenticate_snapshot(&claimed, &fixture.params).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
    }
}

/// A landing may end at any height (LAND-6.1-5): the decoder accepts the three-word slot 285
/// record (STOR-B-9) at every height above the start, heights off the retired grid included, and
/// proves no fourth word. A Comet hash of 0 above the start, or a parent at or above the
/// checkpoint, is refused.
#[test]
fn snapshot_decodes_a_three_word_record_at_any_height() {
    use abci::l1::layout::inbox;
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 2);
    for height in 1..=13u64 {
        let landing = inbox::landing_record_slots(height);
        let fourth = B256::from(U256::from_be_bytes(landing[2].0) + U256::from(1));
        assert!(!super::snapshot_landing_slots(height).contains(&fourth));
        let decode = |parent: u64, comet: u64| {
            let planted = fixture.snapshot_with_inbox_words([
                (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)),
                (landing[0], U256::from(parent)),
                (landing[1], fixture.snapshot.checkpoint_hash.into()),
                (landing[2], U256::from(comet)),
            ]);
            super::decode_snapshot(
                planted.l1_header,
                planted.inbox_witness,
                planted.l1_chain_id,
                planted.l2_chain_id,
                &fixture.params,
            )
        };
        let decoded = decode(height - 1, 7).unwrap();
        assert_eq!(decoded.checkpoint_height, height);
        assert_eq!(decoded.checkpoint_comet_hash, B256::from(U256::from(7)));
        for (parent, comet) in [(height - 1, 0), (height, 7)] {
            let result = decode(parent, comet);
            assert!(matches!(result, Err(LanderError::Safety(_))), "{height}: {result:?}");
        }
    }
}

/// Independently generated packed words bind parent, generation and head to distinct fields.
#[test]
fn snapshot_decodes_the_shared_landing_word_and_rejects_each_contradictory_field() {
    use crate::test_utils::vectors;
    use abci::l1::layout::inbox;
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(18, 18);
    let path = |field: &str| format!("/packed_words/inbox_285_word1/0/{field}");
    let word = U256::from_be_bytes(vectors::b256_at(&path("word")).0);
    let parent = vectors::u64_at(&path("parent_height"));
    let generation = vectors::u64_at(&path("generation"));
    let head = vectors::u64_at(&path("head"));
    let height = fixture.snapshot.checkpoint_height;
    assert!(parent < height);
    let decode = |word: U256| {
        let planted = fixture.snapshot_with_inbox_words([
            (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(generation)),
            (
                inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL),
                U256::from(head) | (U256::from(head) << 48),
            ),
            (inbox::landing_record_slots(height)[0], word),
        ]);
        super::decode_snapshot(
            planted.l1_header,
            planted.inbox_witness,
            planted.l1_chain_id,
            planted.l2_chain_id,
            &fixture.params,
        )
    };
    let decoded = decode(word).unwrap();
    assert_eq!(decoded.generation, generation);
    assert_eq!(decoded.forced_inclusion_head, head);
    for (field, value) in
        [("parent_height", height), ("generation", generation + 1), ("head", head + 1)]
    {
        let offset =
            vectors::u64_at(&format!("/layout/inbox/packing/landing_word1/{field}/offset"));
        let mask: U256 = ((U256::from(1) << 48) - U256::from(1)) << offset;
        let changed = (word & !mask) | (U256::from(value) << offset);
        let error = decode(changed).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{field}: {error}");
    }
}

/// A switching deployment needs explicit configuration; its absence is not a chain fault.
#[test]
fn nonzero_etna_start_requires_switch_configuration() {
    use abci::l1::layout::inbox;
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 2);
    let start = 1000;
    let g = &fixture.snapshot.genesis;
    let landing = inbox::landing_record_slots(start);
    let planted = fixture.snapshot_with_inbox_words([
        (inbox::slot(inbox::GENESIS_PACKED), U256::from(start) | (U256::from(g.l1_0) << 48)),
        (inbox::origin_slots(0)[0], U256::from(start)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(start)),
        (landing[0], U256::from(start)),
        (landing[1], g.genesis_hash.into()),
        (landing[2], U256::ZERO),
    ]);
    let decode = |params: &ChainParams| {
        super::decode_snapshot(
            planted.l1_header.clone(),
            planted.inbox_witness.clone(),
            planted.l1_chain_id,
            planted.l2_chain_id,
            params,
        )
    };
    let error = decode(&fixture.params).unwrap_err();
    assert!(matches!(error, LanderError::Configuration(_)), "{error}");
    assert!(error.to_string().contains("switch configuration"), "{error}");

    let mut configured = fixture.params.clone();
    configured.switch = Some(abci::SwitchConfig {
        unzen_inbox: alloy_primitives::Address::repeat_byte(0x41),
        fork_timestamp: 100,
        signal_service_implementation: alloy_primitives::Address::repeat_byte(0x42),
        staking_implementation: alloy_primitives::Address::repeat_byte(0x43),
    });
    let decoded = decode(&configured).unwrap();
    assert_eq!(decoded.genesis.genesis_height, start);
    assert_eq!(decoded.checkpoint_height, start);
    assert_eq!(decoded.checkpoint_hash, g.genesis_hash);
}

#[test]
fn snapshot_with_an_invalid_forced_inclusion_config_is_a_configuration_error() {
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 2);
    for (forced_inclusion_delay, max_anchor_age) in [(0, 7_200), (1, 1151), (3_600, 0)] {
        let genesis = GenesisRecord {
            forced_inclusion_delay,
            max_anchor_age,
            ..fixture.snapshot.genesis.clone()
        };
        let planted = fixture.snapshot_with_forced_queue(genesis, 0, 0);
        let error = super::decode_snapshot(
            planted.l1_header,
            planted.inbox_witness,
            planted.l1_chain_id,
            planted.l2_chain_id,
            &fixture.params,
        )
        .unwrap_err();
        assert!(matches!(error, LanderError::Configuration(_)), "{error}");
    }
}

#[tokio::test]
async fn snapshot_rejects_different_configured_l1_domain() {
    let (mut source, _l1, _l2, _) = source_with_chain_id(18, false, U256::MAX).await;
    source.params.l1_chain_id = U256::from(1);
    let error =
        source.snapshot().await.expect_err("endpoint must match the configured signing domain");
    assert!(matches!(error, LanderError::Configuration(_)), "{error}");
}

#[tokio::test]
async fn snapshot_preserves_full_uint256_l1_chain_identity() {
    let chain_id = U256::MAX;
    let (source, _l1, _l2, _) = source_with_chain_id(18, false, chain_id).await;
    assert_eq!(source.snapshot().await.unwrap().l1_chain_id, chain_id);
}

#[tokio::test]
async fn snapshot_cannot_mix_inbox_generations_config_and_checkpoint_across_live_heads() {
    let (source, l1, _l2, headers) = source(18, false).await;
    let observed = source.snapshot().await.unwrap();
    let mut expected = crate::test_utils::consensus_mpt::Fixture::new(18, 30).snapshot;
    let mut header: Header = alloy_rlp::decode_exact(expected.l1_header.raw()).unwrap();
    header.number = 20;
    header.parent_hash = headers[&19].hash();
    expected.l1_header = RawL1Header::from(&header);
    expected.l1_block_number = 20;
    expected.l1_block_hash = header.hash_slow();
    assert_eq!(observed, expected);
    let calls = l1.requests.lock().unwrap();
    assert_eq!(calls.iter().filter(|call| call["method"] == "eth_getProof").count(), 2);
    assert!(calls.iter().all(|call| call["method"] != "eth_getStorageAt"));
    assert_eq!(observed.l1_header.hash(), observed.l1_block_hash);
    let _ = headers;
}

#[tokio::test]
async fn reference_only_fetches_and_the_pure_check_rejects_contradictions() {
    let (source, _l1, _l2, headers) = source(18, false).await;
    let snapshot = snapshot(&headers);
    let anchors = vec![anchor(&headers[&12]), anchor(&headers[&15]), anchor(&headers[&15])];
    let expected = (12..=18).rev().map(|number| headers[&number].clone()).collect::<Vec<_>>();
    let fetched = source.reference(&snapshot, &anchors).await.unwrap();
    assert_eq!(fetched, expected);
    crate::batch::verify_reference_chain(&fetched, &anchors).unwrap();
    // The fetch does not compare anchors; the single pure check does (PROOF-6.2-33).
    let mut contradictory = anchors.clone();
    contradictory[1].state_root = B256::ZERO;
    let fetched = source.reference(&snapshot, &contradictory).await.unwrap();
    assert_eq!(fetched, expected);
    assert!(matches!(
        crate::batch::verify_reference_chain(&fetched, &contradictory),
        Err(LanderError::Safety(message)) if message == "reference chain contradicts anchor 15"
    ));
}

#[tokio::test]
async fn finality_lag_expired_reference_and_wrong_fork_are_distinct_errors() {
    let (source, _l1, _l2, headers) = source(12, false).await;
    let snapshot = snapshot(&headers);
    assert!(matches!(
        source.reference(&snapshot, &[anchor(&headers[&15])]).await,
        Err(LanderError::Temporary(_))
    ));
    let mut expired = snapshot;
    expired.l1_block_number = 10_000;
    assert!(matches!(
        source.validate_reference(&expired, 15, headers[&15].hash()).await,
        Err(LanderError::Stale(_))
    ));
    // A fork in the fetched chain is fetched as is and rejected by the pure link check
    // (PROOF-6.2-34).
    let (wrong, _a, _b, headers) = self::source(18, true).await;
    let anchors = [anchor(&headers[&12])];
    let forked = wrong.reference(&self::snapshot(&headers), &anchors).await.unwrap();
    assert_eq!(forked.len(), 7);
    assert!(matches!(
        crate::batch::verify_reference_chain(&forked, &anchors),
        Err(LanderError::Safety(message)) if message == "reference header ancestry is discontinuous"
    ));
}

#[tokio::test]
async fn references_older_than_blockhash_window_require_actual_history_contract_availability() {
    let headers = header_chain();
    let reference = headers[&15].clone();
    let snapshot = snapshot(&headers);
    for served in [B256::ZERO, reference.hash()] {
        let header = reference.clone();
        let expected_pin = snapshot.l1_block_hash;
        let l1 = rpc(move |request| match request["method"].as_str().unwrap() {
            "eth_getBlockByNumber" => json_header(&header),
            "eth_call" => {
                assert_eq!(
                    request["params"][0]["to"],
                    json!(alloy_primitives::address!("0000f90827f1c53a10cb7a02335b175320002935"))
                );
                assert_eq!(
                    request["params"][1],
                    json!({"blockHash":expected_pin,"requireCanonical":true})
                );
                json!(alloy_primitives::Bytes::copy_from_slice(served.as_slice()))
            }
            method => panic!("unexpected availability method {method}"),
        })
        .await;
        let source = RpcLandingSource::new(
            l1.provider.clone(),
            l1.provider.clone(),
            ChainParams::builtin(167001).unwrap(),
        );
        let mut older = snapshot.clone();
        older.l1_block_number = 300;
        let result = source.validate_reference(&older, 15, reference.hash()).await;
        if served.is_zero() {
            assert!(matches!(result, Err(LanderError::Stale(_))));
        } else {
            result.unwrap();
        }
        assert!(l1.requests.lock().unwrap().iter().any(|request| request["method"] == "eth_call"));
    }
}

/// p's anchor witness is checked against p's `extraData` before anything it proves is used: the
/// 13-byte layout, one byte short or long, the wrong generation and every fee-sharing byte other
/// than 100 are refused as `Safety`, as the sharing byte is deployment core like the generation
/// and anchor; the well-formed header accepts the witness.
#[test]
fn checkpoint_anchor_rejects_malformed_extra_data_generation_and_sharing() {
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(24, 30);
    let witness =
        abci::EtnaEnvelope::decode(&fixture.blocks[&23].block.data[0]).unwrap().anchor.unwrap();
    let well_formed = fixture.headers[&24].extra_data.to_vec();
    let mut wrong_generation = well_formed.clone();
    wrong_generation[1..7].copy_from_slice(&1u64.to_be_bytes()[2..]);
    let mut malformed = vec![vec![0; 13], vec![0; 28], vec![0; 30], wrong_generation];
    for sharing in [0, 1, 99, 101, 255] {
        let mut extra_data = well_formed.clone();
        extra_data[0] = sharing;
        malformed.push(extra_data);
    }
    let header = |extra_data: &[u8]| Header {
        extra_data: extra_data.to_vec().into(),
        ..fixture.headers[&24].clone()
    };
    for extra_data in malformed {
        let error = crate::l1::verify_checkpoint_anchor(
            &witness,
            &header(&extra_data),
            0,
            fixture.params.inbox,
        )
        .unwrap_err();
        assert!(
            matches!(error, LanderError::Safety(_)),
            "malformed checkpoint {extra_data:?} must be refused: {error}"
        );
    }
    crate::l1::verify_checkpoint_anchor(&witness, &header(&well_formed), 0, fixture.params.inbox)
        .unwrap();
}

/// The deployment reads are the checked getters and `maxBatchBlocks` only, each pinned to the
/// snapshot block; landing progress does not change them, and no pause flag is read.
#[tokio::test]
async fn v1_deployment_reads_only_checked_getters_and_max_batch_blocks() {
    use crate::contracts::IEtnaInbox;
    use alloy::sol_types::{SolCall, SolValue};
    use alloy_primitives::Bytes;
    use std::sync::atomic::{AtomicU8, Ordering};
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 12);
    let advanced = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
    let mode = Arc::new(AtomicU8::new(0));
    let control = mode.clone();
    let config = fixture.snapshot.config_hash;
    let chain_id = fixture.params.l2_chain_id;
    let hash_a = fixture.snapshot.l1_block_hash;
    let hash_b = advanced.snapshot.l1_block_hash;
    let server = rpc(move |request| {
        let mode = control.load(Ordering::Relaxed);
        let pin = request["params"].as_array().unwrap().last().unwrap();
        assert!(
            [hash_a, hash_b]
                .iter()
                .any(|hash| pin == &json!({"blockHash": hash, "requireCanonical": true}))
        );
        match request["method"].as_str().unwrap() {
            "eth_call" => {
                let input = request["params"][0]
                    .get("input")
                    .or_else(|| request["params"][0].get("data"))
                    .unwrap();
                let input: Bytes = serde_json::from_value(input.clone()).unwrap();
                macro_rules! answer {
                    ($call:ident, $value:expr) => {
                        if input.as_ref() == IEtnaInbox::$call::SELECTOR {
                            return json!(Bytes::from(($value).abi_encode()));
                        }
                    };
                }
                answer!(VERSIONCall, U256::from(if mode == 3 { 2 } else { 1 }));
                answer!(isInitializedCall, true);
                answer!(l2ChainIdCall, U256::from(chain_id));
                answer!(configHashCall, if mode == 5 { B256::ZERO } else { config });
                answer!(maxBatchBlocksCall, U256::from(120));
                panic!("invented or unexpected ABI getter: {input}");
            }
            method => panic!("unexpected deployment RPC {method}"),
        }
    })
    .await;
    let source =
        RpcLandingSource::new(server.provider.clone(), server.provider.clone(), fixture.params);
    let calls = || server.requests.lock().unwrap().len();
    for snapshot in [&fixture.snapshot, &advanced.snapshot] {
        mode.store(0, Ordering::Relaxed);
        let before = calls();
        assert_eq!(
            source.deployment(snapshot).await.unwrap(),
            crate::l1::Deployment { max_batch_blocks: 120 }
        );
        assert_eq!(calls() - before, 5, "exactly the five checked getters, no eth_getCode");
    }
    assert!(server.requests.lock().unwrap().iter().all(|request| request["method"] == "eth_call"));
    for invalid in [3, 5] {
        mode.store(invalid, Ordering::Relaxed);
        assert!(matches!(
            source.deployment(&fixture.snapshot).await,
            Err(LanderError::Configuration(_))
        ));
    }
}

/// The deployment is the one the built-in chain parameters name: an Inbox whose `configHash()`
/// commits another staking proxy, another U or another L2 chain id is refused, though every other
/// getter matches.
#[tokio::test]
async fn deployment_with_another_config_hash_is_refused() {
    use crate::contracts::IEtnaInbox;
    use alloy::sol_types::{SolCall, SolValue};
    use alloy_primitives::{Address, Bytes};
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 12);
    let params = fixture.params.clone();
    assert_eq!(fixture.snapshot.config_hash, params.config_hash());
    let others = [
        ChainParams { staking: Address::repeat_byte(0x11), ..params.clone() }.config_hash(),
        ChainParams { unsettled_limit: params.unsettled_limit + 1, ..params.clone() }.config_hash(),
        ChainParams { l2_chain_id: params.l2_chain_id + 1, ..params.clone() }.config_hash(),
    ];
    for answered in others.into_iter().chain([params.config_hash()]) {
        let chain_id = params.l2_chain_id;
        let server = rpc(move |request| {
            let input = request["params"][0]
                .get("input")
                .or_else(|| request["params"][0].get("data"))
                .unwrap();
            let input: Bytes = serde_json::from_value(input.clone()).unwrap();
            macro_rules! answer {
                ($call:ident, $value:expr) => {
                    if input.as_ref() == IEtnaInbox::$call::SELECTOR {
                        return json!(Bytes::from(($value).abi_encode()));
                    }
                };
            }
            answer!(VERSIONCall, U256::from(1));
            answer!(isInitializedCall, true);
            answer!(l2ChainIdCall, U256::from(chain_id));
            answer!(configHashCall, answered);
            answer!(maxBatchBlocksCall, U256::from(120));
            panic!("unexpected deployment getter: {input}");
        })
        .await;
        let source =
            RpcLandingSource::new(server.provider.clone(), server.provider.clone(), params.clone());
        let result = source.deployment(&fixture.snapshot).await;
        if answered == params.config_hash() {
            assert_eq!(result.unwrap(), crate::l1::Deployment { max_batch_blocks: 120 });
        } else {
            assert!(
                matches!(&result, Err(LanderError::Configuration(_))),
                "another deployment's configuration hash {answered}: {result:?}"
            );
        }
    }
}

/// R's anchor slots and raw header as an L1 endpoint serves them, from the recovery fixture.
fn r_witness(f: &crate::test_utils::consensus_mpt::Fixture) -> abci::AnchorWitness {
    abci::AnchorWitness {
        l1_header: f.l1_headers[&20].clone(),
        inbox: f.import_witness(f.params.inbox, &abci::l1::layout::inbox::anchor_slots(), 20),
    }
}

/// After a recovery the origin anchor is R, read at the origin record's L1 block, whatever the
/// checkpoint's own header names.
#[tokio::test]
async fn recovery_rpc_origin_anchor_reads_r() {
    let f = crate::test_utils::consensus_mpt::recovery::fixture(6, 6, 12).await;
    let expected = crate::batch::recovery_anchor(&f.snapshot).unwrap();
    let witness = r_witness(&f);
    let l1 = rpc(move |request| match request["method"].as_str().unwrap() {
        "eth_getBlockByNumber" => {
            assert_eq!(request["params"][0], "0x14");
            json_header(&witness.l1_header)
        }
        "debug_getRawHeader" => json!(witness.l1_header.raw()),
        "eth_getProof" => {
            let mut proof = witness.inbox.clone();
            proof
                .storage
                .retain(|s| request["params"][1].as_array().unwrap().contains(&json!(s.slot)));
            proof_json(&proof)
        }
        other => panic!("unexpected recovery L1 request: {other}"),
    })
    .await;
    let source = RpcLandingSource::new(l1.provider.clone(), l1.provider.clone(), f.params.clone());
    let observed = source.origin_anchor(&f.snapshot).await.unwrap();
    assert_eq!(observed, expected);
    assert_eq!(observed.number, 20);
}

/// The starting Inbox proof is one EIP-1186 read of exactly the starting slots of the snapshot's
/// generation, pinned to the reference header's canonical hash, and carries that header.
#[tokio::test]
async fn starting_witness_is_read_at_the_reference_hash() {
    let f = crate::test_utils::consensus_mpt::recovery::fixture(6, 12, 18).await;
    let reference = f.l1_headers[&22].clone();
    let slots = crate::l1::starting_slots(2);
    let served = f.import_witness(f.params.inbox, &slots, 22);
    let pin = reference.hash();
    let expected_slots = slots.clone();
    let answer = served.clone();
    let l1 = rpc(move |request| match request["method"].as_str().unwrap() {
        "eth_getProof" => {
            assert_eq!(request["params"][0], json!(answer.address));
            assert_eq!(request["params"][1], json!(expected_slots));
            assert_eq!(request["params"][2], json!({"blockHash": pin, "requireCanonical": true}));
            proof_json(&answer)
        }
        other => panic!("unexpected starting proof request: {other}"),
    })
    .await;
    let source = RpcLandingSource::new(l1.provider.clone(), l1.provider.clone(), f.params.clone());
    let witness = source.starting_inbox_witness(&reference, 2).await.unwrap();
    assert_eq!(witness, abci::AnchorWitness { l1_header: reference.clone(), inbox: served });
    let (_, origin) =
        crate::l1::verify_starting_inbox(&witness, &reference, 2, f.params.inbox).unwrap();
    assert_eq!(origin, crate::l1::snapshot_origin(&f.snapshot).unwrap());
    assert_eq!(l1.requests.lock().unwrap().len(), 1);
}

#[tokio::test]
async fn recovery_finality_waits_for_proven_generation_and_rejects_tampering() {
    for (requested, tamper) in [(1, false), (2, false), (3, false), (2, true)] {
        let f = crate::test_utils::consensus_mpt::recovery::fixture(6, 6, 12).await;
        let witness = r_witness(&f);
        let l1 = rpc(move |request| match request["method"].as_str().unwrap() {
            "eth_getBlockByNumber" => json_header(&witness.l1_header),
            "debug_getRawHeader" => json!(witness.l1_header.raw()),
            "eth_getProof" => {
                let mut proof = witness.inbox.clone();
                proof
                    .storage
                    .retain(|s| request["params"][1].as_array().unwrap().contains(&json!(s.slot)));
                if tamper {
                    proof
                        .storage
                        .iter_mut()
                        .find(|s| {
                            s.slot ==
                                abci::l1::layout::inbox::slot(
                                    abci::l1::layout::inbox::RECOVERY_GENERATION,
                                )
                        })
                        .unwrap()
                        .value += U256::from(1);
                }
                proof_json(&proof)
            }
            other => panic!("unexpected finality request: {other}"),
        })
        .await;
        let source = RpcLandingSource::new(l1.provider.clone(), l1.provider.clone(), f.params);
        let result = source.recovery_finality(requested).await;
        if tamper {
            assert!(matches!(result, Err(LanderError::Safety(_))));
        } else if requested != 2 {
            assert!(matches!(result, Err(LanderError::Temporary(_))), "{result:?}");
        } else {
            result.unwrap();
        }
    }
}

/// The Etna start of the start-checkpoint scenarios.
const SWITCH_S: u64 = 7;
/// Their L1 SignalService.
const L1_SIGNAL_SERVICE: alloy_primitives::Address = alloy_primitives::Address::repeat_byte(0x43);

/// What the start-checkpoint check's own L1 serves: the EtnaInbox's `signalService()` and
/// SignalService's checkpoint at S.
#[derive(Clone)]
struct SwitchL1 {
    signal_service: alloy_primitives::Address,
    /// SignalService's checkpoint at S as `(height, hash, state root)`; `None` reverts as
    /// SignalService does for a missing one.
    checkpoint: Option<(u64, B256, B256)>,
}

/// A snapshot at L1 block 20 whose latest checkpoint is S, switching chain parameters, and an L1
/// whose root-only SignalService holds S's start state root under S, with a zero hash.
fn switch_case() -> (BTreeMap<u64, RawL1Header>, LandingSnapshot, ChainParams, SwitchL1) {
    let headers = header_chain();
    let mut snapshot = snapshot(&headers);
    snapshot.genesis.genesis_height = SWITCH_S;
    snapshot.checkpoint_height = SWITCH_S;
    let mut params = ChainParams::builtin(167001).unwrap();
    params.switch = Some(abci::SwitchConfig {
        unzen_inbox: alloy_primitives::Address::repeat_byte(0x41),
        fork_timestamp: 200,
        signal_service_implementation: alloy_primitives::Address::repeat_byte(0x42),
        staking_implementation: alloy_primitives::Address::repeat_byte(0x43),
    });
    let genesis = &snapshot.genesis;
    let l1 = SwitchL1 {
        signal_service: L1_SIGNAL_SERVICE,
        checkpoint: Some((SWITCH_S, B256::ZERO, genesis.genesis_state_root)),
    };
    (headers, snapshot, params, l1)
}

/// Serves `headers` and the switch facts `l1` holds when each request arrives, asserting that
/// every contract read is pinned to the canonical hash `pin`. Any other contract read, such as
/// one of the Unzen Inbox, fails the test.
async fn switch_rpc(
    headers: BTreeMap<u64, RawL1Header>,
    inbox: alloy_primitives::Address,
    pin: B256,
    l1: Arc<Mutex<SwitchL1>>,
) -> RpcFixture {
    use crate::{contracts::IEtnaInbox, l1::ISwitchCheckpointStore};
    use alloy::sol_types::{SolCall, SolValue};
    use alloy_primitives::{Address, Bytes, aliases::U48};
    rpc(move |request| {
        let number = |value: &Value| {
            u64::from_str_radix(value.as_str().unwrap().trim_start_matches("0x"), 16).unwrap()
        };
        let params = &request["params"];
        let l1 = l1.lock().unwrap().clone();
        match request["method"].as_str().unwrap() {
            "eth_getBlockByNumber" => json_header(&headers[&number(&params[0])]),
            "eth_call" => {
                assert_eq!(params[1], json!({"blockHash": pin, "requireCanonical": true}));
                let to: Address = serde_json::from_value(params[0]["to"].clone()).unwrap();
                let data: Bytes = serde_json::from_value(params[0]["data"].clone()).unwrap();
                let answer = if to == inbox && data[..] == IEtnaInbox::signalServiceCall::SELECTOR {
                    l1.signal_service.abi_encode()
                } else if to == l1.signal_service {
                    let call = ISwitchCheckpointStore::getCheckpointCall {
                        blockNumber: U48::from(SWITCH_S),
                    };
                    assert_eq!(data, call.abi_encode(), "the checkpoint at S");
                    let Some((number, hash, root)) = l1.checkpoint else {
                        return json!({"__rpc_error": {"code": 3, "message": "execution reverted"}});
                    };
                    ISwitchCheckpointStore::getCheckpointCall::abi_encode_returns(
                        &ISwitchCheckpointStore::Checkpoint {
                            blockNumber: U48::from(number),
                            blockHash: hash,
                            stateRoot: root,
                        },
                    )
                } else {
                    panic!("unexpected start-checkpoint call to {to}: {data}")
                };
                json!(Bytes::from(answer))
            }
            other => panic!("unexpected start-checkpoint method {other}"),
        }
    })
    .await
}

/// The contract reads a start-checkpoint check made, by target.
fn switch_calls(l1: &RpcFixture, to: alloy_primitives::Address) -> usize {
    l1.requests
        .lock()
        .unwrap()
        .iter()
        .filter(|request| {
            request["method"] == "eth_call" && request["params"][0]["to"] == json!(to)
        })
        .count()
}

/// At s = S, SignalService's checkpoint at S holds the start state root, read at the snapshot.
/// The check reads nothing of the Unzen Inbox: the start write already required closed,
/// finalized Unzen proposals.
#[tokio::test]
async fn start_checkpoint_matches_s_and_its_state_root_without_unzen_reads() {
    let (headers, snapshot, params, facts) = switch_case();
    let facts = Arc::new(Mutex::new(facts));
    let l1 = switch_rpc(headers, params.inbox, snapshot.l1_block_hash, facts).await;
    let source = abci::l1::source::RpcL1Source::new(l1.provider.clone());
    super::verify_start_checkpoint(&source, &params, &snapshot).await.unwrap();
    assert_eq!(switch_calls(&l1, params.inbox), 1);
    assert_eq!(switch_calls(&l1, L1_SIGNAL_SERVICE), 1);
    assert_eq!(l1.requests.lock().unwrap().len(), 2, "only the two checkpoint reads");
    // A network without a switch has nothing to check.
    let fresh = ChainParams { switch: None, ..params.clone() };
    super::verify_start_checkpoint(&source, &fresh, &snapshot).await.unwrap();
    assert_eq!(l1.requests.lock().unwrap().len(), 2);
}

/// The root-only SignalService returns a zero hash at every height, so the check reads only the
/// height and state root: S's root passes under a zero hash or any other, and another root
/// halts even under S's own hash.
#[tokio::test]
async fn start_checkpoint_reads_the_state_root_and_never_the_hash() {
    let (headers, snapshot, params, facts) = switch_case();
    let honest = facts.clone();
    let facts = Arc::new(Mutex::new(facts));
    let l1 = switch_rpc(headers, params.inbox, snapshot.l1_block_hash, facts.clone()).await;
    let source = abci::l1::source::RpcL1Source::new(l1.provider.clone());
    let (s, hash, root) = honest.checkpoint.unwrap();
    assert!(hash.is_zero(), "the root-only SignalService returns no hash");
    for any in [B256::ZERO, snapshot.genesis.genesis_hash, B256::repeat_byte(0x99)] {
        *facts.lock().unwrap() = SwitchL1 { checkpoint: Some((s, any, root)), ..honest.clone() };
        super::verify_start_checkpoint(&source, &params, &snapshot).await.unwrap();
    }
    let other = B256::repeat_byte(0x99);
    for hash in [B256::ZERO, snapshot.genesis.genesis_hash] {
        *facts.lock().unwrap() = SwitchL1 { checkpoint: Some((s, hash, other)), ..honest.clone() };
        let error = super::verify_start_checkpoint(&source, &params, &snapshot).await.unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
    }
}

/// A missing checkpoint at S (SignalService reverts) is retryable; an Inbox naming no
/// SignalService is a configuration error.
#[tokio::test]
async fn start_checkpoint_missing_is_retryable_and_a_zero_signal_service_is_refused() {
    let (headers, snapshot, params, facts) = switch_case();
    let honest = facts.clone();
    let facts = Arc::new(Mutex::new(facts));
    let l1 = switch_rpc(headers, params.inbox, snapshot.l1_block_hash, facts.clone()).await;
    let source = abci::l1::source::RpcL1Source::new(l1.provider.clone());
    facts.lock().unwrap().checkpoint = None;
    let error = super::verify_start_checkpoint(&source, &params, &snapshot).await.unwrap_err();
    assert!(matches!(error, LanderError::Temporary(_)), "{error}");
    *facts.lock().unwrap() = SwitchL1 { signal_service: alloy_primitives::Address::ZERO, ..honest };
    let error = super::verify_start_checkpoint(&source, &params, &snapshot).await.unwrap_err();
    assert!(matches!(error, LanderError::Configuration(_)), "{error}");
}

/// A SignalService checkpoint at S whose height or state root differs from the start record,
/// or whose state root is zero, is an authenticated contradiction.
#[tokio::test]
async fn start_checkpoint_halts_on_a_contradicting_checkpoint() {
    let (headers, snapshot, params, facts) = switch_case();
    let honest = facts.clone();
    let facts = Arc::new(Mutex::new(facts));
    let l1 = switch_rpc(headers, params.inbox, snapshot.l1_block_hash, facts.clone()).await;
    let source = abci::l1::source::RpcL1Source::new(l1.provider.clone());
    let (s, hash, root) = honest.checkpoint.unwrap();
    let other = B256::repeat_byte(0x99);
    let contradictions = [
        SwitchL1 { checkpoint: Some((s, hash, other)), ..honest.clone() },
        SwitchL1 { checkpoint: Some((s, hash, B256::ZERO)), ..honest.clone() },
        SwitchL1 { checkpoint: Some((s + 1, hash, root)), ..honest },
    ];
    for contradiction in contradictions {
        *facts.lock().unwrap() = contradiction;
        let error = super::verify_start_checkpoint(&source, &params, &snapshot).await.unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
    }
}

/// Staking words that use every bit of their slots: a `snapshotHeight` with bit 255 set above
/// the height, a total stake of 2^256 − 1, seat 0's packed word with bit 72 set above its power,
/// and the first origin key's key-to-seat word with bit 16 set.
fn full_width_staking_words(height: u64, keys: &abci::fallback::FallbackKeys) -> Vec<(B256, U256)> {
    use abci::staking::{
        key_to_seat_slot, record_slots, snapshot_height_slot, snapshot_total_stake_slot,
    };
    let mut words = crate::test_utils::consensus_mpt::staking_words(height, keys);
    let packed = words.iter().find(|(slot, _)| *slot == record_slots(0)[1]).unwrap().1;
    words.extend([
        (snapshot_height_slot(), U256::from(height) | U256::from(1) << 255),
        (snapshot_total_stake_slot(), U256::MAX),
        (record_slots(0)[1], packed | U256::from(1) << 72),
        (key_to_seat_slot(keys.keys()[0].address()), U256::from(0x10001)),
    ]);
    words
}

/// The snapshot and key-to-seat words of `missing` that the planted `(slot, word)` pairs hold,
/// read straight from the pairs rather than through any proof.
fn planted(
    words: Vec<(B256, U256)>,
    missing: &[Address],
) -> (abci::staking::StakingWords, BTreeMap<Address, U256>) {
    let words = words.into_iter().collect::<BTreeMap<_, _>>();
    let word = |slot: B256| words.get(&slot).copied().unwrap_or_default();
    let values = abci::staking::snapshot_slots().map(word);
    (
        abci::staking::StakingWords::from_snapshot_values(&values).unwrap(),
        missing.iter().map(|a| (*a, word(abci::staking::key_to_seat_slot(*a)))).collect(),
    )
}

/// The addresses whose key-to-seat words the staking tests read: the fixture's two origin keys,
/// which hold seats 0 and 1, then an address that holds no seat.
fn missing_addresses(fixture: &crate::test_utils::consensus_mpt::Fixture) -> Vec<Address> {
    let mut missing =
        fixture.origin_keys.keys().iter().map(|key| key.address()).collect::<Vec<_>>();
    missing.push(Address::repeat_byte(0x99));
    missing
}

/// The L2 endpoint answers `eth_getProof` of the staking proxy pinned to a block's canonical hash
/// with the proofs of exactly the requested slots, and the words they prove are taken whole from
/// that block's post-state: they verify under the state root of the EL header with that hash and
/// under no other height's root.
#[tokio::test]
async fn staking_witness_verifies_against_the_header_state_root() {
    use crate::l1::{staking_slots, verify_staking_witness};
    let fixture = crate::test_utils::consensus_mpt::Fixture::with_staking_script(
        0,
        8,
        full_width_staking_words,
    );
    let params = fixture.params.clone();
    let states = fixture
        .headers
        .iter()
        .map(|(height, header)| (header.hash_slow(), fixture.l2_states[height].clone()))
        .collect::<BTreeMap<_, _>>();
    let staking = params.staking;
    let l2 = rpc(move |request| {
        assert_eq!(request["method"], "eth_getProof");
        assert_eq!(request["params"][0], json!(staking));
        let hash: B256 = serde_json::from_value(request["params"][2]["blockHash"].clone()).unwrap();
        assert_eq!(request["params"][2], json!({"blockHash": hash, "requireCanonical": true}));
        let slots: Vec<B256> = serde_json::from_value(request["params"][1].clone()).unwrap();
        proof_json(&states[&hash].witness(staking, &slots))
    })
    .await;
    let source = RpcLandingSource::new(l2.provider.clone(), l2.provider.clone(), params);
    let missing = missing_addresses(&fixture);
    let slots = staking_slots(&missing);
    assert_eq!(slots.len(), abci::staking::SNAPSHOT_SLOT_COUNT + missing.len());
    for height in [1, 5, 8] {
        let header = &fixture.headers[&height];
        let witness = source.staking_witness(header.hash_slow(), &slots).await.unwrap();
        let request = l2.requests.lock().unwrap().last().unwrap().clone();
        assert_eq!(request["params"][1], json!(slots), "the exact slot list, in order");
        let proven =
            verify_staking_witness(header.state_root, staking, &witness, height, &missing).unwrap();
        let expected = planted(full_width_staking_words(height, &fixture.origin_keys), &missing);
        assert_eq!(proven, expected, "height {height}");
        assert_eq!(proven.0.snapshot_height, U256::from(height) | U256::from(1) << 255);
        assert_eq!(proven.0.total_stake, U256::MAX);
        assert_eq!(proven.1[&missing[0]], U256::from(0x10001));
        assert_eq!(proven.1[&missing[2]], U256::ZERO, "an address holding no seat");
        let other = &fixture.headers[&(height - 1)];
        let error = verify_staking_witness(other.state_root, staking, &witness, height, &missing)
            .unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "{error}");
    }
}

/// A staking proof carrying any word other than the one its root holds is a safety error: a
/// snapshot header word, a seat record word, a key-to-seat word and a word proven absent.
#[test]
fn tampered_value_is_safety() {
    use crate::l1::{staking_slots, verify_staking_witness};
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 4);
    let missing = missing_addresses(&fixture);
    let slots = staking_slots(&missing);
    let (root, staking) = (fixture.headers[&3].state_root, fixture.params.staking);
    let honest = fixture.l2_states[&3].witness(staking, &slots);
    verify_staking_witness(root, staking, &honest, 3, &missing).unwrap();
    // snapshotHeight, seat 0's packed power word, seat 1's `ckX`, the first key-to-seat word,
    // an empty seat's `ckX`, proven absent, and the absent key-to-seat word of the address that
    // holds no seat.
    for index in [0, 3, 4, 258, 10, slots.len() - 1] {
        let mut tampered = honest.clone();
        tampered.storage[index].value ^= U256::from(1);
        let error = verify_staking_witness(root, staking, &tampered, 3, &missing).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "slot {index}: {error}");
    }
}

/// A staking proof that leaves out a requested slot, answers fewer key-to-seat words than
/// addresses asked for, or proves the slots in another order is a safety error.
#[test]
fn missing_slot_is_safety() {
    use crate::l1::{staking_slots, verify_staking_witness};
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 4);
    let missing = missing_addresses(&fixture);
    let slots = staking_slots(&missing);
    let (root, staking) = (fixture.headers[&3].state_root, fixture.params.staking);
    let honest = fixture.l2_states[&3].witness(staking, &slots);
    for index in [0, 1, 100, 257, 258, slots.len() - 1] {
        let mut short = honest.clone();
        short.storage.remove(index);
        let error = verify_staking_witness(root, staking, &short, 3, &missing).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "slot {index}: {error}");
    }
    let fewer = fixture.l2_states[&3].witness(staking, &staking_slots(&missing[..1]));
    let error = verify_staking_witness(root, staking, &fewer, 3, &missing).unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
    let mut reordered = honest;
    reordered.storage.swap(258, 259);
    let error = verify_staking_witness(root, staking, &reordered, 3, &missing).unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
}

/// A genuine proof of another account under the same root, holding exactly the staking proxy's
/// storage, is a safety error, as is that proof relabeled with the proxy's address.
#[test]
fn wrong_account_is_safety() {
    use crate::{
        l1::{staking_slots, verify_staking_witness},
        test_utils::consensus_mpt::{Fixture, State, staking_words},
    };
    let fixture = Fixture::new(0, 4);
    let staking = fixture.params.staking;
    let other = Address::repeat_byte(0x55);
    let words = staking_words(3, &fixture.origin_keys);
    let state = State::new(vec![(staking, words.clone()), (other, words)]);
    let missing = missing_addresses(&fixture);
    let slots = staking_slots(&missing);
    verify_staking_witness(state.root, staking, &state.witness(staking, &slots), 3, &missing)
        .unwrap();
    let decoy = state.witness(other, &slots);
    abci::l1::mpt::verify_account_witness(state.root, &decoy, &slots)
        .expect("the other account's own proof verifies under the root");
    let error = verify_staking_witness(state.root, staking, &decoy, 3, &missing).unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
    let mut relabeled = decoy;
    relabeled.address = staking;
    let error = verify_staking_witness(state.root, staking, &relabeled, 3, &missing).unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
}

/// An L2 state without the staking proxy's account holds no snapshot: a complete exclusion
/// proof of the account reads every word zero, so the fallback keys sign, whether the endpoint
/// reports the absent account's code hash as `keccak256("")` or as zero, and in an empty state.
#[test]
fn absent_staking_account_reads_zero_words() {
    use crate::{
        l1::{staking_slots, verify_staking_witness},
        test_utils::consensus_mpt::{Fixture, State, staking_words},
    };
    let fixture = Fixture::new(0, 4);
    let staking = fixture.params.staking;
    let missing = missing_addresses(&fixture);
    let slots = staking_slots(&missing);
    let state =
        State::new(vec![(Address::repeat_byte(0x55), staking_words(5, &fixture.origin_keys))]);
    let empty = State::new(vec![]);
    assert_eq!(empty.root, alloy_trie::EMPTY_ROOT_HASH);
    let zero = (
        abci::staking::StakingWords::header_only(U256::ZERO, U256::ZERO),
        missing.iter().map(|address| (*address, U256::ZERO)).collect::<BTreeMap<_, _>>(),
    );
    for state in [state, empty] {
        let mut witness = state.witness(staking, &slots);
        for code_hash in [alloy_primitives::KECCAK256_EMPTY, B256::ZERO] {
            witness.code_hash = code_hash;
            let proven =
                verify_staking_witness(state.root, staking, &witness, 5, &missing).unwrap();
            assert_eq!(proven, zero);
            let decided = abci::committee::decide(5, &proven.0, U256::ZERO, &fixture.origin_keys);
            assert_eq!(decided.source, abci::committee::SignerSource::Fallback);
        }
    }
}

/// A claim that the staking proxy's account is absent from a root that holds it is a safety
/// error: an exclusion proof from another state, every truncation of the account's own proof,
/// and, under a root that does lack it, a nonzero word or another slot list claimed beside a
/// genuine exclusion proof.
#[test]
fn forged_absence_is_safety() {
    use crate::{
        l1::{staking_slots, verify_staking_witness},
        test_utils::consensus_mpt::{Fixture, State, staking_words},
    };
    let fixture = Fixture::new(0, 4);
    let staking = fixture.params.staking;
    let missing = missing_addresses(&fixture);
    let slots = staking_slots(&missing);
    let root = fixture.headers[&3].state_root;
    let present = fixture.l2_states[&3].witness(staking, &slots);
    let other =
        State::new(vec![(Address::repeat_byte(0x55), staking_words(3, &fixture.origin_keys))]);
    let absent = other.witness(staking, &slots);
    verify_staking_witness(other.root, staking, &absent, 3, &missing).unwrap();
    let mut forgeries = vec![absent.clone()];
    for len in 0..present.account_proof.len() {
        let mut truncated = absent.clone();
        truncated.account_proof = present.account_proof[..len].to_vec();
        forgeries.push(truncated);
    }
    for (index, forged) in forgeries.iter().enumerate() {
        let error = verify_staking_witness(root, staking, forged, 3, &missing).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "forgery {index}: {error}");
    }
    for index in [0, 258, slots.len() - 1] {
        let mut claimed = absent.clone();
        claimed.storage[index].value = U256::from(1);
        let error = verify_staking_witness(other.root, staking, &claimed, 3, &missing).unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)), "slot {index}: {error}");
    }
    let fewer = other.witness(staking, &staking_slots(&missing[..1]));
    let error = verify_staking_witness(other.root, staking, &fewer, 3, &missing).unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
}

/// A staking proof the L2 endpoint does not give, as for pruned state or an unknown hash, or
/// answers with `null`, is the endpoint's own fault: [`LanderError::Temporary`], rendering no
/// endpoint detail, never a value.
#[tokio::test]
async fn unavailable_proof_is_temporary() {
    let secret = "https://alice:password@example.invalid/api_key=secret";
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 4);
    for answer in [
        json!({"__rpc_error":{"code":-32000,"message":format!("missing trie node {secret}")}}),
        json!({"__rpc_error":{"code":-32001,"message":"header not found","data":secret}}),
        json!(null),
    ] {
        let l2 = rpc(move |request| {
            assert_eq!(request["method"], "eth_getProof");
            answer.clone()
        })
        .await;
        let source =
            RpcLandingSource::new(l2.provider.clone(), l2.provider.clone(), fixture.params.clone());
        let error = source
            .staking_witness(fixture.headers[&3].hash_slow(), &crate::l1::staking_slots(&[]))
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Temporary(_)), "{error}");
        for part in ["alice", "password", "api_key", "secret"] {
            assert!(!error.to_string().contains(part), "{error}");
        }
    }
}

/// A fallback key list is accepted only under its own hash: one the L1 answers under another
/// list's hash is refused as `Safety`, and one the L1 cannot give is temporary.
#[tokio::test]
async fn fallback_list_is_accepted_only_under_its_own_hash() {
    use crate::{
        l1::obtain_fallback_list,
        test_utils::consensus::{SigningKey, fallback_keys},
    };
    let list = |seeds: &[u8]| {
        let keys = seeds.iter().map(|seed| SigningKey::from_slice(&[*seed; 32]).unwrap());
        fallback_keys(&keys.collect::<Vec<_>>())
    };
    let (a, b) = (list(&[3]), list(&[4, 5]));
    let forged = B256::repeat_byte(0xdd);
    let mut fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 12);
    fixture.fallback_lists.insert(a.hash(), a.clone());
    fixture.fallback_lists.insert(forged, b);
    let anchor = fixture.anchors[&1].clone();
    let obtain = |hash| obtain_fallback_list(&fixture, hash, anchor.hash, anchor.number);
    assert_eq!(obtain(a.hash()).await.unwrap(), a);
    let error = obtain(forged).await.unwrap_err();
    assert!(matches!(error, LanderError::Safety(_)), "{error}");
    let error = obtain(B256::repeat_byte(0xee)).await.unwrap_err();
    assert!(matches!(error, LanderError::Temporary(_)), "{error}");
}
