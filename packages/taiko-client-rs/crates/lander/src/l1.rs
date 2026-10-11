//! Hash-pinned Inbox reads and authentication of the reference's L1 header chain.

use abci::{
    AnchorState, ChainParams, GenesisRecord, Schedule,
    envelope::AnchorWitness,
    l1::{
        header::RawL1Header,
        layout::{inbox, word_u64},
        source::{L1Source as AnchorSource, RpcL1Source},
        witness::verify_anchor_witness,
    },
};
use alloy::sol_types::SolCall;
use alloy_consensus::Header;
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types::TransactionRequest;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::{
    contracts::IEtnaInbox::{LandInput, hashLandStatementCall},
    error::{LanderError, Result},
    types::LandingSnapshot,
};

/// EIP-2935's block-hash retention window, as enforced by the pinned Inbox.
const REFERENCE_WINDOW: u64 = 8191;
/// EIP-2935 system contract, matching the Inbox's pinned reference-hash resolver.
const HISTORY_STORAGE_ADDRESS: Address =
    alloy_primitives::address!("0000f90827f1c53a10cb7a02335b175320002935");
/// The recent-window branch uses the EVM BLOCKHASH opcode rather than the history contract.
const BLOCKHASH_WINDOW: u64 = 256;
/// Bounds a long-outage reference chain before allocating or issuing its reads.
const MAX_REFERENCE_HEADERS: u64 = 131_072;

/// Execution parent plus the timestamp needed by the Etna base-fee rule.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParentContext {
    /// Header authenticated against the Inbox checkpoint.
    pub header: Header,
    /// Timestamp of the parent's parent; zero for genesis.
    pub grandparent_timestamp: u64,
}

/// Read-only L1/L2 boundary used by batch assembly and transaction reconciliation.
#[async_trait]
pub trait LandingSource: Send + Sync {
    /// Obtain all Inbox facts at one canonical L1 block hash.
    async fn snapshot(&self) -> Result<LandingSnapshot>;
    /// Authenticate the checkpoint's EL parent and its preceding timestamp.
    async fn parent_header(&self, snapshot: &LandingSnapshot) -> Result<ParentContext>;
    /// Recover the exact historical anchor consumed by the checkpoint parent.
    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        parent: &ParentContext,
    ) -> Result<AnchorState>;
    /// Read an already-landed committee at the snapshot's canonical state hash.
    async fn committee_hash(&self, snapshot: &LandingSnapshot, epoch: u64) -> Result<B256>;
    /// Authenticate all consumed anchors along a descending finalized reference chain.
    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>>;
    /// Ask the executing Inbox proxy to hash the identical public statement.
    async fn statement_hash(
        &self,
        snapshot: &LandingSnapshot,
        input: &LandInput,
        reference_hash: B256,
        blob_hashes: &[B256],
    ) -> Result<B256>;
    /// The canonical L1 hash at a requested number, including receipt blocks.
    async fn canonical_hash(&self, number: u64) -> Result<B256>;
    /// Reject a reference that is no longer canonical, past, or retained.
    async fn validate_reference(
        &self,
        snapshot: &LandingSnapshot,
        number: u64,
        hash: B256,
    ) -> Result<()>;
}

/// Public RPC adapter; all mutable Inbox reads use EIP-1898's canonical hash selector.
#[derive(Clone, Debug)]
pub struct RpcLandingSource {
    /// L1 public provider.
    l1: RootProvider,
    /// L2 public provider; Engine API access is unnecessary.
    l2: RootProvider,
    /// Existing raw-header and EIP-1186 adapter.
    anchors: RpcL1Source,
    /// Authenticated chain configuration and expected contract identities.
    params: ChainParams,
}

impl RpcLandingSource {
    /// Wrap public providers whose HTTP deadlines are configured by the caller.
    pub fn new(l1: RootProvider, l2: RootProvider, params: ChainParams) -> Self {
        Self { anchors: RpcL1Source::new(l1.clone()), l1, l2, params }
    }

