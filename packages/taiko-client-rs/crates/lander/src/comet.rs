//! Bounded, read-only CometBFT JSON-RPC collection.

use std::time::Duration;

use crate::native::{Commit, RawBlock};
use abci::CommitteeState;
use async_trait::async_trait;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use futures::StreamExt;
use serde::{Deserialize, de::DeserializeOwned};
use serde_json::{Value, json};
use tendermint::block::{Header, Id};
use tendermint_proto::v0_38::types::Header as RawHeader;
use url::Url;

use crate::{
    error::{LanderError, Result},
    types::CertifiedBlock,
};

/// Node identity and latest locally decided block height.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CometStatus {
    /// The generation-qualified Etna CometBFT chain id.
    pub chain_id: String,
    /// Latest decided height reported by the node.
    pub height: u64,
}

/// Read-only block/certificate and full committee-hint source.
#[async_trait]
pub trait CometSource: Send + Sync {
    /// Reads chain identity and available decided progress.
    async fn status(&self) -> Result<CometStatus>;
    /// Reads a complete block and its decision certificate at exactly `height`.
    async fn block(&self, height: u64) -> Result<CertifiedBlock>;
    /// Reads an untrusted ABCI committee hint; callers must authenticate its full record.
    async fn committee(&self, epoch: u64) -> Result<CommitteeState>;
}

/// A typed HTTP adapter that bounds the complete response body before JSON decoding.
#[derive(Clone, Debug)]
pub struct HttpCometSource {
    /// Validated HTTP endpoint; credentials are not included in error strings.
    url: Url,
    /// Client timeout bounds DNS, connect, header and streamed body reads.
    client: reqwest::Client,
    /// Maximum accumulated JSON bytes of one RPC response.
    max_response_bytes: usize,
}

/// Typed JSON-RPC envelope, retaining explicit remote errors.
#[derive(Deserialize)]
struct RpcResponse<T> {
    /// Result payload, absent on JSON-RPC errors.
    result: Option<T>,
    /// Remote JSON-RPC failure.
    error: Option<RpcError>,
}

/// CometBFT JSON-RPC error without endpoint credentials.
#[derive(Deserialize)]
struct RpcError {
    /// Numeric protocol error code.
    code: i64,
}

/// Fields used from `/status`.
#[derive(Deserialize)]
struct StatusResponse {
    /// Network identity reported by CometBFT.
    node_info: NodeInfo,
    /// Available decided range tip.
    sync_info: SyncInfo,
}

/// CometBFT's configured network name.
#[derive(Deserialize)]
struct NodeInfo {
    /// Generation-qualified chain id.
    network: String,
}

/// String-encoded status height.
#[derive(Deserialize)]
struct SyncInfo {
    /// JSON-RPC intentionally encodes int64 heights as decimal strings.
    latest_block_height: String,
}

/// Complete result from `/block`.
#[derive(Deserialize)]
struct BlockResponse {
    /// Header/part-set identity of the returned block.
    block_id: Id,
    /// Original protobuf-shaped JSON, retained before the domain adapter can rewrite evidence.
    #[serde(deserialize_with = "deserialize_block")]
    block: RawBlock,
}

/// Decodes stock RPC JSON through the lossless native bridge before projection.
fn deserialize_block<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> std::result::Result<RawBlock, D::Error> {
    crate::native::decode_block(Value::deserialize(deserializer)?).map_err(serde::de::Error::custom)
}

/// Reads `/commit`'s header through its protobuf form, restoring a Unix-epoch time.
fn deserialize_header<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> std::result::Result<Header, D::Error> {
    let value = Value::deserialize(deserializer)?;
    let timestamp = value
        .get("time")
        .cloned()
        .ok_or_else(|| serde::de::Error::custom("missing header time"))?;
    let time: tendermint_proto::google::protobuf::Timestamp =
        serde_json::from_value(timestamp).map_err(serde::de::Error::custom)?;
    let mut header: RawHeader = serde_json::from_value(value).map_err(serde::de::Error::custom)?;
    header.time = Some(time);
    header.try_into().map_err(serde::de::Error::custom)
}

/// Reads `/commit`'s certificate through its protobuf form, restoring Unix-epoch vote times.
fn deserialize_commit<'de, D: serde::Deserializer<'de>>(
    deserializer: D,
) -> std::result::Result<Commit, D::Error> {
    crate::native::decode_commit(Value::deserialize(deserializer)?)
        .map_err(serde::de::Error::custom)
}

