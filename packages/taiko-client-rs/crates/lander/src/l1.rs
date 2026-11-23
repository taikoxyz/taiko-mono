//! Hash-pinned Inbox reads and authentication of the reference's L1 header chain.

use abci::{
    AccountWitness, AnchorState, ChainParams, GenesisRecord, OriginRecord,
    envelope::AnchorWitness,
    fallback::{FallbackKeys, fetch_fallback_keys},
    l1::{
        header::RawL1Header,
        layout::{inbox, word_u48, word_u64},
        mpt::{verify_account_absence, verify_account_witness},
        source::{L1Source as AnchorSource, RpcL1Source},
        witness::{WitnessError, verify_anchor_witness, verify_genesis_inbox},
    },
    staking::{self, StakingWords},
};
use alloy::sol_types::SolCall;
use alloy_consensus::Header;
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::{Provider, RootProvider};
use alloy_rpc_types::TransactionRequest;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, time::Duration};

use crate::{
    contracts::IEtnaInbox,
    error::{LanderError, Result, sanitized_rpc_error},
    types::LandingSnapshot,
};

alloy::sol! {
    /// SignalService's checkpoint read, which authenticates the Unzen checkpoint at S.
    interface ISwitchCheckpointStore {
        /// Unzen's settled execution checkpoint.
        struct Checkpoint {
            /// Settled execution height.
            uint48 blockNumber;
            /// Settled execution hash.
            bytes32 blockHash;
            /// Settled execution state root.
            bytes32 stateRoot;
        }
        /// Read the checkpoint at exactly the requested height.
        function getCheckpoint(uint48 blockNumber) external view returns (Checkpoint memory);
    }
}

/// EIP-2935's block-hash retention window, as enforced by the pinned Inbox.
const REFERENCE_WINDOW: u64 = 8191;
/// EIP-2935 system contract, matching the Inbox's pinned reference-hash resolver.
const HISTORY_STORAGE_ADDRESS: Address =
    alloy_primitives::address!("0000f90827f1c53a10cb7a02335b175320002935");
/// The recent-window branch uses the EVM BLOCKHASH opcode rather than the history contract.
const BLOCKHASH_WINDOW: u64 = 256;
/// Bounds a long-outage reference chain before allocating or issuing its reads.
pub(crate) const MAX_REFERENCE_HEADERS: u64 = 131_072;

/// Whether the reference is older than the pinned Inbox's EIP-2935 window at this L1 block.
/// The caller separately checks that a reference is in the past and its hash is readable.
pub(crate) fn reference_expired(reference: u64, at_block: u64) -> bool {
    at_block.saturating_sub(reference) > REFERENCE_WINDOW
}

/// The oldest L1 block of the reference chain from the tip `tip` down to the oldest of
/// `anchors`, the anchors the batch's blocks use: `Safety` without anchors, `Temporary` while
/// `tip` is below the newest anchor, and `Capacity` for a chain of more than `max_headers`
/// headers. Anchors never regress, so the oldest is the first block's, and no shorter batch from
/// the same checkpoint shortens the chain.
pub(crate) fn reference_floor(anchors: &[AnchorState], tip: u64, max_headers: u64) -> Result<u64> {
    let min = anchors
        .iter()
        .map(|a| a.number)
        .min()
        .ok_or_else(|| LanderError::Safety("reference without anchors".into()))?;
    let max = anchors.iter().map(|a| a.number).max().expect("nonempty anchors");
    if tip < max {
        return Err(LanderError::Temporary(format!(
            "finalized L1 reference {tip} has not reached consumed anchor {max}"
        )));
    }
    if tip - min >= max_headers {
        return Err(LanderError::Capacity(format!(
            "reference chain {} headers exceeds {max_headers}",
            tip - min + 1
        )));
    }
    Ok(min)
}

/// Execution parent plus the timestamp needed by the Etna base-fee rule.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParentContext {
    /// Header authenticated against the Inbox checkpoint.
    pub header: Header,
    /// Timestamp of the parent's parent; zero for genesis.
    pub grandparent_timestamp: u64,
}

/// What the deployment reads establish about the executing Inbox.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Deployment {
    /// The Inbox's `maxBatchBlocks`: the most blocks one landing may cover, above which it reverts
    /// `BatchTooLarge`.
    pub max_batch_blocks: u64,
}

