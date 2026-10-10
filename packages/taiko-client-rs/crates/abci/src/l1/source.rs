//! The node's own L1 view (finality = its L1 node's `finalized` tag, SYS-02): the `finalized`
//! block number, canonical block hashes and raw headers, EIP-1186 account proofs and raw storage
//! reads, behind [`L1Source`] so the app can run against an in-memory L1 in tests.
//!
//! Only `PrepareProposal`, `ProcessProposal` (its node-local checks), `InitChain` and the
//! `abci-genesis` builder use it; `FinalizeBlock` and replay never call L1, as every L1 fact a
//! block consumes travels in it.

use std::collections::BTreeSet;

use alloy_consensus::Header;
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, Bytes, U64, U256};
use alloy_provider::{Provider, RootProvider};
use async_trait::async_trait;
use serde_json::{Map, Value};

use super::header::{L1HeaderError, RawL1Header};
use crate::types::{AccountWitness, StorageProof};

/// JSON-RPC error codes with which a node says it does not serve a method: `-32601` (method not
/// found, JSON-RPC 2.0) and `-32004` (method not supported, EIP-1474).
const METHOD_UNAVAILABLE: [i64; 2] = [-32601, -32004];

/// The members of an `eth_getBlockByNumber` result that are not header fields: the block hash
/// and the block-level data nodes return around the header.
const BLOCK_MEMBERS: [&str; 6] =
    ["hash", "totalDifficulty", "size", "uncles", "transactions", "withdrawals"];

/// Why an L1 read failed.
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum L1Error {
    /// The JSON-RPC call failed (transport or JSON-RPC error response); the value names the
    /// method and renders the cause.
    #[error("L1 RPC failed: {0}")]
    Rpc(String),
    /// The L1 node has no block for the tag or number.
    #[error("L1 block {0} not found")]
    BlockNotFound(BlockNumberOrTag),
    /// The L1 node answered with a JSON value of the wrong shape; the value says which.
    #[error("malformed L1 RPC response: {0}")]
    MalformedResponse(String),
    /// The L1 node served a raw header (`debug_getRawHeader`) that is not an L1 header.
    #[error("L1 block {number}: malformed raw header: {error}")]
    MalformedHeader {
        /// The requested block number.
        number: u64,
        /// Why the bytes are not a header.
        error: L1HeaderError,
    },
    /// The L1 node reported a block hash its own header does not hash to.
    #[error("L1 block {number} reported hash {reported}, but its header hashes to {computed}")]
    HeaderHashMismatch {
        /// The requested block number.
        number: u64,
        /// The `hash` field of the `eth_getBlockByNumber` response.
        reported: B256,
        /// `keccak256` of the raw header.
        computed: B256,
    },
    /// The L1 node answered a request for block `requested` with block `got`.
    #[error("requested L1 block {requested}, the node answered block {got}")]
    HeaderNumberMismatch {
        /// The requested block number.
        requested: u64,
        /// The block number of the answer.
        got: u64,
    },
    /// The L1 node does not serve `debug_getRawHeader`, and its JSON header has fields this
    /// client cannot re-encode (an L1 fork newer than the client), so the raw header cannot be
    /// rebuilt: enable the node's `debug` namespace.
    #[error(
        "L1 block {number}: the node does not serve debug_getRawHeader and its JSON header has \
         fields {fields:?} this client cannot re-encode; enable the node's debug namespace"
    )]
    UnknownHeaderFields {
        /// The requested block number.
        number: u64,
        /// The unknown JSON members, in name order.
        fields: Vec<String>,
    },
    /// `eth_getProof` answered for a different account than requested.
    #[error("eth_getProof returned account {got}, requested {requested}")]
    ProofAddressMismatch {
        /// The requested account.
        requested: Address,
        /// The account the response proves.
        got: Address,
    },
    /// `eth_getProof` returned storage proofs for other keys, or in another order, than
    /// requested.
    #[error("eth_getProof returned storage keys {got:?}, requested {requested:?}")]
    ProofSlotMismatch {
        /// The requested slots, in order.
        requested: Vec<B256>,
        /// The keys of the returned storage proofs, in order.
        got: Vec<B256>,
    },
}

