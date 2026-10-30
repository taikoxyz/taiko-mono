//! Exact-block acquisition of calldata forced inclusion transactions.

use alloy_primitives::{Address, B256, Bytes, U64, U256, keccak256};
use alloy_provider::{Provider, RootProvider};
use serde_json::{Value, json};

use super::L1Error;
use crate::forced::MAX_FORCED_TX_BYTES;

/// The fields needed to bind an event to the exact requested queue entry and L1 block.
#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ForcedLog {
    /// Contract that emitted the event.
    address: Address,
    /// Event signature and indexed queue index, with no additional indexed arguments.
    topics: Vec<B256>,
    /// ABI-encoded nonindexed transaction bytes and admission fee in wei.
    data: Bytes,
    /// Numeric canonical block selector used for acquisition.
    block_number: U64,
    /// Reorged logs cannot supply forced inclusion data.
    removed: bool,
}

/// Acquires exactly one event for `index` from `inbox` in the proven `l1_block`.
/// Missing, duplicate or inconsistent logs and noncanonical ABI are acquisition errors;
/// callers still authenticate the returned transaction's hash against the proven entry.
pub(crate) async fn fetch(
    provider: &RootProvider,
    inbox: Address,
    index: u64,
    l1_block: u64,
) -> Result<Bytes, L1Error> {
    if index >= 1 << 48 {
        return Err(malformed("queue index does not fit uint48"));
    }
    let topics =
        [keccak256("ForcedInclusionSaved(uint48,bytes,uint256)"), B256::from(U256::from(index))];
    let block = U64::from(l1_block);
    let filter = json!({"address": inbox, "fromBlock": block, "toBlock": block, "topics": topics});
    let response: Value =
        provider.raw_request("eth_getLogs".into(), (filter,)).await.map_err(|error| {
            L1Error::Rpc(format!(
                "eth_getLogs for forced index {index} at block {l1_block}: {error}"
            ))
        })?;
    let mut logs: Vec<ForcedLog> = serde_json::from_value(response)
        .map_err(|error| malformed(format!("event logs: {error}")))?;
    if logs.is_empty() {
        return Err(L1Error::DataUnavailable(format!("forced event {index} at block {l1_block}")));
    }
    if logs.len() != 1 {
        return Err(malformed(format!("expected one forced event, got {}", logs.len())));
    }
    let log = logs.pop().expect("one event");
    if log.removed || log.address != inbox || log.block_number != block || log.topics != topics {
        return Err(malformed(
            "forced event identity does not match requested block, address and index",
        ));
    }
    decode_bytes(&log.data)
}

/// Decodes the current `(bytes,uint256)` event tuple with bounded length and canonical ABI.
/// The admission fee is a full uint256; consensus authenticates the transaction hash separately.
fn decode_bytes(data: &[u8]) -> Result<Bytes, L1Error> {
    if data.len() < 96 || data[..32] != U256::from(64).to_be_bytes::<32>() {
        return Err(malformed("forced event bytes offset must be 64"));
    }
    let length = U256::from_be_slice(&data[64..96]);
    if length > U256::from(MAX_FORCED_TX_BYTES) {
        return Err(malformed("forced event transaction exceeds 8192 bytes"));
    }
    let length = length.to::<usize>();
    let end = 96 + length;
    let padded_end = 96 + length.div_ceil(32) * 32;
    if data.len() != padded_end || data[end..].iter().any(|byte| *byte != 0) {
        return Err(malformed(
            "forced event bytes are truncated, have trailing data or nonzero padding",
        ));
    }
    Ok(Bytes::copy_from_slice(&data[96..end]))
}

/// Labels inconsistent forced event responses without converting them to skip decisions.
fn malformed(message: impl Into<String>) -> L1Error {
    L1Error::MalformedResponse(message.into())
}

#[cfg(test)]
mod tests {
    use crate::l1::{L1Error, L1Source, RpcL1Source};
    use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
    use alloy_provider::ProviderBuilder;
    use serde_json::{Value, json};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    const INBOX: Address = Address::repeat_byte(0x12);
    const INDEX: u64 = 42;
    const BLOCK: u64 = 123;

    fn encoded(bytes: &[u8]) -> Bytes {
        let mut data = Vec::from(U256::from(64).to_be_bytes::<32>());
        data.extend_from_slice(&U256::from(123_000_000_000u64).to_be_bytes::<32>());
        data.extend_from_slice(&U256::from(bytes.len()).to_be_bytes::<32>());
        data.extend_from_slice(bytes);
        data.resize(96 + bytes.len().div_ceil(32) * 32, 0);
        data.into()
    }

