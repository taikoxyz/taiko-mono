//! Genuine signed CometBFT fixtures with real authenticated L1 witnesses.
//!
//! The EL headers are structural fixtures, not an EVM execution proof. Every host rule and
//! certificate is checked before these fixtures are submitted to the accepting test verifier.

use async_trait::async_trait;
use std::{collections::BTreeMap, sync::Arc};

use abci::{
    AnchorState, EtnaEnvelope, ExecutionBlock, ForcedWitness, ParentInfo, Schedule,
    committee::{record_hash, verify_committee_witness},
    envelope::AnchorWitness,
    l1::{
        fetch::build_committee_witness,
        layout::{inbox, word_u48},
        source::{L1Source, RpcL1Source},
        witness::verify_anchor_witness,
    },
    rules::{HeaderInputs, expected_header},
};
use alloy_consensus::{EMPTY_ROOT_HASH, Header};
use alloy_eips::{BlockId, eip7685::EMPTY_REQUESTS_HASH};
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Result, ensure};
use ed25519_dalek::{Signer, SigningKey};
use lander::{
    CertifiedBlock, LandingSnapshot, Limits, ProofRequest, SidecarMode,
    committee::{AuthenticatedCommittee, authenticate},
    contracts::IEtnaInbox::LandInput,
    l1::{LandingSource, RpcLandingSource},
    validate::{EnvelopeContext, commit_hash, verify_commit, verify_envelope, verify_structure},
};
use sha2::{Digest, Sha256};
use tendermint::{
    AppHash, Block, Hash, Time, Vote,
    block::{Commit, CommitSig, Id, header::Version},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{Protobuf, v0_38::types::CanonicalVote as RawVote};

use super::contracts::{CONSENSUS_SEED, ContractFixture, EtnaInbox, L2_CHAIN_ID, view};

/// Generous explicit fixture limits; no block is truncated to fit a blob.
pub fn limits() -> Limits {
    Limits {
        max_blocks: 100,
        max_blobs: 6,
        max_payload_bytes: 700_000,
        max_message_bytes: 650_000,
        max_decompressed_bytes: 100 * 650_000,
    }
}

/// The decided chain survives checkpoint advances so later fixtures preserve exact history.
#[derive(Clone)]
pub struct FixtureChain {
    pub blocks: Vec<CertifiedBlock>,
    pub headers: Vec<Header>,
    pub anchors: Vec<AnchorState>,
    pub committees: BTreeMap<u64, AuthenticatedCommittee>,
    /// Blobs of submitted forced inclusion entries, by queue index. The first block whose anchor
    /// holds the cursor's entry consumes it when its blob is here and otherwise peeks at it.
    pub forced_blobs: BTreeMap<u64, Bytes>,
}

impl FixtureChain {
    pub async fn new(fixture: &ContractFixture) -> Result<Self> {
        let source = RpcL1Source::new(fixture.anvil.provider.clone());
        let header = source.header(fixture.genesis.l1_0).await?;
        let witness =
            source.account_witness(fixture.inbox, &inbox::anchor_slots(), header.number()).await?;
        let anchor = verify_anchor_witness(
            &AnchorWitness { l1_header: header, inbox: witness },
            fixture.inbox,
        )?;
        let hash = record_hash(L2_CHAIN_ID, &fixture.committee.record);
        let committee = authenticate(fixture.committee.clone(), 0, hash, &fixture.params)?;
        Ok(Self {
            blocks: Vec::new(),
            headers: vec![fixture.parent_header.clone()],
            anchors: vec![anchor],
            committees: BTreeMap::from([(0, committee)]),
            forced_blobs: BTreeMap::new(),
        })
    }

    /// Append structurally valid blocks against actual finalized Inbox/registry state.
    pub async fn extend(&mut self, fixture: &ContractFixture, last: u64) -> Result<()> {
        let source = RpcL1Source::new(fixture.anvil.provider.clone());
        let schedule = Schedule::from_genesis(&fixture.genesis);
        while self.blocks.len() < usize::try_from(last)? {
            let height = u64::try_from(self.blocks.len())? + 1;
            let parent = self.headers.last().expect("genesis header");
            let parent_anchor = self.anchors.last().expect("genesis anchor");
            let raw = source.header(source.finalized_number().await?).await?;
            let switch = schedule.switch_target(height);
            let needs_anchor = height == 1 || raw.number() != parent_anchor.number;
            let witness = if needs_anchor {
                Some(AnchorWitness {
                    inbox: source
                        .account_witness(fixture.inbox, &inbox::anchor_slots(), raw.number())
                        .await?,
                    l1_header: raw,
                })
            } else {
                None
            };
            let anchor = match &witness {
                Some(witness) => verify_anchor_witness(witness, fixture.inbox)?,
                None => parent_anchor.clone(),
            };
            // The entry at the cursor, while the anchor's queue holds one: its real entry proof at
            // the anchor, with its blob when known (a forced inclusion block), else a peek.
            let index = self.forced_cursor();
            let forced = if index < anchor.inbox.forced_inclusion_tail {
                Some(ForcedWitness {
                    index,
                    entry: source
                        .account_witness(
                            fixture.inbox,
                            &inbox::forced_inclusion_entry_slots(index),
                            anchor.number,
                        )
                        .await?,
                    blob: self.forced_blobs.get(&index).cloned().unwrap_or_default(),
                })
            } else {
                None
            };
            let consumed = forced.as_ref().filter(|w| !w.blob.is_empty()).map(|w| w.index);
            let committee = if let Some(target) = switch {
                Some(
                    build_committee_witness(
                        &source,
                        &fixture.params,
                        &schedule,
                        parent_anchor.number,
                        target,
                    )
                    .await?,
                )
            } else {
                None
            };
            if let Some(w) = &committee {
                let target = switch.expect("switch committee");
                let (record, members) =
                    verify_committee_witness(parent_anchor, &schedule, &fixture.params, w, target)?;
                let hash = record_hash(L2_CHAIN_ID, &record);
                self.committees.insert(
                    target,
                    authenticate(
                        abci::CommitteeState { record, members },
                        target,
                        hash,
                        &fixture.params,
                    )?,
                );
            }
            let parent_info = ParentInfo {
                number: parent.number,
                hash: parent.hash_slow(),
                timestamp: parent.timestamp,
                gas_limit: parent.gas_limit,
                gas_used: parent.gas_used,
                base_fee: parent.base_fee_per_gas.expect("base fee"),
                difficulty: parent.difficulty,
                grandparent_timestamp: if self.headers.len() == 1 {
                    0
                } else {
                    self.headers[self.headers.len() - 2].timestamp
                },
            };
            let time = parent.timestamp + 1;
            let expected = expected_header(&HeaderInputs {
                height,
                parent: &parent_info,
                anchor: &anchor,
                bft_time_secs: time,
                generation: 0,
                params: &fixture.params,
                min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(L2_CHAIN_ID),
            })?;
            let header = Header {
                number: height,
                parent_hash: expected.parent_hash,
                timestamp: expected.timestamp,
                beneficiary: expected.beneficiary,
                extra_data: expected.extra_data,
                parent_beacon_block_root: Some(expected.parent_beacon_block_root),
                gas_limit: expected.gas_limit,
                base_fee_per_gas: Some(expected.base_fee),
                mix_hash: expected.mix_hash,
                state_root: B256::from(U256::from(height + 0x1000)),
                withdrawals_root: Some(EMPTY_ROOT_HASH),
                blob_gas_used: Some(0),
                excess_blob_gas: Some(0),
                requests_hash: Some(EMPTY_REQUESTS_HASH),
                ..Header::default()
            };
            let envelope = EtnaEnvelope {
                block: ExecutionBlock { header: header.clone(), transactions: vec![] },
                anchor: witness,
                committee,
                forced,
            };
            let current = &self.committees[&schedule.epoch_of(height)];
            let pair = signed_pair(
                envelope.clone(),
                current,
                &self.committees[&schedule.epoch_of(height + 1)],
                self.blocks.last(),
            );
            verify_commit(&pair.commit, &pair.block.header, current, "taiko-etna-167001-g0")?;
            verify_structure(&pair, self.blocks.last(), height, parent.hash_slow())?;
            let facts = verify_envelope(
                envelope,
                EnvelopeContext {
                    bft_time_secs: time,
                    parent: &parent_info,
                    parent_anchor,
                    generation: 0,
                    schedule: &schedule,
                    params: &fixture.params,
                    max_anchor_age: fixture.genesis.max_anchor_age,
                    forced_cursor: index,
                    forced_inclusion_delay: fixture.genesis.forced_inclusion_delay,
                },
            )?;
            ensure!(facts.forced == consumed, "forced inclusion at height {height}");
            if let Some(derived) = facts.derived {
                let epoch = derived.record.target_epoch;
                let hash = record_hash(L2_CHAIN_ID, &derived.record);
                self.committees.insert(epoch, authenticate(derived, epoch, hash, &fixture.params)?);
            }
            self.blocks.push(pair);
            self.headers.push(header);
            self.anchors.push(facts.anchor);
        }
        Ok(())
    }

    /// The forced inclusion cursor after the last block: the entries the chain has consumed,
    /// each by a block carrying its blob (the chain starts at genesis and consumes no expired
    /// entry).
    pub fn forced_cursor(&self) -> u64 {
        self.blocks
            .iter()
            .filter_map(|pair| EtnaEnvelope::decode(&pair.block.data[0]).ok()?.forced)
            .filter(|witness| !witness.blob.is_empty())
            .count() as u64
    }

    /// Prepare immutable production transport inputs; the real Inbox helper independently hashes
    /// them.
    pub async fn prepare(
        &self,
        fixture: &ContractFixture,
        last: u64,
        mode: SidecarMode,
    ) -> Result<ProofRequest> {
        let p = &fixture.anvil.provider;
        let source = RpcL1Source::new(p.clone());
        let state = source.header(p.get_block_number().await?).await?;
        let pin = Some(BlockId::hash_canonical(state.hash()));
        let checkpoint = view(p, fixture.inbox, EtnaInbox::lastCheckpointCall {}, pin).await?;
        let config = view(p, fixture.inbox, EtnaInbox::committeeConfigHashCall {}, pin).await?;
        let bootstrap =
            view(p, fixture.inbox, EtnaInbox::genesisCommitteeRecordHashCall {}, pin).await?;
        let inbox_witness = source
            .account_witness(fixture.inbox, &lander::l1::snapshot_slots(), state.number())
            .await?;
        let head_tail = inbox_witness
            .storage
            .iter()
            .find(|proof| proof.slot == inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL))
            .expect("the snapshot proof covers the forced inclusion head/tail")
            .value;
        let snapshot = LandingSnapshot {
            l1_block_hash: state.hash(),
            l1_block_number: state.number(),
            l1_chain_id: U256::from(p.get_chain_id().await?),
            l2_chain_id: L2_CHAIN_ID,
            inbox: fixture.inbox,
            registry: fixture.registry,
            generation: 0,
            checkpoint_height: checkpoint.height,
            checkpoint_hash: checkpoint.blockHash,
            forced_inclusion_head: word_u48(head_tail, 0),
            forced_inclusion_tail: word_u48(head_tail, 48),
            genesis: fixture.genesis.clone(),
            committee_config_hash: config,
            genesis_committee_record_hash: bootstrap,
            l1_header: state,
            inbox_witness,
        };
        ensure!(last <= self.blocks.len() as u64, "fixture batch range");
        let chain = Arc::new(Self {
            blocks: self.blocks[..last as usize].to_vec(),
            headers: self.headers[..=last as usize].to_vec(),
            anchors: self.anchors[..=last as usize].to_vec(),
            committees: self.committees.clone(),
            forced_blobs: self.forced_blobs.clone(),
        });
        let adapter = Arc::new(FixtureLanding {
            chain: chain.clone(),
            rpc: RpcLandingSource::new(p.clone(), p.clone(), fixture.params.clone()),
        });
        use lander::batch::BatchSource;
        lander::batch::BatchBuilder::new(
            chain,
            adapter,
            fixture.params.clone(),
            limits(),
            mode,
            test_harness::dev_signer().address(),
        )?
        .prepare(snapshot)
        .await?
        .ok_or_else(|| anyhow::anyhow!("empty fixture batch"))
    }
}