/// Read access to the operator's own L1 execution node.
#[async_trait]
pub trait L1Source: Send + Sync + 'static {
    /// The number of the L1 block the node reports under the `finalized` tag.
    async fn finalized_number(&self) -> Result<u64, L1Error>;

    /// The hash of the node's canonical L1 block at `number`.
    async fn canonical_hash(&self, number: u64) -> Result<B256, L1Error>;

    /// The node's canonical L1 header at `number` as its raw RLP, checked to hash to the block
    /// hash the node reports for `number` and to be block `number`.
    async fn header(&self, number: u64) -> Result<RawL1Header, L1Error>;

    /// An EIP-1186 witness of `address` with storage proofs of exactly `slots` (same order) at
    /// block `number`, ready for [`verify_account_witness`](super::mpt::verify_account_witness)
    /// against that block's `stateRoot`.
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        block: u64,
    ) -> Result<AccountWitness, L1Error>;

    /// The raw (unproven) storage word of `address` at `slot` as of block `block`; used only to
    /// discover which proofs to read (the registry's `checkpoints` length and heads in
    /// `l1::fetch`, the Inbox's `migrationState` and activation word in the genesis builder),
    /// whose proven values are then checked.
    async fn storage_at(&self, address: Address, slot: B256, block: u64) -> Result<U256, L1Error>;
}

/// [`L1Source`] over an alloy JSON-RPC provider.
///
/// Raw headers come from `debug_getRawHeader`. A node that does not serve it (e.g. anvil) gets
/// its `eth_getBlockByNumber` header re-encoded instead, but only while that header has no field
/// alloy's [`Header`] does not know: after an L1 fork appends header fields, such a node fails
/// with [`L1Error::UnknownHeaderFields`] rather than hand out a header that drops them.
#[derive(Clone, Debug)]
pub struct RpcL1Source {
    /// Provider for the operator's own L1 execution node.
    provider: RootProvider,
}

impl RpcL1Source {
    /// Wraps `provider`, which must point at the operator's own L1 execution node.
    pub const fn new(provider: RootProvider) -> Self {
        Self { provider }
    }

    /// `eth_getBlockByNumber(tag, false)` as its JSON object; a missing block is
    /// [`L1Error::BlockNotFound`].
    async fn block(&self, tag: BlockNumberOrTag) -> Result<Map<String, Value>, L1Error> {
        self.provider
            .raw_request::<_, Option<Map<String, Value>>>(
                "eth_getBlockByNumber".into(),
                (tag, false),
            )
            .await
            .map_err(|e| L1Error::Rpc(format!("eth_getBlockByNumber({tag}): {e}")))?
            .ok_or(L1Error::BlockNotFound(tag))
    }
}

