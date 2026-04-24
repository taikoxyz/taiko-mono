//! Transaction builder for constructing proposal transactions.

use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alloy::{
    consensus::{BlobTransactionSidecar, BlobTransactionSidecarVariant, SidecarBuilder},
    eips::{BlockNumberOrTag, eip4844::Blob},
    network::TransactionBuilder4844,
    primitives::{
        Address, Bytes, U256,
        aliases::{U24, U48},
    },
    providers::Provider,
    rpc::types::{TransactionInput, TransactionRequest},
};
use bindings::inbox::{IInbox::ProposeInput, LibBlobs::BlobReference};
use protocol::shasta::{
    BlobCoder,
    constants::derivation_source_max_blocks_for_chain_timestamp,
    manifest::{BlockManifest, DerivationSourceManifest},
};
use rpc::client::ClientWithWallet;
use tracing::info;

use crate::{
    error::{ProposerError, Result},
    proposer::{EngineBuildContext, TransactionLists, current_unix_timestamp},
};

/// Proposer-owned blob payload for a Shasta proposal transaction.
#[derive(Debug, Clone)]
pub(crate) struct ProposalBlobPayload {
    /// The EIP-4844 sidecar that carries the encoded manifest blobs.
    sidecar: BlobTransactionSidecar,
}

impl ProposalBlobPayload {
    /// Create a blob payload from an already-built sidecar.
    pub(crate) fn new(sidecar: BlobTransactionSidecar) -> Self {
        Self { sidecar }
    }

    /// Return the blobs that will be translated into the tx-manager candidate payload.
    #[cfg(test)]
    pub(crate) fn blobs(&self) -> &[Blob] {
        &self.sidecar.blobs
    }

    /// Consume the payload and return the owned blobs for tx-manager submission.
    pub(crate) fn into_blobs(self) -> Vec<Blob> {
        self.sidecar.blobs
    }

    #[cfg(test)]
    pub(crate) fn from_test_blobs(blobs: Vec<Blob>) -> Self {
        Self::new(
            BlobTransactionSidecar::try_from_blobs_with_settings(
                blobs,
                alloy::eips::eip4844::env_settings::EnvKzgSettings::Default.get(),
            )
            .expect("test blobs should produce a blob sidecar"),
        )
    }
}

/// A proposer-owned proposal transaction prepared for adapter-backed submission.
#[derive(Debug, Clone)]
pub struct BuiltProposalTx {
    /// The protocol inbox address that receives the proposal transaction.
    to: Address,
    /// ABI-encoded calldata for `inbox.propose(...)`.
    call_data: Bytes,
    /// Optional gas limit override for the eventual submission request.
    gas_limit: Option<u64>,
    /// Blob payload carrying the encoded proposal manifest.
    blob_payload: ProposalBlobPayload,
}

impl BuiltProposalTx {
    /// Create a new proposer-owned built transaction.
    pub(crate) fn new(to: Address, call_data: Bytes, blob_payload: ProposalBlobPayload) -> Self {
        Self { to, call_data, gas_limit: None, blob_payload }
    }

    /// Return the blob sidecar variant needed by integration tests and beacon stubs.
    pub fn blob_sidecar(&self) -> BlobTransactionSidecarVariant {
        BlobTransactionSidecarVariant::Eip4844(self.blob_payload.sidecar.clone())
    }

    /// Convert the built proposal into a plain transaction request for direct submission.
    ///
    /// This exists for integration tests that still submit proposal transactions through a signed
    /// provider rather than the proposer's tx-manager adapter.
    pub fn to_transaction_request(&self) -> TransactionRequest {
        let request = TransactionRequest::default()
            .to(self.to)
            .value(U256::ZERO)
            .input(TransactionInput::both(self.call_data.clone()))
            .with_blob_sidecar(self.blob_payload.sidecar.clone());

        match self.gas_limit {
            Some(gas_limit) => request.gas_limit(gas_limit),
            None => request,
        }
    }