    fn log(bytes: &[u8]) -> Value {
        json!({ "address": INBOX, "blockNumber": "0x7b", "removed": false,
            "topics": [keccak256("ForcedInclusionSaved(uint48,bytes,uint256)"), B256::from(U256::from(INDEX))],
            "data": encoded(bytes) })
    }

    async fn server(result: Value) -> (RpcL1Source, tokio::task::JoinHandle<Value>) {
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
        (RpcL1Source::new(ProviderBuilder::default().connect_http(url)), handle)
    }

    #[tokio::test]
    async fn forced_tx_requests_exact_block_address_and_index() {
        for tx in [vec![0x02, 0xab, 0xcd], vec![0x01; 8192]] {
            let (source, request) = server(json!({"result":[log(&tx)]})).await;
            assert_eq!(
                source.forced_transaction(INBOX, INDEX, BLOCK).await.unwrap(),
                Bytes::from(tx)
            );
            let request = request.await.unwrap();
            assert_eq!(request["method"], "eth_getLogs");
            assert_eq!(
                request["params"],
                json!([{
                    "fromBlock":"0x7b", "toBlock":"0x7b", "address":INBOX,
                    "topics":[keccak256("ForcedInclusionSaved(uint48,bytes,uint256)"), B256::from(U256::from(INDEX))]
                }])
            );
        }
    }

    #[tokio::test]
    async fn forced_tx_rejects_missing_duplicate_and_inconsistent_logs() {
        let valid = log(&[2, 3]);
        let mut cases = vec![json!([]), json!([valid.clone(), valid.clone()]), Value::Null];
        for (field, value) in [
            ("removed", json!(true)),
            ("removed", Value::Null),
            ("address", json!(Address::ZERO)),
            ("blockNumber", json!("0x7c")),
            ("blockNumber", Value::Null),
            ("topics", json!([B256::ZERO, B256::from(U256::from(INDEX))])),
            (
                "topics",
                json!([keccak256("ForcedInclusionSaved(uint48,bytes,uint256)"), B256::ZERO]),
            ),
            (
                "topics",
                json!([
                    keccak256("ForcedInclusionSaved(uint48,bytes,uint256)"),
                    B256::from(U256::from(INDEX)),
                    B256::ZERO
                ]),
            ),
        ] {
            let mut changed = valid.clone();
            changed[field] = value;
            cases.push(json!([changed]));
        }
        for result in cases {
            let (source, request) = server(json!({"result":result})).await;
            let error = source.forced_transaction(INBOX, INDEX, BLOCK).await.unwrap_err();
            if result.as_array().is_some_and(Vec::is_empty) {
                assert!(matches!(error, L1Error::DataUnavailable(_)), "{result}: {error}");
            } else {
                assert!(matches!(error, L1Error::MalformedResponse(_)), "{result}: {error}");
            }
            request.await.unwrap();
        }
    }

    #[tokio::test]
    async fn forced_tx_rejects_noncanonical_and_out_of_bounds_abi() {
        let mut bad_offset = encoded(&[2]).to_vec();
        bad_offset[31] = 32;
        let mut huge_length = encoded(&[2]).to_vec();
        huge_length[64] = 1;
        let mut bad_padding = encoded(&[2]).to_vec();
        bad_padding[127] = 1;
        let mut trailing = encoded(&[2]).to_vec();
        trailing.extend_from_slice(&[0; 32]);
        let mut truncated = encoded(&[2]).to_vec();
        truncated.pop();
        for data in [
            vec![],
            bad_offset,
            huge_length,
            bad_padding,
            trailing,
            truncated,
            encoded(&[2; 8193]).to_vec(),
        ] {
            let mut event = log(&[2]);
            event["data"] = json!(Bytes::from(data));
            let (source, request) = server(json!({"result":[event]})).await;
            assert!(
                matches!(
                    source.forced_transaction(INBOX, INDEX, BLOCK).await,
                    Err(L1Error::MalformedResponse(_))
                ),
                "{event}"
            );
            request.await.unwrap();
        }
    }

    #[tokio::test]
    async fn forced_tx_rpc_failures_stay_errors() {
        let (source, request) =
            server(json!({"error":{"code":-32000,"message":"unavailable"}})).await;
        assert!(
            matches!(source.forced_transaction(INBOX, INDEX, BLOCK).await, Err(L1Error::Rpc(message)) if message.contains("eth_getLogs"))
        );
        request.await.unwrap();
    }
}