/// Complete certificate result from `/commit`.
#[derive(Deserialize)]
struct CommitResponse {
    /// Header plus that height's precommit certificate.
    signed_header: SignedHeader,
}

/// Avoids assuming the `/block` and `/commit` calls referred to identical headers.
#[derive(Deserialize)]
struct SignedHeader {
    /// Header the certificate signs.
    #[serde(deserialize_with = "deserialize_header")]
    header: Header,
    /// Decision certificate for that header.
    #[serde(deserialize_with = "deserialize_commit")]
    commit: Commit,
}

/// ABCI query result envelope.
#[derive(Deserialize)]
struct QueryResponse {
    /// ABCI-level success/failure independent of JSON-RPC transport success.
    response: QueryResult,
}

/// Only the fields necessary for an authenticated committee hint.
#[derive(Deserialize)]
struct QueryResult {
    /// Zero denotes success.
    #[serde(default)]
    code: u32,
    /// Error detail from ABCI.
    #[serde(default)]
    log: String,
    /// JSON committee bytes, base64 encoded by the CometBFT RPC.
    #[serde(default)]
    value: String,
}

impl HttpCometSource {
    /// Constructs a bounded HTTP(S) source with a nonzero end-to-end RPC deadline.
    pub fn new(url: Url, timeout: Duration, max_response_bytes: usize) -> Result<Self> {
        if !matches!(url.scheme(), "http" | "https") || timeout.is_zero() || max_response_bytes == 0
        {
            return Err(LanderError::Configuration(
                "Comet RPC requires HTTP(S), nonzero timeout and response limit".into(),
            ));
        }
        let client = reqwest::Client::builder()
            .timeout(timeout)
            .build()
            .map_err(|e| LanderError::Configuration(format!("Comet HTTP client: {e}")))?;
        Ok(Self { url, client, max_response_bytes })
    }

    /// Sends one typed read RPC and accumulates only up to the configured body bound.
    async fn rpc<T: DeserializeOwned>(&self, method: &str, params: Value) -> Result<T> {
        let response = self
            .client
            .post(self.url.clone())
            .json(&json!({"jsonrpc":"2.0","id":1,"method":method,"params":params}))
            .send()
            .await
            .map_err(|e| {
                LanderError::Temporary(format!("Comet {method} transport: {}", e.without_url()))
            })?;
        if !response.status().is_success() {
            return Err(LanderError::Temporary(format!(
                "Comet {method} HTTP status {}",
                response.status()
            )));
        }
        if response.content_length().is_some_and(|length| length > self.max_response_bytes as u64) {
            return Err(LanderError::Capacity(format!(
                "Comet {method} response exceeds {} bytes",
                self.max_response_bytes
            )));
        }
        let mut body = Vec::new();
        let mut stream = response.bytes_stream();
        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| {
                LanderError::Temporary(format!("Comet {method} body: {}", e.without_url()))
            })?;
            let length = body
                .len()
                .checked_add(chunk.len())
                .filter(|length| *length <= self.max_response_bytes)
                .ok_or_else(|| {
                    LanderError::Capacity(format!(
                        "Comet {method} response exceeds {} bytes",
                        self.max_response_bytes
                    ))
                })?;
            body.reserve(length - body.len());
            body.extend_from_slice(&chunk);
        }
        let response: RpcResponse<T> = serde_json::from_slice(&body).map_err(|e| {
            // JSON data errors can quote upstream string values, including provider credentials.
            let message = format!(
                "Comet {method} JSON response {:?} at line {} column {}",
                e.classify(),
                e.line(),
                e.column()
            );
            if e.is_syntax() || e.is_eof() {
                LanderError::Temporary(message)
            } else {
                LanderError::Encoding(message)
            }
        })?;
        if let Some(error) = response.error {
            // Providers may echo the authenticated URL in error messages or data.
            let detail = format!("Comet {method}: JSON-RPC code {}", error.code);
            return Err(if matches!(method, "block" | "commit" | "abci_query") {
                LanderError::Unavailable(detail)
            } else {
                LanderError::Temporary(detail)
            });
        }
        response
            .result
            .ok_or_else(|| LanderError::Encoding(format!("Comet {method} response has no result")))
    }
}