/// Read-only L1/L2 boundary used by batch assembly and transaction reconciliation.
#[async_trait]
pub trait LandingSource: Send + Sync {
    /// Obtain all Inbox facts at one canonical L1 block hash.
    async fn snapshot(&self) -> Result<LandingSnapshot>;
    /// Authenticate the checkpoint's EL parent and its preceding timestamp.
    async fn parent_header(&self, snapshot: &LandingSnapshot) -> Result<ParentContext>;
    /// Retain raw L2 SignalService proxy state at S for the first switching proof; the builder
    /// verifies it.
    async fn start_signal_service_witness(
        &self,
        _snapshot: &LandingSnapshot,
    ) -> Result<Option<AccountWitness>> {
        Ok(None)
    }
    /// Read an untrusted public execution header; the builder verifies checkpoint ancestry.
    async fn execution_header(&self, number: u64) -> Result<Header>;
    /// The anchor of the generation's start o, the parent anchor of o + 1: R after a recovery,
    /// `L1_0` at generation zero, with its anchor slots proven under its own L1 header. o + 1
    /// always carries its own anchor witness, so only its number serves a block rule.
    async fn origin_anchor(&self, snapshot: &LandingSnapshot) -> Result<AnchorState>;
    /// Prove the fixed starting Inbox facts, the start record, configuration hash, slot 282 and
    /// `generation`'s origin record ([`starting_slots`]), under the batch's reference header
    /// `reference`, read pinned to its canonical hash. The builder verifies them with
    /// [`verify_starting_inbox`].
    async fn starting_inbox_witness(
        &self,
        reference: &RawL1Header,
        generation: u64,
    ) -> Result<AnchorWitness>;
    /// The fallback key list whose hash is `hash`, as the Inbox stored it, read at the L1 block
    /// with hash `at` and number `at_number`, the block that stored it or a later one; the log
    /// scan reaches down to `from_block` ([`abci::fallback::fetch_fallback_keys`]). The list
    /// hashes to `hash`. One the L1 cannot give, or a failed read, is
    /// [`LanderError::Temporary`], never `Safety`: the fault is the node's own L1.
    async fn fallback_keys(
        &self,
        hash: B256,
        at: B256,
        at_number: u64,
        from_block: u64,
    ) -> Result<FallbackKeys>;
    /// The `EtnaStaking` proxy's account proof and its storage proofs of `slots` in the
    /// post-state of the L2 block whose hash is `block_hash`, read pinned to that canonical hash
    /// and unverified: [`verify_staking_witness`] checks them under that block's state root. A
    /// read the L2 refuses or fails, such as one of state it has pruned, is
    /// [`LanderError::Temporary`].
    async fn staking_witness(&self, block_hash: B256, slots: &[B256]) -> Result<AccountWitness>;
    /// Fetch the descending raw L1 headers from the reference tip, the finalized block below
    /// the snapshot, down to the oldest consumed anchor, failing as [`reference_floor`] does
    /// with `MAX_REFERENCE_HEADERS`. Fetch only: the caller verifies the links and anchors with
    /// [`crate::batch::verify_reference_chain`] and the tip with [`Self::validate_reference`].
    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>>;
    /// Authenticate V1 initialization and the deployment, whose `configHash()` must be the hash
    /// of the built-in L2 chain id, `EtnaStaking` proxy and U, and read the Inbox's
    /// `maxBatchBlocks`.
    async fn deployment(&self, snapshot: &LandingSnapshot) -> Result<Deployment>;
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

    /// Waits until own finalized L1 proves the snapshot's generation before origin discovery.
    async fn recovery_finality(&self, generation: u64) -> Result<()> {
        let finalized = self.anchors.finalized_number().await.map_err(anchor_error)?;
        let anchor = self.anchor_at(finalized).await?;
        if self.anchors.canonical_hash(finalized).await.map_err(anchor_error)? != anchor.hash {
            return Err(LanderError::Temporary(
                "finalized recovery observation changed; refresh L1 snapshot".into(),
            ));
        }
        match anchor.inbox.recovery_generation.cmp(&generation) {
            std::cmp::Ordering::Less => Err(LanderError::Temporary(format!(
                "recovery generation {generation} is not finalized"
            ))),
            std::cmp::Ordering::Greater => Err(LanderError::Temporary(
                "finalized recovery generation advanced; refresh L1 snapshot".into(),
            )),
            std::cmp::Ordering::Equal => Ok(()),
        }
    }

    /// Override [`HEAD_PROOF_GRACE`], the re-read window for an unverifiable head proof.
    #[cfg(test)]
    pub(crate) fn with_head_proof_grace(mut self, grace: Duration) -> Self {
        self.head_proof_grace = grace;
        self
    }

