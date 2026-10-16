//! Entitlement authentication at canonical executed L2 H, and separate claim finality.

use super::{ClaimIdentity, ClaimProof, Vault};
use crate::{
    LanderError, Result,
    contracts::BatchRewardRecorded,
    rewards::{self, Receipt},
    tx::LandingReceipt,
};
use abci::{
    AccountWitness, AnchorWitness, RawL1Header,
    l1::{
        layout::inbox,
        source::{L1Error, L1Source, RpcL1Source},
        verify_account_witness,
        witness::verify_anchor_witness,
    },
};
use alloy::sol_types::{SolCall, SolEvent};
use alloy_consensus::Header;
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, Bytes, U256, address};
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types::TransactionRequest;
use async_trait::async_trait;
use std::time::Duration;

/// EIP-4788 roots contract populated by intended canonical ABCI execution.
pub const ROOTS: Address = address!("000F3df6D732807Ef1319fB7B8bB8522d0Beac02");
/// Bound ancestry work in addition to the complete-operation wall-clock deadline.
const MAX_ANCESTRY: u64 = 131_072;

/// Read-only boundary; implementations must authenticate all returned facts.
#[async_trait]
pub trait ClaimSource: Send + Sync {
    /// Discover and authenticate the exact requested landing receipt.
    async fn prepare(&self, landing_tx: B256, batch_id: B256) -> Result<ClaimProof>;
    /// Read claimed under the own canonical executed head.
    async fn claimed(&self, batch_id: B256) -> Result<bool>;
    /// Independently hash the current canonical execution header at this height.
    async fn canonical_hash(&self, number: u64) -> Result<B256>;
    /// Authenticate a finalized L1 checkpoint and descending EL ancestry through the claim.
    async fn transaction_finalized(&self, receipt: &LandingReceipt) -> Result<bool>;
}

/// Public RPC source. The own EL's executed canonical chain is a trusted input at preparation.
#[derive(Clone)]
pub struct RpcClaimSource {
    /// Own L1 provider used for discovery and chain identity.
    l1: RootProvider,
    /// Own executed L2 provider; never uses pending headers.
    l2: RootProvider,
    /// Existing strict raw-header/EIP-1186 adapter.
    anchors: RpcL1Source,
    /// Fixed public identities discovered from the canonical vault.
    identity: ClaimIdentity,
    /// Overall limit for each prepare/finality traversal, beyond HTTP call deadlines.
    deadline: Duration,
}

impl RpcClaimSource {
    /// Discover the fixed Inbox from the canonical vault, never from an event address.
    pub async fn connect(
        l1: RootProvider,
        l2: RootProvider,
        landing_tx: B256,
        batch_id: B256,
        payer: Address,
        deadline: Duration,
    ) -> Result<Self> {
        if deadline.is_zero() || deadline > Duration::from_secs(3600) {
            return Err(LanderError::Configuration("invalid claim RPC deadline".into()));
        }
        tokio::time::timeout(deadline, async {
            let l1_chain_id = U256::from(l1.get_chain_id().await.map_err(rpc_error)?);
            let l2_chain_id = l2.get_chain_id().await.map_err(rpc_error)?;
            let vault = abci::ChainParams::builtin(l2_chain_id)
                .map_err(|_| LanderError::Configuration("unsupported claim L2 chain".into()))?
                .fee_vault;
            let header = execution_header(&l2, BlockNumberOrTag::Latest).await?;
            let block = BlockId::hash_canonical(header.hash_slow());
            let inbox = call(&l2, vault, Vault::l1InboxCall {}, block).await?;
            let configured_l1 = call(&l2, vault, Vault::l1ChainIdCall {}, block).await?;
            let roots = call(&l2, vault, Vault::ROOTSCall {}, block).await?;
            if configured_l1 != l1_chain_id || roots != ROOTS {
                return Err(LanderError::Safety(
                    "vault L1 chain or roots configuration mismatch".into(),
                ));
            }
            let identity = ClaimIdentity {
                landing_tx,
                batch_id,
                l1_chain_id,
                l2_chain_id,
                inbox,
                vault,
                payer,
            };
            identity.validate()?;
            recheck_header(&l2, &header).await?;
            Ok(Self { anchors: RpcL1Source::new(l1.clone()), l1, l2, identity, deadline })
        })
        .await
        .map_err(|_| timeout_error())?
    }