fn merkle(items: &[Vec<u8>]) -> Hash {
    Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<
        tendermint::crypto::default::Sha256,
    >(items))
}

pub fn signed_pair(
    envelope: EtnaEnvelope,
    committee: &AuthenticatedCommittee,
    next: &AuthenticatedCommittee,
    previous: Option<&CertifiedBlock>,
) -> CertifiedBlock {
    let height = envelope.block.header.number;
    let parent = envelope.block.header.parent_hash;
    let time = envelope.block.header.timestamp;
    let data = vec![envelope.encode().to_vec()];
    let header = tendermint::block::Header {
        version: Version { block: 11, app: 0 },
        chain_id: "taiko-etna-167001-g0".parse().unwrap(),
        height: height.try_into().unwrap(),
        time: Time::from_unix_timestamp(i64::try_from(time).unwrap(), 0).unwrap(),
        last_block_id: previous.map(|p| p.commit.block_id),
        last_commit_hash: Some(previous.map_or_else(|| merkle(&[]), |p| commit_hash(&p.commit))),
        data_hash: Some(merkle(
            &data.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>(),
        )),
        validators_hash: committee.validators.hash(),
        next_validators_hash: next.validators.hash(),
        consensus_hash: Hash::Sha256([2; 32]),
        app_hash: AppHash::try_from(parent.to_vec()).unwrap(),
        last_results_hash: None,
        evidence_hash: Some(merkle(&[])),
        proposer_address: committee.validators.validators()[0].address,
    };
    let block = Block::new(header, data, Default::default(), previous.map(|p| p.commit.clone()));
    let parts = lander::validate::block_parts(&block);
    let mut commit = Commit {
        height: block.header.height,
        round: 0u16.into(),
        block_id: Id { hash: block.header.hash(), part_set_header: parts },
        signatures: vec![],
    };
    let key = SigningKey::from_bytes(&CONSENSUS_SEED);
    let validator = &committee.validators.validators()[0];
    let vote = Vote {
        vote_type: Type::Precommit,
        height: commit.height,
        round: commit.round,
        block_id: Some(commit.block_id),
        timestamp: Some(block.header.time),
        validator_address: validator.address,
        validator_index: 0u32.try_into().unwrap(),
        signature: None,
        extension: vec![],
        extension_signature: None,
    };
    let bytes = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
        vote,
        block.header.chain_id.clone(),
    ));
    commit.signatures = vec![CommitSig::BlockIdFlagCommit {
        validator_address: validator.address,
        timestamp: block.header.time,
        signature: Some(key.sign(&bytes).to_bytes().to_vec().try_into().unwrap()),
    }];
    CertifiedBlock { block, commit }
}