    /// Consume the built proposal into the parts needed by the tx-manager adapter.
    pub(crate) fn into_parts(self) -> (Address, Bytes, Option<u64>, ProposalBlobPayload) {
        (self.to, self.call_data, self.gas_limit, self.blob_payload)
    }

    /// Return a copy of this transaction with an explicit gas-limit override attached.
    #[must_use]
    pub fn with_gas_limit(mut self, gas_limit: u64) -> Self {
        self.gas_limit = Some(gas_limit);
        self
    }
}

/// A transaction builder for Shasta `propose` transactions.
pub struct ShastaProposalTransactionBuilder {
    /// The RPC provider with wallet.
    pub rpc_provider: ClientWithWallet,
    /// The address of the suggested fee recipient for the proposed L2 block.
    pub l2_suggested_fee_recipient: Address,
}

impl ShastaProposalTransactionBuilder {
    /// Creates a new `ShastaProposalTransactionBuilder`.
    pub fn new(rpc_provider: ClientWithWallet, l2_suggested_fee_recipient: Address) -> Self {
        Self { rpc_provider, l2_suggested_fee_recipient }
    }

    /// Build a Shasta `propose` transaction with the given L2 transactions.
    ///
    /// If `engine_params` is provided (engine mode), those parameters will be used directly.
    /// Otherwise, the current L1 head, current timestamp, and latest canonical parent gas limit are
    /// used.
    pub async fn build(
        &self,
        txs_lists: TransactionLists,
        engine_params: Option<EngineBuildContext>,
    ) -> Result<BuiltProposalTx> {
        // Use provided engine params or derive defaults.
        let (anchor_block_number, timestamp, gas_limit, proposal_limit_timestamp) =
            match engine_params {
                Some(params) => {
                    let l1_block = self
                        .rpc_provider
                        .l1_provider
                        .get_block_by_number(BlockNumberOrTag::Number(params.anchor_block_number))
                        .await?
                        .ok_or(ProposerError::LatestBlockNotFound)?;
                    (
                        params.anchor_block_number,
                        params.timestamp,
                        engine_manifest_gas_limit(params),
                        l1_block.header.timestamp,
                    )
                }
                None => {
                    let l1_block = self
                        .rpc_provider
                        .l1_provider
                        .get_block_by_number(BlockNumberOrTag::Latest)
                        .await?
                        .ok_or(ProposerError::LatestBlockNotFound)?;
                    let latest_parent = self
                        .rpc_provider
                        .l2_provider
                        .get_block_by_number(BlockNumberOrTag::Latest)
                        .await?
                        .ok_or(ProposerError::LatestBlockNotFound)?;
                    let gas_limit = non_engine_manifest_gas_limit(
                        latest_parent.number(),
                        latest_parent.header.gas_limit,
                    );
                    (
                        l1_block.header.number,
                        current_unix_timestamp(),
                        gas_limit,
                        l1_block.header.timestamp,
                    )
                }
            };

        let max_blocks = derivation_source_max_blocks_for_chain_timestamp(
            self.rpc_provider.chain_id,
            proposal_limit_timestamp,
        );
        if txs_lists.len() > max_blocks {
            return Err(ProposerError::TooManyTransactionLists {
                count: txs_lists.len(),
                max: max_blocks,
            });
        }

        // Build the proposal manifest.
        let manifest = DerivationSourceManifest {
            blocks: txs_lists
                .iter()
                .enumerate()
                .map(|(index, txs)| {
                    info!(
                        block_index = index,
                        tx_count = txs.len(),
                        timestamp,
                        anchor_block_number,
                        gas_limit,
                        coinbase = ?self.l2_suggested_fee_recipient,
                        "setting up derivation source manifest block"
                    );
                    BlockManifest {
                        timestamp,
                        coinbase: self.l2_suggested_fee_recipient,
                        anchor_block_number,
                        gas_limit,
                        transactions: txs.iter().cloned().map(Into::into).collect(),
                    }
                })
                .collect::<Vec<BlockManifest>>(),
        };

        // Build the blob sidecar from the proposal manifest.
        let sidecar: BlobTransactionSidecar =
            SidecarBuilder::<BlobCoder>::from_slice(&manifest.encode_and_compress()?)
                .build()
                .map_err(|e| ProposerError::Sidecar(e.to_string()))?;

        // Build the propose input.
        let input = ProposeInput {
            deadline: U48::ZERO,
            blobReference: BlobReference {
                blobStartIndex: 0,
                numBlobs: sidecar.blobs.len() as u16,
                offset: U24::ZERO,
            },
            // Include all forced inclusions in the source manifest.
            numForcedInclusions: u16::MAX,
        };

        // Build the proposer-owned transaction boundary.
        let encoded_input = self.rpc_provider.shasta.inbox.encodeProposeInput(input).call().await?;
        let propose_call = self.rpc_provider.shasta.inbox.propose(Bytes::new(), encoded_input);

        Ok(BuiltProposalTx::new(
            *self.rpc_provider.shasta.inbox.address(),
            propose_call.calldata().clone(),
            ProposalBlobPayload::new(sidecar),
        ))
    }
}