    /// Whether the head may be re-read after an Inbox proof that does not verify under the head's
    /// own header ([`HEAD_PROOF_GRACE`]). Both proofs of one snapshot share `deadline`, which the
    /// first such observation starts: `true` after a retry pause while it runs, `false` once it has
    /// elapsed. A nonzero grace always permits at least one re-read, even after a slow response.
    async fn reread_within_grace(
        &self,
        deadline: &mut Option<tokio::time::Instant>,
        l1_block: u64,
    ) -> bool {
        let now = tokio::time::Instant::now();
        if now >= *deadline.get_or_insert(now + self.head_proof_grace) {
            return false;
        }
        tracing::warn!(
            l1_block,
            "Inbox proof does not verify under the head's own header; re-reading the head"
        );
        tokio::time::sleep(HEAD_PROOF_RETRY).await;
        true
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
            let l1_chain_id: U256 =
                self.l1.raw_request("eth_chainId".into(), ()).await.map_err(rpc_error)?;
            if l1_chain_id != self.params.l1_chain_id {
                return Err(LanderError::Configuration(format!(
                    "L1 endpoint chain id {l1_chain_id}, configured {}",
                    self.params.l1_chain_id
                )));
            }
            let l2_chain_id: U256 =
                self.l2.raw_request("eth_chainId".into(), ()).await.map_err(rpc_error)?;
            let l2_chain_id: u64 = l2_chain_id.try_into().map_err(|_| {
                LanderError::Configuration(
                    "L2 chain id exceeds the supported uint64 EVM chain range".into(),
                )
            })?;
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
            if unverifiable && self.reread_within_grace(&mut proof_mismatch_deadline, latest).await
            {
                continue;
            }
            let storage = verify_account_witness(raw.state_root(), &witness, &snapshot_slots())
                .map_err(|e| LanderError::Safety(format!("Inbox snapshot proof: {e}")))?;
            let height = word_u48(
                storage.get(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT)).expect("verified slot"),
                0,
            );
            let landing_slots = snapshot_landing_slots(height);
            let witness = self
                .anchors
                .account_witness_hash_canonical(self.params.inbox, &landing_slots, raw.hash())
                .await
                .map_err(anchor_error)?;
            // The second proof can see the same not-yet-stored head state as the first.
            let unverifiable = witness.address == self.params.inbox &&
                verify_account_witness(raw.state_root(), &witness, &landing_slots).is_err();
            if unverifiable && self.reread_within_grace(&mut proof_mismatch_deadline, latest).await
            {
                continue;
            }
            let mut snapshot =
                decode_snapshot(raw, witness, l1_chain_id, l2_chain_id, &self.params)?;
            if snapshot.generation != 0 {
                self.recovery_finality(snapshot.generation).await?;
                let witness = abci::recovery::authenticate_recovery_with_headers(
                    &self.anchors,
                    &self.params,
                    snapshot.generation,
                    |height| async move {
                        self.el_header(height).await.map(Some).map_err(|error| {
                            if error.is_retryable() {
                                abci::recovery::RecoveryError::Unavailable(error.to_string())
                            } else {
                                abci::recovery::RecoveryError::Invalid(error.to_string())
                            }
                        })
                    },
                )
                .await
                .map_err(recovery_error)?;
                snapshot.recovery = Some(
                    abci::recovery::verify_recovery_witness(&witness, &self.params)
                        .map_err(recovery_error)?,
                );
                snapshot.recovery_witness = Some(alloy_rlp::encode(&witness).into());
            }
            authenticate_snapshot(&snapshot, &self.params)?;
            return Ok(snapshot);
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
        if header.number == snapshot.genesis.genesis_height &&
            header.state_root != snapshot.genesis.genesis_state_root
        {
            return Err(LanderError::Safety("EL start state root contradicts Inbox".into()));
        }
        Ok(ParentContext { header, grandparent_timestamp })
    }

    /// Hash-pin the EIP-1186 read to S and retain every MPT node for the external proof backend.
    async fn start_signal_service_witness(
        &self,
        snapshot: &LandingSnapshot,
    ) -> Result<Option<AccountWitness>> {
        let signal_service = abci::l2_signal_service_address(snapshot.l2_chain_id);
        let response = self
            .l2
            .get_proof(signal_service, vec![crate::types::IMPLEMENTATION_SLOT])
            .block_id(BlockId::hash_canonical(snapshot.genesis.genesis_hash))
            .await
            .map_err(rpc_error)?;
        let witness = account_witness(response);
        let parent = self.parent_header(snapshot).await?;
        crate::types::verify_start_signal_service_witness(
            snapshot,
            &parent.header,
            &self.params,
            Some(&witness),
        )?;
        Ok(Some(witness))
    }

    /// Return public EL data for pure checkpoint-bound history authentication.
    async fn execution_header(&self, number: u64) -> Result<Header> {
        self.el_header(number).await
    }

    async fn origin_anchor(&self, snapshot: &LandingSnapshot) -> Result<AnchorState> {
        self.anchor_at(snapshot.recovery.as_ref().map_or(snapshot.genesis.l1_0, |r| r.l1_number))
            .await
    }

    /// One EIP-1186 read of the starting slots at the reference hash, beside the reference's
    /// own raw header.
    async fn starting_inbox_witness(
        &self,
        reference: &RawL1Header,
        generation: u64,
    ) -> Result<AnchorWitness> {
        let inbox = self
            .anchors
            .account_witness_hash_canonical(
                self.params.inbox,
                &starting_slots(generation),
                reference.hash(),
            )
            .await
            .map_err(anchor_error)?;
        Ok(AnchorWitness { l1_header: reference.clone(), inbox })
    }

    /// Runs [`fetch_fallback_keys`] on the own L1 endpoint. Its failures are the node's own L1:
    /// [`LanderError::Temporary`], naming only the hash, as RPC errors can carry endpoint
    /// credentials.
    async fn fallback_keys(
        &self,
        hash: B256,
        at: B256,
        at_number: u64,
        from_block: u64,
    ) -> Result<FallbackKeys> {
        fetch_fallback_keys(&self.anchors, self.params.inbox, hash, at, at_number, from_block)
            .await
            .map_err(|_| LanderError::Temporary(format!("fallback key list {hash} unavailable")))
    }

    /// One EIP-1186 read of the built-in staking proxy on the public L2 endpoint, pinned with
    /// EIP-1898's canonical hash selector.
    async fn staking_witness(&self, block_hash: B256, slots: &[B256]) -> Result<AccountWitness> {
        let response = self
            .l2
            .get_proof(self.params.staking, slots.to_vec())
            .block_id(BlockId::hash_canonical(block_hash))
            .await
            .map_err(rpc_error)?;
        Ok(account_witness(response))
    }

    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>> {
        let tip = self
            .anchors
            .finalized_number()
            .await
            .map_err(anchor_error)?
            .min(snapshot.l1_block_number.saturating_sub(1));
        let min = reference_floor(anchors, tip, MAX_REFERENCE_HEADERS)?;
        let mut headers =
            Vec::with_capacity(usize::try_from(tip - min + 1).expect("bounded header count"));
        for number in (min..=tip).rev() {
            headers.push(self.anchors.header(number).await.map_err(anchor_error)?);
        }
        Ok(headers)
    }

    /// Read the checked V1 getters and `maxBatchBlocks` at one canonical L1 block: five
    /// `eth_call`s and no code read, since no rule pins the implementation. The configuration
    /// hash must open to the built-in L2 chain id, staking proxy and U; an Inbox that commits
    /// another staking proxy or U is another deployment.
    async fn deployment(&self, snapshot: &LandingSnapshot) -> Result<Deployment> {
        authenticate_snapshot(snapshot, &self.params)?;
        macro_rules! read {
            ($call:ident) => {{
                let call = IEtnaInbox::$call {};
                let bytes = self
                    .l1
                    .call(
                        TransactionRequest::default()
                            .to(snapshot.inbox)
                            .input(call.abi_encode().into()),
                    )
                    .block(BlockId::hash_canonical(snapshot.l1_block_hash))
                    .await
                    .map_err(rpc_error)?;
                IEtnaInbox::$call::abi_decode_returns(&bytes)
                    .map_err(|_| LanderError::Configuration("invalid Inbox ABI response".into()))?
            }};
        }
        let version = read!(VERSIONCall);
        let initialized = read!(isInitializedCall);
        let chain = read!(l2ChainIdCall);
        let config = read!(configHashCall);
        if version != 1 ||
            !initialized ||
            chain != snapshot.l2_chain_id ||
            config != self.params.config_hash()
        {
            return Err(LanderError::Configuration(
                "Inbox V1 deployment/configuration mismatch".into(),
            ));
        }
        Ok(Deployment { max_batch_blocks: read!(maxBatchBlocksCall) })
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
        if number >= snapshot.l1_block_number || reference_expired(number, snapshot.l1_block_number)
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

/// On a switching network, checks that the L1 SignalService checkpoint at S, which the Unzen
/// Inbox saved and the start write read, holds S's hash and state root from the Inbox's start
/// record (DATA-5.3-4), read at the snapshot's canonical L1 block. Checkpoint import at s = S
/// needs it; a landing needs no Unzen read, because the permissionless start write `setOrigin`
/// itself requires Unzen proposals closed and finalized at that hash (START-10-5a, LAND-6.1-8a).
/// A failed or reverted read is retryable, a differing checkpoint a safety contradiction.
pub(crate) async fn verify_start_checkpoint<L: AnchorSource + ?Sized>(
    l1: &L,
    params: &ChainParams,
    snapshot: &LandingSnapshot,
) -> Result<()> {
    if params.switch.is_none() {
        return Ok(());
    }
    let bytes = l1
        .call_at(
            snapshot.inbox,
            IEtnaInbox::signalServiceCall {}.abi_encode().into(),
            snapshot.l1_block_hash,
        )
        .await
        .map_err(anchor_error)?;
    let signal = IEtnaInbox::signalServiceCall::abi_decode_returns(&bytes).map_err(|_| {
        LanderError::Configuration("invalid Inbox signalService ABI response".into())
    })?;
    if signal.is_zero() {
        return Err(LanderError::Configuration("Inbox SignalService is zero".into()));
    }
    let call = ISwitchCheckpointStore::getCheckpointCall {
        blockNumber: alloy_primitives::aliases::U48::from(snapshot.genesis.genesis_height),
    };
    let bytes = l1
        .call_at(signal, call.abi_encode().into(), snapshot.l1_block_hash)
        .await
        .map_err(anchor_error)?;
    let checkpoint = ISwitchCheckpointStore::getCheckpointCall::abi_decode_returns(&bytes)
        .map_err(|_| LanderError::Safety("invalid SignalService checkpoint ABI response".into()))?;
    if checkpoint.blockNumber.to::<u64>() != snapshot.genesis.genesis_height ||
        checkpoint.blockHash != snapshot.genesis.genesis_hash ||
        checkpoint.stateRoot != snapshot.genesis.genesis_state_root
    {
        return Err(LanderError::Safety("SignalService checkpoint contradicts the S tuple".into()));
    }
    Ok(())
}

/// Complete fixed Inbox slots authenticating the start, configuration, generation 0's origin
/// record, checkpoint and the forced inclusion queue's head/tail and configuration.
pub fn snapshot_slots() -> Vec<B256> {
    let mut slots = inbox::genesis_slots();
    slots.extend(inbox::anchor_slots());
    slots.sort_unstable();
    slots.dedup();
    slots
}

/// The fixed starting Inbox slots a batch proves under its reference header: the genesis slots
/// (the start record, configuration hash and slot 282, with generation 0's origin record) and
/// `generation`'s four-word origin record (slot 290), which every proof authenticates. They hold
/// no anchor slot: each block's anchor witness proves those under the block's own anchor.
pub fn starting_slots(generation: u64) -> Vec<B256> {
    let mut slots = inbox::genesis_slots();
    slots.extend(inbox::origin_slots(generation));
    slots.sort_unstable();
    slots.dedup();
    slots
}

/// Fixed Inbox facts plus the exact retained landing record at the supplied checkpoint.
pub fn snapshot_landing_slots(height: u64) -> Vec<B256> {
    let mut slots = snapshot_slots();
    slots.extend(inbox::landing_record_slots(height));
    slots.sort_unstable();
    slots.dedup();
    slots
}

/// Decode all snapshot fields from an address-bound proof under the exact raw canonical header.
pub(crate) fn decode_snapshot(
    raw: RawL1Header,
    witness: AccountWitness,
    l1_chain_id: U256,
    l2_chain_id: u64,
    params: &ChainParams,
) -> Result<LandingSnapshot> {
    if witness.address != params.inbox {
        return Err(LanderError::Safety("snapshot proof names another Inbox".into()));
    }
    let height = witness
        .storage
        .iter()
        .find(|proof| proof.slot == inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT))
        .map(|proof| word_u48(proof.value, 0))
        .ok_or_else(|| LanderError::Safety("snapshot checkpoint slot missing".into()))?;
    let storage =
        verify_account_witness(raw.state_root(), &witness, &snapshot_landing_slots(height))
            .map_err(|e| LanderError::Safety(format!("Inbox snapshot proof: {e}")))?;
    let word = |slot| storage.get(inbox::slot(slot)).expect("verified snapshot slot");
    let (genesis, _, _) = verify_genesis_inbox(
        raw.state_root(),
        &project_witness(&witness, &inbox::genesis_slots()),
        params.inbox,
    )
    .map_err(|e| match e {
        WitnessError::Mpt(_) |
        WitnessError::WrongContract { .. } |
        WitnessError::ReservedBits { .. } |
        WitnessError::InvalidOrigin => {
            LanderError::Safety(format!("snapshot genesis/origin proof: {e}"))
        }
        _ => LanderError::Configuration(format!("Inbox genesis record is invalid: {e}")),
    })?;
    if genesis.config_hash != params.config_hash() {
        return Err(LanderError::Configuration(
            "Inbox configuration hash differs from the built-in chain id, staking proxy and U"
                .into(),
        ));
    }
    if genesis.genesis_state_root.is_zero() {
        return Err(LanderError::Configuration("Inbox genesis record is invalid".into()));
    }
    if genesis.genesis_height != 0 && params.switch.is_none() {
        return Err(LanderError::Configuration(
            "nonzero Etna start requires switch configuration".into(),
        ));
    }
    if word(inbox::LAST_CHECKPOINT_HEIGHT) >> 48 != U256::ZERO {
        return Err(LanderError::Safety(
            "snapshot packed checkpoint height sets reserved bits".into(),
        ));
    }
    let head_tail = word(inbox::FORCED_INCLUSION_HEAD_TAIL);
    let generation = word_u48(word(inbox::RECOVERY_GENERATION), 0);
    // The three-word slot 285 record (STOR-B-9). A landing may end at any height (LAND-6.1-5),
    // so the checkpoint and its actual parent are bounded only by the Etna start.
    let record = inbox::LandingRecord::decode(
        inbox::landing_record_slots(height)
            .map(|slot| storage.get(slot).expect("verified landing slot")),
    )
    .filter(|record| {
        head_tail >> 96 == U256::ZERO &&
            height >= genesis.genesis_height &&
            record.el_hash == B256::from(word(inbox::LAST_CHECKPOINT_HASH)) &&
            record.generation <= generation &&
            record.forced_head == word_u48(head_tail, 0) &&
            if height == genesis.genesis_height {
                record.parent_height == height &&
                    record.generation == 0 &&
                    record.forced_head == 0 &&
                    record.el_hash == genesis.genesis_hash &&
                    record.comet_hash.is_zero()
            } else {
                genesis.genesis_height <= record.parent_height &&
                    record.parent_height < height &&
                    !record.comet_hash.is_zero()
            }
    })
    .ok_or_else(|| LanderError::Safety("invalid checkpoint landing record".into()))?;
    Ok(LandingSnapshot {
        l1_block_hash: raw.hash(),
        l1_block_number: raw.number(),
        l1_chain_id,
        l2_chain_id,
        inbox: params.inbox,
        recovery: None,
        recovery_witness: None,
        generation: word_u64(word(inbox::RECOVERY_GENERATION), 0),
        checkpoint_height: word_u64(word(inbox::LAST_CHECKPOINT_HEIGHT), 0),
        checkpoint_hash: word(inbox::LAST_CHECKPOINT_HASH).into(),
        checkpoint_comet_hash: record.comet_hash,
        forced_inclusion_head: word_u48(head_tail, 0),
        forced_inclusion_tail: word_u48(head_tail, 48),
        config_hash: genesis.config_hash,
        genesis,
        l1_header: raw,
        inbox_witness: witness,
    })
}

