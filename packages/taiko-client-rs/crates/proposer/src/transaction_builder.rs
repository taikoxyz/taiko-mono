//! Transaction builder for constructing proposal transactions.

use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alloy::{
    consensus::{BlobTransactionSidecar, BlobTransactionSidecarVariant, SidecarBuilder},
    network::TransactionBuilder4844,
    primitives::{
        Address, Bytes, U256,
        aliases::{U24, U48},
    },
    rpc::types::{TransactionInput, TransactionRequest},
};
use bindings::inbox::{IInbox::ProposeInput, LibBlobs::BlobReference};
use protocol::shasta::{
    BlobCoder,
    constants::DERIVATION_SOURCE_MAX_BLOCKS,
    manifest::{BlockManifest, DerivationSourceManifest},
};
use rpc::client::Client;
use tracing::info;

use crate::{
    error::{ProposerError, Result},
    proposer::{EngineBuildContext, TransactionLists},
};

/// A proposer-owned proposal transaction prepared for adapter-backed submission.
#[derive(Debug, Clone)]
pub struct BuiltProposalTx {
    /// The protocol inbox address that receives the proposal transaction.
    to: Address,
    /// ABI-encoded calldata for `inbox.propose(...)`.
    call_data: Bytes,
    /// Optional gas limit override for the eventual submission request.
    gas_limit: Option<u64>,
    /// The EIP-4844 sidecar that carries the encoded manifest blobs.
    sidecar: BlobTransactionSidecar,
}

impl BuiltProposalTx {
    /// Create a new proposer-owned built transaction.
    pub(crate) fn new(to: Address, call_data: Bytes, sidecar: BlobTransactionSidecar) -> Self {
        Self { to, call_data, gas_limit: None, sidecar }
    }

    /// Return the blob sidecar variant needed by integration tests and beacon stubs.
    pub fn blob_sidecar(&self) -> BlobTransactionSidecarVariant {
        BlobTransactionSidecarVariant::Eip4844(self.sidecar.clone())
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
            .with_blob_sidecar(self.sidecar.clone());

        match self.gas_limit {
            Some(gas_limit) => request.gas_limit(gas_limit),
            None => request,
        }
    }

    /// Consume the built proposal into the parts needed by the tx-manager adapter.
    pub(crate) fn into_parts(self) -> (Address, Bytes, Option<u64>, BlobTransactionSidecar) {
        (self.to, self.call_data, self.gas_limit, self.sidecar)
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
    /// The RPC client used for L1/L2 reads while assembling proposals.
    pub rpc_provider: Client,
    /// The address of the suggested fee recipient for the proposed L2 block.
    pub l2_suggested_fee_recipient: Address,
}

impl ShastaProposalTransactionBuilder {
    /// Creates a new `ShastaProposalTransactionBuilder`.
    pub fn new(rpc_provider: Client, l2_suggested_fee_recipient: Address) -> Self {
        Self { rpc_provider, l2_suggested_fee_recipient }
    }

