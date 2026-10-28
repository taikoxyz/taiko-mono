use crate::{
    LanderError,
    l1::{LandingSource, RpcLandingSource},
    types::LandingSnapshot,
};
use abci::{AnchorState, ChainParams, GenesisRecord, InboxFacts, l1::header::RawL1Header};
use alloy_consensus::Header;
use alloy_primitives::{B256, U256};
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
    for error in errors {
        assert!(error.is_retryable());
        for secret in ["alice", "password", "private-key-path", "api_key", "secret"] {
            assert!(!error.to_string().contains(secret), "L1 error exposed {secret}");
        }
    }
}

#[tokio::test]
async fn committee_discovery_errors_never_render_wrapped_rpc_credentials() {
    let sensitive = "https://alice:password@example.invalid/private-key-path?api_key=secret";
    let provider = rpc(move |_| json!({"__rpc_error":{"code":-32603,"message":sensitive}})).await;
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
    let source =
        RpcLandingSource::new(provider.provider.clone(), provider.provider.clone(), fixture.params);
    let proving_anchor = anchor(&fixture.snapshot.l1_header);
    let error =
        source.committee_witness(&proving_anchor, proving_anchor.number, 1).await.unwrap_err();
    assert!(error.is_retryable());
    assert!(!provider.requests.lock().unwrap().is_empty());
    for secret in ["alice", "password", "private-key-path", "api_key", "secret"] {
        assert!(!error.to_string().contains(secret), "committee error exposed {secret}");
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
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::repeat_byte(1),
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
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
        registry: params.registry,
        generation: 0,
        checkpoint_height: 0,
        checkpoint_hash: B256::repeat_byte(1),
        checkpoint_comet_hash: B256::ZERO,
        forced_inclusion_head: 0,
        forced_inclusion_tail: 0,
        genesis: GenesisRecord {
            committee_config_hash: B256::repeat_byte(3),
            genesis_height: 0,
            l1_0: 10,
            epoch_len: 20,
            genesis_hash: B256::repeat_byte(1),
            genesis_state_root: B256::repeat_byte(2),
            genesis_cutoff: 9,
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        },
        committee_config_hash: B256::repeat_byte(3),
        genesis_committee_record_hash: B256::repeat_byte(6),
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

/// As [`snapshot_rpc`], but the first `stale_proofs` head proofs come from the other trie, as an
/// endpoint answers while the next block is still extending the head's state.
pub(crate) async fn snapshot_rpc_with(
    reorg: bool,
    before_raw: bool,
    malformed: bool,
    stale_proofs: usize,
) -> SnapshotRpc {
    snapshot_rpc_with_delay(reorg, before_raw, malformed, stale_proofs, Duration::ZERO).await
}

/// A source whose first proof response arrives after a controlled latency.
async fn snapshot_rpc_with_delay(
    reorg: bool,
    before_raw: bool,
    malformed: bool,
    stale_proofs: usize,
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
    let stale = Mutex::new(stale_proofs);
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
                let mut stale = stale.lock().unwrap();
                let from_b = *switched || *stale > 0;
                *stale = stale.saturating_sub(1);
                let mut witness = if from_b { answer_b.inbox_witness.clone() } else { answer_a.inbox_witness.clone() };
                witness.storage.retain(|s| request["params"][1].as_array().unwrap().contains(&json!(s.slot)));
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
            assert!(matches!(call["params"][1].as_array().unwrap().len(), 15 | 18));
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
    let rpc = snapshot_rpc_with_delay(false, false, false, 1, Duration::from_millis(50)).await;
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
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 2);
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
async fn reference_later_than_last_anchor_authenticates_inherited_and_parent_context() {
    let (source, _l1, _l2, headers) = source(18, false).await;
    let snapshot = snapshot(&headers);
    let anchors = vec![anchor(&headers[&12]), anchor(&headers[&15]), anchor(&headers[&15])];
    let verified = source.reference(&snapshot, &anchors).await.unwrap();
    assert_eq!(verified[0].number(), 18);
    assert_eq!(verified.last().unwrap().number(), 12);
    assert_eq!(verified.len(), 7);
    let mut contradictory = anchors.clone();
    contradictory[1].state_root = B256::ZERO;
    assert!(matches!(
        source.reference(&snapshot, &contradictory).await,
        Err(LanderError::Safety(_))
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
    let (wrong, _a, _b, headers) = self::source(18, true).await;
    assert!(matches!(
        wrong.reference(&self::snapshot(&headers), &[anchor(&headers[&12])]).await,
        Err(LanderError::Safety(_))
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

#[tokio::test]
async fn checkpoint_anchor_rejects_legacy_sharing_and_malformed_generation() {
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
    let provider =
        rpc(|_| json!({"__rpc_error":{"code":-32603,"message":"unexpected anchor lookup"}})).await;
    let source =
        RpcLandingSource::new(provider.provider.clone(), provider.provider.clone(), fixture.params);
    let snapshot = fixture.snapshot;
    let mut inputs = vec![vec![0; 12], vec![0; 14]];
    for sharing in [0, 1, 255] {
        let mut bytes = vec![0; 13];
        bytes[0] = sharing;
        inputs.push(bytes);
    }
    let mut wrong_generation = vec![0; 13];
    wrong_generation[1..7].copy_from_slice(&(snapshot.generation + 1).to_be_bytes()[2..]);
    inputs.push(wrong_generation);
    for extra_data in inputs {
        let parent = crate::l1::ParentContext {
            header: Header {
                number: 1,
                extra_data: extra_data.clone().into(),
                ..Default::default()
            },
            grandparent_timestamp: 0,
        };
        let error = source.parent_anchor(&snapshot, &parent).await.unwrap_err();
        assert!(
            matches!(error, LanderError::Safety(_)),
            "malformed checkpoint {extra_data:?} must be rejected before RPC: {error}"
        );
    }
}

/// Pause/checkpoint changes do not change settlement authorization; code/config changes do.
#[tokio::test]
async fn v1_deployment_identity_uses_real_pinned_boundaries_and_ignores_pause_and_progress() {
    use crate::contracts::IEtnaInbox;
    use alloy::sol_types::{SolCall, SolValue};
    use alloy_primitives::{Address, Bytes};
    use std::sync::atomic::{AtomicU8, Ordering};
    let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 12);
    let advanced = crate::test_utils::consensus_mpt::Fixture::new(18, 30);
    let mode = Arc::new(AtomicU8::new(0));
    let control = mode.clone();
    let config = fixture.snapshot.committee_config_hash;
    let registry = fixture.params.registry;
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
            "eth_getCode" => {
                assert_eq!(request["params"][0], json!(Address::repeat_byte(0x42)));
                json!(Bytes::from(if mode == 4 {
                    vec![]
                } else {
                    vec![0x60, if mode == 2 { 1 } else { 0 }]
                }))
            }
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
                answer!(stakingRegistryCall, registry);
                answer!(committeeConfigHashCall, if mode == 5 { B256::ZERO } else { config });
                answer!(GRID_INTERVALCall, U256::from(if mode == 7 { 12 } else { 6 }));
                answer!(
                    implCall,
                    if mode == 6 { Address::ZERO } else { Address::repeat_byte(0x42) }
                );
                answer!(proofVerifierCall, Address::repeat_byte(0x43));
                answer!(signalServiceCall, Address::repeat_byte(0x44));
                answer!(maxBatchBlocksCall, U256::from(120));
                answer!(forcedInclusionFeeInGweiCall, U256::from(1));
                answer!(forcedInclusionFeeDoubleThresholdCall, U256::from(10));
                answer!(protocolFeeRecipientCall, Address::repeat_byte(0x45));
                // Even though this deployment can be paused, landing is not pause-gated.
                answer!(pausedCall, mode == 1);
                panic!("invented or unexpected ABI getter: {input}");
            }
            method => panic!("unexpected identity RPC {method}"),
        }
    })
    .await;
    let source =
        RpcLandingSource::new(server.provider.clone(), server.provider.clone(), fixture.params);
    let original = source.deployment_identity(&fixture.snapshot).await.unwrap();
    mode.store(1, Ordering::Relaxed);
    assert_eq!(source.deployment_identity(&fixture.snapshot).await.unwrap(), original);
    assert_eq!(source.deployment_identity(&advanced.snapshot).await.unwrap(), original);
    mode.store(2, Ordering::Relaxed);
    assert_ne!(source.deployment_identity(&fixture.snapshot).await.unwrap(), original);
    for invalid in [3, 4, 5, 6, 7] {
        mode.store(invalid, Ordering::Relaxed);
        assert!(matches!(
            source.deployment_identity(&fixture.snapshot).await,
            Err(LanderError::Configuration(_))
        ));
    }
}
