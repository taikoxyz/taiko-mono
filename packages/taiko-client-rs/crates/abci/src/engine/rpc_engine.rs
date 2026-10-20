//! [`RpcEngine`]: the [`Engine`] trait over alethia-reth's JWT-authenticated Engine API endpoint
//! (through [`rpc::auth::EngineClient`]) and its public JSON-RPC endpoint (for headers).

use std::{path::Path, time::Duration};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::{Header, TxEnvelope};
use alloy_primitives::B256;
use alloy_provider::{
    Provider, RootProvider,
    transport::{RpcError, TransportError},
};
use alloy_rpc_types_engine::{ForkchoiceState, PayloadStatusEnum};
use async_trait::async_trait;
use rpc::{
    RpcClientError,
    auth::{EngineClient, PoolSelection},
    client::{
        build_jwt_http_provider, connect_http_with_timeout, http_timeout_for, read_jwt_secret,
    },
};
use url::Url;

use super::{Engine, EngineError, PayloadVerdict, block_from_payload, payload_from_block};
use crate::envelope::ExecutionBlock;

/// [`Engine`] over alethia-reth's JSON-RPC endpoints.
#[derive(Clone, Debug)]
pub struct RpcEngine {
    /// Public L2 JSON-RPC provider (`eth_getBlockByNumber`).
    l2: RootProvider,
    /// The public endpoint's flag label, safe to include in errors and Debug output.
    l2_endpoint: String,
    /// Engine API client over the JWT-authenticated endpoint.
    auth: EngineClient,
    /// The authenticated endpoint's flag label, safe to include in errors and Debug output.
    auth_endpoint: String,
}

impl RpcEngine {
    /// Connects to the public endpoint `l2_http` and the Engine API endpoint `l2_auth`, signing
    /// every Engine API request with the hex JWT secret read from `jwt_secret`.
    ///
    /// `l2_http` must be `http` or `https`; `l2_auth` must be plain `http`, as the JWT client
    /// speaks no TLS (serve the Engine API on a local or private network). No request is sent
    /// until the first call (use [`Engine::check_capabilities`] at startup). Fails with
    /// [`EngineError::Setup`] on another scheme or an unreadable secret.
    ///
    /// `call_timeout` is the caller's deadline for one call
    /// ([`AppOptions::engine_timeout`](crate::AppOptions)); every HTTP request times out after
    /// [`http_timeout_for`]`(call_timeout)`, so the transport never cuts a call short of it.
    pub fn new(
        l2_http: Url,
        l2_auth: Url,
        jwt_secret: &Path,
        call_timeout: Duration,
    ) -> Result<Self, EngineError> {
        let scheme_error = |flag: &str, url: &Url, want: &str| {
            EngineError::Setup(format!(
                "{flag}: unsupported URL scheme `{}` (want {want})",
                url.scheme()
            ))
        };
        if !matches!(l2_http.scheme(), "http" | "https") {
            return Err(scheme_error("l2.http", &l2_http, "http or https"));
        }
        if l2_auth.scheme() != "http" {
            return Err(scheme_error(
                "l2.auth",
                &l2_auth,
                "http: the JWT-authenticated Engine API client speaks plain HTTP only",
            ));
        }
        let secret = read_jwt_secret(jwt_secret).ok_or_else(|| {
            EngineError::Setup(format!(
                "cannot read a hex JWT secret from {}",
                jwt_secret.display()
            ))
        })?;
        let timeout = http_timeout_for(call_timeout);
        let (l2_endpoint, auth_endpoint) = ("l2.http".to_owned(), "l2.auth".to_owned());
        Ok(Self::from_parts(
            connect_http_with_timeout(l2_http, timeout),
            l2_endpoint,
            build_jwt_http_provider(l2_auth, secret, timeout),
            auth_endpoint,
        ))
    }

    /// Wraps already-built providers; `*_endpoint` label them in error messages.
    pub(crate) fn from_parts(
        l2: RootProvider,
        l2_endpoint: String,
        auth: RootProvider,
        auth_endpoint: String,
    ) -> Self {
        Self { l2, l2_endpoint, auth: EngineClient::new(auth), auth_endpoint }
    }

    /// The failed Engine API call `method` as an [`EngineError`] naming the authenticated
    /// endpoint ([`client_error`]).
    fn auth_error(&self, method: &str, err: RpcClientError) -> EngineError {
        client_error(format!("{method} at {}", self.auth_endpoint), err)
    }

    /// The verdict of a payload status reply of `method` that alloy's strict decoding refused,
    /// decoded leniently ([`LenientStatus`]) from the raw result `status_of` extracts it from;
    /// otherwise `err` as an [`EngineError`] ([`RpcEngine::auth_error`]).
    fn lenient_verdict(
        &self,
        method: &str,
        err: RpcClientError,
        status_of: fn(serde_json::Value) -> Option<serde_json::Value>,
    ) -> Result<PayloadVerdict, EngineError> {
        if let RpcClientError::Rpc(RpcError::DeserError { text, .. }) = &err {
            let lenient = serde_json::from_str(text)
                .ok()
                .and_then(status_of)
                .and_then(|status| serde_json::from_value::<LenientStatus>(status).ok())
                .and_then(LenientStatus::verdict);
            if let Some(verdict) = lenient {
                return Ok(verdict);
            }
        }
        Err(self.auth_error(method, err))
    }
}

