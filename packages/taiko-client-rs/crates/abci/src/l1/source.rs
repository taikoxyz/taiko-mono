//! The node's own L1 view (spec §6.1, D13): the `finalized` block number, canonical headers,
//! EIP-1186 account proofs and raw storage reads, behind [`L1Source`] so the app can run against
//! an in-memory L1 in tests.
//!
//! Only `PrepareProposal`, `ProcessProposal` (the ¹ checks of spec §5.4) and `InitChain` use it;
//! `FinalizeBlock` and replay never call L1 (D4).

use alloy_consensus::Header;
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::{Provider, RootProvider};
use async_trait::async_trait;

use crate::types::{AccountWitness, StorageProof};

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
    /// The L1 node reported a block hash its own header does not hash to.
    #[error("L1 block {number} reported hash {reported}, but its header hashes to {computed}")]
    HeaderHashMismatch {
        /// The requested block number.
        number: u64,
        /// The `hash` field of the RPC response.
        reported: B256,
        /// `keccak256(rlp(header))` of the returned header fields.
        computed: B256,
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

    /// The canonical L1 header at `number`, checked to hash to the block hash the node reports.
    async fn header(&self, number: u64) -> Result<Header, L1Error>;

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
    /// discover values that are later checked against proven roots (amendment A1).
    async fn storage_at(&self, address: Address, slot: B256, block: u64) -> Result<U256, L1Error>;
}

/// [`L1Source`] over an alloy JSON-RPC provider.
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

    /// `eth_getBlockByNumber(tag, false)`'s header and reported hash; a missing block is
    /// [`L1Error::BlockNotFound`].
    async fn block_header(&self, tag: BlockNumberOrTag) -> Result<(Header, B256), L1Error> {
        let block = self
            .provider
            .get_block_by_number(tag)
            .await
            .map_err(|e| L1Error::Rpc(format!("eth_getBlockByNumber({tag}): {e}")))?
            .ok_or(L1Error::BlockNotFound(tag))?;
        Ok((block.header.inner, block.header.hash))
    }
}