/// Verifies `witness`, the starting Inbox proof of a batch of the recovery generation
/// `generation`, under the batch's reference header `reference`, the newest header of its
/// reference chain, and returns the genesis record and `generation`'s origin record it proves.
///
/// The witness must carry `reference` as its header and prove the configured Inbox's exact
/// [`starting_slots`] under that header's state root, whose genesis slots must pass
/// [`verify_genesis_inbox`], and the reference must be in `generation`. These words never change
/// once written, so the reference proves the values every later block reads, under a root the
/// reference chain authenticates. A proof that does not verify is `Safety`.
pub fn verify_starting_inbox(
    witness: &AnchorWitness,
    reference: &RawL1Header,
    generation: u64,
    inbox_address: Address,
) -> Result<(GenesisRecord, OriginRecord)> {
    if witness.l1_header.hash() != reference.hash() {
        return Err(LanderError::Safety("starting proof is not under the reference header".into()));
    }
    if witness.inbox.address != inbox_address {
        return Err(LanderError::Safety("starting proof names another Inbox".into()));
    }
    let root = reference.state_root();
    let storage = verify_account_witness(root, &witness.inbox, &starting_slots(generation))
        .map_err(|e| LanderError::Safety(format!("starting Inbox proof: {e}")))?;
    let genesis_proof = project_witness(&witness.inbox, &inbox::genesis_slots());
    let (genesis, facts, _) = verify_genesis_inbox(root, &genesis_proof, inbox_address)
        .map_err(|e| LanderError::Safety(format!("starting genesis proof: {e}")))?;
    if facts.recovery_generation != generation {
        return Err(LanderError::Safety(format!(
            "the reference header is in generation {}, not {generation}",
            facts.recovery_generation
        )));
    }
    let origin = inbox::decode_origin_record(
        inbox::origin_slots(generation)
            .map(|slot| storage.get(slot).expect("verified starting slot")),
    )
    .ok_or_else(|| {
        LanderError::Safety(format!("generation {generation}'s origin record sets reserved bits"))
    })?;
    Ok((genesis, origin))
}