/// How many characters of a non-JSON reply body an [`EngineError::Transport`] quotes.
const BODY_EXCERPT_CHARS: usize = 120;

/// A failed JSON-RPC exchange `call` (method and endpoint) as an [`EngineError`]: transport
/// failures ([`RpcError::Transport`]: refused or broken connections, HTTP error statuses) and a
/// reply body that is not JSON at all (e.g. a proxy's HTML page) are [`EngineError::Transport`];
/// a JSON-RPC error object is [`EngineError::ErrorReply`]; anything else (a `null` result, JSON
/// that does not decode into the reply, a request that does not encode) is
/// [`EngineError::BadReply`].
fn transport_error(call: String, err: TransportError) -> EngineError {
    match err {
        RpcError::Transport(kind) => EngineError::Transport(format!("{call}: {kind}")),
        RpcError::ErrorResp(payload) => {
            EngineError::ErrorReply { call, code: payload.code, message: payload.message.into() }
        }
        RpcError::DeserError { err, text }
            if serde_json::from_str::<serde::de::IgnoredAny>(&text).is_err() =>
        {
            let excerpt: String = text.chars().take(BODY_EXCERPT_CHARS).collect();
            EngineError::Transport(format!("{call}: the reply is not JSON ({err}): {excerpt:?}"))
        }
        other => EngineError::BadReply(format!("{call}: {other}")),
    }
}

/// [`transport_error`] for the `rpc` crate's [`RpcClientError`]: its local failures (e.g. a
/// request that does not serialize) are [`EngineError::BadReply`].
fn client_error(call: String, err: RpcClientError) -> EngineError {
    match err {
        RpcClientError::Rpc(err) => transport_error(call, err),
        other => EngineError::BadReply(format!("{call}: {other}")),
    }
}

/// Maps an Engine API status to a [`PayloadVerdict`]: `ACCEPTED` and `SYNCING` both mean "not
/// executed yet".
fn verdict(status: PayloadStatusEnum) -> PayloadVerdict {
    match status {
        PayloadStatusEnum::Valid => PayloadVerdict::Valid,
        PayloadStatusEnum::Invalid { validation_error } => invalid(Some(validation_error)),
        PayloadStatusEnum::Syncing | PayloadStatusEnum::Accepted => PayloadVerdict::Syncing,
    }
}

/// [`PayloadVerdict::Invalid`] with the engine's `validationError`, or `"INVALID"` when it gave
/// none (absent, `null` or empty).
fn invalid(validation_error: Option<String>) -> PayloadVerdict {
    PayloadVerdict::Invalid(
        validation_error.filter(|e| !e.is_empty()).unwrap_or_else(|| "INVALID".to_string()),
    )
}

/// A payload status as engines may send it: alloy's [`PayloadStatusEnum`] requires a string
/// `validationError` with `INVALID`, but engines also send `null` or omit it.
#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LenientStatus {
    /// `VALID`, `INVALID`, `SYNCING` or `ACCEPTED`.
    status: String,
    /// The engine's reason for `INVALID`, if it gave one.
    #[serde(default)]
    validation_error: Option<String>,
}

impl LenientStatus {
    /// The verdict this status carries; `None` for an unknown status.
    fn verdict(self) -> Option<PayloadVerdict> {
        match self.status.as_str() {
            "VALID" => Some(PayloadVerdict::Valid),
            "INVALID" => Some(invalid(self.validation_error)),
            "SYNCING" | "ACCEPTED" => Some(PayloadVerdict::Syncing),
            _ => None,
        }
    }
}

#[async_trait]
impl Engine for RpcEngine {
    /// `engine_exchangeCapabilities` checked by [`rpc::auth::check_engine_capabilities`]; missing
    /// methods fail with [`EngineError::Setup`].
    async fn check_capabilities(&self) -> Result<(), EngineError> {
        self.auth.check_engine_capabilities().await.map_err(|e| match e {
            RpcClientError::EngineMethodsUnsupported { .. } => {
                EngineError::Setup(format!("{}: {e}", self.auth_endpoint))
            }
            e => self.auth_error("engine_exchangeCapabilities", e),
        })
    }

    /// Selects candidate pool transactions over the authenticated endpoint with explicit bounds.
    async fn pool_transactions(
        &self,
        selection: PoolSelection,
    ) -> Result<Vec<TxEnvelope>, EngineError> {
        self.auth
            .tx_pool_transactions(selection)
            .await
            .map_err(|error| self.auth_error("taikoAuth_txPoolContentWithMinTip", error))
    }

