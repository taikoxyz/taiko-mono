//! [`RpcEngine`]: the [`Engine`] trait over alethia-reth's JWT-authenticated Engine API endpoint
//! (through [`rpc::auth::EngineClient`]) and its public JSON-RPC endpoint (for headers).

use std::path::Path;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::Header;
use alloy_primitives::B256;
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types_engine::{ForkchoiceState, ForkchoiceUpdated, PayloadStatusEnum};
use async_trait::async_trait;
use rpc::{
    RpcClientError,
    auth::EngineClient,
    client::{build_jwt_http_provider, connect_http_with_timeout, read_jwt_secret},
};
use url::Url;

use super::{Engine, EngineError, PayloadVerdict, block_from_payload, payload_from_block};
use crate::envelope::ExecutionBlock;

/// [`Engine`] over alethia-reth's JSON-RPC endpoints.
#[derive(Clone, Debug)]
pub struct RpcEngine {
    /// Public L2 JSON-RPC provider (`eth_getBlockByNumber`).
    l2: RootProvider,
    /// The public endpoint, named in [`EngineError::Rpc`] messages.
    l2_endpoint: String,
    /// Engine API client over the JWT-authenticated endpoint.
    auth: EngineClient,
    /// The authenticated endpoint, named in [`EngineError::Rpc`] messages.
    auth_endpoint: String,
}

impl RpcEngine {
    /// Connects to the public endpoint `l2_http` and the Engine API endpoint `l2_auth`, signing
    /// every Engine API request with the hex JWT secret read from `jwt_secret`.
    ///
    /// Both URLs must be `http`/`https`; no request is sent until the first call (use
    /// [`Engine::check_capabilities`] at startup). Fails with [`EngineError::Setup`] on another
    /// scheme or an unreadable secret.
    pub fn new(l2_http: Url, l2_auth: Url, jwt_secret: &Path) -> Result<Self, EngineError> {
        for (flag, url) in [("l2.http", &l2_http), ("l2.auth", &l2_auth)] {
            if !matches!(url.scheme(), "http" | "https") {
                return Err(EngineError::Setup(format!(
                    "{flag} {url}: unsupported URL scheme `{}` (want http or https)",
                    url.scheme()
                )));
            }
        }
        let secret = read_jwt_secret(jwt_secret).ok_or_else(|| {
            EngineError::Setup(format!(
                "cannot read a hex JWT secret from {}",
                jwt_secret.display()
            ))
        })?;
        Ok(Self::from_parts(
            connect_http_with_timeout(l2_http.clone()),
            l2_http.to_string(),
            build_jwt_http_provider(l2_auth.clone(), secret),
            l2_auth.to_string(),
        ))
    }

    /// Wraps already-built providers; `*_endpoint` label them in error messages.
    fn from_parts(
        l2: RootProvider,
        l2_endpoint: String,
        auth: RootProvider,
        auth_endpoint: String,
    ) -> Self {
        Self { l2, l2_endpoint, auth: EngineClient::new(auth), auth_endpoint }
    }

    /// An [`EngineError::Rpc`] naming the authenticated endpoint and `method`.
    fn auth_error(&self, method: &str, err: impl std::fmt::Display) -> EngineError {
        EngineError::Rpc(format!("{method} at {}: {err}", self.auth_endpoint))
    }