    /// Read one storage word at exactly the canonical snapshot block hash.
    async fn word(&self, hash: B256, slot: B256) -> Result<U256> {
        self.l1
            .get_storage_at(self.params.inbox, U256::from_be_bytes(slot.0))
            .block_id(BlockId::hash_canonical(hash))
            .await
            .map_err(rpc_error)
    }

    /// Decode and independently hash one public EL header.
    async fn el_header(&self, number: u64) -> Result<Header> {
        let response: Option<serde_json::Value> = self
            .l2
            .raw_request("eth_getBlockByNumber".into(), (BlockNumberOrTag::Number(number), false))
            .await
            .map_err(rpc_error)?;
        let value = response
            .ok_or_else(|| LanderError::Unavailable(format!("EL parent header {number}")))?;
        let hash: B256 = serde_json::from_value(
            value
                .get("hash")
                .cloned()
                .ok_or_else(|| LanderError::Safety("EL header lacks hash".into()))?,
        )
        .map_err(|e| LanderError::Safety(format!("EL hash: {e}")))?;
        let header: Header = serde_json::from_value(value)
            .map_err(|e| LanderError::Safety(format!("EL header: {e}")))?;
        if header.number != number || header.hash_slow() != hash {
            return Err(LanderError::Safety(format!("EL header {number} number/hash mismatch")));
        }
        Ok(header)
    }

    /// Obtain a proof of historical Inbox facts under the independently verified raw header.
    async fn anchor_at(&self, number: u64) -> Result<AnchorState> {
        let l1_header = self.anchors.header(number).await.map_err(anchor_error)?;
        let witness = self
            .anchors
            .account_witness(self.params.inbox, &inbox::anchor_slots(None), number)
            .await
            .map_err(anchor_error)?;
        verify_anchor_witness(&AnchorWitness { l1_header, inbox: witness }, self.params.inbox, None)
            .map_err(|e| LanderError::Safety(format!("parent anchor {number}: {e}")))
    }
}

