//! Bounded, read-only CometBFT JSON-RPC collection.

use std::time::Duration;

use abci::CommitteeState;
use async_trait::async_trait;
use base64::{Engine as _, engine::general_purpose::STANDARD};
use futures::StreamExt;
use serde::{Deserialize, de::DeserializeOwned};
use serde_json::{Value, json};
use tendermint::{
    Block,
    block::{Commit, Header, Id},
};
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
    /// Human-readable error summary.
    message: String,
    /// Optional method-specific failure detail.
    data: Option<Value>,
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
    /// Complete block, decoded through Tendermint's validated protobuf adapters.
    block: Block,
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
    header: Header,
    /// Decision certificate for that header.
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
        let response: RpcResponse<T> = serde_json::from_slice(&body)
            .map_err(|e| LanderError::Encoding(format!("Comet {method} JSON response: {e}")))?;
        if let Some(error) = response.error {
            let detail = format!(
                "Comet {method}: {} {} {}",
                error.code,
                error.message,
                error.data.unwrap_or(Value::Null)
            );
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
        if response.block.header.height.value() != height ||
            certificate.signed_header.commit.height.value() != height ||
            certificate.signed_header.header != response.block.header ||
            response.block_id != certificate.signed_header.commit.block_id ||
            response.block_id.hash != response.block.header.hash()
        {
            return Err(LanderError::Safety(format!(
                "Comet block/commit/header identity disagrees at height {height}"
            )));
        }
        Ok(CertifiedBlock { block: response.block, commit: certificate.signed_header.commit })
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
                let body = serde_json::to_vec(&response).unwrap();
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
    async fn decodes_string_height_and_preserves_typed_block_commit() {
        let status=source(vec![success(json!({"node_info":{"network":"taiko-etna-167001-g0"},"sync_info":{"latest_block_height":"27"}}))],8192,Duration::from_secs(2)).await;
        assert_eq!(
            status.status().await.unwrap(),
            CometStatus { chain_id: "taiko-etna-167001-g0".into(), height: 27 }
        );
        let (_, committee, keys) = committee(&[1], 0);
        let block = pair(1, B256::ZERO, &committee, &keys, None);
        let rpc=source(vec![success(json!({"block_id":block.commit.block_id,"block":block.block})),success(json!({"signed_header":{"header":block.block.header,"commit":block.commit},"canonical":true}))],128*1024,Duration::from_secs(2)).await;
        assert_eq!(rpc.block(1).await.unwrap(), block);
    }

    #[tokio::test]
    async fn rejects_requested_height_disagreement_and_reports_pruned_history() {
        let (_, committee, keys) = committee(&[1], 0);
        let block = pair(1, B256::ZERO, &committee, &keys, None);
        let rpc = source(
            vec![
                success(json!({"block_id":block.commit.block_id,"block":block.block})),
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
