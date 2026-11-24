//! Genuine signed CometBFT fixtures with real authenticated L1 witnesses.
//!
//! The EL headers are structural fixtures, not an EVM execution proof. Every host rule and
//! certificate is checked before these fixtures are submitted to the accepting test verifier.
//! Each structural block keeps its base's state root, the real L2 state at the generation's start
//! o (the genesis, or S on a switching network): the lander's per-block staking read at any of
//! them is the real EL's proof at o, where no bond is registered, so no candidate is usable and
//! the origin fallback keys sign every height.

use async_trait::async_trait;
use std::{collections::BTreeMap, sync::Arc};

use abci::{
    AnchorState, EtnaEnvelope, ExecutionBlock, ForcedWitness, ParentInfo,
    envelope::AnchorWitness,
    l1::{
        layout::{inbox, word_u48},
        source::{L1Source, RpcL1Source},
        witness::verify_anchor_witness,
    },
    rules::{HeaderInputs, expected_header},
    valstate::ValState,
};
use alloy_consensus::{EMPTY_ROOT_HASH, Header};
use alloy_eips::{BlockId, eip7685::EMPTY_REQUESTS_HASH};
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use lander::{
    CertifiedBlock, LandingSnapshot, Limits, ProofRequest, SidecarMode,
    committee::Validators,
    l1::{LandingSource, RpcLandingSource},
    validate::{
        EnvelopeContext, commit_hash, verify_commit, verify_envelope, verify_structure_at_origin,
    },
};
use sha2::{Digest, Sha256};
use tendermint::{
    AppHash, Hash, Time, Vote,
    block::{Id, header::Version},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{Protobuf, v0_38::types::CanonicalVote as RawVote};

use super::contracts::{ContractFixture, EtnaInbox, L2_CHAIN_ID, view};

use lander::native::{Block, Commit, CommitSig, EvidenceList, RawBlock};

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
/// Heights count from the generation's start o: `blocks[i]` is height o + 1 + i, and
/// `headers[i]`, `anchors[i]` and `val_states[i]` belong to height o + i.
#[derive(Clone)]
pub struct FixtureChain {
    pub chain_id: String,
    pub keys: Vec<test_harness::ValidatorKey>,
    /// The generation's start o, whose real EL header is `headers[0]`.
    pub origin: u64,
    /// The timestamp of o − 1, the first block's grandparent: 0 at a genesis start.
    pub origin_parent_timestamp: u64,
    pub blocks: Vec<CertifiedBlock>,
    pub headers: Vec<Header>,
    pub anchors: Vec<AnchorState>,
    /// The origin fallback key set, which signs every height.
    pub validators: Validators,
    /// Exact admitted transaction bytes by queue index, carried whenever the anchor proves
    /// that entry pending; inclusion at position zero consumes it.
    pub forced_transactions: BTreeMap<u64, Bytes>,
    /// The validator state after each height from o on: the genesis state at o, then one
    /// advance per block by an empty update list, which abci's app returns while the origin set
    /// keeps signing, as `/val_state/<height>` serves them.
    pub val_states: Vec<ValState>,
}

impl FixtureChain {
    /// A chain at the fixture's start: its `genesis` record and `parent_header`, the real L2 header
    /// at o.
    pub async fn new(fixture: &ContractFixture) -> Result<Self> {
        let source = RpcL1Source::new(fixture.anvil.provider.clone());
        let header = source.header(fixture.genesis.l1_0).await?;
        let witness =
            source.account_witness(fixture.inbox, &inbox::anchor_slots(), header.number()).await?;
        let anchor = verify_anchor_witness(
            &AnchorWitness { l1_header: header, inbox: witness },
            fixture.inbox,
        )?;
        let members = fixture.fallback_keys.validator_set();
        let validators = Validators::from_powers(&members)?;
        let origin = fixture.genesis.genesis_height;
        ensure!(
            fixture.parent_header.number == origin,
            "the base header is not the start {origin}"
        );
        let genesis = ValState::genesis(origin, &members)?;
        let origin_parent_timestamp = match origin.checked_sub(1) {
            Some(below) => {
                fixture
                    .l2
                    .provider
                    .get_block_by_number(below.into())
                    .await?
                    .context("the start's parent")?
                    .header
                    .timestamp
            }
            None => 0,
        };
        Ok(Self {
            chain_id: abci::domain::chain_id(&abci::domain::DeploymentDomain {
                l1_chain_id: fixture.params.l1_chain_id,
                l2_chain_id: U256::from(L2_CHAIN_ID),
                inbox: fixture.inbox,
                generation: 0,
            })?,
            keys: fixture.keys.clone(),
            origin,
            origin_parent_timestamp,
            blocks: Vec::new(),
            headers: vec![fixture.parent_header.clone()],
            anchors: vec![anchor],
            validators,
            forced_transactions: BTreeMap::new(),
            val_states: vec![genesis],
        })
    }

    /// The decided height of the last block.
    pub fn head(&self) -> u64 {
        self.origin + self.blocks.len() as u64
    }

    /// The index of height `height` in `headers`, `anchors` and `val_states`.
    fn index(&self, height: u64) -> usize {
        usize::try_from(height - self.origin).expect("a fixture height")
    }

    /// Append structurally valid blocks up to `last` against actual finalized Inbox state.
    pub async fn extend(&mut self, fixture: &ContractFixture, last: u64) -> Result<()> {
        let source = RpcL1Source::new(fixture.anvil.provider.clone());
        while self.head() < last {
            let height = self.head() + 1;
            let first = height == self.origin + 1;
            let parent = self.headers.last().expect("start header");
            let parent_anchor = self.anchors.last().expect("start anchor");
            let raw = source.header(source.finalized_number().await?).await?;
            let needs_anchor = first || raw.number() != parent_anchor.number;
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
            // the anchor, with the exact admitted transaction bytes.
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
                    tx: self
                        .forced_transactions
                        .get(&index)
                        .cloned()
                        .context("missing forced admission bytes")?,
                })
            } else {
                None
            };
            let consumed = forced.as_ref().filter(|w| !w.tx.is_empty()).map(|w| w.index);
            let parent_info = ParentInfo {
                number: parent.number,
                hash: parent.hash_slow(),
                timestamp: parent.timestamp,
                gas_limit: parent.gas_limit,
                gas_used: parent.gas_used,
                base_fee: parent.base_fee_per_gas.expect("base fee"),
                difficulty: parent.difficulty,
                grandparent_timestamp: if self.headers.len() == 1 {
                    self.origin_parent_timestamp
                } else {
                    self.headers[self.headers.len() - 2].timestamp
                },
            };
            let time = parent.timestamp + 1;
            let expected = expected_header(&HeaderInputs {
                height,
                beneficiary: fixture.params.fee_recipient,
                parent: &parent_info,
                anchor: &anchor,
                bft_time_secs: time,
                generation: 0,
                params: &fixture.params,
                min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(L2_CHAIN_ID),
            })?;
            let transactions = forced.as_ref().map(|w| vec![w.tx.clone()]).unwrap_or_default();
            let header = Header {
                transactions_root: alloy_consensus::proofs::ordered_trie_root_encoded(
                    &transactions,
                ),
                number: height,
                parent_hash: expected.parent_hash,
                timestamp: expected.timestamp,
                beneficiary: expected.beneficiary,
                extra_data: expected.extra_data,
                parent_beacon_block_root: Some(expected.parent_beacon_block_root),
                gas_limit: expected.gas_limit,
                base_fee_per_gas: Some(expected.base_fee),
                mix_hash: expected.mix_hash,
                // The start's state: see the module docs.
                state_root: self.headers[0].state_root,
                withdrawals_root: Some(EMPTY_ROOT_HASH),
                blob_gas_used: Some(0),
                excess_blob_gas: Some(0),
                requests_hash: Some(EMPTY_REQUESTS_HASH),
                ..Header::default()
            };
            let envelope = EtnaEnvelope {
                block: ExecutionBlock { header: header.clone(), transactions },
                anchor: witness,
                forced: forced.map(|mut w| {
                    w.tx = Bytes::new();
                    w
                }),
            };
            let pair = signed_pair(
                envelope.clone(),
                &self.validators,
                &self.validators,
                self.blocks.last(),
                &self.chain_id,
                &self.keys,
            );
            verify_commit(&pair.commit, &pair.block.header, &self.validators, &self.chain_id)?;
            verify_structure_at_origin(
                &pair,
                self.blocks.last(),
                height,
                parent.hash_slow(),
                self.origin,
            )?;
            let signers = self.validators.entries();
            let facts = verify_envelope(
                envelope,
                EnvelopeContext {
                    recovery: None,
                    bft_time_secs: time,
                    proposer: pair.block.header.proposer_address,
                    signers: &signers,
                    parent: &parent_info,
                    parent_anchor,
                    generation: 0,
                    genesis: &fixture.genesis,
                    params: &fixture.params,
                    forced_cursor: index,
                },
            )?;
            ensure!(
                facts.forced ==
                    consumed
                        .map(abci::forced::ForcedDecision::Included)
                        .unwrap_or(abci::forced::ForcedDecision::Ordinary),
                "forced inclusion at height {height}"
            );
            let val_state = self.val_states.last().expect("genesis state").advance(&[])?;
            self.val_states.push(val_state);
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
        ensure!(last > self.origin && last <= self.head(), "fixture batch range");
        let pin = Some(BlockId::hash_canonical(state.hash()));
        let checkpoint = view(p, fixture.inbox, EtnaInbox::lastCheckpointCall {}, pin).await?;
        let inbox_witness = source
            .account_witness(
                fixture.inbox,
                &lander::l1::snapshot_landing_slots(checkpoint.height.to()),
                state.number(),
            )
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
            recovery: None,
            recovery_witness: None,
            generation: 0,
            checkpoint_height: checkpoint.height.to(),
            checkpoint_comet_hash: if checkpoint.height.to::<u64>() == self.origin {
                B256::ZERO
            } else {
                B256::from_slice(
                    self.blocks[self.index(checkpoint.height.to()) - 1]
                        .commit
                        .block_id
                        .hash
                        .as_bytes(),
                )
            },
            checkpoint_hash: checkpoint.blockHash,
            forced_inclusion_head: word_u48(head_tail, 0),
            forced_inclusion_tail: word_u48(head_tail, 48),
            genesis: fixture.genesis.clone(),
            config_hash: fixture.genesis.config_hash,
            l1_header: state,
            inbox_witness,
        };
        let end = self.index(last);
        let chain = Arc::new(Self {
            chain_id: self.chain_id.clone(),
            keys: self.keys.clone(),
            origin: self.origin,
            origin_parent_timestamp: self.origin_parent_timestamp,
            blocks: self.blocks[..end].to_vec(),
            headers: self.headers[..=end].to_vec(),
            anchors: self.anchors[..=end].to_vec(),
            validators: self.validators.clone(),
            forced_transactions: self.forced_transactions.clone(),
            val_states: self.val_states[..=end].to_vec(),
        });
        let adapter = Arc::new(FixtureLanding {
            chain: chain.clone(),
            // anvil for the L1 reads, and the fixture's EL, whose real start the structural
            // blocks extend, for the staking, start-proxy and below-start header reads.
            rpc: RpcLandingSource::new(
                p.clone(),
                fixture.l2.provider.clone(),
                fixture.params.clone(),
            ),
        });
        use lander::{batch::BatchSource, l1::LandingSource};
        let max_batch_blocks = adapter.deployment(&snapshot).await?.max_batch_blocks;
        lander::batch::BatchBuilder::new(
            chain,
            adapter,
            lander::batch::BatchBuilderConfig {
                params: fixture.params.clone(),
                limits: limits(),
                mode,
                engine: std::sync::Arc::new(test_harness::unavailable_engine::UnavailableEngine),
                engine_timeout: std::time::Duration::from_secs(1),
                max_batch_blocks,
            },
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
    committee: &Validators,
    next: &Validators,
    previous: Option<&CertifiedBlock>,
    chain_id: &str,
    keys: &[test_harness::ValidatorKey],
) -> CertifiedBlock {
    let height = envelope.block.header.number;
    let parent = envelope.block.header.parent_hash;
    let time = envelope.block.header.timestamp;
    let data = vec![envelope.encode().to_vec()];
    let header = tendermint::block::Header {
        version: Version { block: 11, app: 1 },
        chain_id: chain_id.parse().unwrap(),
        height: height.try_into().unwrap(),
        time: Time::from_unix_timestamp(i64::try_from(time).unwrap(), 0).unwrap(),
        last_block_id: previous.map(|p| p.commit.block_id),
        last_commit_hash: Some(previous.map_or_else(|| merkle(&[]), |p| commit_hash(&p.commit))),
        data_hash: Some(merkle(
            &data.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>(),
        )),
        validators_hash: committee.hash(),
        next_validators_hash: next.hash(),
        consensus_hash: Hash::Sha256([2; 32]),
        // appHash of the parent's EL hash (CONS-3.1-8), never the bare hash. The lander leaves it
        // unchecked (PROOF-6.2-42), so a zero validator-state hash stands in.
        app_hash: AppHash::try_from(abci::valstate::app_hash(parent, B256::ZERO).to_vec()).unwrap(),
        last_results_hash: None,
        evidence_hash: Some(merkle(&[])),
        proposer_address: committee.validators()[0].address,
    };
    let block = Block { header, data, last_commit: previous.map(|p| p.commit.clone()) };
    let mut raw = RawBlock {
        header: Some(block.header.clone().into()),
        data: Some(tendermint_proto::v0_38::types::Data { txs: block.data.clone() }),
        evidence: Some(EvidenceList { evidence: vec![] }),
        last_commit: block.last_commit.clone().map(Into::into),
    };
    if previous.is_none() {
        raw.last_commit = Some(Commit::default().into());
        raw.header.as_mut().unwrap().last_block_id =
            Some(tendermint_proto::v0_38::types::BlockId {
                hash: Vec::new(),
                part_set_header: Some(Default::default()),
            });
    }
    let parts = lander::validate::block_parts(&raw);
    let mut commit = Commit {
        height: block.header.height,
        round: 0u16.into(),
        block_id: Id { hash: block.header.hash(), part_set_header: parts },
        signatures: vec![],
    };
    commit.signatures = committee
        .validators()
        .iter()
        .enumerate()
        .map(|(index, validator)| {
            let key = keys.iter().find(|key| key.pubkey() == validator.pub_key).unwrap();
            let vote = Vote {
                vote_type: Type::Precommit,
                height: commit.height,
                round: commit.round,
                block_id: Some(commit.block_id),
                timestamp: Some(block.header.time),
                validator_address: validator.address,
                validator_index: (index as u32).try_into().unwrap(),
                signature: None,
                extension: vec![],
                extension_signature: None,
            };
            let bytes = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
                vote,
                block.header.chain_id.clone(),
            ));
            CommitSig::BlockIdFlagCommit {
                validator_address: validator.address,
                timestamp: block.header.time,
                signature: Some(key.sign_native_message(&bytes).try_into().unwrap()),
            }
        })
        .collect();
    CertifiedBlock::from_raw(raw, commit).unwrap()
}