#[async_trait]
impl LandingSource for RpcLandingSource {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        let latest = self.l1.get_block_number().await.map_err(rpc_error)?;
        let raw = self.anchors.header(latest).await.map_err(anchor_error)?;
        let pin = raw.hash();
        let l1_chain_id = U256::from(self.l1.get_chain_id().await.map_err(rpc_error)?);
        let l2_chain_id = self.l2.get_chain_id().await.map_err(rpc_error)?;
        if l2_chain_id != self.params.l2_chain_id {
            return Err(LanderError::Configuration(format!(
                "L2 endpoint chain id {l2_chain_id}, configured {}",
                self.params.l2_chain_id
            )));
        }
        let status = self.word(pin, inbox::slot(inbox::STATUS)).await?;
        if status != U256::from(inbox::ETNA_ACTIVE) {
            return Err(LanderError::Configuration(format!(
                "Inbox status {status}, expected {}",
                inbox::ETNA_ACTIVE
            )));
        }
        let generation =
            word_u64(self.word(pin, inbox::slot(inbox::RECOVERY_GENERATION)).await?, 0);
        let packed = self.word(pin, inbox::slot(inbox::GENESIS_PACKED)).await?;
        let genesis = GenesisRecord {
            genesis_height: word_u64(packed, 0),
            l1_0: word_u64(packed, 64),
            epoch_len: word_u64(packed, 128),
            epoch_len_l1: word_u64(packed, 192),
            genesis_hash: self.word(pin, inbox::slot(inbox::GENESIS_BLOCK_HASH)).await?.into(),
            genesis_state_root: self
                .word(pin, inbox::slot(inbox::GENESIS_STATE_ROOT))
                .await?
                .into(),
            genesis_cutoff: word_u64(self.word(pin, inbox::slot(inbox::GENESIS_CUTOFF)).await?, 0),
        };
        if genesis.genesis_height != 0 ||
            genesis.genesis_hash.is_zero() ||
            genesis.genesis_state_root.is_zero() ||
            genesis.genesis_cutoff >= genesis.l1_0
        {
            return Err(LanderError::Configuration("Inbox genesis record is invalid".into()));
        }
        Schedule::from_genesis(&genesis)
            .validate(self.params.unsettled_cap())
            .map_err(|e| LanderError::Configuration(format!("Inbox epoch parameters: {e}")))?;
        let checkpoint_height =
            word_u64(self.word(pin, inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT)).await?, 0);
        let checkpoint_hash =
            self.word(pin, inbox::slot(inbox::LAST_CHECKPOINT_HASH)).await?.into();
        let start_committee_record_hash: B256 = self
            .word(pin, inbox::committee_slot(checkpoint_height / genesis.epoch_len))
            .await?
            .into();
        if start_committee_record_hash.is_zero() {
            return Err(LanderError::Safety("Inbox starting committee hash is zero".into()));
        }
        Ok(LandingSnapshot {
            l1_block_hash: pin,
            l1_block_number: latest,
            l1_chain_id,
            l2_chain_id,
            inbox: self.params.inbox,
            registry: self.params.registry,
            generation,
            checkpoint_height,
            checkpoint_hash,
            genesis,
            start_committee_record_hash,
        })
    }

    async fn parent_header(&self, snapshot: &LandingSnapshot) -> Result<ParentContext> {
        let header = self.el_header(snapshot.checkpoint_height).await?;
        if header.hash_slow() != snapshot.checkpoint_hash {
            return Err(LanderError::Safety(format!(
                "EL checkpoint {} contradicts Inbox {}",
                snapshot.checkpoint_height, snapshot.checkpoint_hash
            )));
        }
        let grandparent_timestamp = if header.number == 0 {
            0
        } else {
            let preceding = self.el_header(header.number - 1).await?;
            if preceding.hash_slow() != header.parent_hash {
                return Err(LanderError::Safety("EL checkpoint ancestry is inconsistent".into()));
            }
            preceding.timestamp
        };
        if header.number == 0 && header.state_root != snapshot.genesis.genesis_state_root {
            return Err(LanderError::Safety("EL genesis state root contradicts Inbox".into()));
        }
        Ok(ParentContext { header, grandparent_timestamp })
    }

    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        parent: &ParentContext,
    ) -> Result<AnchorState> {
        let number = if parent.header.number == 0 {
            snapshot.genesis.l1_0
        } else {
            let bytes = parent.header.extra_data.as_ref();
            if bytes.len() != 13 || bytes[0] != 100 {
                return Err(LanderError::Safety("EL checkpoint has invalid Etna extraData".into()));
            }
            let generation = bytes[1..7].iter().fold(0u64, |n, b| (n << 8) | u64::from(*b));
            if generation != snapshot.generation {
                return Err(LanderError::Safety(
                    "EL checkpoint generation differs from Inbox".into(),
                ));
            }
            bytes[7..13].iter().fold(0u64, |n, b| (n << 8) | u64::from(*b))
        };
        let anchor = self.anchor_at(number).await?;
        if parent.header.number != 0 &&
            parent.header.parent_beacon_block_root != Some(anchor.state_root)
        {
            return Err(LanderError::Safety("EL checkpoint anchor root differs from L1".into()));
        }
        Ok(anchor)
    }

    async fn committee_hash(&self, snapshot: &LandingSnapshot, epoch: u64) -> Result<B256> {
        Ok(self.word(snapshot.l1_block_hash, inbox::committee_slot(epoch)).await?.into())
    }

    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>> {
        let min = anchors
            .iter()
            .map(|a| a.number)
            .min()
            .ok_or_else(|| LanderError::Safety("reference without anchors".into()))?;
        let max = anchors.iter().map(|a| a.number).max().expect("nonempty anchors");
        let tip = self
            .anchors
            .finalized_number()
            .await
            .map_err(anchor_error)?
            .min(snapshot.l1_block_number.saturating_sub(1));
        if tip < max {
            return Err(LanderError::Temporary(format!(
                "finalized L1 reference {tip} has not reached consumed anchor {max}"
            )));
        }
        if tip - min >= MAX_REFERENCE_HEADERS {
            return Err(LanderError::Capacity(format!(
                "reference chain {} headers exceeds {MAX_REFERENCE_HEADERS}",
                tip - min + 1
            )));
        }
        let mut headers =
            Vec::with_capacity(usize::try_from(tip - min + 1).expect("bounded header count"));
        let mut expected = None;
        for number in (min..=tip).rev() {
            let header = self.anchors.header(number).await.map_err(anchor_error)?;
            if expected.is_some_and(|hash| hash != header.hash()) {
                return Err(LanderError::Safety(format!("L1 reference chain fork at {number}")));
            }
            for anchor in anchors.iter().filter(|a| a.number == number) {
                if anchor.hash != header.hash() ||
                    anchor.state_root != header.state_root() ||
                    anchor.timestamp != header.timestamp()
                {
                    return Err(LanderError::Safety(format!(
                        "consumed anchor {number} differs from L1 reference ancestry"
                    )));
                }
            }
            expected = Some(header.parent_hash());
            headers.push(header);
        }
        self.validate_reference(snapshot, tip, headers[0].hash()).await?;
        Ok(headers)
    }

    async fn statement_hash(
        &self,
        snapshot: &LandingSnapshot,
        input: &LandInput,
        reference_hash: B256,
        blob_hashes: &[B256],
    ) -> Result<B256> {
        let call = hashLandStatementCall {
            _generation: snapshot.generation,
            _parentHeight: snapshot.checkpoint_height,
            _parentHash: snapshot.checkpoint_hash,
            _startCommitteeRecordHash: snapshot.start_committee_record_hash,
            _input: input.clone(),
            _l1ReferenceBlockHash: reference_hash,
            _blobHashes: blob_hashes.to_vec(),
        };
        let tx = TransactionRequest::default().to(snapshot.inbox).input(call.abi_encode().into());
        let bytes = self
            .l1
            .call(tx)
            .block(BlockId::hash_canonical(snapshot.l1_block_hash))
            .await
            .map_err(rpc_error)?;
        hashLandStatementCall::abi_decode_returns(&bytes)
            .map_err(|e| LanderError::Configuration(format!("Inbox statement helper: {e}")))
    }

    async fn canonical_hash(&self, number: u64) -> Result<B256> {
        self.anchors.canonical_hash(number).await.map_err(anchor_error)
    }

    async fn validate_reference(
        &self,
        snapshot: &LandingSnapshot,
        number: u64,
        hash: B256,
    ) -> Result<()> {
        if number >= snapshot.l1_block_number ||
            snapshot.l1_block_number - number > REFERENCE_WINDOW
        {
            return Err(LanderError::Stale(format!(
                "L1 reference {number} is unavailable at L1 {}",
                snapshot.l1_block_number
            )));
        }
        if self.canonical_hash(number).await? != hash {
            return Err(LanderError::Stale(format!("L1 reference {number} is no longer canonical")));
        }
        if snapshot.l1_block_number - number > BLOCKHASH_WINDOW {
            let call = TransactionRequest::default()
                .to(HISTORY_STORAGE_ADDRESS)
                .input(U256::from(number).to_be_bytes::<32>().to_vec().into());
            let bytes = self
                .l1
                .call(call)
                .block(BlockId::hash_canonical(snapshot.l1_block_hash))
                .await
                .map_err(rpc_error)?;
            if bytes.len() != 32 || B256::from_slice(&bytes) != hash || hash.is_zero() {
                return Err(LanderError::Stale(format!(
                    "EIP-2935 history does not serve L1 reference {number} at snapshot {}",
                    snapshot.l1_block_number
                )));
            }
        }
        Ok(())
    }
}

/// An RPC failure has no authenticated contradiction and can safely be retried.
fn rpc_error(error: impl std::fmt::Display) -> LanderError {
    LanderError::Temporary(format!("public RPC: {error}"))
}

/// Preserve the raw-header adapter's distinction between transport failures and malformed data.
fn anchor_error(error: abci::l1::source::L1Error) -> LanderError {
    use abci::l1::source::L1Error;
    match error {
        L1Error::Rpc(_) | L1Error::BlockNotFound(_) => LanderError::Temporary(error.to_string()),
        _ => LanderError::Safety(error.to_string()),
    }
}

#[cfg(test)]
#[path = "test_utils/runtime_l1.rs"]
pub(crate) mod tests;