    /// `engine_forkchoiceUpdatedV3({head: parent, safe: 0, finalized: 0}, attrs)`, which must
    /// answer `VALID` with a payload id ([`EngineError::BuildNotStarted`] otherwise), then
    /// `engine_getPayloadV5`, rebuilt with [`block_from_payload`] (zk gas = `blockValue`, root =
    /// the attributes' `parentBeaconBlockRoot`).
    async fn build_block(
        &self,
        parent_hash: B256,
        attrs: TaikoPayloadAttributes,
    ) -> Result<ExecutionBlock, EngineError> {
        let root = attrs
            .payload_attributes
            .parent_beacon_block_root
            .ok_or(EngineError::NotEtnaShaped("parent_beacon_block_root"))?;
        let state = ForkchoiceState {
            head_block_hash: parent_hash,
            safe_block_hash: B256::ZERO,
            finalized_block_hash: B256::ZERO,
        };
        let updated = self
            .auth
            .engine_forkchoice_updated_v3(state, Some(attrs))
            .await
            .map_err(|e| self.auth_error("engine_forkchoiceUpdatedV3", e))?;
        let payload_id = match (&updated.payload_status.status, updated.payload_id) {
            (PayloadStatusEnum::Valid, Some(id)) => id,
            (status, id) => {
                return Err(EngineError::BuildNotStarted(format!(
                    "forkchoice on {parent_hash} answered {status} with payload id {id:?}"
                )));
            }
        };
        let envelope = self
            .auth
            .engine_get_payload_v5(payload_id)
            .await
            .map_err(|e| self.auth_error("engine_getPayloadV5", e))?;
        block_from_payload(&envelope.execution_payload, envelope.block_value, root)
    }

    /// [`payload_from_block`], then `engine_newPayloadV4`; an `INVALID` status without a
    /// `validationError` is still [`PayloadVerdict::Invalid`] ([`LenientStatus`]).
    async fn new_payload(&self, block: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        let (payload, difficulty, root) = payload_from_block(block)?;
        match self.auth.engine_new_payload_v4(&payload, difficulty, root).await {
            Ok(status) => Ok(verdict(status.status)),
            Err(e) => self.lenient_verdict("engine_newPayloadV4", e, Some),
        }
    }

    /// `engine_forkchoiceUpdatedV3` without attributes; an `INVALID` status without a
    /// `validationError` is still [`PayloadVerdict::Invalid`] ([`LenientStatus`]).
    async fn forkchoice(
        &self,
        head: B256,
        safe: B256,
        finalized: B256,
    ) -> Result<PayloadVerdict, EngineError> {
        let state = ForkchoiceState {
            head_block_hash: head,
            safe_block_hash: safe,
            finalized_block_hash: finalized,
        };
        match self.auth.engine_forkchoice_updated_v3(state, None).await {
            Ok(updated) => Ok(verdict(updated.payload_status.status)),
            Err(e) => self.lenient_verdict("engine_forkchoiceUpdatedV3", e, |mut reply| {
                reply.get_mut("payloadStatus").map(serde_json::Value::take)
            }),
        }
    }

