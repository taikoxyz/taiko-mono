//! Consecutive, authenticated batch assembly and immutable proof-job construction.

use std::{collections::BTreeMap, sync::Arc};

use abci::{AnchorState, ChainParams, ParentInfo, Schedule, committee::record_hash, rules};
use async_trait::async_trait;

use crate::{
    blob, codec,
    comet::CometSource,
    committee::{AuthenticatedCommittee, authenticate},
    contracts::IEtnaInbox::{CommitteeRecord, LandInput},
    error::{LanderError, Result},
    l1::{LandingSource, ParentContext},
    proof::ProofRequest,
    statement,
    types::{CertifiedBlock, LandingSnapshot, Limits, PreparedBatch, SidecarMode},
    validate::{EnvelopeContext, verify_body, verify_commit, verify_envelope, verify_structure},
};

/// Boundary used by the runner to prepare jobs and authenticate competing checkpoint progress.
#[async_trait]
pub trait BatchSource: Send + Sync {
    /// Build the largest complete publishable prefix above this coherent checkpoint.
    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>>;
    /// Ensure the current L1 checkpoint identifies this node's certified execution chain.
    async fn validate_checkpoint(&self, snapshot: &LandingSnapshot) -> Result<()>;
}

/// Collector-backed builder; no proof computation or transaction mutation occurs here.
pub struct BatchBuilder<C: ?Sized, L: ?Sized> {
    /// Read-only CometBFT block/certificate and committee hints.
    comet: Arc<C>,
    /// Coherent L1 reads and public L2 checkpoint headers.
    l1: Arc<L>,
    /// Shared Etna constants; the existing ABCI helpers enforce them.
    params: ChainParams,
    /// Explicit codec, complete-block and transaction blob bounds.
    limits: Limits,
    /// Operator-selected target L1 sidecar representation.
    mode: SidecarMode,
}

impl<C: CometSource + ?Sized, L: LandingSource + ?Sized> BatchBuilder<C, L> {
    /// Create a builder after validating operator and consensus limits.
    pub fn new(
        comet: Arc<C>,
        l1: Arc<L>,
        params: ChainParams,
        limits: Limits,
        mode: SidecarMode,
    ) -> Result<Self> {
        params.validate().map_err(|e| LanderError::Configuration(e.to_string()))?;
        limits.validate()?;
        Ok(Self { comet, l1, params, limits, mode })
    }

    /// Ensure one coherent Inbox context matches the configured chain and genesis schedule.
    fn schedule(&self, snapshot: &LandingSnapshot) -> Result<Schedule> {
        if snapshot.l2_chain_id != self.params.l2_chain_id ||
            snapshot.inbox != self.params.inbox ||
            snapshot.registry != self.params.registry ||
            snapshot.genesis.genesis_height != 0 ||
            snapshot.genesis.genesis_cutoff >= snapshot.genesis.l1_0 ||
            snapshot.genesis.genesis_hash.is_zero() ||
            snapshot.genesis.genesis_state_root.is_zero() ||
            snapshot.start_committee_record_hash.is_zero() ||
            snapshot.checkpoint_hash.is_zero()
        {
            return Err(LanderError::Configuration(
                "landing snapshot identity/genesis contradicts chain parameters".into(),
            ));
        }
        let schedule = Schedule::from_genesis(&snapshot.genesis);
        schedule
            .validate(self.params.unsettled_cap())
            .map_err(|e| LanderError::Configuration(e.to_string()))?;
        Ok(schedule)
    }

    /// Load a full hint only when its authenticating mapping hash is available.
    async fn committee(
        &self,
        snapshot: &LandingSnapshot,
        epoch: u64,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
    ) -> Result<()> {
        if committees.contains_key(&epoch) {
            return Ok(());
        }
        let expected = if epoch == snapshot.checkpoint_height / snapshot.genesis.epoch_len {
            snapshot.start_committee_record_hash
        } else {
            self.l1.committee_hash(snapshot, epoch).await?
        };
        if expected.is_zero() {
            return Err(LanderError::Unavailable(format!(
                "committee epoch {epoch} is not landed in snapshot"
            )));
        }
        let hint = self.comet.committee(epoch).await?;
        let authenticated = authenticate(hint, epoch, expected, &self.params)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        committees.insert(epoch, authenticated);
        Ok(())
    }