#[async_trait]
impl lander::comet::CometSource for FixtureChain {
    async fn status(&self) -> lander::error::Result<lander::comet::CometStatus> {
        Ok(lander::comet::CometStatus {
            chain_id: "taiko-etna-167001-g0".into(),
            height: self.blocks.len() as u64,
        })
    }
    async fn block(&self, height: u64) -> lander::error::Result<CertifiedBlock> {
        self.blocks
            .get(height as usize - 1)
            .cloned()
            .ok_or_else(|| lander::error::LanderError::Unavailable("fixture block".into()))
    }
    async fn committee(&self, _: u64) -> lander::error::Result<abci::CommitteeState> {
        panic!("production builder must derive from L1, never trust committee hints")
    }
}

struct FixtureLanding {
    chain: Arc<FixtureChain>,
    rpc: RpcLandingSource,
}
#[async_trait]
impl LandingSource for FixtureLanding {
    async fn snapshot(&self) -> lander::error::Result<LandingSnapshot> {
        unreachable!()
    }
    async fn parent_header(
        &self,
        snapshot: &LandingSnapshot,
    ) -> lander::error::Result<lander::l1::ParentContext> {
        let height = snapshot.checkpoint_height as usize;
        Ok(lander::l1::ParentContext {
            header: self.chain.headers[height].clone(),
            grandparent_timestamp: height
                .checked_sub(1)
                .map_or(0, |h| self.chain.headers[h].timestamp),
        })
    }
    async fn execution_header(&self, number: u64) -> lander::error::Result<Header> {
        self.chain.headers.get(number as usize).cloned().ok_or_else(|| {
            lander::LanderError::Unavailable(format!("required execution history height {number}"))
        })
    }
    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        parent: &lander::l1::ParentContext,
    ) -> lander::error::Result<AnchorState> {
        self.rpc.parent_anchor(snapshot, parent).await
    }
    async fn starting_inbox_witness(
        &self,
        anchor: &AnchorState,
    ) -> lander::error::Result<abci::AnchorWitness> {
        self.rpc.starting_inbox_witness(anchor).await
    }
    async fn committee_witness(
        &self,
        snapshot: &LandingSnapshot,
        anchor: &AnchorState,
        snapshot_number: u64,
        epoch: u64,
    ) -> lander::error::Result<abci::CommitteeWitness> {
        self.rpc.committee_witness(snapshot, anchor, snapshot_number, epoch).await
    }
    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> lander::error::Result<Vec<abci::RawL1Header>> {
        self.rpc.reference(snapshot, anchors).await
    }
    async fn statement_hash(
        &self,
        snapshot: &LandingSnapshot,
        input: &LandInput,
        hash: B256,
        blobs: &[B256],
    ) -> lander::error::Result<B256> {
        self.rpc.statement_hash(snapshot, input, hash, blobs).await
    }
    async fn canonical_hash(&self, number: u64) -> lander::error::Result<B256> {
        self.rpc.canonical_hash(number).await
    }
    async fn validate_reference(
        &self,
        snapshot: &LandingSnapshot,
        number: u64,
        hash: B256,
    ) -> lander::error::Result<()> {
        self.rpc.validate_reference(snapshot, number, hash).await
    }
}