/// Verifies `witness`, the anchor witness of a batch's checkpoint p above its generation's start,
/// against p's EL header `header`, and returns the anchor it proves.
///
/// The witness must verify under its own L1 header ([`verify_anchor_witness`]) and prove
/// `generation`; `header`'s extraData must name `generation` and that L1 header's number as its
/// anchor, and its `parentBeaconBlockRoot` must be that header's state root. p's EL header, whose
/// hash the checkpoint's slot 285 record holds, so authenticates the root under which p's anchor
/// proves its `minTotalStake` and `fallbackKeysHash`, with no L1 ancestry. Every failure is
/// `Safety`.
pub fn verify_checkpoint_anchor(
    witness: &AnchorWitness,
    header: &Header,
    generation: u64,
    inbox_address: Address,
) -> Result<AnchorState> {
    // The decoder refuses a fee-sharing byte other than 100; the generation and anchor fields
    // are checked here.
    let extra = abci::rules::decode_extra_data(&header.extra_data)
        .map_err(|_| LanderError::Safety("EL checkpoint has invalid Etna extraData".into()))?;
    if extra.generation != generation {
        return Err(LanderError::Safety(
            "checkpoint execution header belongs to another generation".into(),
        ));
    }
    let anchor = verify_anchor_witness(witness, inbox_address)
        .map_err(|e| LanderError::Safety(format!("checkpoint anchor witness: {e}")))?;
    if anchor.number != extra.anchor {
        return Err(LanderError::Safety(format!(
            "checkpoint anchor witness proves L1 {}, but the checkpoint's extraData names L1 {}",
            anchor.number, extra.anchor
        )));
    }
    if header.parent_beacon_block_root != Some(anchor.state_root) {
        return Err(LanderError::Safety(
            "checkpoint anchor witness root differs from the checkpoint's parentBeaconBlockRoot"
                .into(),
        ));
    }
    if anchor.inbox.recovery_generation != generation {
        return Err(LanderError::Safety("checkpoint anchor proves another generation".into()));
    }
    Ok(anchor)
}