    /// Hash-check the EL checkpoint and authenticate its BFT certificate when non-genesis.
    async fn checkpoint(
        &self,
        snapshot: &LandingSnapshot,
        schedule: &Schedule,
        committees: &mut BTreeMap<u64, AuthenticatedCommittee>,
    ) -> Result<(ParentContext, Option<CertifiedBlock>)> {
        let parent = self.l1.parent_header(snapshot).await?;
        if parent.header.number != snapshot.checkpoint_height ||
            parent.header.hash_slow() != snapshot.checkpoint_hash
        {
            return Err(LanderError::Safety(format!(
                "EL parent disagrees with checkpoint {}",
                snapshot.checkpoint_height
            )));
        }
        if snapshot.checkpoint_height == 0 {
            if snapshot.checkpoint_hash != snapshot.genesis.genesis_hash ||
                parent.header.state_root != snapshot.genesis.genesis_state_root
            {
                return Err(LanderError::Safety(
                    "genesis checkpoint hash/state root mismatch".into(),
                ));
            }
            return Ok((parent, None));
        }
        let pair = self.comet.block(snapshot.checkpoint_height).await?;
        let epoch = schedule.epoch_of(snapshot.checkpoint_height);
        self.committee(snapshot, epoch, committees).await?;
        let envelope = verify_body(&pair, snapshot.checkpoint_height, parent.header.parent_hash)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        if envelope.block.header != parent.header {
            return Err(LanderError::Safety(format!(
                "decided EL block contradicts checkpoint {}",
                snapshot.checkpoint_height
            )));
        }
        verify_commit(
            &pair.commit,
            &pair.block.header,
            &committees[&epoch],
            &rules::chain_id_for(snapshot.l2_chain_id, snapshot.generation),
        )
        .map_err(|e| LanderError::Safety(e.to_string()))?;
        Ok((parent, Some(pair)))
    }
}

#[async_trait]
impl<C: CometSource + ?Sized, L: LandingSource + ?Sized> BatchSource for BatchBuilder<C, L> {
    async fn validate_checkpoint(&self, snapshot: &LandingSnapshot) -> Result<()> {
        let schedule = self.schedule(snapshot)?;
        let status = self.comet.status().await?;
        crate::metrics::LanderMetrics::progress(snapshot.checkpoint_height, status.height);
        if status.chain_id != rules::chain_id_for(snapshot.l2_chain_id, snapshot.generation) {
            return Err(LanderError::Safety("Comet endpoint chain/generation mismatch".into()));
        }
        if status.height < snapshot.checkpoint_height {
            return Err(LanderError::Unavailable(format!(
                "Comet decided tip {} is below checkpoint {}",
                status.height, snapshot.checkpoint_height
            )));
        }
        self.checkpoint(snapshot, &schedule, &mut BTreeMap::new()).await?;
        Ok(())
    }