    /// `eth_getBlockByNumber(number)` on the public endpoint; the header must hash to the reported
    /// hash ([`EngineError::HeaderHashMismatch`]) and be block `number`
    /// ([`EngineError::HeaderNumberMismatch`]).
    async fn header_by_number(&self, number: u64) -> Result<Option<Header>, EngineError> {
        let Some(block) = self.l2.get_block_by_number(number.into()).await.map_err(|e| {
            transport_error(format!("eth_getBlockByNumber({number}) at {}", self.l2_endpoint), e)
        })?
        else {
            return Ok(None);
        };
        let (header, reported) = (block.header.inner, block.header.hash);
        let computed = header.hash_slow();
        if computed != reported {
            return Err(EngineError::HeaderHashMismatch { number, reported, computed });
        }
        if header.number != number {
            return Err(EngineError::HeaderNumberMismatch { requested: number, got: header.number });
        }
        Ok(Some(header))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::rules::{ExpectedHeader, encode_extra_data, payload_attributes};
    use alloy_primitives::U256;
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types_engine::ExecutionPayloadV3;
    use alloy_transport::mock::Asserter;
    use rpc::auth::REQUIRED_ENGINE_METHODS;
    use serde_json::{Value, json};

    /// alethia-reth's `engine_getPayloadV5` output for devnet block 1 (see `convert` tests).
    const GOLDEN: &str = include_str!("testdata/etna_block_1.json");
    /// An anvil `eth_getBlockByNumber` result, used as a generic block for header reads.
    const ANVIL: &str = include_str!("../l1/testdata/anvil_get_proof.json");

    const L2: &str = "http://l2-http.test/";
    const AUTH: &str = "http://l2-auth.test/";

    struct Mocked {
        engine: RpcEngine,
        l2: Asserter,
        auth: Asserter,
    }

    fn mocked() -> Mocked {
        let (l2, auth) = (Asserter::new(), Asserter::new());
        let engine = RpcEngine::from_parts(
            ProviderBuilder::default().connect_mocked_client(l2.clone()),
            L2.to_string(),
            ProviderBuilder::default().connect_mocked_client(auth.clone()),
            AUTH.to_string(),
        );
        Mocked { engine, l2, auth }
    }

    fn golden() -> Value {
        serde_json::from_str(GOLDEN).expect("fixture is JSON")
    }

    fn golden_root() -> B256 {
        serde_json::from_value(golden()["parentBeaconBlockRoot"].clone()).unwrap()
    }

    fn golden_payload() -> ExecutionPayloadV3 {
        serde_json::from_value(golden()["executionPayload"].clone()).unwrap()
    }

    /// The `engine_getPayloadV5` envelope around the golden payload.
    fn golden_envelope() -> Value {
        json!({
            "executionPayload": golden()["executionPayload"],
            "blockValue": golden()["blockValue"],
            "blobsBundle": { "commitments": [], "proofs": [], "blobs": [] },
            "shouldOverrideBuilder": false,
            "executionRequests": [],
        })
    }

    fn golden_block() -> ExecutionBlock {
        let zk_gas: U256 = serde_json::from_value(golden()["blockValue"].clone()).unwrap();
        block_from_payload(&golden_payload(), zk_gas, golden_root()).expect("golden block")
    }

    /// Build attributes for the golden block's height carrying `root`.
    fn attrs(root: B256) -> TaikoPayloadAttributes {
        let p = golden_payload().payload_inner.payload_inner;
        payload_attributes(
            &ExpectedHeader {
                number: p.block_number,
                parent_hash: p.parent_hash,
                timestamp: p.timestamp,
                beneficiary: p.fee_recipient,
                extra_data: encode_extra_data(0, 1).unwrap(),
                parent_beacon_block_root: root,
                gas_limit: p.gas_limit,
                base_fee: u64::try_from(p.base_fee_per_gas).unwrap(),
                mix_hash: p.prev_randao,
            },
            B256::repeat_byte(0x11),
            None,
        )
    }

    fn status(status: &str, validation_error: Option<&str>) -> Value {
        json!({
            "status": status,
            "latestValidHash": B256::repeat_byte(0x01),
            "validationError": validation_error,
        })
    }

    fn fcu(status_value: Value, payload_id: Option<&str>) -> Value {
        json!({ "payloadStatus": status_value, "payloadId": payload_id })
    }

    fn selection() -> super::super::PoolSelection {
        super::super::PoolSelection {
            beneficiary: alloy_primitives::Address::repeat_byte(0x12),
            base_fee: 1_000_000_000,
            gas_limit: 30_000_000,
            max_bytes: 100_000,
            min_tip: 1_000_000,
        }
    }

    /// Pinned alethia-reth returns pending RPC transaction objects inside `txList`, with
    /// decimal list statistics; the canonical signed envelope survives those extra fields.
    fn pool_reply() -> Value {
        let transactions = crate::test_utils::sample_transactions()
            .into_iter()
            .map(|tx| {
                let mut value = serde_json::to_value(tx).unwrap();
                let object = value.as_object_mut().unwrap();
                object.insert("from".into(), json!(alloy_primitives::Address::repeat_byte(0x33)));
                object.insert("blockHash".into(), Value::Null);
                object.insert("blockNumber".into(), Value::Null);
                object.insert("transactionIndex".into(), Value::Null);
                if value["type"] != "0x0" {
                    value["gasPrice"] = json!("0x3b9aca00");
                }
                value
            })
            .collect::<Vec<_>>();
        json!([{"txList":transactions,"estimatedGasUsed":71000,"bytesLength":258}])
    }

    #[tokio::test]
    async fn pool_transactions_mock_uses_configured_list_and_records_selection() {
        let engine = crate::test_utils::MockEngine::new();
        let transactions = crate::test_utils::sample_transactions();
        engine.state().pool = transactions.clone();
        assert_eq!(engine.pool_transactions(selection()).await.unwrap(), transactions);
        assert_eq!(
            engine.calls(),
            vec![crate::test_utils::EngineCall::PoolTransactions(selection())]
        );
        engine
            .state()
            .pool_script
            .push_back(Err(EngineError::Transport("pool unavailable".into())));
        assert!(engine.pool_transactions(selection()).await.is_err());
    }

    #[tokio::test]
    async fn pool_transactions_preserve_canonical_envelopes_and_empty_pool() {
        let m = mocked();
        m.auth.push_success(&pool_reply());
        let transactions = m.engine.pool_transactions(selection()).await.unwrap();
        assert_eq!(transactions, crate::test_utils::sample_transactions());
        for result in [json!([]), json!([{"txList":[],"estimatedGasUsed":0,"bytesLength":0}])] {
            m.auth.push_success(&result);
            assert!(m.engine.pool_transactions(selection()).await.unwrap().is_empty());
        }
    }

    #[tokio::test]
    async fn pool_transactions_fail_closed_on_unusable_replies() {
        for result in [
            Value::Null,
            json!({}),
            json!([{"txList":["0x02"],"estimatedGasUsed":0,"bytesLength":0}]),
            json!([{"txList":[],"estimatedGasUsed":0,"bytesLength":0}, {"txList":[],"estimatedGasUsed":0,"bytesLength":0}]),
        ] {
            let m = mocked();
            m.auth.push_success(&result);
            assert!(
                matches!(
                    m.engine.pool_transactions(selection()).await,
                    Err(EngineError::BadReply(_))
                ),
                "{result}"
            );
        }
        let m = mocked();
        m.auth.push_failure_msg("pool unavailable");
        assert!(matches!(
            m.engine.pool_transactions(selection()).await,
            Err(EngineError::ErrorReply { .. })
        ));
    }

    #[tokio::test]
    async fn pool_transactions_send_exact_authenticated_positional_params() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        let request = tokio::spawn(async move {
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
            let response =
                json!({"jsonrpc":"2.0","id":body["id"],"result":pool_reply()}).to_string();
            socket.write_all(format!("HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",response.len(),response).as_bytes()).await.unwrap();
            body
        });
        assert_eq!(
            over_http(&url).pool_transactions(selection()).await.unwrap(),
            crate::test_utils::sample_transactions()
        );
        let request = request.await.unwrap();
        assert_eq!(request["method"], "taikoAuth_txPoolContentWithMinTip");
        assert_eq!(
            request["params"],
            json!([
                selection().beneficiary,
                1_000_000_000,
                30_000_000,
                100_000,
                null,
                1,
                1_000_000
            ])
        );
    }