/// The current generation's origin record as the snapshot authenticates it: a recovery
/// generation's authenticated origin, or generation 0's record from the snapshot's own genesis
/// proof under its header.
pub fn snapshot_origin(snapshot: &LandingSnapshot) -> Result<OriginRecord> {
    match &snapshot.recovery {
        Some(origin) => Ok(OriginRecord {
            start_height: origin.height,
            l1_number: origin.l1_number,
            l1_timestamp: origin.l1_timestamp,
            fallback_keys_hash: origin.fallback_keys_hash,
        }),
        None if snapshot.generation == 0 => {
            let root = snapshot.l1_header.state_root();
            let slots = snapshot_landing_slots(snapshot.checkpoint_height);
            verify_account_witness(root, &snapshot.inbox_witness, &slots)
                .map_err(|e| LanderError::Safety(format!("Inbox snapshot proof: {e}")))?;
            let genesis_proof = project_witness(&snapshot.inbox_witness, &inbox::genesis_slots());
            let (_, _, origin) = verify_genesis_inbox(root, &genesis_proof, snapshot.inbox)
                .map_err(|e| LanderError::Safety(format!("snapshot genesis proof: {e}")))?;
            Ok(origin)
        }
        None => Err(LanderError::Safety(
            "generation requires matching recovery origin and evidence".into(),
        )),
    }
}