#[async_trait]
impl L1Source for RpcL1Source {
    /// `eth_getBlockByNumber("finalized")`'s `number`; a node without a finalized block fails
    /// with [`L1Error::BlockNotFound`].
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        let block = self.block(BlockNumberOrTag::Finalized).await?;
        Ok(member::<U64>(&block, "number")?.to())
    }

    /// `eth_getBlockByNumber(number)`'s `hash`; an answer for another block is
    /// [`L1Error::HeaderNumberMismatch`].
    async fn canonical_hash(&self, number: u64) -> Result<B256, L1Error> {
        let block = self.block(BlockNumberOrTag::Number(number)).await?;
        let got = member::<U64>(&block, "number")?.to();
        if got != number {
            return Err(L1Error::HeaderNumberMismatch { requested: number, got });
        }
        member(&block, "hash")
    }

    /// `eth_getBlockByNumber(number)`'s `hash`, then `debug_getRawHeader(number)`, which must be
    /// an L1 header ([`L1Error::MalformedHeader`]) hashing to that hash
    /// ([`L1Error::HeaderHashMismatch`]) and numbered `number` ([`L1Error::HeaderNumberMismatch`]).
    ///
    /// When the node does not serve `debug_getRawHeader` (method not found or not supported),
    /// the JSON header is re-encoded instead, under the same checks, if every member of the JSON
    /// block is a field alloy's [`Header`] knows or a block-level member
    /// ([`L1Error::UnknownHeaderFields`] otherwise).
    async fn header(&self, number: u64) -> Result<RawL1Header, L1Error> {
        let tag = BlockNumberOrTag::Number(number);
        let block = self.block(tag).await?;
        let reported: B256 = member(&block, "hash")?;
        let header = match self
            .provider
            .raw_request::<_, Bytes>("debug_getRawHeader".into(), (tag,))
            .await
        {
            Ok(raw) => RawL1Header::from_raw(raw)
                .map_err(|error| L1Error::MalformedHeader { number, error })?,
            Err(e) if e.as_error_resp().is_some_and(|p| METHOD_UNAVAILABLE.contains(&p.code)) => {
                header_from_json(number, block)?
            }
            Err(e) => return Err(L1Error::Rpc(format!("debug_getRawHeader({number}): {e}"))),
        };
        let computed = header.hash();
        if computed != reported {
            return Err(L1Error::HeaderHashMismatch { number, reported, computed });
        }
        if header.number() != number {
            return Err(L1Error::HeaderNumberMismatch { requested: number, got: header.number() });
        }
        Ok(header)
    }

    /// `eth_getProof(address, slots, block)`; fails with [`L1Error::ProofAddressMismatch`] or
    /// [`L1Error::ProofSlotMismatch`] when the response proves another account or other keys.
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        block: u64,
    ) -> Result<AccountWitness, L1Error> {
        let response = self
            .provider
            .get_proof(address, slots.to_vec())
            .block_id(BlockId::number(block))
            .await
            .map_err(|e| L1Error::Rpc(format!("eth_getProof({address}) at block {block}: {e}")))?;
        if response.address != address {
            return Err(L1Error::ProofAddressMismatch { requested: address, got: response.address });
        }
        let got: Vec<B256> = response.storage_proof.iter().map(|p| p.key.as_b256()).collect();
        if got != slots {
            return Err(L1Error::ProofSlotMismatch { requested: slots.to_vec(), got });
        }
        Ok(AccountWitness {
            address,
            nonce: response.nonce,
            balance: response.balance,
            storage_root: response.storage_hash,
            code_hash: response.code_hash,
            account_proof: response.account_proof,
            storage: response
                .storage_proof
                .into_iter()
                .zip(slots)
                .map(|(p, slot)| StorageProof { slot: *slot, value: p.value, proof: p.proof })
                .collect(),
        })
    }

    /// `eth_getStorageAt(address, slot, block)`.
    async fn storage_at(&self, address: Address, slot: B256, block: u64) -> Result<U256, L1Error> {
        self.provider
            .get_storage_at(address, U256::from_be_bytes(slot.0))
            .block_id(BlockId::number(block))
            .await
            .map_err(|e| {
                L1Error::Rpc(format!("eth_getStorageAt({address}, {slot}) at block {block}: {e}"))
            })
    }
}

/// The member `name` of a JSON block object as a `T`; a missing or ill-typed member is
/// [`L1Error::MalformedResponse`].
fn member<T: serde::de::DeserializeOwned>(
    block: &Map<String, Value>,
    name: &str,
) -> Result<T, L1Error> {
    let value = block
        .get(name)
        .ok_or_else(|| L1Error::MalformedResponse(format!("block without `{name}`")))?;
    T::deserialize(value)
        .map_err(|e| L1Error::MalformedResponse(format!("block member `{name}`: {e}")))
}

/// The raw header of block `number` re-encoded from its `eth_getBlockByNumber` JSON `block`.
///
/// Every member must be a header field alloy's [`Header`] (de)serializes or one of
/// [`BLOCK_MEMBERS`]; others are [`L1Error::UnknownHeaderFields`], as re-encoding would drop
/// them. The caller still checks the result against the reported block hash.
fn header_from_json(number: u64, block: Map<String, Value>) -> Result<RawL1Header, L1Error> {
    let known = known_header_fields();
    let fields: Vec<String> = block
        .keys()
        .filter(|name| !known.contains(name.as_str()) && !BLOCK_MEMBERS.contains(&name.as_str()))
        .cloned()
        .collect();
    if !fields.is_empty() {
        return Err(L1Error::UnknownHeaderFields { number, fields });
    }
    let header: Header = serde_json::from_value(Value::Object(block))
        .map_err(|e| L1Error::MalformedResponse(format!("block {number} header: {e}")))?;
    Ok(RawL1Header::from(&header))
}

/// The JSON names of every header field alloy's [`Header`] knows: the members of a header with
/// every optional field set.
fn known_header_fields() -> BTreeSet<String> {
    let full = Header {
        base_fee_per_gas: Some(0),
        withdrawals_root: Some(B256::ZERO),
        blob_gas_used: Some(0),
        excess_blob_gas: Some(0),
        parent_beacon_block_root: Some(B256::ZERO),
        requests_hash: Some(B256::ZERO),
        ..Header::default()
    };
    match serde_json::to_value(full) {
        Ok(Value::Object(fields)) => fields.into_iter().map(|(name, _)| name).collect(),
        other => unreachable!("a header serializes as a JSON object: {other:?}"),
    }
}