    #[tokio::test]
    async fn capabilities_require_every_engine_method() {
        let m = mocked();
        m.auth.push_success(&REQUIRED_ENGINE_METHODS);
        assert_eq!(m.engine.check_capabilities().await, Ok(()));

        m.auth.push_success(&["engine_forkchoiceUpdatedV2", "engine_newPayloadV2"]);
        let err = m.engine.check_capabilities().await.unwrap_err();
        assert!(
            matches!(&err, EngineError::Setup(msg) if msg.contains("engine_getPayloadV5")),
            "{err:?}"
        );
    }

    #[tokio::test]
    async fn build_block_returns_the_hash_checked_golden_block() {
        let m = mocked();
        m.auth.push_success(&fcu(status("VALID", None), Some("0x0000000000000001")));
        m.auth.push_success(&golden_envelope());

        let parent = golden_payload().payload_inner.payload_inner.parent_hash;
        let block = m.engine.build_block(parent, attrs(golden_root())).await.expect("block");
        assert_eq!(block, golden_block());
        assert_eq!(
            block.header.hash_slow(),
            golden_payload().payload_inner.payload_inner.block_hash
        );
    }

    /// The rebuilt header commits to the attributes' root: a payload built for another root
    /// fails the hash check.
    #[tokio::test]
    async fn build_block_binds_the_attributes_root() {
        let m = mocked();
        m.auth.push_success(&fcu(status("VALID", None), Some("0x0000000000000001")));
        m.auth.push_success(&golden_envelope());

        let err = m.engine.build_block(B256::ZERO, attrs(B256::repeat_byte(0x77))).await;
        assert!(matches!(err, Err(EngineError::BlockHashMismatch { .. })), "{err:?}");
    }

    #[tokio::test]
    async fn build_block_requires_a_valid_status_and_a_payload_id() {
        for reply in [
            fcu(status("SYNCING", None), Some("0x0000000000000001")),
            fcu(status("INVALID", Some("bad parent")), None),
            fcu(status("VALID", None), None),
        ] {
            let m = mocked();
            m.auth.push_success(&reply);
            let err = m.engine.build_block(B256::ZERO, attrs(golden_root())).await;
            assert!(matches!(err, Err(EngineError::BuildNotStarted(_))), "{reply}: {err:?}");
        }
    }

    #[tokio::test]
    async fn build_block_requires_a_parent_beacon_block_root() {
        let m = mocked();
        let mut attrs = attrs(golden_root());
        attrs.payload_attributes.parent_beacon_block_root = None;
        assert_eq!(
            m.engine.build_block(B256::ZERO, attrs).await,
            Err(EngineError::NotEtnaShaped("parent_beacon_block_root"))
        );
    }