/// The slots of one staking read at an L2 height: the candidate snapshot's words in
/// [`staking::snapshot_slots`] order, then the live key-to-seat word of each address of
/// `missing`, in its order.
pub fn staking_slots(missing: &[Address]) -> Vec<B256> {
    staking::snapshot_slots()
        .into_iter()
        .chain(missing.iter().map(|address| staking::key_to_seat_slot(*address)))
        .collect()
}

/// Verifies `witness`, the staking proxy `staking`'s proofs at [`staking_slots`]`(missing)` in
/// the post-state of L2 block `height`, under that block's state root `state_root`, and returns
/// the candidate snapshot it proves and the live key-to-seat word of each address of `missing`.
///
/// Every word is returned whole, never masked: the caller decides with them
/// ([`abci::committee::decide`], [`staking::decode_seat`]). An address without an account holds
/// no storage, as one without code holds no snapshot: when the account proof is a complete
/// exclusion proof under the root, every word is zero, so the snapshot is not the height's own and
/// the fallback keys sign. The witness must then claim the requested slots with zero values, as
/// `eth_getProof` answers for an absent account. A witness that names another account or another
/// slot list, claims a word the proofs do not give, or whose account or storage proofs do not
/// verify, is [`LanderError::Safety`]: the caller authenticated the root.
pub fn verify_staking_witness(
    state_root: B256,
    staking: Address,
    witness: &AccountWitness,
    height: u64,
    missing: &[Address],
) -> Result<(StakingWords, BTreeMap<Address, U256>)> {
    if witness.address != staking {
        return Err(LanderError::Safety(format!(
            "staking proof at L2 {height} names {}, not the staking proxy {staking}",
            witness.address
        )));
    }
    let slots = staking_slots(missing);
    let storage = if verify_account_absence(state_root, staking, &witness.account_proof).is_ok() {
        if !witness.storage.iter().map(|proof| proof.slot).eq(slots.iter().copied()) ||
            witness.storage.iter().any(|proof| !proof.value.is_zero())
        {
            return Err(LanderError::Safety(format!(
                "staking proof at L2 {height} proves no staking account but claims other slots \
                 or nonzero words"
            )));
        }
        None
    } else {
        Some(
            verify_account_witness(state_root, witness, &slots)
                .map_err(|e| LanderError::Safety(format!("staking proof at L2 {height}: {e}")))?,
        )
    };
    let word = |slot| storage.as_ref().map_or(U256::ZERO, |s| s.get(slot).expect("verified slot"));
    let words = StakingWords::from_snapshot_values(&staking::snapshot_slots().map(word))
        .expect("every snapshot slot");
    let seats = missing
        .iter()
        .map(|address| (*address, word(staking::key_to_seat_slot(*address))))
        .collect();
    Ok((words, seats))
}

/// The fallback key list whose hash is `hash`, read from `l1` at the block with hash `at` and
/// number `at_number`, the block that stored it or a later one ([`LandingSource::fallback_keys`],
/// whose log scan reaches block 0). A list the L1 cannot give is [`LanderError::Temporary`]; one
/// that hashes elsewhere is refused as `Safety`.
pub async fn obtain_fallback_list<L: LandingSource + ?Sized>(
    l1: &L,
    hash: B256,
    at: B256,
    at_number: u64,
) -> Result<FallbackKeys> {
    let keys = l1.fallback_keys(hash, at, at_number, 0).await?;
    if keys.hash() != hash {
        return Err(LanderError::Safety(format!(
            "L1 source answered the fallback key list {hash} with {}",
            keys.hash()
        )));
    }
    Ok(keys)
}

