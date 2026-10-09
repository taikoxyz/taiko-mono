//! Authenticated RPC extensions for Taiko execution engine.

use std::borrow::Cow;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::{B256, Bytes};
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV5, ExecutionPayloadV3, ForkchoiceState, ForkchoiceUpdated, PayloadId,
    PayloadStatus,
};
use anyhow::anyhow;
use serde_json::Value;

use super::client::Client;
use crate::error::{Result, RpcClientError};

/// The Engine API methods this client calls, for every fork: the Osaka methods alethia-reth
/// serves since it removed the V2 methods.
pub const REQUIRED_ENGINE_METHODS: [&str; 3] =
    ["engine_forkchoiceUpdatedV3", "engine_getPayloadV5", "engine_newPayloadV4"];

/// JSON payload submitted as the first `engine_newPayloadV4` argument.
///
/// Exactly the 17 standard `ExecutionPayloadV3` properties plus `headerDifficulty`: alethia-reth
/// rejects any other property on this route, including the legacy `txHash`, `withdrawalsHash`,
/// `taikoBlock` and `slotNumber` fields, even when they are null.
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct EngineNewPayloadV4Request<'a> {
    /// Standard execution payload fields, including the required transaction array.
    #[serde(flatten)]
    payload: &'a ExecutionPayloadV3,
    /// The block's finalized zk gas, restored as its header difficulty.
    ///
    /// Serialized as a decimal JSON number, which alethia-reth requires; zero is valid (an empty
    /// Etna block has no zk gas).
    header_difficulty: u64,
}

/// Serialize an execution payload and its header difficulty into the `engine_newPayloadV4`
/// payload object.
fn engine_new_payload_v4_value(
    payload: &ExecutionPayloadV3,
    header_difficulty: u64,
) -> Result<Value> {
    serde_json::to_value(EngineNewPayloadV4Request { payload, header_difficulty })
        .map_err(|err| RpcClientError::Other(anyhow!(err)))
}

/// Positional `engine_newPayloadV4` params: the payload object, the empty
/// `expectedBlobVersionedHashes`, the `parentBeaconBlockRoot` and the empty `executionRequests`.
type EngineNewPayloadV4Params = (Value, Vec<B256>, B256, Vec<Bytes>);

/// Build the positional `engine_newPayloadV4` params
/// `(payload, [], parentBeaconBlockRoot, [])`; Taiko blocks carry no blobs and no requests.
fn engine_new_payload_v4_params(
    payload: &ExecutionPayloadV3,
    header_difficulty: u64,
    parent_beacon_block_root: B256,
) -> Result<EngineNewPayloadV4Params> {
    Ok((
        engine_new_payload_v4_value(payload, header_difficulty)?,
        Vec::new(),
        parent_beacon_block_root,
        Vec::new(),
    ))
}

/// Build the positional `engine_forkchoiceUpdatedV3` params `(forkchoiceState, attributes)`.
///
/// `None` attributes only move the forkchoice and serialize as JSON `null`.
fn engine_forkchoice_updated_v3_params(
    forkchoice_state: ForkchoiceState,
    payload_attributes: Option<&TaikoPayloadAttributes>,
) -> Result<(Value, Option<Value>)> {
    let forkchoice_state = serde_json::to_value(forkchoice_state)
        .map_err(|err| RpcClientError::Other(anyhow!(err)))?;
    let payload_attributes = payload_attributes
        .map(serde_json::to_value)
        .transpose()
        .map_err(|err| RpcClientError::Other(anyhow!(err)))?;
    Ok((forkchoice_state, payload_attributes))
}

/// Check the execution engine's advertised Engine API methods against
/// [`REQUIRED_ENGINE_METHODS`], returning [`RpcClientError::EngineMethodsUnsupported`] naming the
/// missing ones.
pub fn check_engine_capabilities(advertised: Vec<String>) -> Result<()> {
    let missing = REQUIRED_ENGINE_METHODS
        .into_iter()
        .filter(|method| !advertised.iter().any(|advertised| advertised == method))
        .collect::<Vec<_>>();
    if missing.is_empty() {
        Ok(())
    } else {
        Err(RpcClientError::EngineMethodsUnsupported { missing, advertised })
    }
}

