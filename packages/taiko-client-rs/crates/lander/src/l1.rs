//! Hash-pinned Inbox reads and authentication of the reference's L1 header chain.

use abci::{
    AccountWitness, AnchorState, ChainParams, CommitteeWitness, GenesisRecord, Schedule,
    envelope::AnchorWitness,
    l1::{
        fetch::build_committee_witness_at_cutoff,
        header::RawL1Header,
        layout::{inbox, word_u48, word_u64},
        mpt::verify_account_witness,
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
use std::time::Duration;

use crate::{
    contracts::IEtnaInbox::{LandInput, hashLandStatementCall},
    error::{LanderError, Result, sanitized_rpc_error},
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
    /// Read an untrusted public execution header; the builder verifies checkpoint ancestry.
    async fn execution_header(&self, number: u64) -> Result<Header>;
    /// Recover the exact historical anchor consumed by the checkpoint parent.
    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        parent: &ParentContext,
    ) -> Result<AnchorState>;
    /// Prove genesis/config/bootstrap and all consumed Inbox anchor facts under the parent root.
    async fn starting_inbox_witness(&self, anchor: &AnchorState) -> Result<AnchorWitness>;
    /// Discover a registry witness under the given authenticated anchor, never a committee hint.
    async fn committee_witness(
        &self,
        snapshot: &LandingSnapshot,
        anchor: &AnchorState,
        snapshot_number: u64,
        epoch: u64,
    ) -> Result<CommitteeWitness>;
    /// Authenticate all consumed anchors along a descending finalized reference chain.
    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>>;
    /// Ask the executing Inbox proxy to hash the identical public V10 statement.
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
    /// How long a head whose Inbox proof fails under its own header is re-read.
    head_proof_grace: Duration,
}

impl RpcLandingSource {
    /// Wrap public providers whose HTTP deadlines are configured by the caller.
    pub fn new(l1: RootProvider, l2: RootProvider, params: ChainParams) -> Self {
        Self {
            anchors: RpcL1Source::new(l1.clone()),
            l1,
            l2,
            params,
            head_proof_grace: HEAD_PROOF_GRACE,
        }
    }

    /// Override [`HEAD_PROOF_GRACE`], the re-read window for an unverifiable head proof.
    pub fn with_head_proof_grace(mut self, grace: Duration) -> Self {
        self.head_proof_grace = grace;
        self
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
            .account_witness(self.params.inbox, &inbox::anchor_slots(), number)
            .await
            .map_err(anchor_error)?;
        verify_anchor_witness(&AnchorWitness { l1_header, inbox: witness }, self.params.inbox)
            .map_err(|e| LanderError::Safety(format!("parent anchor {number}: {e}")))
    }
}

/// How long to re-read the head after first observing an Inbox proof that does not verify under
/// its header. Initial RPC latency cannot consume the grace before inconsistency is observed.
///
/// An endpoint can answer the head's proofs from state the next block is still extending: anvil
/// stores block `n`'s state only when it starts mining `n + 1`, so a transaction being mined
/// leaks into `n`'s proofs until `n + 1` appears. The lander acts on no unverified data, so
/// re-reading only delays the safety stop for an endpoint that stays inconsistent.
pub const HEAD_PROOF_GRACE: Duration = Duration::from_secs(5);
/// Pause between head re-reads within the grace.
const HEAD_PROOF_RETRY: Duration = Duration::from_millis(100);

#[async_trait]
impl LandingSource for RpcLandingSource {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        let mut proof_mismatch_deadline = None;
        loop {
            let latest = self.l1.get_block_number().await.map_err(rpc_error)?;
            let raw = self.anchors.header_hash_pinned(latest).await.map_err(anchor_error)?;
            let l1_chain_id = U256::from(self.l1.get_chain_id().await.map_err(rpc_error)?);
            let l2_chain_id = self.l2.get_chain_id().await.map_err(rpc_error)?;
            if l2_chain_id != self.params.l2_chain_id {
                return Err(LanderError::Configuration(format!(
                    "L2 endpoint chain id {l2_chain_id}, configured {}",
                    self.params.l2_chain_id
                )));
            }
            let witness = self
                .anchors
                .account_witness_hash_canonical(self.params.inbox, &snapshot_slots(), raw.hash())
                .await
                .map_err(anchor_error)?;
            let unverifiable = witness.address == self.params.inbox &&
                verify_account_witness(raw.state_root(), &witness, &snapshot_slots()).is_err();
            if unverifiable {
                let now = tokio::time::Instant::now();
                // Preserve the first suspicion's deadline across every head re-read. A nonzero
                // grace always permits at least one re-read, even if the first response was slow.
                let deadline = *proof_mismatch_deadline.get_or_insert(now + self.head_proof_grace);
                if now < deadline {
                    tracing::warn!(
                        l1_block = latest,
                        "Inbox proof does not verify under the head's own header; re-reading the head"
                    );
                    tokio::time::sleep(HEAD_PROOF_RETRY).await;
                    continue;
                }
            }
            return decode_snapshot(raw, witness, l1_chain_id, l2_chain_id, &self.params);
        }
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

    /// Return public EL data for pure checkpoint-bound history authentication.
    async fn execution_header(&self, number: u64) -> Result<Header> {
        self.el_header(number).await
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
            if bytes.len() != 13 || bytes[0] != abci::rules::BASEFEE_SHARING_PCTG {
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

    /// Retain every fixed starting Inbox slot and its raw header in the reference ancestry.
    async fn starting_inbox_witness(&self, anchor: &AnchorState) -> Result<AnchorWitness> {
        let l1_header = self.anchors.header(anchor.number).await.map_err(anchor_error)?;
        let inbox = self
            .anchors
            .account_witness(self.params.inbox, &snapshot_slots(), anchor.number)
            .await
            .map_err(anchor_error)?;
        Ok(AnchorWitness { l1_header, inbox })
    }

    /// Historical discovery remains untrusted until the builder verifies its root and record.
    async fn committee_witness(
        &self,
        snapshot: &LandingSnapshot,
        anchor: &AnchorState,
        snapshot_number: u64,
        epoch: u64,
    ) -> Result<CommitteeWitness> {
        build_committee_witness_at_cutoff(
            &self.anchors,
            &self.params,
            &Schedule::from_genesis(&snapshot.genesis),
            anchor.number,
            snapshot_number,
            epoch,
        )
        .await
        .map_err(|error| match error {
            abci::l1::FetchError::L1(abci::l1::source::L1Error::Rpc(_)) => {
                LanderError::Temporary("committee discovery: L1 RPC failure".into())
            }
            error => LanderError::Temporary(format!("committee discovery: {error}")),
        })
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
            _forcedInclusionHeadBefore: snapshot.forced_inclusion_head_u48()?,
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

/// Complete fixed Inbox slots authenticating schedule, configuration, bootstrap, checkpoint and
/// the forced inclusion queue's head/tail and configuration.
pub fn snapshot_slots() -> Vec<B256> {
    let mut slots = inbox::genesis_slots();
    slots.extend(inbox::anchor_slots());
    slots.sort_unstable();
    slots.dedup();
    slots
}

/// Decode all snapshot fields from an address-bound proof under the exact raw canonical header.
fn decode_snapshot(
    raw: RawL1Header,
    witness: AccountWitness,
    l1_chain_id: U256,
    l2_chain_id: u64,
    params: &ChainParams,
) -> Result<LandingSnapshot> {
    if witness.address != params.inbox {
        return Err(LanderError::Safety("snapshot proof names another Inbox".into()));
    }
    let storage = verify_account_witness(raw.state_root(), &witness, &snapshot_slots())
        .map_err(|e| LanderError::Safety(format!("Inbox snapshot proof: {e}")))?;
    let word = |slot| storage.get(inbox::slot(slot)).expect("verified snapshot slot");
    if word(inbox::STATUS) != U256::from(inbox::ETNA_ACTIVE) {
        return Err(LanderError::Configuration("Inbox is not active".into()));
    }
    let config: B256 = word(inbox::COMMITTEE_CONFIG_HASH).into();
    if config != abci::committee::committee_config_hash(params) || config.is_zero() {
        return Err(LanderError::Configuration("Inbox committee config opening mismatch".into()));
    }
    let packed = word(inbox::GENESIS_PACKED);
    let forced_config = word(inbox::FORCED_INCLUSION_CONFIG);
    let genesis = GenesisRecord {
        committee_config_hash: config,
        genesis_height: word_u64(packed, 0),
        l1_0: word_u64(packed, 64),
        epoch_len: word_u64(packed, 128),
        epoch_len_l1: word_u64(packed, 192),
        genesis_hash: word(inbox::GENESIS_BLOCK_HASH).into(),
        genesis_state_root: word(inbox::GENESIS_STATE_ROOT).into(),
        genesis_cutoff: word_u64(word(inbox::GENESIS_CUTOFF), 0),
        forced_inclusion_delay: word_u64(forced_config, 0),
        max_anchor_age: word_u64(forced_config, 64),
    };
    let bootstrap: B256 = word(inbox::GENESIS_COMMITTEE_HASH).into();
    if genesis.genesis_height != 0 ||
        genesis.genesis_hash.is_zero() ||
        genesis.genesis_state_root.is_zero() ||
        genesis.genesis_cutoff >= genesis.l1_0 ||
        genesis.forced_inclusion_delay == 0 ||
        genesis.max_anchor_age < 1152 ||
        bootstrap.is_zero()
    {
        return Err(LanderError::Configuration("Inbox genesis record is invalid".into()));
    }
    Schedule::from_genesis(&genesis)
        .validate(params.unsettled_cap())
        .map_err(|e| LanderError::Configuration(format!("Inbox epoch parameters: {e}")))?;
    let head_tail = word(inbox::FORCED_INCLUSION_HEAD_TAIL);
    Ok(LandingSnapshot {
        l1_block_hash: raw.hash(),
        l1_block_number: raw.number(),
        l1_chain_id,
        l2_chain_id,
        inbox: params.inbox,
        registry: params.registry,
        generation: word_u64(word(inbox::RECOVERY_GENERATION), 0),
        checkpoint_height: word_u64(word(inbox::LAST_CHECKPOINT_HEIGHT), 0),
        checkpoint_hash: word(inbox::LAST_CHECKPOINT_HASH).into(),
        forced_inclusion_head: word_u48(head_tail, 0),
        forced_inclusion_tail: word_u48(head_tail, 48),
        genesis,
        committee_config_hash: config,
        genesis_committee_record_hash: bootstrap,
        l1_header: raw,
        inbox_witness: witness,
    })
}

/// Authenticate the complete starting Inbox proof, then project exact existing verifier slot sets.
///
/// The full proof must include checkpoint facts as well as genesis/config/bootstrap. Its raw
/// header and decoded anchor facts must equal the consumed parent anchor; no latest snapshot can
/// substitute for this ancestor. Projection preserves the strict slot-set checks of both verifiers.
pub fn verify_starting_inbox(
    witness: &AnchorWitness,
    anchor: &AnchorState,
    inbox_address: Address,
) -> Result<(GenesisRecord, B256)> {
    if witness.inbox.address != inbox_address {
        return Err(LanderError::Safety("starting proof names another Inbox".into()));
    }
    verify_account_witness(anchor.state_root, &witness.inbox, &snapshot_slots())
        .map_err(|e| LanderError::Safety(format!("starting Inbox proof: {e}")))?;
    let genesis_proof = project_witness(&witness.inbox, &inbox::genesis_slots());
    let (genesis, _, bootstrap) =
        abci::l1::witness::verify_genesis_inbox(anchor.state_root, &genesis_proof, inbox_address)
            .map_err(|e| LanderError::Safety(format!("starting genesis proof: {e}")))?;
    let anchor_proof = AnchorWitness {
        l1_header: witness.l1_header.clone(),
        inbox: project_witness(&witness.inbox, &inbox::anchor_slots()),
    };
    let verified = verify_anchor_witness(&anchor_proof, inbox_address)
        .map_err(|e| LanderError::Safety(format!("starting anchor proof: {e}")))?;
    if verified != *anchor {
        return Err(LanderError::Safety("starting proof contradicts consumed parent anchor".into()));
    }
    Ok((genesis, bootstrap))
}

/// Project a previously authenticated complete proof in exactly the verifier's required order.
fn project_witness(witness: &AccountWitness, slots: &[B256]) -> AccountWitness {
    let mut projected = witness.clone();
    projected.storage = slots
        .iter()
        .map(|slot| {
            witness
                .storage
                .iter()
                .find(|proof| proof.slot == *slot)
                .expect("full slot set was verified")
                .clone()
        })
        .collect();
    projected
}

/// Recompute the snapshot from its proof so no schedule/configuration field is an unchecked hint.
pub fn authenticate_snapshot(snapshot: &LandingSnapshot, params: &ChainParams) -> Result<()> {
    let verified = decode_snapshot(
        snapshot.l1_header.clone(),
        snapshot.inbox_witness.clone(),
        snapshot.l1_chain_id,
        snapshot.l2_chain_id,
        params,
    )?;
    if verified != *snapshot {
        return Err(LanderError::Safety(
            "snapshot fields contradict authenticated Inbox storage".into(),
        ));
    }
    Ok(())
}

/// An RPC failure has no authenticated contradiction and can safely be retried.
fn rpc_error(error: alloy::transports::TransportError) -> LanderError {
    sanitized_rpc_error("public RPC", error)
}

/// Preserve the raw-header adapter's distinction between transport failures and malformed data.
fn anchor_error(error: abci::l1::source::L1Error) -> LanderError {
    use abci::l1::source::L1Error;
    match error {
        L1Error::Rpc(_) => LanderError::Temporary("L1 RPC failure".into()),
        L1Error::BlockNotFound(_) => LanderError::Temporary(error.to_string()),
        _ => LanderError::Safety(error.to_string()),
    }
}

#[cfg(test)]
#[path = "test_utils/runtime_l1.rs"]
pub(crate) mod tests;