    /// Public identity used to bind the journal before any proof acquisition or signing.
    pub fn identity(&self) -> &ClaimIdentity {
        &self.identity
    }

    /// Authenticate an anchor by descending from the own finalized L1 header.
    async fn finalized_anchor(&self, number: u64) -> Result<RawL1Header> {
        let finalized = self.anchors.finalized_number().await.map_err(anchor_error)?;
        if number > finalized {
            return Err(LanderError::Unavailable("L2 anchor is not finalized on own L1".into()));
        }
        if finalized - number > MAX_ANCESTRY {
            return Err(LanderError::Unavailable(
                "claim L1 ancestry exceeds bounded traversal".into(),
            ));
        }
        let mut header = self.anchors.header_hash_pinned(finalized).await.map_err(anchor_error)?;
        while header.number() > number {
            let parent =
                self.anchors.header_hash_pinned(header.number() - 1).await.map_err(anchor_error)?;
            if header.parent_hash() != parent.hash() {
                return Err(LanderError::Safety("finalized L1 ancestry mismatch".into()));
            }
            header = parent;
        }
        if self.anchors.canonical_hash(number).await.map_err(anchor_error)? != header.hash() {
            return Err(LanderError::Unavailable("L1 anchor changed during authentication".into()));
        }
        Ok(header)
    }

    /// Discover one typed event from a canonical successful landing; no event alone authorizes pay.
    async fn discover(&self) -> Result<Receipt> {
        let tx = self.identity.landing_tx;
        let receipt = self
            .l1
            .get_transaction_receipt(tx)
            .await
            .map_err(rpc_error)?
            .ok_or_else(|| LanderError::Unavailable("landing receipt unavailable".into()))?;
        let number = receipt
            .block_number
            .ok_or_else(|| LanderError::Safety("landing receipt has no block".into()))?;
        let hash = receipt
            .block_hash
            .ok_or_else(|| LanderError::Safety("landing receipt has no block hash".into()))?;
        if !receipt.status() ||
            receipt.transaction_hash != tx ||
            self.anchors.canonical_hash(number).await.map_err(anchor_error)? != hash
        {
            return Err(LanderError::Safety(
                "landing receipt is unsuccessful or noncanonical".into(),
            ));
        }
        let mut found = None;
        for log in receipt.inner.logs() {
            if log.address() != self.identity.inbox ||
                log.topic0() != Some(&BatchRewardRecorded::SIGNATURE_HASH)
            {
                continue;
            }
            if log.removed ||
                log.transaction_hash != Some(tx) ||
                log.block_hash != Some(hash) ||
                log.block_number != Some(number)
            {
                return Err(LanderError::Safety("landing event context mismatch".into()));
            }
            let event = BatchRewardRecorded::decode_log_data_validate(&log.inner.data)
                .map_err(|_| LanderError::Safety("malformed reward event".into()))?;
            if event.batchId != self.identity.batch_id {
                continue;
            }
            if found.is_some() {
                return Err(LanderError::Safety("duplicate reward events".into()));
            }
            let reward = Receipt {
                l1ChainId: self.identity.l1_chain_id,
                l2ChainId: self.identity.l2_chain_id,
                inbox: self.identity.inbox,
                generation: event.generation,
                parentHeight: event.parentHeight,
                parentHash: event.parentHash,
                lastHeight: event.lastHeight,
                lastBlockHash: event.lastBlockHash,
                l2RewardRecipient: event.l2RewardRecipient,
                baseFeeAmount: event.baseFeeAmount,
            };
            self.identity.validate_receipt(&reward)?;
            found = Some(reward);
        }
        found.ok_or_else(|| {
            LanderError::Safety("requested reward event not found in landing".into())
        })
    }