/// Engine API client over one JWT-authenticated provider.
///
/// Holds nothing but the provider, so callers that never talk to L1 (the `abci` crate) can drive
/// the execution engine without building a full [`Client`]; [`Client`] delegates its Engine API
/// methods here.
#[derive(Clone, Debug)]
pub struct EngineClient {
    /// JWT-authenticated provider for the execution engine's auth RPC endpoint.
    pub provider: RootProvider,
}

impl EngineClient {
    /// Wrap an already-authenticated provider (see [`crate::client::build_jwt_http_provider`]).
    pub const fn new(provider: RootProvider) -> Self {
        Self { provider }
    }

    /// Verify through `engine_exchangeCapabilities` that the execution engine serves every
    /// method in [`REQUIRED_ENGINE_METHODS`] ([`check_engine_capabilities`]).
    ///
    /// An execution engine from before the Osaka switch advertises only the V2 methods, so pairing
    /// it with this client fails here at startup instead of on the first Engine API call.
    pub async fn check_engine_capabilities(&self) -> Result<()> {
        let advertised = self
            .provider
            .raw_request(Cow::Borrowed("engine_exchangeCapabilities"), (REQUIRED_ENGINE_METHODS,))
            .await?;
        check_engine_capabilities(advertised)
    }

    /// Update the forkchoice state via `engine_forkchoiceUpdatedV3`, optionally starting a payload
    /// build.
    ///
    /// The attributes are forwarded unchanged, so the caller must give every build
    /// `withdrawals: []` and a `parentBeaconBlockRoot`: zero before Etna, the anchor block's L1
    /// state root from Etna on. `None` attributes only move the forkchoice and are sent as JSON
    /// `null`.
    pub async fn engine_forkchoice_updated_v3(
        &self,
        forkchoice_state: ForkchoiceState,
        payload_attributes: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated> {
        let params =
            engine_forkchoice_updated_v3_params(forkchoice_state, payload_attributes.as_ref())?;

        self.provider
            .raw_request(Cow::Borrowed("engine_forkchoiceUpdatedV3"), params)
            .await
            .map_err(Into::into)
    }

    /// Retrieve a built payload via `engine_getPayloadV5`.
    ///
    /// Taiko reuses `blockValue` to carry the block's finalized zk gas, i.e. its header
    /// difficulty, which the matching `engine_newPayloadV4` call sends back as
    /// `headerDifficulty`. The envelope does not carry the parent beacon block root.
    pub async fn engine_get_payload_v5(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV5> {
        self.provider
            .raw_request(Cow::Borrowed("engine_getPayloadV5"), (payload_id,))
            .await
            .map_err(Into::into)
    }

    /// Submit a payload via `engine_newPayloadV4(payload, [], parentBeaconBlockRoot, [])`.
    ///
    /// `parent_beacon_block_root` must be the root sent with the forkchoice update that started
    /// the build (or, for an existing block, its header root); `header_difficulty` is the block's
    /// zk gas.
    pub async fn engine_new_payload_v4(
        &self,
        payload: &ExecutionPayloadV3,
        header_difficulty: u64,
        parent_beacon_block_root: B256,
    ) -> Result<PayloadStatus> {
        let params =
            engine_new_payload_v4_params(payload, header_difficulty, parent_beacon_block_root)?;

        self.provider
            .raw_request(Cow::Borrowed("engine_newPayloadV4"), params)
            .await
            .map_err(Into::into)
    }
}

impl Client {
    /// An [`EngineClient`] over this client's `l2_auth_provider`.
    pub fn engine(&self) -> EngineClient {
        EngineClient::new(self.l2_auth_provider.clone())
    }

    /// [`EngineClient::check_engine_capabilities`] over `l2_auth_provider`.
    pub async fn check_engine_capabilities(&self) -> Result<()> {
        self.engine().check_engine_capabilities().await
    }

    /// [`EngineClient::engine_forkchoice_updated_v3`] over `l2_auth_provider`.
    pub async fn engine_forkchoice_updated_v3(
        &self,
        forkchoice_state: ForkchoiceState,
        payload_attributes: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated> {
        self.engine().engine_forkchoice_updated_v3(forkchoice_state, payload_attributes).await
    }

    /// [`EngineClient::engine_get_payload_v5`] over `l2_auth_provider`.
    pub async fn engine_get_payload_v5(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV5> {
        self.engine().engine_get_payload_v5(payload_id).await
    }

    /// [`EngineClient::engine_new_payload_v4`] over `l2_auth_provider`.
    pub async fn engine_new_payload_v4(
        &self,
        payload: &ExecutionPayloadV3,
        header_difficulty: u64,
        parent_beacon_block_root: B256,
    ) -> Result<PayloadStatus> {
        self.engine()
            .engine_new_payload_v4(payload, header_difficulty, parent_beacon_block_root)
            .await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alethia_reth_primitives::payload::attributes::RpcL1Origin;
    use alloy_primitives::{Address, B256, Bytes, U256};
    use alloy_rpc_types_engine::{ExecutionPayloadV1, ExecutionPayloadV2, ExecutionPayloadV3};

    /// Owned capability list naming `methods`.
    fn advertised(methods: &[&str]) -> Vec<String> {
        methods.iter().map(|method| method.to_string()).collect()
    }

    #[test]
    fn engine_capabilities_require_every_osaka_method() {
        assert!(check_engine_capabilities(advertised(&REQUIRED_ENGINE_METHODS)).is_ok());
        let mut superset = advertised(&REQUIRED_ENGINE_METHODS);
        superset.push("engine_getBlobsV1".to_string());
        assert!(check_engine_capabilities(superset).is_ok());

        let v2 = ["engine_forkchoiceUpdatedV2", "engine_getPayloadV2", "engine_newPayloadV2"];
        let err = check_engine_capabilities(advertised(&v2)).unwrap_err();
        assert!(
            matches!(
                &err,
                RpcClientError::EngineMethodsUnsupported { missing, advertised: list }
                    if missing == &REQUIRED_ENGINE_METHODS && list == &advertised(&v2)
            ),
            "unexpected error: {err:?}"
        );

        let err = check_engine_capabilities(advertised(&REQUIRED_ENGINE_METHODS[..2]))
            .unwrap_err()
            .to_string();
        assert!(err.contains(r#"["engine_newPayloadV4"]"#), "{err}");
    }

    /// Build the `ExecutionPayloadV3` shared by the `engine_new_payload_v4_value` tests,
    /// parameterized on its transaction list.
    fn payload_v3(transactions: Vec<Bytes>) -> ExecutionPayloadV3 {
        ExecutionPayloadV3 {
            payload_inner: ExecutionPayloadV2 {
                payload_inner: ExecutionPayloadV1 {
                    parent_hash: B256::from(U256::from(10u64)),
                    fee_recipient: Address::from([1u8; 20]),
                    state_root: B256::from(U256::from(2u64)),
                    receipts_root: B256::from(U256::from(3u64)),
                    logs_bloom: Default::default(),
                    prev_randao: B256::from(U256::from(4u64)),
                    block_number: 7,
                    gas_limit: 30_000_000,
                    gas_used: 0,
                    timestamp: 123,
                    extra_data: Bytes::from_static(&[0x32, 0, 0, 0, 0, 0, 7]),
                    base_fee_per_gas: U256::from(1u64),
                    block_hash: B256::from(U256::from(42u64)),
                    transactions,
                },
                withdrawals: vec![],
            },
            blob_gas_used: 0,
            excess_blob_gas: 0,
        }
    }

    #[test]
    fn engine_new_payload_v4_value_sends_only_v3_fields_and_header_difficulty() {
        let value = engine_new_payload_v4_value(&payload_v3(vec![]), 7).unwrap();
        let obj = value.as_object().expect("payload should serialize to a JSON object");

        let mut keys: Vec<&str> = obj.keys().map(String::as_str).collect();
        keys.sort_unstable();
        assert_eq!(
            keys,
            [
                "baseFeePerGas",
                "blobGasUsed",
                "blockHash",
                "blockNumber",
                "excessBlobGas",
                "extraData",
                "feeRecipient",
                "gasLimit",
                "gasUsed",
                "headerDifficulty",
                "logsBloom",
                "parentHash",
                "prevRandao",
                "receiptsRoot",
                "stateRoot",
                "timestamp",
                "transactions",
                "withdrawals",
            ]
        );
        // alethia-reth rejects legacy Taiko properties on this route even when they are null.
        for legacy in ["txHash", "withdrawalsHash", "taikoBlock", "slotNumber"] {
            assert!(!obj.contains_key(legacy), "{legacy} must not be sent");
        }
    }

    #[test]
    fn engine_new_payload_v4_value_writes_header_difficulty_as_decimal_number() {
        for difficulty in [0, 1234, u64::MAX] {
            let value = engine_new_payload_v4_value(&payload_v3(vec![]), difficulty).unwrap();
            let header_difficulty = &value["headerDifficulty"];

            assert!(
                header_difficulty.is_u64(),
                "headerDifficulty must be a JSON number, got {header_difficulty}"
            );
            assert_eq!(header_difficulty, &serde_json::json!(difficulty));
        }
    }

    #[test]
    fn engine_new_payload_v4_value_keeps_empty_transactions_and_withdrawals() {
        let value = engine_new_payload_v4_value(&payload_v3(vec![]), 0).unwrap();

        assert_eq!(value["transactions"], serde_json::json!([]));
        assert_eq!(value["withdrawals"], serde_json::json!([]));
    }

    /// alethia-reth's own `engine_newPayloadV4` input type accepts the body for both an Unzen
    /// (zero) and an Etna (nonzero) root (taikoxyz/alethia-reth#248).
    #[test]
    fn engine_new_payload_v4_value_passes_alethia_reth_normalization() {
        use alethia_reth_primitives::engine::osaka::TaikoExecutionPayloadV3;

        for (transactions, root) in [
            (vec![], B256::ZERO),
            (vec![Bytes::from_static(&[0x01, 0x02])], B256::with_last_byte(0xaa)),
        ] {
            let value = engine_new_payload_v4_value(&payload_v3(transactions), 1234).unwrap();

            let wire: TaikoExecutionPayloadV3 =
                serde_json::from_value(value).expect("alethia-reth deserializes the body");
            assert_eq!(wire.header_difficulty, 1234);
            let data = wire
                .into_execution_data(vec![], root, vec![])
                .expect("alethia-reth normalization accepts the body");
            assert_eq!(data.taiko_sidecar.header_difficulty, Some(U256::from(1234u64)));
            assert_eq!(
                data.taiko_sidecar.osaka.map(|osaka| osaka.parent_beacon_block_root),
                Some(root)
            );
        }
    }

    /// `engine_newPayloadV4` goes out as `[payload, [], parentBeaconBlockRoot, []]`, carrying
    /// the given root in the third slot.
    #[test]
    fn engine_new_payload_v4_params_are_payload_empty_hashes_root_and_empty_requests() {
        let payload = payload_v3(vec![Bytes::from_static(&[0x01, 0x02])]);
        for root in [B256::ZERO, B256::with_last_byte(0xaa)] {
            let params = engine_new_payload_v4_params(&payload, 1234, root).unwrap();

            assert_eq!(
                serde_json::to_value(params).unwrap(),
                serde_json::json!([
                    engine_new_payload_v4_value(&payload, 1234).unwrap(),
                    [],
                    root,
                    [],
                ])
            );
        }
    }

    /// `engine_forkchoiceUpdatedV3` goes out as `[forkchoiceState, attributes]`, with JSON
    /// `null` attributes for a forkchoice-only update.
    #[test]
    fn engine_forkchoice_updated_v3_params_are_state_then_attributes_or_null() {
        let state = ForkchoiceState {
            head_block_hash: B256::with_last_byte(0x01),
            safe_block_hash: B256::with_last_byte(0x02),
            finalized_block_hash: B256::with_last_byte(0x03),
        };
        let state_value = serde_json::to_value(state).unwrap();

        let params = engine_forkchoice_updated_v3_params(state, None).unwrap();
        assert_eq!(
            serde_json::to_value(params).unwrap(),
            serde_json::json!([state_value.clone(), null])
        );

        let attributes = TaikoPayloadAttributes {
            payload_attributes: Default::default(),
            base_fee_per_gas: U256::from(7u64),
            block_metadata: Default::default(),
            l1_origin: RpcL1Origin {
                block_id: U256::from(9u64),
                l2_block_hash: B256::ZERO,
                l1_block_height: None,
                l1_block_hash: None,
                build_payload_args_id: [0u8; 8],
                is_forced_inclusion: false,
                signature: [0u8; 65],
            },
            anchor_transaction: None,
        };
        let params = engine_forkchoice_updated_v3_params(state, Some(&attributes)).unwrap();
        assert_eq!(
            serde_json::to_value(params).unwrap(),
            serde_json::json!([state_value, serde_json::to_value(&attributes).unwrap()])
        );
    }
}