/// The node's canonical raw L1 header at `number` ([`L1Source::header`]), required to be block
/// `number` whatever the [`L1Source`] ([`L1Error::HeaderNumberMismatch`] otherwise).
pub async fn header_at<L: L1Source + ?Sized>(l1: &L, number: u64) -> Result<RawL1Header, L1Error> {
    let header = l1.header(number).await?;
    if header.number() != number {
        return Err(L1Error::HeaderNumberMismatch { requested: number, got: header.number() });
    }
    Ok(header)
}

/// Whether `header` is final and canonical in the node's own L1 view: the node's `finalized`
/// number is at least `header.number() + extra_depth` (`F_L1`) and the node's canonical block
/// hash at `header.number()` is `header.hash()`, i.e. `keccak256` of the raw header.
///
/// An overflowing `header.number() + extra_depth` is never final. The canonical hash is only
/// fetched once the finality bound holds.
pub async fn is_final_canonical<L: L1Source + ?Sized>(
    l1: &L,
    header: &RawL1Header,
    extra_depth: u64,
) -> Result<bool, L1Error> {
    let Some(bound) = header.number().checked_add(extra_depth) else {
        return Ok(false);
    };
    if l1.finalized_number().await? < bound {
        return Ok(false);
    }
    Ok(l1.canonical_hash(header.number()).await? == header.hash())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        l1::mpt::verify_account_witness,
        test_utils::{L1Call, MockL1, l1_header, raw_with_future_fields},
    };
    use alloy_primitives::keccak256;
    use alloy_provider::ProviderBuilder;
    use alloy_transport::mock::Asserter;
    use serde_json::json;

    /// `eth_getBlockByNumber` and `eth_getProof` responses of a local anvil (see `source`).
    const ANVIL: &str = include_str!("testdata/anvil_get_proof.json");

    fn fixture() -> Value {
        serde_json::from_str(ANVIL).expect("fixture is JSON")
    }

    /// anvil's `eth_getBlockByNumber(1)` result.
    fn block() -> Value {
        fixture()["block"].clone()
    }

    /// The raw header a node with the `debug` namespace serves for [`block`].
    fn raw_block_header() -> Bytes {
        let header: Header = serde_json::from_value(block()).expect("an alloy header");
        alloy_rlp::encode(&header).into()
    }

    fn fixture_slots() -> Vec<B256> {
        serde_json::from_value(fixture()["slots"].clone()).expect("slots")
    }

    fn fixture_address() -> Address {
        serde_json::from_value(fixture()["address"].clone()).expect("address")
    }

    /// An [`RpcL1Source`] answering from `asserter`'s queue.
    fn mocked() -> (RpcL1Source, Asserter) {
        let asserter = Asserter::new();
        let provider = ProviderBuilder::default().connect_mocked_client(asserter.clone());
        (RpcL1Source::new(provider), asserter)
    }

    /// Queues the JSON-RPC error `code` with `message` as `asserter`'s next answer.
    fn push_rpc_error(asserter: &Asserter, code: i64, message: &str) {
        let payload = json!({ "code": code, "message": message });
        asserter.push_failure(serde_json::from_value(payload).expect("a JSON-RPC error payload"));
    }

    /// Queues the error anvil 1.5.1 answers `debug_getRawHeader` with.
    fn push_method_not_found(asserter: &Asserter) {
        push_rpc_error(asserter, -32601, "Method not found");
    }

    #[tokio::test]
    async fn finalized_number_reads_the_finalized_block() {
        let (l1, asserter) = mocked();
        asserter.push_success(&block());
        assert_eq!(l1.finalized_number().await, Ok(1));
    }

    #[tokio::test]
    async fn missing_finalized_block_is_an_error() {
        let (l1, asserter) = mocked();
        asserter.push_success(&Value::Null);
        assert_eq!(
            l1.finalized_number().await,
            Err(L1Error::BlockNotFound(BlockNumberOrTag::Finalized))
        );
    }

    #[tokio::test]
    async fn canonical_hash_is_the_reported_hash_of_the_requested_block() {
        let (l1, asserter) = mocked();
        asserter.push_success(&block());
        let hash: B256 = serde_json::from_value(block()["hash"].clone()).unwrap();
        assert_eq!(l1.canonical_hash(1).await, Ok(hash));

        asserter.push_success(&block());
        assert_eq!(
            l1.canonical_hash(2).await,
            Err(L1Error::HeaderNumberMismatch { requested: 2, got: 1 })
        );

        let mut no_hash = block();
        no_hash.as_object_mut().unwrap().remove("hash");
        asserter.push_success(&no_hash);
        assert!(matches!(l1.canonical_hash(1).await, Err(L1Error::MalformedResponse(_))));
    }

    /// With the `debug` namespace, the header is the node's raw bytes, checked against the
    /// reported hash.
    #[tokio::test]
    async fn header_is_the_raw_header_checked_against_the_reported_hash() {
        let (l1, asserter) = mocked();
        asserter.push_success(&block());
        asserter.push_success(&raw_block_header());

        let header = l1.header(1).await.expect("header");
        let hash: B256 = serde_json::from_value(block()["hash"].clone()).unwrap();
        let state_root: B256 = serde_json::from_value(block()["stateRoot"].clone()).unwrap();
        assert_eq!(header.raw(), &raw_block_header());
        assert_eq!(header.hash(), hash);
        assert_eq!(header.number(), 1);
        assert_eq!(header.state_root(), state_root);
    }

    /// A header from a later L1 fork (two fields alloy does not know) is served as is: its hash
    /// is `keccak256` of the raw bytes, which is the node's block hash.
    #[tokio::test]
    async fn a_raw_header_with_unknown_trailing_fields_is_served_as_is() {
        let base: Header = serde_json::from_value(block()).unwrap();
        let raw = raw_with_future_fields(&base);
        let hash = keccak256(&raw);

        let mut json = block();
        json["hash"] = json!(hash);
        json["blockAccessListHash"] = json!(B256::repeat_byte(0xba));
        json["slotNumber"] = json!("0x1020304");
        let (l1, asserter) = mocked();
        asserter.push_success(&json);
        asserter.push_success(&raw);
        let header = l1.header(1).await.expect("the raw header is served as is");
        assert_eq!(header.raw(), &raw);
        assert_eq!(header.hash(), hash);
        assert_eq!(header.state_root(), base.state_root);
    }

    /// anvil 1.5.1 answers `debug_getRawHeader` with "method not found"; its JSON header holds
    /// only fields alloy knows, so it is re-encoded and still checked against the hash.
    #[tokio::test]
    async fn a_node_without_debug_get_raw_header_falls_back_to_the_json_header() {
        let (l1, asserter) = mocked();
        asserter.push_success(&block());
        push_method_not_found(&asserter);
        let header = l1.header(1).await.expect("re-encoded from JSON");
        assert_eq!(header.raw(), &raw_block_header());
        assert_eq!(header.hash(), serde_json::from_value::<B256>(block()["hash"].clone()).unwrap());

        // EIP-1474's "method not supported" falls back too.
        asserter.push_success(&block());
        push_rpc_error(&asserter, -32004, "method not supported");
        assert_eq!(l1.header(1).await.map(|h| h.hash()), Ok(header.hash()));
    }

    /// Without `debug_getRawHeader`, a JSON header with a field alloy does not know cannot be
    /// rebuilt: refused, naming the fields.
    #[tokio::test]
    async fn the_json_fallback_refuses_unknown_header_fields() {
        let mut json = block();
        json["slotNumber"] = json!("0x7");
        json["blockAccessListHash"] = json!(B256::repeat_byte(0xba));
        let (l1, asserter) = mocked();
        asserter.push_success(&json);
        push_method_not_found(&asserter);
        assert_eq!(
            l1.header(1).await,
            Err(L1Error::UnknownHeaderFields {
                number: 1,
                fields: vec!["blockAccessListHash".into(), "slotNumber".into()],
            })
        );
    }

    #[tokio::test]
    async fn header_not_hashing_to_the_reported_hash_is_rejected() {
        let mut wrong_hash = block();
        wrong_hash["hash"] = json!(B256::repeat_byte(0xee));
        let mut wrong_field = block();
        wrong_field["gasUsed"] = json!("0x1");

        // A raw header against a wrong hash, and re-encoded JSON headers against their hash.
        let cases = [(wrong_hash.clone(), true), (wrong_hash, false), (wrong_field, false)];
        for (json, debug) in cases {
            let (l1, asserter) = mocked();
            asserter.push_success(&json);
            if debug {
                asserter.push_success(&raw_block_header());
            } else {
                push_method_not_found(&asserter);
            }
            let err = l1.header(1).await.unwrap_err();
            assert!(
                matches!(err, L1Error::HeaderHashMismatch { number: 1, reported, computed }
                    if reported != computed),
                "{err:?}"
            );
        }
    }

    /// A node answering the request for block 2 with block 1 (hash and header consistent) is
    /// caught by the number check.
    #[tokio::test]
    async fn a_header_of_another_block_is_rejected() {
        let (l1, asserter) = mocked();
        asserter.push_success(&block());
        asserter.push_success(&raw_block_header());
        assert_eq!(l1.header(2).await, Err(L1Error::HeaderNumberMismatch { requested: 2, got: 1 }));
    }

    #[tokio::test]
    async fn a_malformed_raw_header_is_rejected() {
        let (l1, asserter) = mocked();
        asserter.push_success(&block());
        asserter.push_success(&Bytes::from_static(&[0xc1, 0x80]));
        assert_eq!(
            l1.header(1).await,
            Err(L1Error::MalformedHeader {
                number: 1,
                error: L1HeaderError::TooFewFields { got: 1 }
            })
        );
    }

    #[tokio::test]
    async fn missing_header_is_an_error() {
        let (l1, asserter) = mocked();
        asserter.push_success(&Value::Null);
        assert_eq!(l1.header(7).await, Err(L1Error::BlockNotFound(BlockNumberOrTag::Number(7))));
    }

    /// The converted anvil proof verifies against the block's state root with the shared MPT
    /// verifier, and carries the requested slots in order.
    #[tokio::test]
    async fn account_witness_converts_a_real_get_proof_response() {
        let (l1, asserter) = mocked();
        asserter.push_success(&fixture()["proof"]);
        let slots = fixture_slots();
        let address = fixture_address();

        let witness = l1.account_witness(address, &slots, 1).await.expect("witness");
        assert_eq!(witness.address, address);
        assert_eq!(witness.storage.iter().map(|p| p.slot).collect::<Vec<_>>(), slots);

        let state_root: B256 = serde_json::from_value(block()["stateRoot"].clone()).unwrap();
        let verified = verify_account_witness(state_root, &witness, &slots).expect("verifies");
        assert_eq!(verified.get(slots[0]), Some(U256::from(3)));
        assert_eq!(verified.get(slots[1]), Some(U256::from(1234)));
        assert_eq!(verified.get(slots[2]), Some(U256::ZERO));
    }

    #[tokio::test]
    async fn account_witness_rejects_keys_out_of_request_order() {
        let slots = fixture_slots();
        let mut swapped = fixture()["proof"].clone();
        swapped["storageProof"].as_array_mut().unwrap().swap(0, 1);
        let mut missing = fixture()["proof"].clone();
        missing["storageProof"].as_array_mut().unwrap().pop();

        for proof in [swapped, missing] {
            let (l1, asserter) = mocked();
            asserter.push_success(&proof);
            let err = l1.account_witness(fixture_address(), &slots, 1).await.unwrap_err();
            assert!(
                matches!(&err, L1Error::ProofSlotMismatch { requested, got }
                    if requested == &slots && got != &slots),
                "{err:?}"
            );
        }
    }

    #[tokio::test]
    async fn account_witness_rejects_another_account() {
        let (l1, asserter) = mocked();
        asserter.push_success(&fixture()["proof"]);
        let other = Address::repeat_byte(0x42);
        assert_eq!(
            l1.account_witness(other, &fixture_slots(), 1).await,
            Err(L1Error::ProofAddressMismatch { requested: other, got: fixture_address() })
        );
    }

    #[tokio::test]
    async fn storage_at_reads_the_word() {
        let (l1, asserter) = mocked();
        asserter.push_success(&U256::from(1234));
        assert_eq!(
            l1.storage_at(fixture_address(), fixture_slots()[1], 1).await,
            Ok(U256::from(1234))
        );
    }

    #[tokio::test]
    async fn rpc_failures_name_the_method() {
        let (l1, asserter) = mocked();
        asserter.push_failure_msg("boom");
        let err = l1.header(3).await.unwrap_err();
        assert!(
            matches!(&err, L1Error::Rpc(msg) if msg.contains("eth_getBlockByNumber") && msg.contains("boom")),
            "{err:?}"
        );

        // Any other debug_getRawHeader failure than an unserved method is an error, not a
        // fallback.
        asserter.push_success(&block());
        asserter.push_failure_msg("header not found");
        let err = l1.header(1).await.unwrap_err();
        assert!(
            matches!(&err, L1Error::Rpc(msg) if msg.contains("debug_getRawHeader") && msg.contains("header not found")),
            "{err:?}"
        );

        asserter.push_failure_msg("missing trie node");
        let err = l1.account_witness(fixture_address(), &fixture_slots(), 1).await.unwrap_err();
        assert!(
            matches!(&err, L1Error::Rpc(msg) if msg.contains("eth_getProof") && msg.contains("missing trie node")),
            "{err:?}"
        );
    }

    /// The fallback knows every header field of alloy's [`Header`] (through Prague) and nothing
    /// a later fork adds.
    #[test]
    fn known_header_fields_are_alloys() {
        let known = known_header_fields();
        for field in ["parentHash", "sha3Uncles", "miner", "stateRoot", "number", "requestsHash"] {
            assert!(known.contains(field), "{field}");
        }
        assert_eq!(known.len(), 21);
        let anvil = block();
        let members = anvil.as_object().unwrap().keys();
        assert!(
            members
                .filter(|m| !known.contains(m.as_str()))
                .all(|m| BLOCK_MEMBERS.contains(&m.as_str())),
            "every member of anvil's block is a header field or a block member"
        );
    }

    #[tokio::test]
    async fn final_canonical_header_is_accepted() {
        let header = RawL1Header::from(&l1_header(10, 100));
        let l1 = MockL1::new(12);
        l1.insert_header(header.clone());

        assert_eq!(is_final_canonical(&l1, &header, 0).await, Ok(true));
        assert_eq!(is_final_canonical(&l1, &header, 2).await, Ok(true), "finalized == n + F_L1");
        assert!(
            l1.calls().iter().all(|call| !matches!(call, L1Call::Header(_))),
            "only the canonical hash is read, never the raw header"
        );
    }

    #[tokio::test]
    async fn header_above_the_finality_bound_is_not_final() {
        let header = RawL1Header::from(&l1_header(10, 100));
        let l1 = MockL1::new(12);
        l1.insert_header(header.clone());

        assert_eq!(is_final_canonical(&l1, &header, 3).await, Ok(false));
        assert_eq!(is_final_canonical(&l1, &header, u64::MAX).await, Ok(false), "overflow");
        let later = RawL1Header::from(&l1_header(13, 100));
        assert_eq!(is_final_canonical(&l1, &later, 0).await, Ok(false));
        assert!(
            !l1.calls().iter().any(|call| matches!(call, L1Call::CanonicalHash(_))),
            "no canonical hash read before finality holds"
        );

        l1.set_finalized(13);
        assert_eq!(is_final_canonical(&l1, &header, 3).await, Ok(true), "finality advanced");
    }

    #[tokio::test]
    async fn non_canonical_header_is_rejected() {
        let canonical = RawL1Header::from(&l1_header(10, 100));
        let l1 = MockL1::new(12);
        l1.insert_header(canonical.clone());

        let fork = RawL1Header::from(&l1_header(10, 101));
        assert_ne!(fork.hash(), canonical.hash());
        assert_eq!(is_final_canonical(&l1, &fork, 0).await, Ok(false));
    }

    #[tokio::test]
    async fn unknown_canonical_header_is_an_error() {
        let l1 = MockL1::new(12);
        assert_eq!(
            is_final_canonical(&l1, &RawL1Header::from(&l1_header(10, 100)), 0).await,
            Err(L1Error::BlockNotFound(BlockNumberOrTag::Number(10)))
        );
    }

    /// The trait is object safe, so the app can hold a `dyn L1Source`.
    #[tokio::test]
    async fn works_through_a_trait_object() {
        let header = RawL1Header::from(&l1_header(5, 100));
        let l1 = MockL1::new(5);
        l1.insert_header(header.clone());
        let dyn_l1: &dyn L1Source = &l1;
        assert_eq!(is_final_canonical(dyn_l1, &header, 0).await, Ok(true));
    }
}