    /// `engine_forkchoiceUpdatedV3(state, attrs)` with transport errors named.
    async fn forkchoice_updated(
        &self,
        state: ForkchoiceState,
        attrs: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated, EngineError> {
        self.auth
            .engine_forkchoice_updated_v3(state, attrs)
            .await
            .map_err(|e| self.auth_error("engine_forkchoiceUpdatedV3", e))
    }
}

/// Maps an Engine API status to a [`PayloadVerdict`]: `ACCEPTED` and `SYNCING` both mean "not
/// executed yet".
fn verdict(status: PayloadStatusEnum) -> PayloadVerdict {
    match status {
        PayloadStatusEnum::Valid => PayloadVerdict::Valid,
        PayloadStatusEnum::Invalid { validation_error } if validation_error.is_empty() => {
            PayloadVerdict::Invalid("INVALID".to_string())
        }
        PayloadStatusEnum::Invalid { validation_error } => {
            PayloadVerdict::Invalid(validation_error)
        }
        PayloadStatusEnum::Syncing | PayloadStatusEnum::Accepted => PayloadVerdict::Syncing,
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
        let updated = self.forkchoice_updated(state, Some(attrs)).await?;
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

    /// [`payload_from_block`], then `engine_newPayloadV4`.
    async fn new_payload(&self, block: &ExecutionBlock) -> Result<PayloadVerdict, EngineError> {
        let (payload, difficulty, root) = payload_from_block(block)?;
        let status = self
            .auth
            .engine_new_payload_v4(&payload, difficulty, root)
            .await
            .map_err(|e| self.auth_error("engine_newPayloadV4", e))?;
        Ok(verdict(status.status))
    }

    /// `engine_forkchoiceUpdatedV3` without attributes.
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
        Ok(verdict(self.forkchoice_updated(state, None).await?.payload_status.status))
    }

    /// `eth_getBlockByNumber(number)` on the public endpoint.
    async fn header_by_number(&self, number: u64) -> Result<Option<Header>, EngineError> {
        let Some(block) = self.l2.get_block_by_number(number.into()).await.map_err(|e| {
            EngineError::Rpc(format!("eth_getBlockByNumber({number}) at {}: {e}", self.l2_endpoint))
        })?
        else {
            return Ok(None);
        };
        let (header, reported) = (block.header.inner, block.header.hash);
        let computed = header.hash_slow();
        if computed != reported {
            return Err(EngineError::HeaderHashMismatch { number, reported, computed });
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
    /// carrying it is an error, never a verdict.
    #[tokio::test]
    async fn new_payload_rejects_an_unknown_status() {
        let m = mocked();
        m.auth.push_success(&status("INVALID_BLOCK_HASH", Some("bad hash")));
        let err = m.engine.new_payload(&golden_block()).await;
        assert!(matches!(err, Err(EngineError::Rpc(_))), "{err:?}");
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

    #[tokio::test]
    async fn transport_errors_name_the_endpoint_and_method() {
        let m = mocked();
        m.auth.push_failure_msg("connection refused");
        let err = m.engine.forkchoice(B256::ZERO, B256::ZERO, B256::ZERO).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::Rpc(msg)
                if msg.contains(AUTH) && msg.contains("engine_forkchoiceUpdatedV3")
                    && msg.contains("connection refused")),
            "{err:?}"
        );

        m.l2.push_failure_msg("timeout");
        let err = m.engine.header_by_number(1).await.unwrap_err();
        assert!(
            matches!(&err, EngineError::Rpc(msg)
                if msg.contains(L2) && msg.contains("eth_getBlockByNumber") && msg.contains("timeout")),
            "{err:?}"
        );
    }

    #[test]
    fn new_validates_schemes_and_the_jwt_secret() {
        let jwt = Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../../tests/docker/jwt.hex"));
        let http = |s: &str| Url::parse(s).unwrap();

        assert!(RpcEngine::new(http(L2), http(AUTH), jwt).is_ok());
        for (l2, auth) in [("ws://l2.test", AUTH), (L2, "ipc://auth.test")] {
            let err = RpcEngine::new(http(l2), http(auth), jwt).unwrap_err();
            assert!(matches!(&err, EngineError::Setup(msg) if msg.contains("scheme")), "{err:?}");
        }
        let err =
            RpcEngine::new(http(L2), http(AUTH), Path::new("/nonexistent/jwt.hex")).unwrap_err();
        assert!(
            matches!(&err, EngineError::Setup(msg) if msg.contains("/nonexistent/jwt.hex")),
            "{err:?}"
        );
    }
}