    async fn prepare(&self, snapshot: LandingSnapshot) -> Result<Option<ProofRequest>> {
        let schedule = self.schedule(&snapshot)?;
        let status = self.comet.status().await?;
        crate::metrics::LanderMetrics::progress(snapshot.checkpoint_height, status.height);
        let chain_id = rules::chain_id_for(snapshot.l2_chain_id, snapshot.generation);
        if status.chain_id != chain_id {
            return Err(LanderError::Safety("Comet endpoint chain/generation mismatch".into()));
        }
        if status.height < snapshot.checkpoint_height {
            return Err(LanderError::Unavailable(format!(
                "Comet decided tip {} is below checkpoint {}",
                status.height, snapshot.checkpoint_height
            )));
        }
        if status.height == snapshot.checkpoint_height {
            return Ok(None);
        }
        let mut committees = BTreeMap::new();
        let (parent_context, mut previous) =
            self.checkpoint(&snapshot, &schedule, &mut committees).await?;
        let parent_anchor = self.l1.parent_anchor(&snapshot, &parent_context).await?;
        let mut anchor = parent_anchor.clone();
        let mut parent = parent_info(&parent_context)?;
        let mut blocks = Vec::new();
        let mut anchors = Vec::new();
        let mut records = Vec::new();
        let mut payload = Vec::new();
        let mut terminal = None;
        let stop = status
            .height
            .min(snapshot.checkpoint_height.saturating_add(self.limits.max_blocks as u64));
        for height in snapshot.checkpoint_height + 1..=stop {
            let pair = self.comet.block(height).await?;
            // Choose complete-block boundaries before expensive signature/MPT verification.
            blocks.push(pair.clone());
            let encoded = match codec::encode(&blocks, &self.limits) {
                Ok(encoded) if blob::required_blobs(encoded.len()) <= self.limits.max_blobs => {
                    encoded
                }
                Ok(encoded) => {
                    if blocks.len() == 1 {
                        return Err(LanderError::Capacity(format!(
                            "block {height} needs {} blobs, configured {}",
                            blob::required_blobs(encoded.len()),
                            self.limits.max_blobs
                        )));
                    }
                    blocks.pop();
                    break;
                }
                Err(LanderError::Capacity(reason)) if blocks.len() > 1 => {
                    let _ = reason;
                    blocks.pop();
                    break;
                }
                Err(LanderError::Capacity(reason)) => {
                    return Err(LanderError::Capacity(format!("block {height}: {reason}")))
                }
                Err(error) => return Err(error),
            };
            let epoch = schedule.epoch_of(height);
            self.committee(&snapshot, epoch, &mut committees).await?;
            if let Some(target) = schedule.switch_target(height) {
                self.committee(&snapshot, target, &mut committees).await?;
            }
            let envelope = verify_structure(&pair, previous.as_ref(), height, parent.hash)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
            if let (Some(last), Some(previous)) = (&pair.block.last_commit, previous.as_ref()) {
                let prev_epoch = schedule.epoch_of(height - 1);
                self.committee(&snapshot, prev_epoch, &mut committees).await?;
                verify_commit(last, &previous.block.header, &committees[&prev_epoch], &chain_id)
                    .map_err(|e| LanderError::Safety(e.to_string()))?;
            }
            verify_commit(&pair.commit, &pair.block.header, &committees[&epoch], &chain_id)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
            let bft_secs = u64::try_from(pair.block.header.time.unix_timestamp())
                .map_err(|_| LanderError::Safety("negative BFT block timestamp".into()))?;
            let facts = verify_envelope(
                envelope,
                EnvelopeContext {
                    bft_time_secs: bft_secs,
                    parent: &parent,
                    parent_anchor: &anchor,
                    generation: snapshot.generation,
                    schedule: &schedule,
                    params: &self.params,
                    committees: &committees,
                },
            )
            .map_err(|e| LanderError::Safety(e.to_string()))?;
            if let Some(derived) = facts.derived {
                let epoch = derived.record.target_epoch;
                let hash = record_hash(snapshot.l2_chain_id, &derived.record);
                if let Some(existing) = committees.get(&epoch) &&
                    existing.state != derived
                {
                    return Err(LanderError::Safety(format!(
                        "derived committee {epoch} conflicts with authenticated context"
                    )));
                }
                committees.insert(
                    epoch,
                    authenticate(derived, epoch, hash, &self.params)
                        .map_err(|e| LanderError::Safety(e.to_string()))?,
                );
                records.push(CommitteeRecord { epoch, recordHash: hash });
            }
            let next_epoch = schedule.epoch_of(
                height
                    .checked_add(1)
                    .ok_or_else(|| LanderError::Safety("height overflow".into()))?,
            );
            self.committee(&snapshot, next_epoch, &mut committees).await?;
            if pair.block.header.next_validators_hash != committees[&next_epoch].validators.hash() {
                return Err(LanderError::Safety(format!(
                    "next validator hash disagrees at height {height}"
                )));
            }
            terminal = Some(facts.envelope.block.header.clone());
            parent = facts.parent;
            anchor = facts.anchor;
            anchors.push(anchor.clone());
            payload = encoded;
            previous = Some(pair);
        }
        let Some(last) = terminal else {
            return Ok(None);
        };
        let consumed = std::iter::once(parent_anchor.clone())
            .chain(anchors.iter().cloned())
            .collect::<Vec<_>>();
        let headers = self.l1.reference(&snapshot, &consumed).await?;
        verify_reference_chain(&headers, &consumed)?;
        let reference = &headers[0];
        self.l1.validate_reference(&snapshot, reference.number(), reference.hash()).await?;
        let input = LandInput {
            lastHeight: last.number,
            lastBlockHash: last.hash_slow(),
            lastStateRoot: last.state_root,
            l1ReferenceBlockNumber: reference.number(),
            records,
        };
        let blobs = blob::build(&payload, &self.limits, self.mode)?;
        let hash = statement::hash(&snapshot, &input, reference.hash(), &blobs.versioned_hashes);
        let contract_hash = self
            .l1
            .statement_hash(&snapshot, &input, reference.hash(), &blobs.versioned_hashes)
            .await?;
        if contract_hash != hash {
            return Err(LanderError::Configuration(format!(
                "local V3 statement {hash} differs from Inbox helper {contract_hash}"
            )));
        }
        Ok(Some(ProofRequest {
            batch: PreparedBatch {
                snapshot,
                parent_header: parent_context.header,
                grandparent_timestamp: parent_context.grandparent_timestamp,
                parent_anchor,
                blocks,
                anchors,
                reference_headers: headers.iter().map(|header| header.raw().clone()).collect(),
                committees: committees.into_values().map(|committee| committee.state).collect(),
                input,
                blobs,
                statement_hash: hash,
            },
        }))
    }
}