    #[tokio::test]
    async fn new_payload_maps_the_status() {
        let cases = [
            (status("VALID", None), PayloadVerdict::Valid),
            (
                status("INVALID", Some("state root mismatch")),
                PayloadVerdict::Invalid("state root mismatch".into()),
            ),
            (status("INVALID", Some("")), PayloadVerdict::Invalid("INVALID".into())),
            (status("SYNCING", None), PayloadVerdict::Syncing),
            (status("ACCEPTED", None), PayloadVerdict::Syncing),
        ];
        for (reply, verdict) in cases {
            let m = mocked();
            m.auth.push_success(&reply);
            assert_eq!(m.engine.new_payload(&golden_block()).await, Ok(verdict), "{reply}");
        }
    }

    /// `INVALID_BLOCK_HASH` left the Engine API with Shanghai and is not a V3+ status; a reply
    /// carrying it, or no result at all, is a reply-class error, never a verdict.
    #[tokio::test]
    async fn new_payload_rejects_an_unknown_status() {
        for reply in [status("INVALID_BLOCK_HASH", Some("bad hash")), Value::Null, json!({})] {
            let m = mocked();
            m.auth.push_success(&reply);
            let err = m.engine.new_payload(&golden_block()).await.unwrap_err();
            assert!(
                matches!(&err, EngineError::BadReply(msg)
                    if msg.contains(AUTH) && msg.contains("engine_newPayloadV4")),
                "{reply}: {err:?}"
            );
            assert!(!err.is_retryable(), "{reply}");
        }
    }

    /// alethia-reth may send `INVALID` with a `null` or absent `validationError`, which alloy's
    /// `PayloadStatusEnum` cannot decode: the verdict is still `INVALID`, never an error that
    /// `FinalizeBlock` would retry.
    #[tokio::test]
    async fn invalid_without_a_validation_error_is_invalid() {
        let null = json!({ "status": "INVALID", "latestValidHash": null, "validationError": null });
        let absent = json!({ "status": "INVALID", "latestValidHash": B256::repeat_byte(1) });
        for reply in [null, absent] {
            let m = mocked();
            m.auth.push_success(&reply);
            assert_eq!(
                m.engine.new_payload(&golden_block()).await,
                Ok(PayloadVerdict::Invalid("INVALID".into())),
                "newPayload {reply}"
            );

            let m = mocked();
            m.auth.push_success(&fcu(reply.clone(), None));
            let head = B256::repeat_byte(0x0a);
            assert_eq!(
                m.engine.forkchoice(head, head, B256::ZERO).await,
                Ok(PayloadVerdict::Invalid("INVALID".into())),
                "forkchoice {reply}"
            );
        }
    }