#[async_trait]
impl CometSource for HttpCometSource {
    async fn status(&self) -> Result<CometStatus> {
        let response: StatusResponse = self.rpc("status", json!({})).await?;
        let height = response
            .sync_info
            .latest_block_height
            .parse::<u64>()
            .map_err(|e| LanderError::Encoding(format!("Comet status height: {e}")))?;
        if height > i64::MAX as u64 {
            return Err(LanderError::Encoding("Comet status height exceeds int64".into()));
        }
        Ok(CometStatus { chain_id: response.node_info.network, height })
    }

    async fn block(&self, height: u64) -> Result<CertifiedBlock> {
        if height == 0 || height > i64::MAX as u64 {
            return Err(LanderError::Configuration(format!(
                "Comet height {height} is outside 1..=int64::MAX"
            )));
        }
        let params = json!({"height":height.to_string()});
        let response: BlockResponse =
            self.rpc("block", params.clone()).await.map_err(|e| annotate_history(e, height))?;
        let certificate: CommitResponse =
            self.rpc("commit", params).await.map_err(|e| annotate_history(e, height))?;
        let pair = CertifiedBlock::from_raw(response.block, certificate.signed_header.commit)
            .map_err(|e| LanderError::Safety(format!("Comet block at height {height}: {e}")))?;
        if pair.block.header.height.value() != height ||
            pair.commit.height.value() != height ||
            certificate.signed_header.header != pair.block.header ||
            response.block_id != pair.commit.block_id ||
            response.block_id.hash != pair.block.header.hash()
        {
            return Err(LanderError::Safety(format!(
                "Comet block/commit/header identity disagrees at height {height}"
            )));
        }
        Ok(pair)
    }

    async fn committee(&self, epoch: u64) -> Result<CommitteeState> {
        let response: QueryResponse = self
            .rpc("abci_query", json!({"path":format!("/committee/{epoch}"),"prove":false}))
            .await?;
        if response.response.code != 0 {
            return Err(LanderError::Unavailable(format!(
                "committee epoch {epoch}: ABCI code {} {}",
                response.response.code, response.response.log
            )));
        }
        let value = STANDARD
            .decode(response.response.value)
            .map_err(|e| LanderError::Encoding(format!("committee epoch {epoch} base64: {e}")))?;
        let state: CommitteeState = serde_json::from_slice(&value)
            .map_err(|e| LanderError::Encoding(format!("committee epoch {epoch} JSON: {e}")))?;
        if state.record.target_epoch != epoch {
            return Err(LanderError::Safety(format!(
                "committee response epoch {} differs from requested {epoch}",
                state.record.target_epoch
            )));
        }
        Ok(state)
    }
}

