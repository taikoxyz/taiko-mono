//! Genuine MPT and deterministic HTTP fixtures shared by offline claim source and CLI tests.
use super::claim_library as lander;
use abci::{AccountWitness, l1::layout::inbox};
use alloy::sol_types::{SolCall, SolEvent, SolValue};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes, U256, address, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};
use lander::{
    Result,
    claim::{
        ClaimIdentity, Vault,
        source::{ROOTS, RpcClaimSource},
    },
    contracts::BatchRewardRecorded,
    rewards::{self, Receipt},
};
use serde_json::{Value, json};
use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

pub fn receipt() -> Receipt {
    Receipt {
        l1ChainId: U256::from(1),
        l2ChainId: 167001,
        inbox: Address::repeat_byte(1),
        generation: 2,
        parentHeight: 3,
        parentHash: B256::repeat_byte(4),
        lastHeight: 5,
        lastBlockHash: B256::repeat_byte(6),
        l2RewardRecipient: Address::repeat_byte(7),
        baseFeeAmount: U256::from(11),
    }
}
pub fn identity() -> ClaimIdentity {
    ClaimIdentity {
        landing_tx: B256::repeat_byte(9),
        batch_id: rewards::batch_id(&receipt()),
        l1_chain_id: U256::from(1),
        l2_chain_id: 167001,
        inbox: Address::repeat_byte(1),
        vault: address!("1670010000000000000000000000000000010001"),
        payer: Address::repeat_byte(8),
    }
}
fn trie(values: BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in values {
        builder.add_leaf(Nibbles::unpack(key), &value);
    }
    (builder.root(), builder.take_proof_nodes())
}
fn nodes(proofs: &ProofNodes, key: B256) -> Vec<Bytes> {
    proofs.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, n)| n).collect()
}
pub fn witness(values: &BTreeMap<B256, U256>, slots: &[B256]) -> (B256, AccountWitness) {
    let id = identity();
    let leaves = values
        .iter()
        .filter(|(_, v)| !v.is_zero())
        .map(|(s, v)| (keccak256(s), alloy_rlp::encode(v)))
        .collect();
    let (storage_root, storage_proofs) =
        trie(leaves, slots.iter().map(|s| Nibbles::unpack(keccak256(s))).collect());
    let account = TrieAccount {
        nonce: 1,
        balance: U256::from(17),
        storage_root,
        code_hash: keccak256(b"Inbox"),
    };
    let (root, accounts) = trie(
        BTreeMap::from([(keccak256(id.inbox), alloy_rlp::encode(account))]),
        vec![Nibbles::unpack(keccak256(id.inbox))],
    );
    (
        root,
        AccountWitness {
            address: id.inbox,
            nonce: 1,
            balance: account.balance,
            storage_root,
            code_hash: account.code_hash,
            account_proof: nodes(&accounts, keccak256(id.inbox)),
            storage: slots
                .iter()
                .map(|slot| abci::StorageProof {
                    slot: *slot,
                    value: values.get(slot).copied().unwrap_or_default(),
                    proof: nodes(&storage_proofs, keccak256(slot)),
                })
                .collect(),
        },
    )
}
pub fn values() -> BTreeMap<B256, U256> {
    BTreeMap::from([
        (
            rewards::receipt_slot(identity().batch_id),
            U256::from_be_bytes(rewards::commitment(&receipt()).0),
        ),
        (inbox::slot(inbox::STATUS), U256::from(3)),
        (inbox::slot(inbox::RECOVERY_GENERATION), U256::from(9)),
    ])
}