/// Converts an authenticated public EL parent into existing ABCI derivation inputs.
fn parent_info(context: &ParentContext) -> Result<ParentInfo> {
    let header = &context.header;
    Ok(ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        difficulty: header.difficulty,
        base_fee: header
            .base_fee_per_gas
            .ok_or_else(|| LanderError::Safety("EL parent has no base fee".into()))?,
        grandparent_timestamp: context.grandparent_timestamp,
    })
}

/// Independently checks the exact descending header chain and every consumed anchor.
///
/// The source authenticates finality/canonicality; this pure check prevents an adapter from
/// silently changing a per-block anchor while selecting a newer L1 reference.
pub fn verify_reference_chain(
    headers: &[abci::RawL1Header],
    anchors: &[AnchorState],
) -> Result<()> {
    if headers.is_empty() || anchors.is_empty() {
        return Err(LanderError::Safety("empty reference header/anchor context".into()));
    }
    let oldest = anchors.iter().map(|anchor| anchor.number).min().expect("nonempty anchors");
    if headers.last().expect("nonempty headers").number() != oldest {
        return Err(LanderError::Safety(
            "reference chain does not terminate at oldest consumed anchor".into(),
        ));
    }
    for pair in headers.windows(2) {
        if pair[0].number().checked_sub(1) != Some(pair[1].number()) ||
            pair[0].parent_hash() != pair[1].hash()
        {
            return Err(LanderError::Safety("reference header ancestry is discontinuous".into()));
        }
    }
    let by_number =
        headers.iter().map(|header| (header.number(), header)).collect::<BTreeMap<_, _>>();
    for anchor in anchors {
        let header = by_number.get(&anchor.number).ok_or_else(|| {
            LanderError::Safety(format!("reference chain omits anchor {}", anchor.number))
        })?;
        if header.hash() != anchor.hash ||
            header.state_root() != anchor.state_root ||
            header.timestamp() != anchor.timestamp
        {
            return Err(LanderError::Safety(format!(
                "reference chain contradicts anchor {}",
                anchor.number
            )));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus_mpt::Fixture;
    use std::sync::atomic::Ordering;

    fn limits(blocks: usize) -> Limits {
        Limits {
            max_blocks: blocks,
            max_blobs: 2,
            max_payload_bytes: 240_000,
            max_message_bytes: 200_000,
        }
    }
    fn builder(fixture: Arc<Fixture>, limits: Limits) -> BatchBuilder<Fixture, Fixture> {
        BatchBuilder::new(
            fixture.clone(),
            fixture.clone(),
            fixture.params.clone(),
            limits,
            SidecarMode::Eip4844,
        )
        .unwrap()
    }

    #[tokio::test]
    async fn genesis_batch_binds_actual_proofs_committee_outputs_and_later_reference() {
        let fixture = Arc::new(Fixture::new(0, 3));
        let snapshot = fixture.snapshot.clone();
        let request = builder(fixture, limits(3)).prepare(snapshot).await.unwrap().unwrap();
        assert_eq!(request.batch.blocks.len(), 3);
        assert_eq!(request.batch.input.lastHeight, 3);
        assert_eq!(request.batch.input.records.len(), 1);
        assert_eq!(request.batch.input.records[0].epoch, 1);
        assert_eq!(request.batch.input.l1ReferenceBlockNumber, 14);
        assert_eq!(request.batch.parent_anchor.number, 10);
        assert!(request.batch.anchors.iter().all(|anchor| anchor.number == 10));
        assert_eq!(
            codec::decode(
                &blob::decode(request.batch.blobs.sidecar.blobs(), &limits(3)).unwrap(),
                &limits(3)
            )
            .unwrap(),
            request.batch.blocks
        );
    }

    #[tokio::test]
    async fn middle_epoch_batch_authenticates_h_plus_two_switch_and_derives_exact_next_record() {
        let fixture = Arc::new(Fixture::new(20, 26));
        let snapshot = fixture.snapshot.clone();
        let request = builder(fixture.clone(), limits(6)).prepare(snapshot).await.unwrap().unwrap();
        assert_eq!(request.batch.input.lastHeight, 26);
        assert_eq!(request.batch.input.records.len(), 1);
        assert_eq!(request.batch.input.records[0].epoch, 2);
        assert_eq!(
            request
                .batch
                .committees
                .iter()
                .map(|committee| committee.record.target_epoch)
                .collect::<Vec<_>>(),
            vec![0, 1, 2]
        );
        assert_eq!(request.batch.blocks[1].block.header.height.value(), 22);
        assert_eq!(
            request.batch.blocks[1].block.header.validators_hash,
            fixture.committees[&0].validators.hash()
        );
        assert_eq!(
            request.batch.blocks[2].block.header.next_validators_hash,
            fixture.committees[&1].validators.hash()
        );
        assert_eq!(
            request.batch.blocks[3].block.header.validators_hash,
            fixture.committees[&1].validators.hash()
        );
        assert_ne!(
            fixture.committees[&0].validators.hash(),
            fixture.committees[&1].validators.hash()
        );
        assert_eq!(request.batch.parent_anchor.number, 11);
        assert_eq!(request.batch.anchors[1].number, 12);
        assert_eq!(request.batch.input.l1ReferenceBlockNumber, 14);
    }

    #[tokio::test]
    async fn chooses_whole_block_prefix_and_reports_oversized_first_height() {
        let fixture = Arc::new(Fixture::new(0, 3));
        let first = codec::encode(&[fixture.blocks[&1].clone()], &limits(3)).unwrap();
        let mut bound = limits(3);
        bound.max_payload_bytes = first.len();
        let request = builder(fixture.clone(), bound)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.blocks.len(), 1);
        bound.max_payload_bytes -= 1;
        let error =
            builder(fixture.clone(), bound).prepare(fixture.snapshot.clone()).await.unwrap_err();
        assert!(matches!(error, LanderError::Capacity(_)));
        assert!(error.to_string().contains("block 1"));
    }

    #[tokio::test]
    async fn pruned_history_and_contract_statement_disagreement_never_yield_jobs() {
        let mut fixture = Fixture::new(20, 26);
        fixture.blocks.remove(&22);
        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Unavailable(_)));
        assert!(error.to_string().contains("height 22"));
        let fixture = Arc::new(Fixture::new(0, 1));
        fixture.mismatch_statement.store(true, Ordering::Relaxed);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Configuration(_))
        ));
    }

    #[test]
    fn reference_chain_preserves_per_block_anchor_roots_and_requires_complete_ancestry() {
        let fixture = Fixture::new(20, 26);
        let anchors = vec![fixture.anchors[&20].clone(), fixture.anchors[&22].clone()];
        let headers =
            (11..=14).rev().map(|number| fixture.l1_headers[&number].clone()).collect::<Vec<_>>();
        verify_reference_chain(&headers, &anchors).unwrap();
        assert!(verify_reference_chain(&headers[..3], &anchors).is_err());
        let mut wrong = anchors.clone();
        wrong[1].state_root = alloy_primitives::B256::ZERO;
        assert!(verify_reference_chain(&headers, &wrong).is_err());
        let mut wrong = headers.clone();
        wrong.swap(0, 1);
        assert!(verify_reference_chain(&wrong, &anchors).is_err());
    }
    fn alter_envelope(
        fixture: &mut Fixture,
        height: u64,
        change: impl FnOnce(&mut abci::EtnaEnvelope),
    ) {
        let pair = fixture.blocks.get_mut(&height).unwrap();
        let mut envelope = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
        change(&mut envelope);
        pair.block.data[0] = envelope.encode().to_vec();
        use sha2::Digest;
        pair.block.header.data_hash = Some(crate::test_utils::consensus::merkle(
            &pair.block.data.iter().map(|tx| sha2::Sha256::digest(tx).to_vec()).collect::<Vec<_>>(),
        ));
        pair.commit.block_id.part_set_header = crate::validate::block_parts(&pair.block);
        let keys = vec![
            ed25519_dalek::SigningKey::from_bytes(&[1; 32]),
            ed25519_dalek::SigningKey::from_bytes(&[2; 32]),
        ];
        let epoch = abci::Schedule::from_genesis(&fixture.snapshot.genesis).epoch_of(height);
        crate::test_utils::consensus::resign(pair, &fixture.committees[&epoch], &keys);
    }

    #[tokio::test]
    async fn missing_extra_and_wrong_epoch_committee_witnesses_are_rejected() {
        let mut fixture = Fixture::new(20, 26);
        alter_envelope(&mut fixture, 24, |envelope| envelope.committee = None);
        let fixture = Arc::new(fixture);
        let error = builder(fixture.clone(), limits(6))
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap_err();
        assert!(matches!(error, LanderError::Safety(_)));
        assert!(error.to_string().contains("committee witness presence"));
        let mut fixture = Fixture::new(20, 26);
        let extra =
            abci::EtnaEnvelope::decode(&fixture.blocks[&24].block.data[0]).unwrap().committee;
        alter_envelope(&mut fixture, 21, |envelope| envelope.committee = extra);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(6)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Safety(_))
        ));
        let mut fixture = Fixture::new(20, 26);
        alter_envelope(&mut fixture, 24, |envelope| {
            envelope.committee.as_mut().unwrap().record.target_epoch = 1
        });
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(6)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Safety(_))
        ));
    }

    #[tokio::test]
    async fn checkpoint_certificate_authenticates_its_complete_envelope_body() {
        let mut fixture = Fixture::new(20, 26);
        let pair = fixture.blocks.get_mut(&20).unwrap();
        let mut envelope = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap();
        envelope
            .block
            .transactions
            .push(alloy_primitives::Bytes::from_static(b"forged checkpoint body"));
        pair.block.data[0] = envelope.encode().to_vec();
        // Its original header/certificate remain genuine; only the purported payload was replaced.
        crate::validate::verify_commit(
            &pair.commit,
            &pair.block.header,
            &fixture.committees[&0],
            "taiko-etna-167001-g0",
        )
        .unwrap();
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(6)).validate_checkpoint(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }
}