/// Derive the manifest gas limit for engine mode by applying the anchor-gas discount.
///
/// This keeps the manifest aligned with the driver-side validation for engine-built payloads.
fn engine_manifest_gas_limit(engine_params: EngineBuildContext) -> u64 {
    if engine_params.parent_block_number == 0 {
        engine_params.gas_limit
    } else {
        engine_params.gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT)
    }
}

/// Derive the manifest gas limit for non-engine mode from the canonical parent block.
///
/// The genesis parent keeps its gas limit unchanged; all later parents apply the anchor-gas
/// discount expected by the driver.
fn non_engine_manifest_gas_limit(parent_block_number: u64, parent_gas_limit: u64) -> u64 {
    if parent_block_number == 0 {
        parent_gas_limit
    } else {
        parent_gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        ShastaProposalTransactionBuilder, engine_manifest_gas_limit, non_engine_manifest_gas_limit,
    };
    use alloy::{
        consensus::{Header as ConsensusHeader, TxEnvelope},
        eips::eip4844::Blob,
        network::TransactionBuilder4844,
        primitives::{Address, Bytes},
        rpc::{
            client::RpcClient,
            json_rpc::{
                Id, RequestPacket, Response, ResponsePacket, ResponsePayload, SerializedRequest,
            },
        },
        signers::local::PrivateKeySigner,
        sol_types::SolValue,
        transports::{TransportError, TransportFut},
    };
    use alloy_network::EthereumWallet;
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types::eth::{Block as RpcBlock, Header as RpcHeader};
    use bindings::{anchor::Anchor::AnchorInstance, inbox::Inbox::InboxInstance};
    use protocol::shasta::{
        BlobCoder,
        constants::{
            DERIVATION_SOURCE_MAX_BLOCKS, TAIKO_DEVNET_CHAIN_ID, set_devnet_unzen_override,
        },
        manifest::DerivationSourceManifest,
    };
    use rpc::client::{Client, ClientWithWallet, ShastaProtocolInstance};
    use std::sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    };

    use crate::{
        error::ProposerError,
        proposer::EngineBuildContext,
        transaction_builder::{BuiltProposalTx, ProposalBlobPayload},
    };

    impl BuiltProposalTx {
        /// Return the internal blob payload for crate-local tests.
        pub(crate) fn blob_payload(&self) -> &ProposalBlobPayload {
            &self.blob_payload
        }
    }

    #[test]
    fn built_proposal_tx_exposes_blob_sidecar_and_transaction_request() {
        let built = BuiltProposalTx::new(
            Address::repeat_byte(0x44),
            Bytes::from_static(b"blobbed-proposal"),
            ProposalBlobPayload::from_test_blobs(vec![Blob::ZERO]),
        )
        .with_gas_limit(210_000);

        let sidecar = built.blob_sidecar();
        let request = built.to_transaction_request();

        assert_eq!(sidecar.as_eip4844().expect("expected EIP-4844 sidecar").blobs.len(), 1);
        assert_eq!(request.gas, Some(210_000));
        assert_eq!(
            request.blob_sidecar().expect("transaction request should retain sidecar").blobs.len(),
            1
        );
    }

    #[derive(Clone, Debug)]
    struct ManifestTestTransport {
        l1_block_number: u64,
        call_result: Bytes,
        latest_block: Option<RpcBlock<TxEnvelope>>,
        genesis_block: Option<RpcBlock<TxEnvelope>>,
        requests: Arc<Mutex<Vec<String>>>,
        saw_latest_block: Arc<AtomicBool>,
        saw_genesis_block: Arc<AtomicBool>,
    }

    impl ManifestTestTransport {
        fn l1(l1_block_number: u64, call_result: Bytes) -> Self {
            let latest_block = RpcBlock::<TxEnvelope> {
                header: RpcHeader {
                    hash: Default::default(),
                    inner: ConsensusHeader {
                        number: l1_block_number,
                        timestamp: l1_block_number,
                        ..Default::default()
                    },
                    total_difficulty: None,
                    size: None,
                },
                ..Default::default()
            };

            Self {
                l1_block_number,
                call_result,
                latest_block: Some(latest_block),
                genesis_block: None,
                requests: Arc::new(Mutex::new(Vec::new())),
                saw_latest_block: Arc::new(AtomicBool::new(false)),
                saw_genesis_block: Arc::new(AtomicBool::new(false)),
            }
        }

        fn l2(latest_block: RpcBlock<TxEnvelope>, genesis_block: RpcBlock<TxEnvelope>) -> Self {
            Self {
                l1_block_number: 0,
                call_result: Bytes::new(),
                latest_block: Some(latest_block),
                genesis_block: Some(genesis_block),
                requests: Arc::new(Mutex::new(Vec::new())),
                saw_latest_block: Arc::new(AtomicBool::new(false)),
                saw_genesis_block: Arc::new(AtomicBool::new(false)),
            }
        }

        fn seen_latest_block_request(&self) -> bool {
            self.saw_latest_block.load(Ordering::SeqCst)
        }

        fn seen_genesis_block_request(&self) -> bool {
            self.saw_genesis_block.load(Ordering::SeqCst)
        }

        fn request_log(&self) -> Vec<String> {
            self.requests.lock().expect("request log should not be poisoned").clone()
        }

        fn handle_request(
            &self,
            request: SerializedRequest,
        ) -> Response<Box<serde_json::value::RawValue>> {
            let method = request.method().to_string();
            let params = request.params().map(|params| params.get().to_string());
            self.requests
                .lock()
                .expect("request log should not be poisoned")
                .push(format!("{method} {}", params.as_deref().unwrap_or("")));

            match method.as_str() {
                "eth_blockNumber" => success_u64(request.id().clone(), self.l1_block_number),
                "eth_call" => success_bytes(request.id().clone(), &self.call_result),
                "eth_getBlockByNumber" => {
                    self.handle_get_block_by_number(request.id().clone(), params.as_deref())
                }
                "eth_chainId" => success_u64(request.id().clone(), 1),
                _ => success_null(request.id().clone()),
            }
        }

        fn handle_get_block_by_number(
            &self,
            id: Id,
            params: Option<&str>,
        ) -> Response<Box<serde_json::value::RawValue>> {
            let parsed_params: serde_json::Value = params
                .and_then(|raw| serde_json::from_str(raw).ok())
                .unwrap_or(serde_json::Value::Null);
            let requested_block = parsed_params.as_array().and_then(|items| items.first());

            match requested_block {
                Some(serde_json::Value::String(tag)) if tag == "latest" => {
                    self.saw_latest_block.store(true, Ordering::SeqCst);
                    success_block(
                        id,
                        self.latest_block
                            .as_ref()
                            .expect("latest block fixture should be configured"),
                    )
                }
                Some(serde_json::Value::String(tag))
                    if tag == "0x0" || tag == "0x00" || tag == "0" =>
                {
                    self.saw_genesis_block.store(true, Ordering::SeqCst);
                    success_block(
                        id,
                        self.genesis_block
                            .as_ref()
                            .expect("genesis block fixture should be configured"),
                    )
                }
                Some(serde_json::Value::Number(number)) if number.as_u64() == Some(0) => {
                    self.saw_genesis_block.store(true, Ordering::SeqCst);
                    success_block(
                        id,
                        self.genesis_block
                            .as_ref()
                            .expect("genesis block fixture should be configured"),
                    )
                }
                _ => success_block(
                    id,
                    self.latest_block.as_ref().expect("latest block fixture should be configured"),
                ),
            }
        }
    }

    impl tower::Service<RequestPacket> for ManifestTestTransport {
        type Response = ResponsePacket;
        type Error = TransportError;
        type Future = TransportFut<'static>;

        fn poll_ready(
            &mut self,
            _cx: &mut std::task::Context<'_>,
        ) -> std::task::Poll<Result<(), Self::Error>> {
            std::task::Poll::Ready(Ok(()))
        }

        fn call(&mut self, req: RequestPacket) -> Self::Future {
            let this = self.clone();
            Box::pin(async move {
                match req {
                    RequestPacket::Single(req) => {
                        Ok(ResponsePacket::Single(this.handle_request(req)))
                    }
                    RequestPacket::Batch(reqs) => Ok(ResponsePacket::Batch(
                        reqs.into_iter().map(|req| this.handle_request(req)).collect(),
                    )),
                }
            })
        }
    }

    fn success_json(id: Id, json: String) -> Response<Box<serde_json::value::RawValue>> {
        Response {
            id,
            payload: ResponsePayload::Success(
                serde_json::value::RawValue::from_string(json)
                    .expect("test response should serialize"),
            ),
        }
    }

    fn success_u64(id: Id, value: u64) -> Response<Box<serde_json::value::RawValue>> {
        success_json(id, serde_json::to_string(&value).expect("test response should serialize"))
    }

    fn success_null(id: Id) -> Response<Box<serde_json::value::RawValue>> {
        success_json(id, "null".to_string())
    }

    fn success_bytes(id: Id, value: &Bytes) -> Response<Box<serde_json::value::RawValue>> {
        success_json(id, serde_json::to_string(value).expect("test response should serialize"))
    }

    fn success_block(
        id: Id,
        value: &RpcBlock<TxEnvelope>,
    ) -> Response<Box<serde_json::value::RawValue>> {
        success_json(id, serde_json::to_string(value).expect("test response should serialize"))
    }

    fn test_rpc_client(
        l1_transport: ManifestTestTransport,
        l2_transport: ManifestTestTransport,
    ) -> ClientWithWallet {
        let signer = PrivateKeySigner::from_bytes(&alloy::primitives::B256::from([1u8; 32]))
            .expect("test private key should be valid");
        let wallet = EthereumWallet::new(signer);

        let l1_provider = ProviderBuilder::new()
            .wallet(wallet)
            .connect_client(RpcClient::new(l1_transport, true));
        let l2_provider =
            ProviderBuilder::default().connect_client(RpcClient::new(l2_transport, true));
        let l2_auth_provider = l2_provider.clone();
        let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
        let anchor = AnchorInstance::new(Address::ZERO, l2_auth_provider.clone());
        let shasta = ShastaProtocolInstance { inbox, anchor };

        Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
    }

    #[test]
    fn manifest_gas_limit_uses_effective_parent_limit_in_non_engine_mode() {
        assert_eq!(non_engine_manifest_gas_limit(42, 45_000_000), 44_000_000);
    }

    #[test]
    fn manifest_gas_limit_keeps_genesis_parent_limit_in_non_engine_mode() {
        assert_eq!(non_engine_manifest_gas_limit(0, 45_000_000), 45_000_000);
    }

    #[test]
    fn manifest_gas_limit_keeps_genesis_parent_limit_in_engine_mode() {
        assert_eq!(
            engine_manifest_gas_limit(EngineBuildContext {
                anchor_block_number: 7,
                parent_block_number: 0,
                timestamp: 1_234,
                gas_limit: 45_000_000,
            }),
            45_000_000
        );
    }

    #[tokio::test]
    async fn build_manifest_gas_limit_uses_latest_parent_block_in_non_engine_mode()
    -> crate::error::Result<()> {
        let latest_parent = RpcBlock::<TxEnvelope> {
            header: RpcHeader {
                hash: Default::default(),
                inner: ConsensusHeader { number: 42, gas_limit: 46_000_000, ..Default::default() },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        };
        let genesis_parent = RpcBlock::<TxEnvelope> {
            header: RpcHeader {
                hash: Default::default(),
                inner: ConsensusHeader { number: 0, gas_limit: 47_000_000, ..Default::default() },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        };
        let call_result = Bytes::from(Bytes::from_static(b"proposal-encoded-bytes").abi_encode());
        let l1_transport = ManifestTestTransport::l1(1, call_result);
        let l2_transport = ManifestTestTransport::l2(latest_parent, genesis_parent);
        let rpc_provider = test_rpc_client(l1_transport.clone(), l2_transport.clone());
        let builder =
            ShastaProposalTransactionBuilder::new(rpc_provider, Address::repeat_byte(0x11));

        let built_tx = builder.build(vec![vec![]], None).await?;
        let blob_payload = built_tx.blob_payload();
        let manifest_payload =
            BlobCoder::decode_blob(&blob_payload.blobs()[0]).expect("manifest blob should decode");
        let manifest = DerivationSourceManifest::decompress_and_decode(&manifest_payload, 0)
            .expect("manifest should decode from blob sidecar");

        assert_eq!(manifest.blocks.len(), 1);
        assert_eq!(manifest.blocks[0].gas_limit, 45_000_000);
        assert!(
            l2_transport.seen_latest_block_request(),
            "build should query eth_getBlockByNumber latest"
        );
        assert!(
            !l2_transport.seen_genesis_block_request(),
            "build should not query the genesis block in non-engine mode"
        );
        assert!(
            l2_transport
                .request_log()
                .iter()
                .any(|entry| entry.contains("eth_getBlockByNumber") && entry.contains("latest")),
            "request log should include an eth_getBlockByNumber latest lookup"
        );

        Ok(())
    }

    #[tokio::test]
    async fn build_rejects_too_many_pre_unzen_landed_l1_timestamp() {
        set_devnet_unzen_override(100);
        let call_result = Bytes::from(Bytes::from_static(b"proposal-encoded-bytes").abi_encode());
        let l1_transport = ManifestTestTransport::l1(1, call_result);
        let l2_transport = ManifestTestTransport::l2(RpcBlock::default(), RpcBlock::default());
        let mut rpc_provider = test_rpc_client(l1_transport.clone(), l2_transport);
        rpc_provider.chain_id = TAIKO_DEVNET_CHAIN_ID;
        let builder =
            ShastaProposalTransactionBuilder::new(rpc_provider, Address::repeat_byte(0x11));

        let result = builder
            .build(
                vec![vec![]; DERIVATION_SOURCE_MAX_BLOCKS + 1],
                Some(EngineBuildContext {
                    anchor_block_number: 1,
                    parent_block_number: 1,
                    timestamp: 101,
                    gas_limit: 45_000_000,
                }),
            )
            .await;

        let err = result.expect_err("too many transaction lists should be rejected");
        match err {
            ProposerError::TooManyTransactionLists { count, max } => {
                assert_eq!(count, DERIVATION_SOURCE_MAX_BLOCKS + 1);
                assert_eq!(max, DERIVATION_SOURCE_MAX_BLOCKS);
            }
            other => panic!("unexpected error: {other:?}"),
        }
        assert!(
            l1_transport
                .request_log()
                .iter()
                .any(|entry| entry.contains("eth_getBlockByNumber") && entry.contains("0x1")),
            "build should query the landed L1 block by anchor number"
        );
    }
}