    /// Complete proof acquisition, including actual roots-contract read at the pinned H state.
    async fn prepare_inner(&self) -> Result<ClaimProof> {
        let receipt = self.discover().await?;
        let header = execution_header(&self.l2, BlockNumberOrTag::Latest).await?;
        let (sharing, _, anchor_number) = abci::rules::decode_extra_data(&header.extra_data)
            .map_err(|_| LanderError::Safety("invalid Etna L2 extraData".into()))?;
        if sharing != 0 || header.number == 0 {
            return Err(LanderError::Safety(
                "claim requires a committed Etna execution header".into(),
            ));
        }
        let anchor = self.finalized_anchor(anchor_number).await?;
        if header.parent_beacon_block_root != Some(anchor.state_root()) {
            return Err(LanderError::Safety("L2 anchor root differs from finalized L1".into()));
        }
        let block = BlockId::hash_canonical(header.hash_slow());
        let output = self
            .l2
            .call(TransactionRequest::default().to(ROOTS).input(
                Bytes::copy_from_slice(&U256::from(header.timestamp).to_be_bytes::<32>()).into(),
            ))
            .block(block)
            .await
            .map_err(rpc_error)?;
        verify_root(&output, anchor.state_root())?;
        let slot = rewards::receipt_slot(self.identity.batch_id);
        let witness = self
            .anchors
            .account_witness_hash_canonical(self.identity.inbox, &[slot], anchor.hash())
            .await
            .map_err(anchor_error)?;
        verify_receipt(&self.identity, &receipt, anchor.state_root(), &witness)?;
        recheck_header(&self.l2, &header).await?;
        if self.anchors.canonical_hash(anchor.number()).await.map_err(anchor_error)? !=
            anchor.hash()
        {
            return Err(LanderError::Unavailable("claim anchor changed before signing".into()));
        }
        Ok(ClaimProof {
            receipt,
            anchor_timestamp: header.timestamp,
            account_proof: witness.account_proof,
            storage_proof: witness.storage[0].proof.clone(),
        })
    }

    /// Prove the Inbox checkpoint under finalized L1 and walk authenticated EL parents.
    async fn finalized_inner(&self, receipt: &LandingReceipt) -> Result<bool> {
        let number = self.anchors.finalized_number().await.map_err(anchor_error)?;
        let header = self.finalized_anchor(number).await?;
        let witness = self
            .anchors
            .account_witness_hash_canonical(
                self.identity.inbox,
                &inbox::anchor_slots(),
                header.hash(),
            )
            .await
            .map_err(anchor_error)?;
        let anchor = verify_anchor_witness(
            &AnchorWitness { l1_header: header.clone(), inbox: witness },
            self.identity.inbox,
        )
        .map_err(|_| LanderError::Safety("invalid finalized Inbox checkpoint proof".into()))?;
        let checkpoint = anchor.inbox.last_checkpoint_height;
        if checkpoint < receipt.block_number {
            return Ok(false);
        }
        if checkpoint - receipt.block_number > MAX_ANCESTRY {
            return Err(LanderError::Unavailable(
                "claim EL ancestry exceeds bounded traversal".into(),
            ));
        }
        let mut expected = anchor.inbox.last_checkpoint_hash;
        for height in (receipt.block_number..=checkpoint).rev() {
            let h = execution_header(&self.l2, BlockNumberOrTag::Number(height)).await?;
            if h.hash_slow() != expected {
                return Err(LanderError::Safety("finalized claim EL ancestry mismatch".into()));
            }
            if height == receipt.block_number && expected != receipt.block_hash {
                return Err(LanderError::Safety(
                    "claim block absent from finalized checkpoint ancestry".into(),
                ));
            }
            expected = h.parent_hash;
        }
        if self.anchors.canonical_hash(header.number()).await.map_err(anchor_error)? !=
            header.hash()
        {
            return Err(LanderError::Safety("finalized checkpoint changed".into()));
        }
        Ok(true)
    }
}

#[async_trait]
impl ClaimSource for RpcClaimSource {
    /// Authenticate one claim without imposing a later L1 landing on preparation H.
    async fn prepare(&self, landing_tx: B256, batch_id: B256) -> Result<ClaimProof> {
        if landing_tx != self.identity.landing_tx || batch_id != self.identity.batch_id {
            return Err(LanderError::Safety("claim request identity mismatch".into()));
        }
        tokio::time::timeout(self.deadline, self.prepare_inner())
            .await
            .map_err(|_| timeout_error())?
    }
    /// Pin and recheck the own executed head around the vault read.
    async fn claimed(&self, batch_id: B256) -> Result<bool> {
        let h = execution_header(&self.l2, BlockNumberOrTag::Latest).await?;
        let result = call(
            &self.l2,
            self.identity.vault,
            Vault::claimedCall { batchId: batch_id },
            BlockId::hash_canonical(h.hash_slow()),
        )
        .await?;
        recheck_header(&self.l2, &h).await?;
        Ok(result)
    }
    /// Return only an independently hashed canonical header.
    async fn canonical_hash(&self, number: u64) -> Result<B256> {
        Ok(execution_header(&self.l2, BlockNumberOrTag::Number(number)).await?.hash_slow())
    }
    /// Bound the full ancestry traversal, retaining the signed job on any timeout.
    async fn transaction_finalized(&self, receipt: &LandingReceipt) -> Result<bool> {
        tokio::time::timeout(self.deadline, self.finalized_inner(receipt))
            .await
            .map_err(|_| timeout_error())?
    }
}