#[async_trait]
impl lander::comet::CometSource for FixtureChain {
    async fn status(&self) -> lander::error::Result<lander::comet::CometStatus> {
        Ok(lander::comet::CometStatus { chain_id: self.chain_id.clone(), height: self.head() })
    }
    async fn block(&self, height: u64) -> lander::error::Result<CertifiedBlock> {
        height
            .checked_sub(self.origin + 1)
            .and_then(|index| self.blocks.get(usize::try_from(index).ok()?))
            .cloned()
            .ok_or_else(|| lander::error::LanderError::Unavailable("fixture block".into()))
    }
    /// As the app answers `/val_state/<height>`: any retained height.
    async fn val_state(&self, height: u64) -> lander::error::Result<Vec<u8>> {
        height
            .checked_sub(self.origin)
            .and_then(|index| usize::try_from(index).ok())
            .and_then(|index| self.val_states.get(index))
            .map(ValState::encode)
            .ok_or_else(|| {
                lander::error::LanderError::Temporary(format!(
                    "fixture app rejects the validator state query at {height}"
                ))
            })
    }
    /// As stock CometBFT answers `/validators`: the one set that signs every fixture height.
    async fn archive_validators(
        &self,
        height: u64,
    ) -> lander::error::Result<Vec<(abci::key::ConsensusKey, u64)>> {
        height
            .checked_sub(self.origin + 1)
            .and_then(|index| self.blocks.get(usize::try_from(index).ok()?))
            .map(|_| self.validators.validators().iter().map(|v| (v.pub_key, v.power())).collect())
            .ok_or_else(|| lander::error::LanderError::Unavailable("fixture validators".into()))
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
        let index = self.chain.index(snapshot.checkpoint_height);
        Ok(lander::l1::ParentContext {
            header: self.chain.headers[index].clone(),
            grandparent_timestamp: index
                .checked_sub(1)
                .map_or(self.chain.origin_parent_timestamp, |h| self.chain.headers[h].timestamp),
        })
    }
    /// The start S is the real EL's block, so its proxies' implementation proofs are the EL's.
    async fn start_proxy_witness(
        &self,
        snapshot: &LandingSnapshot,
        proxy: alloy_primitives::Address,
    ) -> lander::error::Result<Option<abci::AccountWitness>> {
        self.rpc.start_proxy_witness(snapshot, proxy).await
    }
    /// The structural blocks' headers; below the start, the real EL's.
    async fn execution_header(&self, number: u64) -> lander::error::Result<Header> {
        if number < self.chain.origin {
            return self.rpc.execution_header(number).await;
        }
        self.chain.headers.get(self.chain.index(number)).cloned().ok_or_else(|| {
            lander::LanderError::Unavailable(format!("required execution history height {number}"))
        })
    }
    async fn origin_anchor(
        &self,
        snapshot: &LandingSnapshot,
    ) -> lander::error::Result<AnchorState> {
        self.rpc.origin_anchor(snapshot).await
    }
    async fn starting_inbox_witness(
        &self,
        reference: &abci::RawL1Header,
        generation: u64,
    ) -> lander::error::Result<abci::AnchorWitness> {
        self.rpc.starting_inbox_witness(reference, generation).await
    }
    async fn fallback_keys(
        &self,
        hash: alloy_primitives::B256,
        at: alloy_primitives::B256,
        at_number: u64,
        from_block: u64,
    ) -> lander::error::Result<abci::fallback::FallbackKeys> {
        self.rpc.fallback_keys(hash, at, at_number, from_block).await
    }
    /// Every structural block keeps the start's state root (see the module docs), so the real
    /// EL's proof at the start proves each block's staking words.
    async fn staking_witness(
        &self,
        _block_hash: B256,
        slots: &[B256],
    ) -> lander::error::Result<abci::AccountWitness> {
        self.rpc.staking_witness(self.chain.headers[0].hash_slow(), slots).await
    }
    async fn reference(
        &self,
        snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> lander::error::Result<Vec<abci::RawL1Header>> {
        self.rpc.reference(snapshot, anchors).await
    }
    async fn deployment(
        &self,
        snapshot: &LandingSnapshot,
    ) -> lander::error::Result<lander::l1::Deployment> {
        self.rpc.deployment(snapshot).await
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