/// Keeps missing/pruned history actionable even when the remote error omitted its height.
fn annotate_history(error: LanderError, height: u64) -> LanderError {
    match error {
        LanderError::Unavailable(message) => {
            LanderError::Unavailable(format!("height {height}: {message}"))
        }
        other => other,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus::{committee, pair};
    use alloy_primitives::B256;
    use tokio::{
        io::{AsyncReadExt, AsyncWriteExt},
        net::TcpListener,
    };

    async fn source(
        responses: Vec<(Value, Duration)>,
        limit: usize,
        timeout: Duration,
    ) -> HttpCometSource {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}", listener.local_addr().unwrap())).unwrap();
        tokio::spawn(async move {
            for (response, delay) in responses {
                let (mut stream, _) = listener.accept().await.unwrap();
                let mut request = Vec::new();
                loop {
                    let mut chunk = [0; 4096];
                    let read = stream.read(&mut chunk).await.unwrap();
                    if read == 0 {
                        break;
                    }
                    request.extend_from_slice(&chunk[..read]);
                    if let Some(end) = request.windows(4).position(|window| window == b"\r\n\r\n") {
                        let text = String::from_utf8_lossy(&request[..end]);
                        let length = text
                            .lines()
                            .find_map(|line| {
                                line.split_once(':')
                                    .filter(|(name, _)| name.eq_ignore_ascii_case("content-length"))
                                    .map(|(_, value)| value.trim().parse::<usize>().unwrap())
                            })
                            .unwrap_or(0);
                        if request.len() >= end + 4 + length {
                            break;
                        }
                    }
                }
                tokio::time::sleep(delay).await;
                let body = response.get("__body").and_then(Value::as_str).map_or_else(
                    || serde_json::to_vec(&response).unwrap(),
                    |raw| raw.as_bytes().to_vec(),
                );
                let chunked = response.get("__chunked").and_then(Value::as_bool).unwrap_or(false);
                let header = if chunked {
                    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
                        .to_string()
                } else {
                    format!(
                        "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                        body.len()
                    )
                };
                let _ = stream.write_all(header.as_bytes()).await;
                if chunked {
                    let _ = stream.write_all(format!("{:x}\r\n", body.len()).as_bytes()).await;
                }
                let _ = stream.write_all(&body).await;
                if chunked {
                    let _ = stream.write_all(b"\r\n0\r\n\r\n").await;
                }
            }
        });
        HttpCometSource::new(url, timeout, limit).unwrap()
    }

    fn success(value: Value) -> (Value, Duration) {
        (json!({"jsonrpc":"2.0","id":1,"result":value}), Duration::ZERO)
    }

    #[tokio::test]
    async fn rpc_errors_do_not_echo_credentials_from_upstream_messages_or_data() {
        let endpoint = "https://user-secret:pass-secret@provider/path-secret?key=query-secret";
        let responses = [
            json!({"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":endpoint,"data":endpoint}}),
            json!({"jsonrpc":"2.0","id":1,"result":endpoint}),
        ];
        for response in responses {
            let rpc = source(vec![(response, Duration::ZERO)], 8192, Duration::from_secs(2)).await;
            let error = rpc.status().await.unwrap_err();
            let rendered = format!("{error} {error:?}");
            for secret in ["user-secret", "pass-secret", "path-secret", "query-secret"] {
                assert!(!rendered.contains(secret), "upstream error exposed {secret}");
            }
        }
    }

    #[tokio::test]
    async fn retries_gateway_html_empty_and_truncated_json_on_http_success() {
        for body in ["<html>gateway unavailable</html>", "", "{\"result\":"] {
            let rpc = source(
                vec![(json!({"__body":body}), Duration::ZERO)],
                8192,
                Duration::from_secs(2),
            )
            .await;
            assert!(matches!(rpc.block(1).await, Err(LanderError::Temporary(_))), "{body}");
        }
    }

    #[tokio::test]
    async fn authenticates_stock_go_duplicate_extended_nil_and_light_client_evidence() {
        let fixture: Value =
            serde_json::from_str(include_str!("../testdata/cometbft-v0.40/vectors.json")).unwrap();
        let (_, committee, _) = crate::test_utils::consensus::stock_go_committee(&[10, 30], 0);
        for vector in fixture["vectors"].as_array().unwrap() {
            let rpc = source(
                vec![success(vector["block_rpc"].clone()), success(vector["commit_rpc"].clone())],
                128 * 1024,
                Duration::from_secs(2),
            )
            .await;
            let pair = rpc.block(1).await.unwrap();
            crate::validate::verify_commit(
                &pair.commit,
                &pair.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
            )
            .unwrap();
            let result = crate::validate::verify_body(&pair, 1, B256::ZERO);
            assert!(result.is_ok(), "{}: {result:?}", vector["name"]);
            let expected =
                alloy_primitives::hex::decode(vector["block_proto"].as_str().unwrap()).unwrap();
            assert_eq!(pair.raw_block.as_ref(), expected.as_slice(), "{}", vector["name"]);
            assert_eq!(
                pair.block.header.evidence_hash.unwrap().as_bytes(),
                alloy_primitives::hex::decode(vector["evidence_hash"].as_str().unwrap()).unwrap(),
            );
            assert_eq!(
                pair.commit.block_id.part_set_header.total,
                vector["parts_total"].as_u64().unwrap() as u32
            );
            assert_eq!(
                pair.commit.block_id.part_set_header.hash.as_bytes(),
                alloy_primitives::hex::decode(vector["parts_hash"].as_str().unwrap()).unwrap(),
            );
            let wire = serde_json::to_value(&pair).unwrap();
            let restored: CertifiedBlock = serde_json::from_value(wire.clone()).unwrap();
            assert_eq!(restored, pair);
            crate::validate::verify_body(&restored, 1, B256::ZERO).unwrap();
            let mut missing = wire;
            missing.as_object_mut().unwrap().remove("raw_block");
            assert!(serde_json::from_value::<CertifiedBlock>(missing).is_err());
            let mut changed = pair.clone();
            changed.block.header.time = tendermint::Time::from_unix_timestamp(999, 0).unwrap();
            assert!(crate::validate::verify_body(&changed, 1, B256::ZERO).is_err());
            let mut noncanonical = pair.clone();
            let mut bytes = noncanonical.raw_block.to_vec();
            bytes.extend_from_slice(&[0xf8, 0x07, 0x01]);
            noncanonical.raw_block = bytes.into();
            assert!(crate::validate::verify_body(&noncanonical, 1, B256::ZERO).is_err());
            assert!(
                serde_json::from_value::<CertifiedBlock>(
                    serde_json::to_value(&noncanonical).unwrap()
                )
                .is_err()
            );
        }
    }

    /// Stock blocks and certificates as CometBFT's RPC serves them, named edge cases (Unix-epoch
    /// times, int32-extreme rounds and indices, 120 validators, an app version, light-client
    /// attacks with a 65-byte nil signature or a secp256k1 validator) then seeded random ones
    /// (validator sets, heights, commit flags, times including the Unix epoch and Go's zero time,
    /// duplicate-vote and light-client-attack evidence with extensions): each reads back into
    /// exactly Go's block and commit protobufs, its certificate verifies, its commitments match,
    /// and the journal wire restores it unchanged.
    #[tokio::test]
    async fn reads_stock_go_blocks_and_commits_byte_for_byte() {
        use crate::validate::{ValidationError, verify_body, verify_commit};
        use prost::Message;
        use tendermint_proto::v0_38::types::Commit as RawCommit;

        let fixture: Value =
            serde_json::from_str(include_str!("../testdata/cometbft-v0.40/differential.json"))
                .unwrap();
        let hex = |value: &Value| alloy_primitives::hex::decode(value.as_str().unwrap()).unwrap();
        for vector in fixture["vectors"].as_array().unwrap() {
            let name = vector["name"].as_str().unwrap();
            let height = vector["height"].as_u64().unwrap();
            let powers: Vec<u64> = vector["powers"]
                .as_str()
                .unwrap()
                .split(',')
                .map(|power| power.parse().unwrap())
                .collect();
            let rpc = source(
                vec![success(vector["block_rpc"].clone()), success(vector["commit_rpc"].clone())],
                1 << 20,
                Duration::from_secs(2),
            )
            .await;
            let pair = rpc.block(height).await.unwrap_or_else(|e| panic!("{name}: {e}"));
            assert_eq!(pair.raw_block.as_ref(), hex(&vector["block_proto"]), "{name}: block");
            assert_eq!(
                RawCommit::from(pair.commit.clone()).encode_to_vec(),
                hex(&vector["commit_proto"]),
                "{name}: commit"
            );
            let (_, committee, _) = crate::test_utils::consensus::stock_go_committee(&powers, 0);
            let certificate = verify_commit(
                &pair.commit,
                &pair.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
            );
            if pair.block.header.version.app == abci::app::APP_VERSION {
                certificate.unwrap_or_else(|e| panic!("{name}: {e}"));
            } else {
                assert!(
                    certificate.is_err(),
                    "foreign app version is lossless wire, not Etna authorization"
                );
            }
            assert_eq!(
                pair.block.header.evidence_hash.unwrap().as_bytes(),
                hex(&vector["evidence_hash"]),
                "{name}"
            );
            assert_eq!(
                pair.commit.block_id.part_set_header.hash.as_bytes(),
                hex(&vector["parts_hash"]),
                "{name}"
            );
            assert_eq!(
                u64::from(pair.commit.block_id.part_set_header.total),
                vector["parts_total"].as_u64().unwrap(),
                "{name}"
            );
            // Every consensus commitment precedes the envelope's execution height, which the
            // shared height-1 fixture envelope only matches at height 1.
            let body = |pair: &CertifiedBlock| match verify_body(pair, height, B256::ZERO) {
                Ok(_) => assert_eq!(height, 1, "{name}"),
                Err(ValidationError::Etna(reason)) if height > 1 => {
                    assert_eq!(reason, "execution height / parent hash mismatch", "{name}")
                }
                Err(e) => panic!("{name}: {e}"),
            };
            body(&pair);
            let restored: CertifiedBlock =
                serde_json::from_value(serde_json::to_value(&pair).unwrap())
                    .unwrap_or_else(|e| panic!("{name}: journal: {e}"));
            assert_eq!(restored, pair, "{name}: journal");
            body(&restored);
        }
    }

    #[tokio::test]
    async fn decodes_string_height_and_preserves_typed_block_commit() {
        let status=source(vec![success(json!({"node_info":{"network":"etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"},"sync_info":{"latest_block_height":"27"}}))],8192,Duration::from_secs(2)).await;
        assert_eq!(
            status.status().await.unwrap(),
            CometStatus {
                chain_id: "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4".into(),
                height: 27
            }
        );
        let (_, committee, keys) = committee(&[1], 0);
        let block = pair(1, B256::ZERO, &committee, &keys, None);
        let rpc=source(vec![success(json!({"block_id":block.commit.block_id,"block":block.block_proto().unwrap()})),success(json!({"signed_header":{"header":block.block.header,"commit":block.commit},"canonical":true}))],128*1024,Duration::from_secs(2)).await;
        assert_eq!(rpc.block(1).await.unwrap(), block);
    }

    #[tokio::test]
    async fn rejects_requested_height_disagreement_and_reports_pruned_history() {
        let (_, committee, keys) = committee(&[1], 0);
        let block = pair(1, B256::ZERO, &committee, &keys, None);
        let rpc = source(
            vec![
                success(
                    json!({"block_id":block.commit.block_id,"block":block.block_proto().unwrap()}),
                ),
                success(
                    json!({"signed_header":{"header":block.block.header,"commit":block.commit}}),
                ),
            ],
            128 * 1024,
            Duration::from_secs(2),
        )
        .await;
        assert!(matches!(rpc.block(2).await, Err(LanderError::Safety(_))));
        let rpc=source(vec![(json!({"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"height below base","data":"pruned"}}),Duration::ZERO)],8192,Duration::from_secs(2)).await;
        let error = rpc.block(7).await.unwrap_err();
        assert!(matches!(error, LanderError::Unavailable(_)));
        assert!(error.to_string().contains("height 7"));
    }

    #[tokio::test]
    async fn committee_queries_reject_abci_errors_bad_base64_and_wrong_epochs() {
        let (_, committee, _) = committee(&[1], 0);
        let encoded = STANDARD.encode(serde_json::to_vec(&committee.state).unwrap());
        let rpc = source(
            vec![success(json!({"response":{"code":0,"value":encoded}}))],
            8192,
            Duration::from_secs(2),
        )
        .await;
        assert_eq!(rpc.committee(0).await.unwrap(), committee.state);
        for (value, expected) in [
            (json!({"response":{"code":1,"log":"unknown committee"}}), "unavailable"),
            (json!({"response":{"code":0,"value":"?invalid"}}), "encoding"),
            (json!({"response":{"code":0,"value":encoded}}), "safety"),
        ] {
            let rpc = source(vec![success(value)], 8192, Duration::from_secs(2)).await;
            let error = rpc.committee(1).await.unwrap_err();
            match expected {
                "unavailable" => assert!(matches!(error, LanderError::Unavailable(_))),
                "encoding" => assert!(matches!(error, LanderError::Encoding(_))),
                _ => assert!(matches!(error, LanderError::Safety(_))),
            }
        }
    }

    #[tokio::test]
    async fn bounds_response_size_and_rpc_deadline() {
        let rpc =
            source(vec![success(json!({"padding":"x".repeat(4096)}))], 64, Duration::from_secs(2))
                .await;
        assert!(matches!(rpc.status().await, Err(LanderError::Capacity(_))));
        let rpc = source(
            vec![(json!({"__chunked":true,"result":{"padding":"x".repeat(4096)}}), Duration::ZERO)],
            64,
            Duration::from_secs(2),
        )
        .await;
        assert!(matches!(rpc.status().await, Err(LanderError::Capacity(_))));
        let rpc = source(
            vec![(json!({"result":{}}), Duration::from_millis(200))],
            8192,
            Duration::from_millis(20),
        )
        .await;
        assert!(matches!(rpc.status().await, Err(LanderError::Temporary(_))));
        let rpc = source(
            vec![success(
                json!({"node_info":{"network":"etna"},"sync_info":{"latest_block_height":27}}),
            )],
            8192,
            Duration::from_secs(2),
        )
        .await;
        assert!(matches!(rpc.status().await, Err(LanderError::Encoding(_))));
    }
}