/// Check the exact raw roots return; the lookup key is H.timestamp, not the L1 timestamp.
fn verify_root(output: &[u8], expected: B256) -> Result<()> {
    if expected.is_zero() || output.len() != 32 || output != expected.as_slice() {
        return Err(LanderError::Unavailable(
            "roots entry unavailable or mismatched; retry with a newer canonical header".into(),
        ));
    }
    Ok(())
}

/// Authenticate the fixed account and exactly one fixed slot before projecting proof calldata.
fn verify_receipt(
    identity: &ClaimIdentity,
    receipt: &Receipt,
    root: B256,
    witness: &AccountWitness,
) -> Result<()> {
    identity.validate_receipt(receipt)?;
    let slot = rewards::receipt_slot(identity.batch_id);
    if witness.address != identity.inbox || witness.account_proof.is_empty() {
        return Err(LanderError::Safety("receipt proof has wrong or empty Inbox account".into()));
    }
    let storage = verify_account_witness(root, witness, &[slot])
        .map_err(|_| LanderError::Safety("invalid reward account/storage proof".into()))?;
    if storage.get(slot) != Some(U256::from_be_bytes(rewards::commitment(receipt).0)) {
        return Err(LanderError::Safety(
            "reward event differs from authenticated receipt commitment".into(),
        ));
    }
    Ok(())
}

/// Strict typed eth_call at an EIP-1898 canonical block hash.
async fn call<C: SolCall>(
    provider: &RootProvider,
    address: Address,
    call: C,
    block: BlockId,
) -> Result<C::Return> {
    let output = provider
        .call(
            TransactionRequest::default().to(address).input(Bytes::from(call.abi_encode()).into()),
        )
        .block(block)
        .await
        .map_err(rpc_error)?;
    C::abi_decode_returns_validate(&output)
        .map_err(|_| LanderError::Safety("malformed vault response".into()))
}

/// Decode and independently hash a non-pending public EL header; never expose response bodies.
async fn execution_header(provider: &RootProvider, tag: BlockNumberOrTag) -> Result<Header> {
    let value: Option<serde_json::Value> = provider
        .raw_request("eth_getBlockByNumber".into(), (tag, false))
        .await
        .map_err(rpc_error)?;
    let value = value
        .ok_or_else(|| LanderError::Unavailable("canonical execution header unavailable".into()))?;
    let hash: B256 = serde_json::from_value(value.get("hash").cloned().unwrap_or_default())
        .map_err(|_| LanderError::Safety("malformed EL block hash".into()))?;
    let header: Header = serde_json::from_value(value)
        .map_err(|_| LanderError::Safety("malformed EL header".into()))?;
    if header.hash_slow() != hash ||
        matches!(tag, BlockNumberOrTag::Number(n) if n != header.number)
    {
        return Err(LanderError::Safety("EL header number/hash mismatch".into()));
    }
    Ok(header)
}

/// Detect a changed canonical H before signing, even if eth_call silently ignored canonicality.
async fn recheck_header(provider: &RootProvider, header: &Header) -> Result<()> {
    if execution_header(provider, BlockNumberOrTag::Number(header.number)).await?.hash_slow() !=
        header.hash_slow()
    {
        return Err(LanderError::Unavailable("canonical L2 header changed".into()));
    }
    Ok(())
}

/// Stable credential-free RPC diagnostic.
pub(super) fn rpc_error(error: alloy::transports::TransportError) -> LanderError {
    crate::error::sanitized_rpc_error("claim RPC", error)
}
/// Hide every upstream L1 response string, including malformed JSON contents.
fn anchor_error(error: L1Error) -> LanderError {
    match error {
        L1Error::Rpc(_) | L1Error::BlockNotFound(_) => {
            LanderError::Temporary("claim L1 RPC unavailable".into())
        }
        _ => LanderError::Safety("invalid claim L1 header or proof response".into()),
    }
}
/// A whole-operation deadline never discards signed state.
pub(super) fn timeout_error() -> LanderError {
    LanderError::Temporary("claim operation timed out".into())
}

#[cfg(test)]
#[path = "source_tests.rs"]
mod tests;
