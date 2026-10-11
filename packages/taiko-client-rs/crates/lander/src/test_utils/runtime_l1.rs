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
            status: 3,
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::repeat_byte(1),
            committee: None,
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
        genesis: GenesisRecord {
            genesis_height: 0,
            l1_0: 10,
            epoch_len: 20,
            epoch_len_l1: 1,
            genesis_hash: B256::repeat_byte(1),
            genesis_state_root: B256::repeat_byte(2),
            genesis_cutoff: 9,
        },
        start_committee_record_hash: B256::repeat_byte(3),
    }
}
async fn source(
    finalized: u64,
    wrong_parent: bool,
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
    let pin = answers[&20].hash();
    let l1 = rpc(move |request| match request["method"].as_str().unwrap() {
        "eth_chainId" => json!("0x1"),
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
            let number = u64::from_str_radix(
                request["params"][0].as_str().unwrap().trim_start_matches("0x"),
                16,
            )
            .unwrap();
            json!(answers[&number].raw())
        }
        "eth_getStorageAt" => {
            // The live head would move after every call. Only the exact EIP-1898 selector can
            // consistently read genesis/config/checkpoint; an unpinned adapter sees status 0.
            if request["params"][2] != json!({"blockHash":pin,"requireCanonical":true}) {
                return json!(U256::ZERO);
            }
            let slot: U256 = serde_json::from_value(request["params"][1].clone()).unwrap();
            let word = match u64::try_from(slot).unwrap_or(u64::MAX) {
                258 => U256::from(3),
                268 | 270 => U256::ZERO,
                271 | 273 => U256::from_be_bytes(B256::repeat_byte(1).0),
                272 => (U256::from(10) << 64) | (U256::from(20) << 128) | (U256::from(1) << 192),
                274 => U256::from_be_bytes(B256::repeat_byte(2).0),
                279 => U256::from(9),
                _ => U256::from_be_bytes(B256::repeat_byte(3).0),
            };
            json!(word)
        }
        other => panic!("unexpected L1 method {other}"),
    })
    .await;
    let l2 = rpc(|request| {
        assert_eq!(request["method"], "eth_chainId");
        json!("0x28c59")
    })
    .await;
    let source = RpcLandingSource::new(
        l1.provider.clone(),
        l2.provider.clone(),
        ChainParams::builtin(167001).unwrap(),
    );
    (source, l1, l2, headers)
}

#[tokio::test]
async fn snapshot_cannot_mix_inbox_generations_config_and_checkpoint_across_live_heads() {
    let (source, l1, _l2, headers) = source(18, false).await;
    let observed = source.snapshot().await.unwrap();
    assert_eq!(observed, snapshot(&headers));
    let calls = l1.requests.lock().unwrap();
    let slots =
        calls.iter().filter(|call| call["method"] == "eth_getStorageAt").collect::<Vec<_>>();
    assert_eq!(slots.len(), 9);
    for call in slots {
        assert_eq!(
            call["params"][2],
            json!({"blockHash":headers[&20].hash(),"requireCanonical":true})
        );
    }
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