    /// A JSON-RPC error object is an [`EngineError::ErrorReply`] carrying its code and message;
    /// the code decides whether a retry may cure it ([`EngineError::is_retryable`]).
    #[tokio::test]
    async fn json_rpc_error_replies_are_reply_errors() {
        let error = |code: i64, message: &str| -> alloy_transport::mock::MockResponse {
            alloy_transport::mock::MockResponse::Failure(
                serde_json::from_value(json!({ "code": code, "message": message })).unwrap(),
            )
        };
        let m = mocked();
        m.auth.push(error(-38002, "Invalid forkchoice state"));
        let err = m.engine.forkchoice(B256::ZERO, B256::ZERO, B256::ZERO).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::ErrorReply { call, code: -38002, message }
                if call.contains(AUTH) && call.contains("engine_forkchoiceUpdatedV3")
                    && message == "Invalid forkchoice state"),
            "{err:?}"
        );
        assert!(!err.is_retryable(), "invalid forkchoice state is a verdict");

        m.auth.push(error(-32602, "Invalid params"));
        let err = m.engine.new_payload(&golden_block()).await.unwrap_err();
        assert!(matches!(&err, EngineError::ErrorReply { code: -32602, .. }), "{err:?}");
        assert!(!err.is_retryable(), "invalid params is a verdict");

        m.auth.push(error(-32603, "beacon consensus engine task stopped"));
        let err = m.engine.new_payload(&golden_block()).await.unwrap_err();
        assert!(matches!(&err, EngineError::ErrorReply { code: -32603, .. }), "{err:?}");
        assert!(err.is_retryable(), "an internal error is transient");

        m.l2.push(error(-32000, "header not found"));
        let err = m.engine.header_by_number(1).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::ErrorReply { call, code: -32000, .. }
                if call.contains(L2) && call.contains("eth_getBlockByNumber")),
            "{err:?}"
        );
        assert!(err.is_retryable(), "a server-range error is transient");
    }

    /// Serves every HTTP request on a local port with `200 OK`, `content_type` and `body`, as a
    /// proxy or login page in front of the engine might; returns the endpoint.
    async fn http_200(content_type: &'static str, body: &'static str) -> Url {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};

        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let url = Url::parse(&format!("http://{}/", listener.local_addr().unwrap())).unwrap();
        tokio::spawn(async move {
            while let Ok((mut socket, _)) = listener.accept().await {
                tokio::spawn(async move {
                    // Read the whole request (head and `content-length` body) before answering.
                    let (mut request, mut chunk) = (Vec::new(), [0u8; 4096]);
                    loop {
                        if let Some(end) = request.windows(4).position(|w| w == b"\r\n\r\n") {
                            let head = String::from_utf8_lossy(&request[..end]).to_lowercase();
                            let len = head
                                .lines()
                                .find_map(|line| line.strip_prefix("content-length:"))
                                .and_then(|len| len.trim().parse::<usize>().ok())
                                .unwrap_or(0);
                            if request.len() >= end + 4 + len {
                                break;
                            }
                        }
                        match socket.read(&mut chunk).await {
                            Ok(0) | Err(_) => return,
                            Ok(n) => request.extend_from_slice(&chunk[..n]),
                        }
                    }
                    let response = format!(
                        "HTTP/1.1 200 OK\r\ncontent-type: {content_type}\r\ncontent-length: {}\r\n\
                         connection: close\r\n\r\n{body}",
                        body.len()
                    );
                    let _ = socket.write_all(response.as_bytes()).await;
                    let _ = socket.shutdown().await;
                });
            }
        });
        url
    }

    /// An [`RpcEngine`] whose public and Engine API endpoints are both `url`, over HTTP.
    fn over_http(url: &Url) -> RpcEngine {
        RpcEngine::from_parts(
            ProviderBuilder::default().connect_http(url.clone()),
            url.to_string(),
            ProviderBuilder::default().connect_http(url.clone()),
            url.to_string(),
        )
    }

    /// An HTTP 200 whose body is not JSON at all (e.g. a proxy's error or login page in front of
    /// the engine) says nothing about the call: a transport failure, retried. A JSON body that
    /// does not decode into the reply stays [`EngineError::BadReply`].
    #[tokio::test]
    async fn a_non_json_body_is_a_transport_error() {
        let engine = over_http(&http_200("text/html", "<html><body>Sign in</body></html>").await);
        let errors = [
            engine.new_payload(&golden_block()).await.unwrap_err(),
            engine.forkchoice(B256::ZERO, B256::ZERO, B256::ZERO).await.unwrap_err(),
            engine.header_by_number(1).await.unwrap_err(),
        ];
        for (err, method) in errors.iter().zip([
            "engine_newPayloadV4",
            "engine_forkchoiceUpdatedV3",
            "eth_getBlockByNumber",
        ]) {
            assert!(
                matches!(err, EngineError::Transport(msg) if msg.contains(method) && msg.contains("Sign in")),
                "{err:?}"
            );
            assert!(err.is_retryable());
        }

        let engine = over_http(&http_200("application/json", r#"{"login":"required"}"#).await);
        let errors = [
            engine.new_payload(&golden_block()).await.unwrap_err(),
            engine.forkchoice(B256::ZERO, B256::ZERO, B256::ZERO).await.unwrap_err(),
            engine.header_by_number(1).await.unwrap_err(),
        ];
        for err in errors {
            assert!(matches!(&err, EngineError::BadReply(_)), "{err:?}");
            assert!(!err.is_retryable());
        }
    }

    /// A reply that fails to decode is classified by whether it is JSON at all.
    #[test]
    fn undecodable_replies_are_classified_by_whether_they_are_json() {
        let deser = |text: &str| {
            TransportError::deser_err(serde_json::from_str::<Value>("x").unwrap_err(), text)
        };
        for text in ["<html>502 Bad Gateway</html>", "", "Bad Gateway", "{\"status\":"] {
            let err = transport_error("engine_x at http://el.test/".into(), deser(text));
            assert!(matches!(&err, EngineError::Transport(_)), "{text:?}: {err:?}");
        }
        for text in ["null", "{}", "[]", r#"{"status":"MAYBE"}"#, "  \"text\"\n"] {
            let err = transport_error("engine_x at http://el.test/".into(), deser(text));
            assert!(matches!(&err, EngineError::BadReply(_)), "{text:?}: {err:?}");
        }
    }

    #[tokio::test]
    async fn new_payload_rejects_a_non_etna_block_before_sending() {
        let m = mocked();
        let mut block = golden_block();
        block.header.parent_beacon_block_root = None;
        assert_eq!(
            m.engine.new_payload(&block).await,
            Err(EngineError::NotEtnaShaped("parent_beacon_block_root"))
        );
    }

    #[tokio::test]
    async fn forkchoice_maps_the_status() {
        let cases = [
            (status("VALID", None), PayloadVerdict::Valid),
            (
                status("INVALID", Some("unknown ancestor")),
                PayloadVerdict::Invalid("unknown ancestor".into()),
            ),
            (status("SYNCING", None), PayloadVerdict::Syncing),
        ];
        for (reply, verdict) in cases {
            let m = mocked();
            m.auth.push_success(&fcu(reply.clone(), None));
            let head = B256::repeat_byte(0x0a);
            assert_eq!(m.engine.forkchoice(head, head, B256::ZERO).await, Ok(verdict), "{reply}");
        }
    }

    #[tokio::test]
    async fn header_by_number_returns_the_hash_checked_header() {
        let block: Value = serde_json::from_str::<Value>(ANVIL).unwrap()["block"].clone();
        let hash: B256 = serde_json::from_value(block["hash"].clone()).unwrap();

        let m = mocked();
        m.l2.push_success(&block);
        let header = m.engine.header_by_number(1).await.expect("header").expect("present");
        assert_eq!(header.hash_slow(), hash);

        m.l2.push_success(&Value::Null);
        assert_eq!(m.engine.header_by_number(2).await, Ok(None));

        let mut tampered = block;
        tampered["gasUsed"] = Value::String("0x5".into());
        m.l2.push_success(&tampered);
        let err = m.engine.header_by_number(1).await;
        assert!(
            matches!(err, Err(EngineError::HeaderHashMismatch { number: 1, reported, .. }) if reported == hash),
            "{err:?}"
        );
    }

    /// An answer for another block than requested is refused, even though it is self-consistent.
    #[tokio::test]
    async fn header_by_number_rejects_another_block() {
        let block: Value = serde_json::from_str::<Value>(ANVIL).unwrap()["block"].clone();
        let m = mocked();
        m.l2.push_success(&block);
        let err = m.engine.header_by_number(2).await;
        assert_eq!(err, Err(EngineError::HeaderNumberMismatch { requested: 2, got: 1 }));
        assert!(!err.unwrap_err().is_retryable());
    }

    /// The mocked transport fails in transport when it has no response queued (as a refused
    /// connection would): a transport-class error naming the endpoint and method.
    #[tokio::test]
    async fn transport_errors_name_the_endpoint_and_method() {
        let m = mocked();
        let err = m.engine.forkchoice(B256::ZERO, B256::ZERO, B256::ZERO).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::Transport(msg)
                if msg.contains(AUTH) && msg.contains("engine_forkchoiceUpdatedV3")),
            "{err:?}"
        );
        assert!(err.is_retryable());

        let err = m.engine.new_payload(&golden_block()).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::Transport(msg) if msg.contains("engine_newPayloadV4")),
            "{err:?}"
        );

        let err = m.engine.header_by_number(1).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::Transport(msg)
                if msg.contains(L2) && msg.contains("eth_getBlockByNumber")),
            "{err:?}"
        );
    }

    /// The public endpoint may use TLS; the JWT client speaks plain HTTP only, so an `https`
    /// Engine API endpoint is refused at startup instead of failing every call.
    #[test]
    fn new_validates_schemes_and_the_jwt_secret() {
        let jwt = Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex"));
        let http = |s: &str| Url::parse(s).unwrap();
        let new = |l2: &str, auth: &str, jwt: &Path| {
            RpcEngine::new(http(l2), http(auth), jwt, Duration::from_secs(5))
        };

        assert!(new(L2, AUTH, jwt).is_ok());
        assert!(new("https://l2.test/", AUTH, jwt).is_ok());
        for (l2, auth, flag) in [
            ("ws://l2.test", AUTH, "l2.http"),
            (L2, "ipc://auth.test", "l2.auth"),
            (L2, "https://auth.test", "l2.auth"),
        ] {
            let err = new(l2, auth, jwt).unwrap_err();
            assert!(
                matches!(&err, EngineError::Setup(msg) if msg.starts_with(flag) && msg.contains("scheme")),
                "{l2} {auth}: {err:?}"
            );
        }
        let err = new(L2, "https://auth.test", jwt).unwrap_err().to_string();
        assert!(err.contains("plain HTTP only"), "{err}");
        let err = new(L2, AUTH, Path::new("/nonexistent/jwt.hex")).unwrap_err();
        assert!(
            matches!(&err, EngineError::Setup(msg) if msg.contains("/nonexistent/jwt.hex")),
            "{err:?}"
        );
    }

    #[test]
    fn engine_setup_and_debug_hide_endpoint_credentials() {
        let jwt = Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex"));
        let endpoint = |scheme| {
            Url::parse(&format!(
                "{scheme}://user-secret:pass-secret@localhost/path-secret?key=query-secret"
            ))
            .unwrap()
        };
        let error =
            RpcEngine::new(endpoint("http"), endpoint("https"), jwt, Duration::from_secs(1))
                .unwrap_err();
        let engine =
            RpcEngine::new(endpoint("http"), endpoint("http"), jwt, Duration::from_secs(1))
                .unwrap();
        let call_error = engine
            .auth_error("engine_getPayloadV5", RpcClientError::RpcMessage("unreachable".into()));
        let rendered = format!("{error}\n{error:?}\n{engine:?}\n{call_error}\n{call_error:?}");
        for credential in ["user-secret", "pass-secret", "path-secret", "query-secret"] {
            assert!(!rendered.contains(credential), "Engine errors or debug exposed {credential}");
        }
        assert!(error.to_string().contains("l2.auth"));
        assert!(call_error.to_string().contains("engine_getPayloadV5"));
    }
}