    /// Build a Shasta `propose` transaction with the given L2 transactions.
    ///
    /// The caller supplies the [`EngineBuildContext`] snapshot (L1 anchor, timestamp base, and
    /// the L2 parent's gas limit) so that transaction selection and manifest construction always
    /// describe the same chain state; the builder performs no chain reads of its own besides the
    /// propose-input encoding.
    pub async fn build(
        &self,
        txs_lists: TransactionLists,
        ctx: EngineBuildContext,
    ) -> Result<BuiltProposalTx> {
        let anchor_block_number = ctx.anchor_block_number;
        let timestamp = ctx.timestamp;
        let gas_limit = manifest_gas_limit(ctx.parent_block_number, ctx.gas_limit);

        // Proposer intentionally keeps the stricter Shasta cap. It is below the
        // Unzen derivation-source cap, so proposals that pass here are safe there.
        if txs_lists.len() > DERIVATION_SOURCE_MAX_BLOCKS {
            return Err(ProposerError::TooManyBlocks {
                count: txs_lists.len(),
                max: DERIVATION_SOURCE_MAX_BLOCKS,
            });
        }

        // Build the proposal manifest.
        let manifest = DerivationSourceManifest {
            blocks: txs_lists
                .iter()
                .enumerate()
                .map(|(index, txs)| {
                    // Driver validation requires strictly increasing block timestamps
                    // (parent + 1 lower bound), so stagger multi-block manifests by index
                    // exactly like the Go proposer does (`l1Head.Time + i`). Shared ceiling
                    // with Go: blocks whose index exceeds the proposal's actual L1 inclusion
                    // delay trip the driver's upper bound (timestamp <= inclusion timestamp),
                    // which cannot be known at build time.
                    let block_timestamp = timestamp + index as u64;
                    info!(
                        block_index = index,
                        tx_count = txs.len(),
                        timestamp = block_timestamp,
                        anchor_block_number,
                        gas_limit,
                        coinbase = ?self.l2_suggested_fee_recipient,
                        "setting up derivation source manifest block"
                    );
                    BlockManifest {
                        timestamp: block_timestamp,
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
        let input = build_propose_input(sidecar.blobs.len() as u16);

        // Build the proposer-owned transaction boundary.
        let encoded_input = self.rpc_provider.shasta.inbox.encodeProposeInput(input).call().await?;
        let propose_call = self.rpc_provider.shasta.inbox.propose(Bytes::new(), encoded_input);

        Ok(BuiltProposalTx::new(
            *self.rpc_provider.shasta.inbox.address(),
            propose_call.calldata().clone(),
            sidecar,
        ))
    }
}

/// Build the `ProposeInput` for `inbox.propose(...)` describing the manifest blobs.
///
/// The proposal carries no deadline and references `num_blobs` sidecar blobs starting at blob
/// index zero with no byte offset.
fn build_propose_input(num_blobs: u16) -> ProposeInput {
    ProposeInput {
        deadline: U48::ZERO,
        blobReference: BlobReference { blobStartIndex: 0, numBlobs: num_blobs, offset: U24::ZERO },
        // Include all forced inclusions in the source manifest.
        numForcedInclusions: u16::MAX,
    }
}

/// Derive the manifest gas limit from the parent block, applying the anchor-gas discount.
///
/// The genesis parent (block number 0) keeps its gas limit unchanged; all later parents apply the
/// anchor-gas discount expected by the driver-side validation.
pub(crate) fn manifest_gas_limit(parent_block_number: u64, gas_limit: u64) -> u64 {
    if parent_block_number == 0 {
        gas_limit
    } else {
        gas_limit.saturating_sub(ANCHOR_V3_V4_GAS_LIMIT)
    }
}

#[cfg(test)]
mod tests {
    use super::{ShastaProposalTransactionBuilder, build_propose_input, manifest_gas_limit};
    use alloy::{
        consensus::BlobTransactionSidecar,
        eips::eip4844::Blob,
        network::TransactionBuilder4844,
        primitives::{
            Address, Bytes,
            aliases::{U24, U48},
        },
        rpc::{
            client::RpcClient,
            json_rpc::{
                Id, RequestPacket, Response, ResponsePacket, ResponsePayload, SerializedRequest,
            },
        },
        sol_types::SolValue,
        transports::{TransportError, TransportFut},
    };
    use alloy_provider::ProviderBuilder;
    use bindings::{anchor::Anchor::AnchorInstance, inbox::Inbox::InboxInstance};
    use protocol::shasta::{BlobCoder, manifest::DerivationSourceManifest};
    use rpc::client::{Client, ShastaProtocolInstance};

    use crate::{proposer::EngineBuildContext, transaction_builder::BuiltProposalTx};

    impl BuiltProposalTx {
        /// Build a proposal transaction from raw blobs for crate-local tests.
        pub(crate) fn from_test_blobs(to: Address, call_data: Bytes, blobs: Vec<Blob>) -> Self {
            let sidecar = BlobTransactionSidecar::try_from_blobs_with_settings(
                blobs,
                alloy::eips::eip4844::env_settings::EnvKzgSettings::Default.get(),
            )
            .expect("test blobs should produce a blob sidecar");
            Self::new(to, call_data, sidecar)
        }

        /// Return the manifest blobs for crate-local test assertions.
        pub(crate) fn blobs(&self) -> &[Blob] {
            &self.sidecar.blobs
        }
    }

    #[test]
    fn built_proposal_tx_exposes_blob_sidecar_and_transaction_request() {
        let built = BuiltProposalTx::from_test_blobs(
            Address::repeat_byte(0x44),
            Bytes::from_static(b"blobbed-proposal"),
            vec![Blob::ZERO],
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

    /// Minimal transport for builder tests: serves the propose-input `eth_call` and
    /// `eth_chainId`. The builder performs no other chain reads — its inputs arrive via
    /// [`EngineBuildContext`].
    #[derive(Clone, Debug)]
    struct ManifestTestTransport {
        call_result: Bytes,
    }

    impl ManifestTestTransport {
        fn handle_request(
            &self,
            request: SerializedRequest,
        ) -> Response<Box<serde_json::value::RawValue>> {
            match request.method() {
                "eth_call" => success_bytes(request.id().clone(), &self.call_result),
                "eth_chainId" => success_u64(request.id().clone(), 1),
                _ => success_null(request.id().clone()),
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

    fn test_rpc_client(call_result: Bytes) -> Client {
        let transport = ManifestTestTransport { call_result };
        let l1_provider =
            ProviderBuilder::new().connect_client(RpcClient::new(transport.clone(), true));
        let l2_provider =
            ProviderBuilder::default().connect_client(RpcClient::new(transport, true));
        let l2_auth_provider = l2_provider.clone();
        let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
        let anchor = AnchorInstance::new(Address::ZERO, l2_auth_provider.clone());
        let shasta = ShastaProtocolInstance { inbox, anchor };

        Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
    }

    #[test]
    fn manifest_gas_limit_applies_anchor_discount_for_non_genesis_parent() {
        assert_eq!(manifest_gas_limit(42, 45_000_000), 44_000_000);
    }

    #[test]
    fn manifest_gas_limit_keeps_genesis_parent_limit() {
        assert_eq!(manifest_gas_limit(0, 45_000_000), 45_000_000);
    }

    #[test]
    fn propose_input_pins_deadline_blob_reference_and_forced_inclusions() {
        let input = build_propose_input(3);

        assert_eq!(input.deadline, U48::ZERO);
        assert_eq!(input.blobReference.blobStartIndex, 0);
        assert_eq!(input.blobReference.numBlobs, 3);
        assert_eq!(input.blobReference.offset, U24::ZERO);
        // The proposer opts into draining every queued forced inclusion.
        assert_eq!(input.numForcedInclusions, u16::MAX);
    }

    #[tokio::test]
    async fn build_applies_anchor_gas_discount_from_context() -> crate::error::Result<()> {
        let call_result = Bytes::from(Bytes::from_static(b"proposal-encoded-bytes").abi_encode());
        let builder = ShastaProposalTransactionBuilder::new(
            test_rpc_client(call_result),
            Address::repeat_byte(0x11),
        );
        let ctx = EngineBuildContext {
            anchor_block_number: 77,
            parent_block_number: 42,
            timestamp: 1_000,
            gas_limit: 46_000_000,
        };

        let built_tx = builder.build(vec![vec![]], ctx).await?;
        let manifest = decode_built_manifest(&built_tx);

        assert_eq!(manifest.blocks.len(), 1);
        assert_eq!(manifest.blocks[0].gas_limit, 45_000_000);
        assert_eq!(manifest.blocks[0].anchor_block_number, 77);

        Ok(())
    }

    #[tokio::test]
    async fn build_stamps_context_timestamp_and_staggers_blocks() -> crate::error::Result<()> {
        let call_result = Bytes::from(Bytes::from_static(b"proposal-encoded-bytes").abi_encode());
        let builder = ShastaProposalTransactionBuilder::new(
            test_rpc_client(call_result),
            Address::repeat_byte(0x11),
        );
        let ctx = EngineBuildContext {
            anchor_block_number: 77,
            parent_block_number: 42,
            timestamp: 1_234_567,
            gas_limit: 46_000_000,
        };

        // Two tx lists: driver validation requires strictly increasing timestamps across the
        // manifest blocks, so identical stamps would void the whole proposal.
        let built_tx = builder.build(vec![vec![], vec![]], ctx).await?;
        let manifest = decode_built_manifest(&built_tx);

        assert_eq!(manifest.blocks.len(), 2);
        // The base timestamp comes from the caller's L1-head snapshot (never above the
        // proposal's L1 inclusion timestamp), not from the local wall clock.
        assert_eq!(manifest.blocks[0].timestamp, 1_234_567);
        assert_eq!(manifest.blocks[1].timestamp, 1_234_568);
        assert_eq!(manifest.blocks[0].anchor_block_number, 77);

        Ok(())
    }

    /// Decode the manifest back out of the built transaction's first blob.
    fn decode_built_manifest(built_tx: &BuiltProposalTx) -> DerivationSourceManifest {
        let manifest_payload =
            BlobCoder::decode_blob(&built_tx.blobs()[0]).expect("manifest blob should decode");
        DerivationSourceManifest::decompress_and_decode(&manifest_payload, 0)
            .expect("manifest should decode from blob sidecar")
    }
}