#[async_trait]
impl L1Source for RpcL1Source {
    /// `eth_getBlockByNumber("finalized")`; a node without a finalized block fails with
    /// [`L1Error::BlockNotFound`].
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        Ok(self.block_header(BlockNumberOrTag::Finalized).await?.0.number)
    }

    /// `eth_getBlockByNumber(number)`; fails with [`L1Error::HeaderHashMismatch`] when the
    /// returned header does not hash to the returned block hash.
    async fn header(&self, number: u64) -> Result<Header, L1Error> {
        let (header, reported) = self.block_header(BlockNumberOrTag::Number(number)).await?;
        let computed = header.hash_slow();
        if computed != reported {
            return Err(L1Error::HeaderHashMismatch { number, reported, computed });
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

/// Whether `header` is final and canonical in the node's own L1 view (spec §6.1): the node's
/// `finalized` number is at least `header.number + extra_depth` (`F_L1`) and the node's canonical
/// header at `header.number` hashes to the same value as `header`.
///
/// An overflowing `header.number + extra_depth` is never final. The canonical header is only
/// fetched once the finality bound holds.
pub async fn is_final_canonical<L: L1Source + ?Sized>(
    l1: &L,
    header: &Header,
    extra_depth: u64,
) -> Result<bool, L1Error> {
    let Some(bound) = header.number.checked_add(extra_depth) else {
        return Ok(false);
    };
    if l1.finalized_number().await? < bound {
        return Ok(false);
    }
    Ok(l1.header(header.number).await?.hash_slow() == header.hash_slow())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        l1::mpt::verify_account_witness,
        test_utils::{L1Call, MockL1, l1_header},
    };
    use alloy_provider::ProviderBuilder;
    use alloy_transport::mock::Asserter;
    use serde_json::Value;

    /// `eth_getBlockByNumber` and `eth_getProof` responses of a local anvil (see `source`).
    const ANVIL: &str = include_str!("testdata/anvil_get_proof.json");

    fn fixture() -> Value {
        serde_json::from_str(ANVIL).expect("fixture is JSON")
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

    #[tokio::test]
    async fn finalized_number_reads_the_finalized_block() {
        let (l1, asserter) = mocked();
        asserter.push_success(&fixture()["block"]);
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
    async fn header_is_the_hash_checked_consensus_header() {
        let (l1, asserter) = mocked();
        let block = fixture()["block"].clone();
        asserter.push_success(&block);

        let header = l1.header(1).await.expect("header");
        let hash: B256 = serde_json::from_value(block["hash"].clone()).unwrap();
        let state_root: B256 = serde_json::from_value(block["stateRoot"].clone()).unwrap();
        assert_eq!(header.hash_slow(), hash);
        assert_eq!(header.number, 1);
        assert_eq!(header.state_root, state_root);
    }

    #[tokio::test]
    async fn header_not_hashing_to_the_reported_hash_is_rejected() {
        let mut wrong_hash = fixture()["block"].clone();
        wrong_hash["hash"] = Value::String(format!("{}", B256::repeat_byte(0xee)));
        let mut wrong_field = fixture()["block"].clone();
        wrong_field["gasUsed"] = Value::String("0x1".into());

        for block in [wrong_hash, wrong_field] {
            let (l1, asserter) = mocked();
            asserter.push_success(&block);
            let err = l1.header(1).await.unwrap_err();
            assert!(
                matches!(err, L1Error::HeaderHashMismatch { number: 1, reported, computed }
                    if reported != computed),
                "{err:?}"
            );
        }
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

        let state_root: B256 =
            serde_json::from_value(fixture()["block"]["stateRoot"].clone()).unwrap();
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

        asserter.push_failure_msg("missing trie node");
        let err = l1.account_witness(fixture_address(), &fixture_slots(), 1).await.unwrap_err();
        assert!(
            matches!(&err, L1Error::Rpc(msg) if msg.contains("eth_getProof") && msg.contains("missing trie node")),
            "{err:?}"
        );
    }

    #[tokio::test]
    async fn final_canonical_header_is_accepted() {
        let header = l1_header(10, 100);
        let l1 = MockL1::new(12);
        l1.insert_header(header.clone());

        assert_eq!(is_final_canonical(&l1, &header, 0).await, Ok(true));
        assert_eq!(is_final_canonical(&l1, &header, 2).await, Ok(true), "finalized == n + F_L1");
    }

    #[tokio::test]
    async fn header_above_the_finality_bound_is_not_final() {
        let header = l1_header(10, 100);
        let l1 = MockL1::new(12);
        l1.insert_header(header.clone());

        assert_eq!(is_final_canonical(&l1, &header, 3).await, Ok(false));
        assert_eq!(is_final_canonical(&l1, &header, u64::MAX).await, Ok(false), "overflow");
        assert_eq!(is_final_canonical(&l1, &l1_header(13, 100), 0).await, Ok(false));
        assert!(
            !l1.calls().iter().any(|call| matches!(call, L1Call::Header(_))),
            "no header fetched before finality holds"
        );

        l1.set_finalized(13);
        assert_eq!(is_final_canonical(&l1, &header, 3).await, Ok(true), "finality advanced");
    }

    #[tokio::test]
    async fn non_canonical_header_is_rejected() {
        let canonical = l1_header(10, 100);
        let l1 = MockL1::new(12);
        l1.insert_header(canonical.clone());

        let fork = l1_header(10, 101);
        assert_ne!(fork.hash_slow(), canonical.hash_slow());
        assert_eq!(is_final_canonical(&l1, &fork, 0).await, Ok(false));
    }

    #[tokio::test]
    async fn unknown_canonical_header_is_an_error() {
        let l1 = MockL1::new(12);
        assert_eq!(
            is_final_canonical(&l1, &l1_header(10, 100), 0).await,
            Err(L1Error::BlockNotFound(BlockNumberOrTag::Number(10)))
        );
    }

    /// The trait is object safe, so the app can hold a `dyn L1Source`.
    #[tokio::test]
    async fn works_through_a_trait_object() {
        let header = l1_header(5, 100);
        let l1 = MockL1::new(5);
        l1.insert_header(header.clone());
        let dyn_l1: &dyn L1Source = &l1;
        assert_eq!(is_final_canonical(dyn_l1, &header, 0).await, Ok(true));
    }
}
