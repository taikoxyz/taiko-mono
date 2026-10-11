//! Genuine signed CometBFT fixtures with real authenticated L1 witnesses.
//!
//! The EL headers are structural fixtures, not an EVM execution proof. Every host rule and
//! certificate is checked before these fixtures are submitted to the accepting test verifier.

use std::collections::BTreeMap;

use abci::{
    AnchorState, EtnaEnvelope, ExecutionBlock, ParentInfo, Schedule,
    committee::record_hash,
    envelope::AnchorWitness,
    l1::{
        fetch::build_committee_witness,
        layout::inbox,
        source::{L1Source, RpcL1Source},
        witness::verify_anchor_witness,
    },
    rules::{HeaderInputs, expected_header},
};
use alloy_consensus::{EMPTY_ROOT_HASH, Header};
use alloy_eips::{BlockId, eip7685::EMPTY_REQUESTS_HASH};
use alloy_primitives::{B256, U256};
use alloy_provider::Provider;
use anyhow::{Result, ensure};
use ed25519_dalek::{Signer, SigningKey};
use lander::{
    CertifiedBlock, LandingSnapshot, Limits, PreparedBatch, ProofRequest, SidecarMode, blob, codec,
    committee::{AuthenticatedCommittee, authenticate},
    contracts::IEtnaInbox::{CommitteeRecord, LandInput},
    l1::{LandingSource, RpcLandingSource},
    statement,
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
    Limits { max_blocks: 100, max_blobs: 6, max_payload_bytes: 700_000, max_message_bytes: 650_000 }
}

/// The decided chain survives checkpoint advances so later fixtures preserve exact history.
pub struct FixtureChain {
    pub blocks: Vec<CertifiedBlock>,
    pub headers: Vec<Header>,
    pub anchors: Vec<AnchorState>,
    pub committees: BTreeMap<u64, AuthenticatedCommittee>,
}

impl FixtureChain {
    pub async fn new(fixture: &ContractFixture) -> Result<Self> {
        let source = RpcL1Source::new(fixture.anvil.provider.clone());
        let header = source.header(fixture.genesis.l1_0).await?;
        let witness = source
            .account_witness(fixture.inbox, &inbox::anchor_slots(Some(0)), header.number())
            .await?;
        let anchor = verify_anchor_witness(
            &AnchorWitness { l1_header: header, inbox: witness },
            fixture.inbox,
            Some(0),
        )?;
        let hash = record_hash(L2_CHAIN_ID, &fixture.committee.record);
        let committee = authenticate(fixture.committee.clone(), 0, hash, &fixture.params)?;
        Ok(Self {
            blocks: Vec::new(),
            headers: vec![fixture.parent_header.clone()],
            anchors: vec![anchor],
            committees: BTreeMap::from([(0, committee)]),
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
            let needs_anchor =
                height == 1 || switch.is_some() || raw.number() != parent_anchor.number;
            let witness = if needs_anchor {
                Some(AnchorWitness {
                    inbox: source
                        .account_witness(fixture.inbox, &inbox::anchor_slots(switch), raw.number())
                        .await?,
                    l1_header: raw,
                })
            } else {
                None
            };
            let anchor = match &witness {
                Some(witness) => verify_anchor_witness(witness, fixture.inbox, switch)?,
                None => parent_anchor.clone(),
            };
            let committee = if let Some(epoch) = schedule.epoch_starting_at(height) {
                Some(
                    build_committee_witness(
                        &source,
                        &fixture.params,
                        &schedule,
                        parent_anchor.number,
                        epoch + 1,
                    )
                    .await?,
                )
            } else {
                None
            };
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
            };
            let current = &self.committees[&schedule.epoch_of(height)];
            let pair = signed_pair(envelope.clone(), current, self.blocks.last());
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
                    committees: &self.committees,
                },
            )?;
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
        let start_epoch = checkpoint.height / fixture.genesis.epoch_len;
        let starting =
            view(p, fixture.inbox, EtnaInbox::committeeCall { _epoch: start_epoch }, pin).await?;
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
            genesis: fixture.genesis.clone(),
            start_committee_record_hash: starting,
        };
        let first = usize::try_from(checkpoint.height)?;
        let stop = usize::try_from(last)?;
        ensure!(first < stop && stop <= self.blocks.len(), "fixture batch range");
        ensure!(
            self.headers[first].hash_slow() == checkpoint.blockHash,
            "fixture checkpoint contradiction"
        );
        let blocks = self.blocks[first..stop].to_vec();
        let anchors = self.anchors[first + 1..=stop].to_vec();
        let reference = source.header(source.finalized_number().await?).await?;
        let oldest = self.anchors[first..=stop]
            .iter()
            .map(|anchor| anchor.number)
            .min()
            .expect("parent anchor");
        ensure!(
            reference.number() >=
                anchors.iter().map(|anchor| anchor.number).max().expect("batch anchor"),
            "reference before anchor"
        );
        let mut reference_headers = vec![];
        for number in (oldest..=reference.number()).rev() {
            reference_headers.push(source.header(number).await?.raw().clone());
        }
        let schedule = Schedule::from_genesis(&fixture.genesis);
        let records = ((checkpoint.height + 1)..=last)
            .filter_map(|height| schedule.epoch_starting_at(height))
            .map(|epoch| {
                let state = &self.committees[&(epoch + 1)].state;
                CommitteeRecord {
                    epoch: epoch + 1,
                    recordHash: record_hash(L2_CHAIN_ID, &state.record),
                }
            })
            .collect();
        let terminal = &self.headers[stop];
        let input = LandInput {
            lastHeight: last,
            lastBlockHash: terminal.hash_slow(),
            lastStateRoot: terminal.state_root,
            l1ReferenceBlockNumber: reference.number(),
            records,
        };
        let payload = codec::encode(&blocks, &limits())?;
        let blobs = blob::build(&payload, &limits(), mode)?;
        let statement_hash =
            statement::hash(&snapshot, &input, reference.hash(), &blobs.versioned_hashes);
        let adapter = RpcLandingSource::new(p.clone(), p.clone(), fixture.params.clone());
        ensure!(
            adapter
                .statement_hash(&snapshot, &input, reference.hash(), &blobs.versioned_hashes)
                .await? ==
                statement_hash,
            "real proxy V3 hash differs"
        );
        Ok(ProofRequest {
            batch: PreparedBatch {
                snapshot,
                parent_header: self.headers[first].clone(),
                grandparent_timestamp: if first == 0 {
                    0
                } else {
                    self.headers[first - 1].timestamp
                },
                parent_anchor: self.anchors[first].clone(),
                blocks,
                anchors,
                reference_headers,
                committees: self.committees.values().map(|c| c.state.clone()).collect(),
                input,
                blobs,
                statement_hash,
            },
        })
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
        next_validators_hash: committee.validators.hash(),
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
