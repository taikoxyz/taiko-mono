//! HTTP client for the raiko proving service.

use std::time::Duration;

use url::Url;

use super::types::{RaikoBatchProofRequest, RaikoError, RaikoProofResponse};

/// Connection settings for [`RaikoClient`].
#[derive(Debug, Clone)]
pub struct RaikoClientConfig {
    /// Base URL of the raiko host.
    pub endpoint: Url,
    /// Optional API key sent as `X-API-KEY` (omitted when `None` or empty).
    pub api_key: Option<String>,
    /// Per-request timeout (Go default: 10m via `--raiko.requestTimeout`).
    pub request_timeout: Duration,
}

/// Thin HTTP client over `POST {endpoint}/v3/proof/batch/shasta`.
#[derive(Debug, Clone)]
pub struct RaikoClient {
    /// Connection settings.
    cfg: RaikoClientConfig,
    /// Shared reqwest client carrying the request timeout.
    http: reqwest::Client,
}

impl RaikoClient {
    /// Endpoint path for Shasta batch proofs (Go `compose_proof_producer.go:261`).
    const BATCH_PROOF_PATH: &'static str = "/v3/proof/batch/shasta";

    /// Build a client; panics only if the TLS backend fails to initialize.
    #[must_use]
    pub fn new(cfg: RaikoClientConfig) -> Self {
        let http = reqwest::Client::builder()
            .timeout(cfg.request_timeout)
            .build()
            .expect("reqwest client construction");
        Self { cfg, http }
    }

    /// POST a batch proof request and parse (but not semantically validate) the
    /// response. Callers run [`RaikoProofResponse::validate`] and map statuses
    /// to polling behavior. Logs a hint on HTTP 429 (Go `common.go:124-127`).
    pub async fn request_batch_proof(
        &self,
        request: &RaikoBatchProofRequest,
    ) -> Result<RaikoProofResponse, RaikoError> {
        // `Url::join` with an absolute path replaces any path on the endpoint,
        // matching Go's host+path string concatenation for host-only endpoints.
        let url = self.cfg.endpoint.join(Self::BATCH_PROOF_PATH).map_err(|_| {
            RaikoError::Failed { error: Some("invalid raiko endpoint".to_owned()), message: None }
        })?;
        let mut req = self.http.post(url).json(request);
        if let Some(key) = self.cfg.api_key.as_deref().map(str::trim).filter(|k| !k.is_empty()) {
            req = req.header("X-API-KEY", key);
        }
        let resp = req.send().await?;
        let status = resp.status();
        if status == reqwest::StatusCode::TOO_MANY_REQUESTS {
            tracing::error!(
                "raiko rate limited (HTTP 429); using your own Taiko L2 node as raiko's RPC is recommended"
            );
        }
        // Go accepts exactly HTTP 200 (common.go:123), not any 2xx.
        if status != reqwest::StatusCode::OK {
            return Err(RaikoError::Status(status.as_u16()));
        }
        Ok(resp.json::<RaikoProofResponse>().await?)
    }
}

#[cfg(test)]
mod tests {
    use std::{net::SocketAddr, time::Duration};

    use super::{
        super::types::{
            ProofType, RaikoBatchProofRequest, RaikoCheckpoint, RaikoError, RaikoProposal,
        },
        RaikoClient, RaikoClientConfig,
    };

    /// Build a one-proposal batch proof request with fixed values.
    fn sample_request(proof_type: ProofType, aggregate: bool) -> RaikoBatchProofRequest {
        RaikoBatchProofRequest {
            proposals: vec![RaikoProposal {
                proposal_id: 7,
                l1_inclusion_block_number: 42,
                l2_block_numbers: vec![100, 101],
                checkpoint: RaikoCheckpoint {
                    block_number: 101,
                    block_hash: "ab".repeat(32),
                    state_root: "cd".repeat(32),
                },
                last_anchor_block_number: 40,
            }],
            prover: "ef".repeat(20),
            aggregate,
            proof_type,
        }
    }

    /// Serve `app` on an ephemeral localhost port and return its address.
    async fn spawn_app(app: axum::Router) -> SocketAddr {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
        addr
    }

    /// Build a client pointed at `addr` with the given API key and timeout.
    fn client_for(addr: SocketAddr, api_key: Option<String>, timeout: Duration) -> RaikoClient {
        RaikoClient::new(RaikoClientConfig {
            endpoint: format!("http://{addr}").parse().unwrap(),
            api_key,
            request_timeout: timeout,
        })
    }

    #[tokio::test]
    async fn posts_batch_request_with_api_key_and_parses_response() {
        let app = axum::Router::new().route(
            "/v3/proof/batch/shasta",
            axum::routing::post(|headers: axum::http::HeaderMap, body: String| async move {
                assert_eq!(headers.get("x-api-key").unwrap(), "secret");
                assert_eq!(headers.get("content-type").unwrap(), "application/json");
                let req: serde_json::Value = serde_json::from_str(&body).unwrap();
                assert_eq!(req["proof_type"], "sgx");
                assert_eq!(req["aggregate"], false);
                axum::Json(serde_json::json!({
                    "data": { "proof": { "proof": "0xff00" }, "status": "ok" },
                    "proof_type": "sgx"
                }))
            }),
        );
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });

        let client = RaikoClient::new(RaikoClientConfig {
            endpoint: format!("http://{addr}").parse().unwrap(),
            api_key: Some("secret".into()),
            request_timeout: std::time::Duration::from_secs(5),
        });
        let resp =
            client.request_batch_proof(&sample_request(ProofType::Sgx, false)).await.unwrap();
        assert_eq!(resp.proof_type, Some(ProofType::Sgx));
        resp.validate().unwrap();
    }

    #[tokio::test]
    async fn omits_api_key_header_when_unset() {
        let app = axum::Router::new().route(
            "/v3/proof/batch/shasta",
            axum::routing::post(|headers: axum::http::HeaderMap| async move {
                // Go only sets X-API-KEY when len(apiKey) > 0 (common.go:114-116).
                assert!(headers.get("x-api-key").is_none());
                axum::Json(serde_json::json!({
                    "data": { "proof": { "proof": "0xff00" }, "status": "ok" },
                    "proof_type": "sgx"
                }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        let resp =
            client.request_batch_proof(&sample_request(ProofType::Sgx, false)).await.unwrap();
        resp.validate().unwrap();
    }

    #[tokio::test]
    async fn non_200_maps_to_status_error() {
        let app = axum::Router::new().route(
            "/v3/proof/batch/shasta",
            axum::routing::post(|| async {
                (axum::http::StatusCode::INTERNAL_SERVER_ERROR, "boom")
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        let err =
            client.request_batch_proof(&sample_request(ProofType::Sgx, false)).await.unwrap_err();
        assert!(matches!(err, RaikoError::Status(500)), "expected Status(500), got {err:?}");
    }

    #[tokio::test]
    async fn request_times_out() {
        let app = axum::Router::new().route(
            "/v3/proof/batch/shasta",
            axum::routing::post(|| async {
                tokio::time::sleep(Duration::from_secs(2)).await;
                "late"
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_millis(100));
        let err =
            client.request_batch_proof(&sample_request(ProofType::Sgx, false)).await.unwrap_err();
        match err {
            RaikoError::Http(e) => assert!(e.is_timeout(), "expected timeout, got {e:?}"),
            other => panic!("expected RaikoError::Http, got {other:?}"),
        }
    }
}