#[derive(Clone, Copy, Default)]
pub enum Fault {
    #[default]
    None,
    FakeEvent,
    ForwardedLanding,
    WrongInbox,
    EmptyAccount,
    WrongSlot,
    Nonfinal,
    Roots,
    NewAnchor,
    Reorg,
    Ancestry,
    RpcLeak,
    WrongChain,
    ZeroInbox,
    PendingAnchor,
    FarCheckpoint,
    WrongBranch,
    ForgedCovering,
}
pub struct Fixture {
    pub l1: BTreeMap<u64, Header>,
    pub l2: BTreeMap<u64, Header>,
    anchor_values: BTreeMap<B256, U256>,
    pub final_values: BTreeMap<B256, U256>,
    fault: Fault,
    pub checkpoint: bool,
    pub covering: Vec<Receipt>,
    pub covering_block: u64,
    pub covering_blocks: Vec<u64>,
    pub finalized_head: std::sync::atomic::AtomicU64,
    pub chunked_logs: bool,
    pub log_error: Option<(i64, &'static str)>,
    pub log_status: u16,
    pub max_log_response_bytes: std::sync::atomic::AtomicUsize,
    pub hang_logs_end: std::sync::atomic::AtomicU64,
    pub branch_headers: Vec<Header>,
    pub pending_anchor: std::sync::atomic::AtomicBool,
    pub fail_bootstrap: std::sync::atomic::AtomicBool,
    pub hang_receipts: std::sync::atomic::AtomicBool,
    pub hung_started: std::sync::atomic::AtomicBool,
    pub hide_logs: std::sync::atomic::AtomicBool,
    pub hang_ancestry: std::sync::atomic::AtomicBool,
    pub missing_hashes: Mutex<Vec<B256>>,
    pub slow_hashes: Mutex<Vec<B256>>,
    pub hash_delay: Duration,
    pub requests: Mutex<Vec<Value>>,
    pub sends: Mutex<Vec<Bytes>>,
    accepted: Mutex<Option<B256>>,
    pub fail_next_send: std::sync::atomic::AtomicBool,
    pub claim_directory: Mutex<Option<std::path::PathBuf>>,
}
impl Fixture {
    pub fn new(fault: Fault, checkpoint: bool) -> Self {
        let anchor_values = values();
        let (anchor_root, _) =
            witness(&anchor_values, &[rewards::receipt_slot(identity().batch_id)]);
        let landing = Header { number: 9, timestamp: 200, ..Default::default() };
        let anchor = Header {
            number: 10,
            timestamp: 201,
            state_root: anchor_root,
            parent_hash: landing.hash_slow(),
            ..Default::default()
        };
        let mut extra = vec![0; 13];
        extra[6] = 9;
        extra[12] = 10;
        let h8 = Header {
            number: 8,
            base_fee_per_gas: Some(7),
            timestamp: 1000,
            extra_data: extra.clone().into(),
            parent_beacon_block_root: Some(anchor_root),
            ..Default::default()
        };
        let mut h9 = Header {
            number: 9,
            base_fee_per_gas: Some(7),
            timestamp: 1001,
            extra_data: extra.into(),
            parent_beacon_block_root: Some(anchor_root),
            parent_hash: h8.hash_slow(),
            ..Default::default()
        };
        let mut final_values = anchor_values.clone();
        let mut covering = vec![];
        let mut branch_headers = vec![];
        if checkpoint {
            let mut r = receipt();
            r.parentHeight = 5;
            r.lastHeight = 9;
            r.lastBlockHash = h9.hash_slow();
            r.generation = 9;
            if matches!(fault, Fault::WrongBranch) {
                let mut old8 = h8.clone();
                old8.timestamp += 50;
                let mut old9 = h9.clone();
                old9.parent_hash = old8.hash_slow();
                let mut old = r.clone();
                old.generation = 4;
                old.lastBlockHash = old9.hash_slow();
                final_values.insert(
                    rewards::receipt_slot(rewards::batch_id(&old)),
                    U256::from_be_bytes(rewards::commitment(&old).0),
                );
                covering.push(old);
                branch_headers.extend([old8, old9]);
            }
            final_values.insert(
                rewards::receipt_slot(rewards::batch_id(&r)),
                U256::from_be_bytes(rewards::commitment(&r).0),
            );
            if matches!(fault, Fault::ForgedCovering) {
                r.baseFeeAmount += U256::from(1);
            }
            covering.push(r);
        }
        if checkpoint {
            final_values.insert(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(9));
            final_values.insert(
                inbox::slot(inbox::LAST_CHECKPOINT_HASH),
                U256::from_be_bytes(h9.hash_slow().0),
            );
        }
        if matches!(fault, Fault::FarCheckpoint | Fault::WrongBranch) {
            // A distant checkpoint (or recovery reset) must not determine historical discovery.
            final_values.insert(
                inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT),
                U256::from(if matches!(fault, Fault::FarCheckpoint) { 999_999 } else { 0 }),
            );
        }
        if matches!(fault, Fault::NewAnchor) {
            final_values.insert(inbox::slot(299), U256::from(7));
        }
        let (final_root, _) = witness(&final_values, &inbox::anchor_slots());
        if matches!(fault, Fault::NewAnchor) {
            let mut extra = h9.extra_data.to_vec();
            extra[12] = 11;
            h9.extra_data = extra.into();
            h9.parent_beacon_block_root = Some(final_root);
            h9.timestamp += 8191;
        }
        let finalized = Header {
            number: 11,
            timestamp: 202,
            state_root: final_root,
            parent_hash: anchor.hash_slow(),
            ..Default::default()
        };
        Self {
            l1: BTreeMap::from([(9, landing), (10, anchor), (11, finalized)]),
            l2: BTreeMap::from([(8, h8), (9, h9)]),
            anchor_values,
            final_values,
            fault,
            checkpoint,
            covering,
            branch_headers,
            covering_block: 11,
            covering_blocks: vec![],
            finalized_head: std::sync::atomic::AtomicU64::new(0),
            chunked_logs: false,
            log_error: None,
            log_status: 200,
            max_log_response_bytes: std::sync::atomic::AtomicUsize::new(0),
            hang_logs_end: std::sync::atomic::AtomicU64::new(u64::MAX),
            pending_anchor: std::sync::atomic::AtomicBool::new(matches!(
                fault,
                Fault::PendingAnchor
            )),
            fail_bootstrap: std::sync::atomic::AtomicBool::new(false),
            hang_receipts: std::sync::atomic::AtomicBool::new(false),
            hung_started: std::sync::atomic::AtomicBool::new(false),
            hide_logs: std::sync::atomic::AtomicBool::new(false),
            hang_ancestry: std::sync::atomic::AtomicBool::new(false),
            missing_hashes: Mutex::new(vec![]),
            slow_hashes: Mutex::new(vec![]),
            hash_delay: Duration::ZERO,
            requests: Mutex::new(vec![]),
            sends: Mutex::new(vec![]),
            accepted: Mutex::new(None),
            fail_next_send: std::sync::atomic::AtomicBool::new(false),
            claim_directory: Mutex::new(None),
        }
    }
    fn response(&self, request: &Value, l1: bool) -> Value {
        self.requests.lock().unwrap().push(request.clone());
        let p = &request["params"];
        let id = identity();
        match request["method"].as_str().unwrap() {
            "eth_chainId" => {
                json!(if l1 || matches!(self.fault, Fault::WrongChain) { "0x1" } else { "0x28c59" })
            }
            "eth_getBlockByNumber" => {
                let tag = p[0].as_str().unwrap();
                let n = match tag {
                    "latest" => {
                        if l1 {
                            *self.l1.last_key_value().unwrap().0
                        } else {
                            9
                        }
                    }
                    "finalized" => {
                        if matches!(self.fault, Fault::Nonfinal) {
                            9
                        } else {
                            let head =
                                self.finalized_head.load(std::sync::atomic::Ordering::SeqCst);
                            if head == 0 { *self.l1.last_key_value().unwrap().0 } else { head }
                        }
                    }
                    _ => u64::from_str_radix(&tag[2..], 16).unwrap(),
                };
                let mut h = if l1 { self.l1[&n].clone() } else { self.l2[&n].clone() };
                if !l1 &&
                    ((matches!(self.fault, Fault::Reorg) && tag != "latest" && n == 9) ||
                        (matches!(self.fault, Fault::Ancestry) && n == 8))
                {
                    h.timestamp += 1;
                }
                if !l1 && self.pending_anchor.load(std::sync::atomic::Ordering::SeqCst) {
                    let mut extra = h.extra_data.to_vec();
                    extra[12] = 8;
                    h.extra_data = extra.into();
                }
                let mut value = serde_json::to_value(&h).unwrap();
                value["hash"] = json!(h.hash_slow());
                value["transactions"] = json!([]);
                value
            }
            "eth_getBlockByHash" => {
                let hash: B256 = serde_json::from_value(p[0].clone()).unwrap();
                if self.missing_hashes.lock().unwrap().contains(&hash) {
                    return Value::Null;
                }
                let Some(mut h) = self
                    .l2
                    .values()
                    .chain(self.branch_headers.iter())
                    .find(|h| h.hash_slow() == hash)
                    .cloned()
                else {
                    return Value::Null;
                };
                if matches!(self.fault, Fault::Ancestry) && h.number == 8 {
                    h.timestamp += 1;
                }
                let mut value = serde_json::to_value(&h).unwrap();
                value["hash"] = json!(hash);
                value["transactions"] = json!([]);
                value
            }
            "eth_getLogs" => {
                assert_eq!(p[0]["address"], json!(id.inbox));
                let start = u64::from_str_radix(
                    p[0]["fromBlock"].as_str().unwrap().trim_start_matches("0x"),
                    16,
                )
                .unwrap();
                let end = u64::from_str_radix(
                    p[0]["toBlock"].as_str().unwrap().trim_start_matches("0x"),
                    16,
                )
                .unwrap();
                assert!(end - start < 1024);
                if self.hide_logs.load(std::sync::atomic::Ordering::SeqCst) {
                    return json!([]);
                }
                json!(self.covering.iter().enumerate().filter_map(|(i, r)| {
                    let block = self.covering_blocks.get(i).copied().unwrap_or(self.covering_block);
                    if !(start..=end).contains(&block) { return None; }
                    let log = BatchRewardRecorded { batchId: rewards::batch_id(r), l2RewardRecipient: r.l2RewardRecipient, baseFeeAmount: r.baseFeeAmount,
                        generation:r.generation, parentHeight:r.parentHeight,parentHash:r.parentHash,lastHeight:r.lastHeight,lastBlockHash:r.lastBlockHash }.encode_log_data();
                    Some(json!({"address":id.inbox,"topics":log.topics(),"data":log.data,"blockNumber":format!("0x{block:x}"),"blockHash":self.l1[&block].hash_slow(),
                        "transactionHash":B256::repeat_byte(77),"transactionIndex":"0x0","logIndex":format!("0x{i:x}"),"removed":false}))
                }).collect::<Vec<_>>())
            }
            "debug_getRawHeader" => {
                let hash: B256 = serde_json::from_value(p[0].clone()).unwrap();
                let h = self.l1.values().find(|h| h.hash_slow() == hash).unwrap();
                json!(Bytes::from(alloy_rlp::encode(h)))
            }
            "eth_call" => {
                let input = p[0].get("input").or_else(|| p[0].get("data")).unwrap();
                let data: Bytes = serde_json::from_value(input.clone()).unwrap();
                let to: Address = serde_json::from_value(p[0]["to"].clone()).unwrap();
                assert_eq!(p[1]["requireCanonical"], true);
                if !self.pending_anchor.load(std::sync::atomic::Ordering::SeqCst) {
                    assert!(self.l2.values().any(|h| p[1]["blockHash"] == json!(h.hash_slow())));
                }
                let output = if to == ROOTS {
                    assert_eq!(
                        data.as_ref(),
                        U256::from(self.l2[&9].timestamp).to_be_bytes::<32>(),
                        "roots uses L2 timestamp, not L1 timestamp"
                    );
                    if matches!(self.fault, Fault::Roots) {
                        Bytes::copy_from_slice(B256::ZERO.as_slice())
                    } else {
                        Bytes::copy_from_slice(
                            self.l2[&9].parent_beacon_block_root.unwrap().as_slice(),
                        )
                    }
                } else if data.as_ref() == (Vault::l1InboxCall {}).abi_encode() {
                    if matches!(self.fault, Fault::ZeroInbox) {
                        Address::ZERO.abi_encode().into()
                    } else {
                        id.inbox.abi_encode().into()
                    }
                } else if data.as_ref() == (Vault::l1ChainIdCall {}).abi_encode() {
                    U256::from(1).abi_encode().into()
                } else if data.as_ref() == (Vault::ROOTSCall {}).abi_encode() {
                    ROOTS.abi_encode().into()
                } else {
                    self.accepted.lock().unwrap().is_some().abi_encode().into()
                };
                json!(output)
            }
            "eth_estimateGas" => json!("0x10000"),
            "eth_getTransactionCount" => json!("0x3"),
            "eth_maxPriorityFeePerGas" => json!("0x1"),
            "eth_feeHistory" => {
                json!({"oldestBlock":"0x0","baseFeePerGas":vec!["0x7";21],"gasUsedRatio":vec![0.5;20],"reward":vec![vec!["0x1"];20]})
            }
            "eth_getTransactionByHash" => Value::Null,
            "eth_sendRawTransaction" => {
                let raw: Bytes = serde_json::from_value(p[0].clone()).unwrap();
                if let Some(dir) = self.claim_directory.lock().unwrap().as_ref() {
                    let journal: Value = serde_json::from_slice(
                        &std::fs::read(dir.join("claim-state.json")).unwrap(),
                    )
                    .unwrap();
                    assert_eq!(journal["job"]["state"], "Pending");
                    assert_eq!(journal["job"]["transaction"]["bytes"], json!(raw));
                }
                self.sends.lock().unwrap().push(raw.clone());
                if !self.fail_next_send.load(std::sync::atomic::Ordering::SeqCst) {
                    *self.accepted.lock().unwrap() = Some(keccak256(&raw));
                }
                json!(keccak256(&raw))
            }
            "eth_getTransactionReceipt" if !l1 => {
                let accepted = *self.accepted.lock().unwrap();
                if let Some(hash) = accepted {
                    json!({"transactionHash":hash,"transactionIndex":"0x0","blockHash":self.l2[&9].hash_slow(),"blockNumber":"0x9",
                    "from":id.payer,"to":id.vault,"cumulativeGasUsed":"0x100","gasUsed":"0x100","effectiveGasPrice":"0x1",
                    "status":"0x1","type":"0x2","logsBloom":format!("0x{}","00".repeat(256)),"logs":[]})
                } else {
                    Value::Null
                }
            }
            "eth_getTransactionReceipt" => {
                let r = receipt();
                let hash = self.l1[&9].hash_slow();
                let event = BatchRewardRecorded {
                    batchId: id.batch_id,
                    l2RewardRecipient: r.l2RewardRecipient,
                    baseFeeAmount: r.baseFeeAmount +
                        U256::from(u8::from(matches!(self.fault, Fault::FakeEvent))),
                    generation: r.generation,
                    parentHeight: r.parentHeight,
                    parentHash: r.parentHash,
                    lastHeight: r.lastHeight,
                    lastBlockHash: r.lastBlockHash,
                };
                let log = event.encode_log_data();
                json!({"transactionHash":id.landing_tx,"transactionIndex":"0x0","blockHash":hash,"blockNumber":"0x9",
                    "from":id.payer,"to":if matches!(self.fault,Fault::ForwardedLanding){Address::repeat_byte(55)}else{id.inbox},"cumulativeGasUsed":"0x100","gasUsed":"0x100","effectiveGasPrice":"0x1",
                    "status":"0x1","type":"0x2","logsBloom":format!("0x{}","00".repeat(256)),
                    "logs":[{"address":if matches!(self.fault,Fault::WrongInbox){Address::repeat_byte(33)}else{id.inbox},"topics":log.topics(),"data":log.data,
                    "blockNumber":"0x9","blockHash":hash,"transactionHash":id.landing_tx,"transactionIndex":"0x0","logIndex":"0x0","removed":false}]})
            }
            "eth_getProof" => {
                assert_eq!(p[0], json!(id.inbox));
                assert_eq!(p[2]["requireCanonical"], true);
                let slots: Vec<B256> = serde_json::from_value(p[1].clone()).unwrap();
                let state = if p[2]["blockHash"] == json!(self.l1[&10].hash_slow()) {
                    &self.anchor_values
                } else {
                    assert_eq!(
                        p[2]["blockHash"],
                        json!(
                            self.l1[&match self
                                .finalized_head
                                .load(std::sync::atomic::Ordering::SeqCst)
                            {
                                0 => *self.l1.last_key_value().unwrap().0,
                                n => n,
                            }]
                                .hash_slow()
                        )
                    );
                    &self.final_values
                };
                let (_, mut w) = witness(state, &slots);
                if matches!(self.fault, Fault::EmptyAccount) {
                    w.account_proof.clear();
                }
                if matches!(self.fault, Fault::WrongSlot) {
                    w.storage[0].slot = B256::repeat_byte(33);
                }
                json!({"address":w.address,"nonce":"0x1","balance":w.balance,"storageHash":w.storage_root,"codeHash":w.code_hash,"accountProof":w.account_proof,
                    "storageProof":w.storage.iter().map(|s|json!({"key":s.slot,"value":s.value,"proof":s.proof})).collect::<Vec<_>>()})
            }
            other => panic!("unexpected RPC method {other}"),
        }
    }
}
pub struct Server {
    pub url: url::Url,
    task: tokio::task::JoinHandle<()>,
}
impl Drop for Server {
    fn drop(&mut self) {
        self.task.abort();
    }
}
pub async fn server(fixture: Arc<Fixture>, l1: bool) -> Server {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap()).parse().unwrap();
    let task = tokio::spawn(async move {
        loop {
            let (mut stream, _) = listener.accept().await.unwrap();
            let fixture = fixture.clone();
            tokio::spawn(async move {
                let mut bytes = vec![];
                let mut buf = [0; 4096];
                let (start, len) = loop {
                    let n = stream.read(&mut buf).await.unwrap();
                    if n == 0 {
                        return;
                    }
                    bytes.extend_from_slice(&buf[..n]);
                    if let Some(end) = bytes.windows(4).position(|b| b == b"\r\n\r\n") {
                        let headers = String::from_utf8_lossy(&bytes[..end]).to_lowercase();
                        let len = headers
                            .lines()
                            .find_map(|line| {
                                line.strip_prefix("content-length:")
                                    .map(|v| v.trim().parse::<usize>().unwrap())
                            })
                            .unwrap();
                        break (end + 4, len);
                    }
                };
                while bytes.len() < start + len {
                    let n = stream.read(&mut buf).await.unwrap();
                    if n == 0 {
                        return;
                    }
                    bytes.extend_from_slice(&buf[..n]);
                }
                let request: Value = serde_json::from_slice(&bytes[start..start + len]).unwrap();
                if l1 && request["method"] == "eth_getLogs" {
                    let end = u64::from_str_radix(
                        request["params"][0]["toBlock"].as_str().unwrap().trim_start_matches("0x"),
                        16,
                    )
                    .unwrap();
                    if end == fixture.hang_logs_end.load(std::sync::atomic::Ordering::SeqCst) {
                        fixture.requests.lock().unwrap().push(request.clone());
                        std::future::pending::<()>().await;
                    }
                }
                if !l1 &&
                    request["method"] == "eth_getTransactionReceipt" &&
                    fixture.hang_receipts.load(std::sync::atomic::Ordering::SeqCst)
                {
                    fixture.hung_started.store(true, std::sync::atomic::Ordering::SeqCst);
                    std::future::pending::<()>().await;
                }
                if !l1 &&
                    request["method"] == "eth_getBlockByHash" &&
                    fixture.hang_ancestry.load(std::sync::atomic::Ordering::SeqCst)
                {
                    std::future::pending::<()>().await;
                }
                if !l1 && request["method"] == "eth_getBlockByHash" {
                    let hash: B256 = serde_json::from_value(request["params"][0].clone()).unwrap();
                    let slow = fixture.slow_hashes.lock().unwrap().contains(&hash);
                    if slow {
                        tokio::time::sleep(fixture.hash_delay).await;
                    }
                }
                let limited_logs = l1 && request["method"] == "eth_getLogs" && {
                    let height = |name| {
                        u64::from_str_radix(
                            request["params"][0][name].as_str().unwrap().trim_start_matches("0x"),
                            16,
                        )
                        .unwrap()
                    };
                    height("toBlock") - height("fromBlock") >= 256
                };
                let response = if limited_logs && let Some((code, message)) = fixture.log_error {
                    fixture.requests.lock().unwrap().push(request.clone());
                    json!({"jsonrpc":"2.0","id":request["id"],"error":{"code":code,"message":message}})
                } else if fixture.fail_bootstrap.swap(false, std::sync::atomic::Ordering::SeqCst) {
                    json!({"jsonrpc":"2.0","id":request["id"],"error":{"code":-32000,"message":"secret-transient"}})
                } else if matches!(fixture.fault, Fault::RpcLeak) {
                    json!({"jsonrpc":"2.0","id":request["id"],"error":{"code":-32601,"message":"https://secret-user:secret-password@rpc/?token=secret-token"}})
                } else {
                    json!({"jsonrpc":"2.0","id":request["id"],"result":fixture.response(&request,l1)})
                };
                let response = if request["method"] == "eth_sendRawTransaction" &&
                    fixture.fail_next_send.swap(false, std::sync::atomic::Ordering::SeqCst)
                {
                    json!({"jsonrpc":"2.0","id":request["id"],"error":{"code":-32000,"message":"ambiguous send outcome"}})
                } else {
                    response
                };
                let body = serde_json::to_vec(&response).unwrap();
                let logs = l1 && request["method"] == "eth_getLogs";
                if logs {
                    fixture
                        .max_log_response_bytes
                        .fetch_max(body.len(), std::sync::atomic::Ordering::SeqCst);
                }
                let status = if limited_logs { fixture.log_status } else { 200 };
                let framing = if logs && fixture.chunked_logs {
                    "Transfer-Encoding: chunked".to_owned()
                } else {
                    format!("Content-Length: {}", body.len())
                };
                let headers = format!(
                    "HTTP/1.1 {status} Test\r\nContent-Type: application/json\r\n{framing}\r\nConnection: close\r\n\r\n"
                );
                let written = async {
                    stream.write_all(headers.as_bytes()).await?;
                    if logs && fixture.chunked_logs {
                        for chunk in body.chunks(64 * 1024) {
                            stream.write_all(format!("{:x}\r\n", chunk.len()).as_bytes()).await?;
                            stream.write_all(chunk).await?;
                            stream.write_all(b"\r\n").await?;
                        }
                        stream.write_all(b"0\r\n\r\n").await
                    } else {
                        stream.write_all(&body).await
                    }
                }
                .await;
                if let Err(error) = written {
                    // Bounded clients deliberately close oversized responses before EOF.
                    assert!(
                        body.len() > CLAIM_RESPONSE_BYTES &&
                            matches!(
                                error.kind(),
                                std::io::ErrorKind::BrokenPipe |
                                    std::io::ErrorKind::ConnectionReset
                            ),
                        "unexpected fixture response write failure: {error}"
                    );
                }
            });
        }
    });
    Server { url, task }
}
pub const CLAIM_RESPONSE_BYTES: usize = 2 * 1024 * 1024;

pub async fn connect(fixture: Arc<Fixture>) -> (Result<RpcClaimSource>, Server, Server) {
    let l1 = server(fixture.clone(), true).await;
    let l2 = server(fixture, false).await;
    let deadline = Duration::from_secs(3);
    let id = identity();
    let source = RpcClaimSource::connect(
        rpc::client::connect_http_with_limits(l1.url.clone(), deadline, CLAIM_RESPONSE_BYTES),
        rpc::client::connect_http_with_limits(l2.url.clone(), deadline, CLAIM_RESPONSE_BYTES),
        id.landing_tx,
        id.batch_id,
        id.payer,
        deadline,
    )
    .await;
    (source, l1, l2)
}