/// The fallback key lists the signing-set decisions of a batch from the proof origin `p` fall
/// back to, by hash: `anchors[i]` is the anchor of height `p + i`, for the heights whose
/// decisions the batch checks, each proving the `fallbackKeysHash` of the list its decision falls
/// back to.
///
/// A list `known` holds is reused; each other distinct hash is obtained once, at the first anchor
/// proving it ([`obtain_fallback_list`]), and added to `known`. The generation's start height
/// `origin` decides nothing, as the origin record's list signs its next two blocks, so its
/// anchor's words are never read.
pub async fn anchor_fallback_lists<L: LandingSource + ?Sized>(
    l1: &L,
    origin: u64,
    p: u64,
    anchors: &[AnchorState],
    known: &mut BTreeMap<B256, FallbackKeys>,
) -> Result<BTreeMap<B256, FallbackKeys>> {
    let mut lists = BTreeMap::new();
    for (height, anchor) in (p..).zip(anchors) {
        let hash = anchor.inbox.fallback_keys_hash;
        if height <= origin || lists.contains_key(&hash) {
            continue;
        }
        let keys = match known.get(&hash) {
            Some(keys) => keys.clone(),
            None => {
                let keys = obtain_fallback_list(l1, hash, anchor.hash, anchor.number).await?;
                known.insert(hash, keys.clone());
                keys
            }
        };
        lists.insert(hash, keys);
    }
    Ok(lists)
}

/// Converts an EIP-1186 response into the witness the MPT verifier checks, keeping every node.
fn account_witness(response: alloy_rpc_types::EIP1186AccountProofResponse) -> AccountWitness {
    AccountWitness {
        address: response.address,
        nonce: response.nonce,
        balance: response.balance,
        storage_root: response.storage_hash,
        code_hash: response.code_hash,
        account_proof: response.account_proof,
        storage: response
            .storage_proof
            .into_iter()
            .map(|proof| abci::StorageProof {
                slot: proof.key.as_b256(),
                value: proof.value,
                proof: proof.proof,
            })
            .collect(),
    }
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
    let mut verified = decode_snapshot(
        snapshot.l1_header.clone(),
        snapshot.inbox_witness.clone(),
        snapshot.l1_chain_id,
        snapshot.l2_chain_id,
        params,
    )?;
    match (&snapshot.recovery, &snapshot.recovery_witness) {
        (None, None) if snapshot.generation == 0 => {}
        (Some(origin), Some(bytes)) if snapshot.generation != 0 => {
            use alloy_rlp::Decodable;
            let mut remaining = bytes.as_ref();
            let witness = abci::recovery::RecoveryWitness::decode(&mut remaining)
                .map_err(|e| LanderError::Safety(format!("recovery evidence: {e}")))?;
            if !remaining.is_empty() || alloy_rlp::encode(&witness).as_slice() != bytes.as_ref() {
                return Err(LanderError::Safety("noncanonical recovery evidence".into()));
            }
            let (authenticated, genesis) =
                abci::recovery::verify_recovery_deployment(&witness, params)
                    .map_err(recovery_error)?;
            if genesis != snapshot.genesis ||
                &authenticated != origin ||
                origin.generation != snapshot.generation ||
                origin.height > snapshot.checkpoint_height ||
                origin.l1_number > snapshot.l1_block_number ||
                (origin.height == snapshot.checkpoint_height &&
                    (origin.el_hash != snapshot.checkpoint_hash ||
                        origin.comet_hash != snapshot.checkpoint_comet_hash ||
                        origin.forced_cursor != snapshot.forced_inclusion_head))
            {
                return Err(LanderError::Safety(
                    "snapshot contradicts authenticated recovery origin".into(),
                ));
            }
            verified.recovery = Some(authenticated);
            verified.recovery_witness = Some(bytes.clone());
        }
        _ => {
            return Err(LanderError::Safety(
                "generation requires matching recovery origin and evidence".into(),
            ))
        }
    }
    if snapshot.checkpoint_height > snapshot.origin_height() || snapshot.generation == 0 {
        let packed = snapshot
            .inbox_witness
            .storage
            .iter()
            .find(|p| p.slot == inbox::landing_record_slots(verified.checkpoint_height)[0])
            .expect("decoded landing slot")
            .value;
        if word_u48(packed, 48) != snapshot.generation {
            return Err(LanderError::Safety(
                "checkpoint landing belongs to another generation".into(),
            ));
        }
    }
    if verified != *snapshot {
        return Err(LanderError::Safety(
            "snapshot fields contradict authenticated Inbox storage".into(),
        ));
    }
    Ok(())
}

/// Preserves recovery acquisition failures as retryable without trusting unauthenticated hints.
/// An EL that has not yet taken the settled block at c is such a failure too.
fn recovery_error(error: abci::recovery::RecoveryError) -> LanderError {
    match error {
        abci::recovery::RecoveryError::Unavailable(_) |
        abci::recovery::RecoveryError::OriginNotHeld { .. } => {
            LanderError::Temporary("recovery evidence unavailable from L1 or EL".into())
        }
        abci::recovery::RecoveryError::ConfigMismatch { .. } => {
            LanderError::Configuration(error.to_string())
        }
        _ => LanderError::Safety(error.to_string()),
    }
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
