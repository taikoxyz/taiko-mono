//! HTTP client for the raiko proving service.

use std::time::Duration;

use url::Url;

use super::types::{
    RaikoBatchProofRequest, RaikoError, RaikoProofResponse, RaikoProverStatusResponse,
};

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
    /// Endpoint path for discarding the ZK (`zk_any`) backlog (raiko2 #93).
    const CLEAR_PATH: &'static str = "/v3/prover/clear";
    /// Endpoint path for the ZK backend idle status (raiko2 #93).
    const STATUS_PATH: &'static str = "/v3/prover/status";

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
        let url = self
            .cfg
            .endpoint
            .join(Self::BATCH_PROOF_PATH)
            .map_err(|_| RaikoError::Failed("invalid raiko endpoint".to_owned()))?;
        let resp = self.with_api_key(self.http.post(url).json(request)).send().await?;
        let status = resp.status();
        if status == reqwest::StatusCode::TOO_MANY_REQUESTS {
            tracing::error!(
                "raiko rate limited (HTTP 429); using your own Taiko L2 node as raiko's RPC is recommended"
            );
        }
        // Go accepts exactly HTTP 200 (common.go:123), not any 2xx.
        if status != reqwest::StatusCode::OK {
            return Err(RaikoError::Failed(format!(
                "raiko returned http status {}",
                status.as_u16()
            )));
        }
        Ok(resp.json::<RaikoProofResponse>().await?)
    }

    /// Apply the optional `X-API-KEY` header (omitted when `None`/empty), Go
    /// `common.go:114-116`.
    fn with_api_key(&self, req: reqwest::RequestBuilder) -> reqwest::RequestBuilder {
        match self.cfg.api_key.as_deref().map(str::trim).filter(|key| !key.is_empty()) {
            Some(key) => req.header("X-API-KEY", key),
            None => req,
        }
    }

    /// `POST /v3/prover/clear` — discard non-terminal `zk_any` tasks on the ZK
    /// backend. HTTP 200 = success; the response body is unused.
    pub async fn clear_backlog(&self) -> Result<(), RaikoError> {
        let url = self
            .cfg
            .endpoint
            .join(Self::CLEAR_PATH)
            .map_err(|_| RaikoError::Failed("invalid raiko endpoint".to_owned()))?;
        let resp = self.with_api_key(self.http.post(url)).send().await?;
        let status = resp.status();
        if status != reqwest::StatusCode::OK {
            return Err(RaikoError::Failed(format!(
                "raiko returned http status {}",
                status.as_u16()
            )));
        }
        Ok(())
    }

    /// `GET /v3/prover/status` — true iff `data.clean`, i.e. the ZK backend is
    /// fully idle.
    pub async fn prover_status_clean(&self) -> Result<bool, RaikoError> {
        let url = self
            .cfg
            .endpoint
            .join(Self::STATUS_PATH)
            .map_err(|_| RaikoError::Failed("invalid raiko endpoint".to_owned()))?;
        let resp = self.with_api_key(self.http.get(url)).send().await?;
        let status = resp.status();
        if status != reqwest::StatusCode::OK {
            return Err(RaikoError::Failed(format!(
                "raiko returned http status {}",
                status.as_u16()
            )));
        }
        Ok(resp.json::<RaikoProverStatusResponse>().await?.data.clean)
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
        let addr = spawn_app(app).await;

        let client = client_for(addr, Some("secret".into()), Duration::from_secs(5));
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
        assert!(
            matches!(&err, RaikoError::Failed(msg) if msg == "raiko returned http status 500"),
            "expected Failed(\"... 500\"), got {err:?}"
        );
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

    #[tokio::test]
    async fn clear_backlog_posts_to_clear_endpoint() {
        let app = axum::Router::new().route(
            "/v3/prover/clear",
            axum::routing::post(|headers: axum::http::HeaderMap| async move {
                assert_eq!(headers.get("x-api-key").unwrap(), "secret");
                axum::Json(serde_json::json!({ "status": "ok" }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, Some("secret".into()), Duration::from_secs(5));
        client.clear_backlog().await.unwrap();
    }

    #[tokio::test]
    async fn clear_backlog_errors_on_non_200() {
        let app = axum::Router::new().route(
            "/v3/prover/clear",
            axum::routing::post(|| async { axum::http::StatusCode::INTERNAL_SERVER_ERROR }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(client.clear_backlog().await.is_err());
    }

    #[tokio::test]
    async fn prover_status_clean_parses_clean_field() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async {
                axum::Json(serde_json::json!({
                    "status": "ok",
                    "data": { "clean": true, "tasks": { "pending": 0 } }
                }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(client.prover_status_clean().await.unwrap());
    }

    #[tokio::test]
    async fn prover_status_not_clean() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async {
                axum::Json(serde_json::json!({ "data": { "clean": false } }))
            }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(!client.prover_status_clean().await.unwrap());
    }

    #[tokio::test]
    async fn prover_status_errors_on_non_200() {
        let app = axum::Router::new().route(
            "/v3/prover/status",
            axum::routing::get(|| async { axum::http::StatusCode::NOT_FOUND }),
        );
        let addr = spawn_app(app).await;

        let client = client_for(addr, None, Duration::from_secs(5));
        assert!(client.prover_status_clean().await.is_err());
    }
}
