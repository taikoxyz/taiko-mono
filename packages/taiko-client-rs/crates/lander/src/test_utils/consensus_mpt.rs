//! Genuine trie/proof and epoch-changing fixtures for immutable batch assembly.

use super::consensus::{pair_with_envelope, parameters};
use crate::{
    batch::verify_reference_chain,
    comet::{CometSource, CometStatus},
    committee::{AuthenticatedCommittee, authenticate},
    contracts::IEtnaInbox::LandInput,
    error::{LanderError, Result},
    l1::{LandingSource, ParentContext},
    statement,
    types::{CertifiedBlock, LandingSnapshot},
};
use abci::{
    AccountWitness, AnchorState, AnchorWitness, ChainParams, CommitteeState, CommitteeWitness,
    EtnaEnvelope, ExecutionBlock, GenesisRecord, InboxFacts, ParentInfo, RawL1Header,
    RegistryEntry, Schedule, StorageProof,
    committee::{Snapshot, derive, entries_root, record_hash, snapshot_slots},
    l1::layout::{inbox, registry},
    rules::{self, HeaderInputs},
};
use alloy_consensus::{EMPTY_OMMER_ROOT_HASH, EMPTY_ROOT_HASH, Header};
use alloy_eips::eip7685::EMPTY_REQUESTS_HASH;
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_trie::{
    HashBuilder, Nibbles, TrieAccount,
    proof::{ProofNodes, ProofRetainer},
};
use async_trait::async_trait;
use ed25519_dalek::SigningKey;
use std::{
    collections::BTreeMap,
    sync::atomic::{AtomicBool, Ordering},
};

#[derive(Clone)]
struct State {
    accounts: BTreeMap<Address, (BTreeMap<B256, U256>, B256)>,
    root: B256,
}

fn trie(leaves: BTreeMap<B256, Vec<u8>>, targets: Vec<Nibbles>) -> (B256, ProofNodes) {
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(targets));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), &value);
    }
    let root = builder.root();
    (root, builder.take_proof_nodes())
}
fn nodes(proofs: &ProofNodes, key: B256) -> Vec<Bytes> {
    proofs.matching_nodes_sorted(&Nibbles::unpack(key)).into_iter().map(|(_, node)| node).collect()
}
impl State {
    fn new(accounts: Vec<(Address, Vec<(B256, U256)>)>) -> Self {
        let accounts = accounts
            .into_iter()
            .map(|(address, slots)| {
                let slots = slots
                    .into_iter()
                    .filter(|(_, value)| !value.is_zero())
                    .collect::<BTreeMap<_, _>>();
                let root = trie(
                    slots
                        .iter()
                        .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
                        .collect(),
                    vec![],
                )
                .0;
                (address, (slots, root))
            })
            .collect::<BTreeMap<_, _>>();
        let root = trie(Self::leaves(&accounts), vec![]).0;
        Self { accounts, root }
    }
    fn leaves(
        accounts: &BTreeMap<Address, (BTreeMap<B256, U256>, B256)>,
    ) -> BTreeMap<B256, Vec<u8>> {
        accounts
            .iter()
            .map(|(address, (_, root))| {
                (
                    keccak256(address),
                    alloy_rlp::encode(TrieAccount {
                        nonce: 0,
                        balance: U256::ZERO,
                        storage_root: *root,
                        code_hash: keccak256(b"test account"),
                    }),
                )
            })
            .collect()
    }
    fn witness(&self, address: Address, slots: &[B256]) -> AccountWitness {
        let (storage, root) = &self.accounts[&address];
        let (_, account_proofs) =
            trie(Self::leaves(&self.accounts), vec![Nibbles::unpack(keccak256(address))]);
        let (_, storage_proofs) = trie(
            storage
                .iter()
                .map(|(slot, value)| (keccak256(slot), alloy_rlp::encode(value)))
                .collect(),
            slots.iter().map(|slot| Nibbles::unpack(keccak256(slot))).collect(),
        );
        AccountWitness {
            address,
            nonce: 0,
            balance: U256::ZERO,
            storage_root: *root,
            code_hash: keccak256(b"test account"),
            account_proof: nodes(&account_proofs, keccak256(address)),
            storage: slots
                .iter()
                .map(|slot| StorageProof {
                    slot: *slot,
                    value: storage.get(slot).copied().unwrap_or_default(),
                    proof: nodes(&storage_proofs, keccak256(slot)),
                })
                .collect(),
        }
    }
}

pub struct Fixture {
    pub params: ChainParams,
    pub snapshot: LandingSnapshot,
    pub blocks: BTreeMap<u64, CertifiedBlock>,
    pub committees: BTreeMap<u64, AuthenticatedCommittee>,
    pub anchors: BTreeMap<u64, AnchorState>,
    pub headers: BTreeMap<u64, Header>,
    pub l1_headers: BTreeMap<u64, RawL1Header>,
    pub mismatch_statement: AtomicBool,
}

fn l1_header(number: u64, state: &State, parent: B256) -> RawL1Header {
    RawL1Header::from_raw(
        alloy_rlp::encode(Header {
            number,
            parent_hash: parent,
            state_root: state.root,
            timestamp: number,
            ..Default::default()
        })
        .into(),
    )
    .unwrap()
}
fn state(
    params: &ChainParams,
    entries: &[RegistryEntry],
    height: u64,
    hash: B256,
    committees: &BTreeMap<u64, AuthenticatedCommittee>,
) -> State {
    let mut slots = vec![
        (inbox::slot(inbox::STATUS), U256::from(3)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HASH), hash.into()),
        (
            inbox::committee_slot(0),
            record_hash(params.l2_chain_id, &committees[&0].state.record).into(),
        ),
    ];
    if height > 0 {
        slots.push((
            inbox::committee_slot(1),
            record_hash(params.l2_chain_id, &committees[&1].state.record).into(),
        ));
    }
    let checkpoint = registry::checkpoint_slots(0);
    State::new(vec![
        (params.inbox, slots),
        (
            params.registry,
            vec![
                (registry::length_slot(), U256::from(1)),
                (checkpoint[0], U256::from(1) | (U256::from(entries.len()) << 64)),
                (checkpoint[1], entries_root(entries).into()),
            ],
        ),
    ])
}
fn anchor(
    raw: &RawL1Header,
    height: u64,
    hash: B256,
    committee: Option<(u64, B256)>,
) -> AnchorState {
    AnchorState {
        number: raw.number(),
        hash: raw.hash(),
        state_root: raw.state_root(),
        timestamp: raw.timestamp(),
        inbox: InboxFacts {
            status: 3,
            recovery_generation: 0,
            last_checkpoint_height: height,
            last_checkpoint_hash: hash,
            committee,
        },
    }
}

impl Fixture {
    pub fn new(checkpoint: u64, tip: u64) -> Self {
        assert!(checkpoint == 0 || checkpoint == 20);
        let mut params = parameters();
        params.d_max = 20;
        let genesis_header = Header {
            number: 0,
            state_root: B256::repeat_byte(7),
            timestamp: 100,
            gas_limit: params.block_gas_limit,
            base_fee_per_gas: Some(1_000_000),
            ..Default::default()
        };
        let genesis = GenesisRecord {
            genesis_height: 0,
            l1_0: 10,
            epoch_len: 23,
            epoch_len_l1: 1,
            genesis_cutoff: 1,
            genesis_hash: genesis_header.hash_slow(),
            genesis_state_root: genesis_header.state_root,
        };
        let schedule = Schedule::from_genesis(&genesis);
        let keys = vec![SigningKey::from_bytes(&[1; 32]), SigningKey::from_bytes(&[2; 32])];
        let entries = keys
            .iter()
            .enumerate()
            .map(|(index, key)| RegistryEntry {
                pubkey: B256::from(key.verifying_key().to_bytes()),
                eff_stake: U256::from(if index == 0 { 3 } else { 1 }),
                active_from_l1: if index == 0 { 1 } else { 10 },
                exit_effective_l1: u64::MAX,
                last_heartbeat_at: 1,
                last_heartbeat_seq: 1,
            })
            .collect::<Vec<_>>();
        let snapshot = Snapshot { checkpoint_index: 0, l1_block: 1, entries: entries.clone() };
        let mut committees = BTreeMap::new();
        for (epoch, cutoff) in [(0, 1), (1, 10), (2, 12)] {
            let (record, members) = derive(&snapshot, cutoff, epoch, &schedule, &params).unwrap();
            let hash = record_hash(params.l2_chain_id, &record);
            committees.insert(
                epoch,
                authenticate(CommitteeState { record, members }, epoch, hash, &params).unwrap(),
            );
        }
        let genesis_state = state(&params, &entries, 0, genesis.genesis_hash, &committees);
        let raw10 = l1_header(10, &genesis_state, B256::repeat_byte(9));
        let anchor10 = anchor(&raw10, 0, genesis.genesis_hash, None);
        let mut states = BTreeMap::from([(10, genesis_state)]);
        let mut l1_headers = BTreeMap::from([(10, raw10)]);
        let mut anchors = BTreeMap::from([(0, anchor10.clone())]);
        let mut headers = BTreeMap::from([(0, genesis_header)]);
        let mut blocks = BTreeMap::new();
        let mut parent = ParentInfo {
            number: 0,
            hash: genesis.genesis_hash,
            timestamp: 100,
            gas_limit: params.block_gas_limit,
            gas_used: 0,
            base_fee: 1_000_000,
            difficulty: U256::ZERO,
            grandparent_timestamp: 0,
        };
        for height in 1..=tip {
            if checkpoint > 0 && height == 2 {
                let s = state(&params, &entries, 1, parent.hash, &committees);
                let raw = l1_header(11, &s, l1_headers[&10].hash());
                states.insert(11, s);
                l1_headers.insert(11, raw);
            }
            if checkpoint > 0 && height == 22 {
                let s = state(&params, &entries, 20, headers[&20].hash_slow(), &committees);
                let raw = l1_header(12, &s, l1_headers[&11].hash());
                states.insert(12, s);
                l1_headers.insert(12, raw);
            }
            let number = if checkpoint == 0 || height == 1 {
                10
            } else if height < 22 {
                11
            } else {
                12
            };
            let cp = if number == 10 {
                0
            } else if number == 11 {
                1
            } else {
                20
            };
            let cp_hash = headers[&cp].hash_slow();
            let forced = height == 1 || schedule.switch_target(height).is_some();
            let changing = anchors[&(height - 1)].number != number;
            let switch = schedule.switch_target(height);
            let raw = &l1_headers[&number];
            let a = anchor(
                raw,
                cp,
                cp_hash,
                switch.map(|epoch| {
                    (epoch, record_hash(params.l2_chain_id, &committees[&epoch].state.record))
                }),
            );
            let witness = (forced || changing).then(|| AnchorWitness {
                l1_header: raw.clone(),
                inbox: states[&number].witness(params.inbox, &inbox::anchor_slots(switch)),
            });
            let committee = schedule.epoch_starting_at(height).map(|epoch| {
                let target = epoch + 1;
                let parent_anchor = &anchors[&(height - 1)];
                CommitteeWitness {
                    record: committees[&target].state.record.clone(),
                    registry: states[&parent_anchor.number]
                        .witness(params.registry, &snapshot_slots(0, false)),
                    entries: entries.clone(),
                }
            });
            let expected = rules::expected_header(&HeaderInputs {
                height,
                parent: &parent,
                anchor: &a,
                bft_time_secs: 100 + height,
                generation: 0,
                params: &params,
                min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(
                    params.l2_chain_id,
                ),
            })
            .unwrap();
            let el = Header {
                number: height,
                parent_hash: expected.parent_hash,
                state_root: B256::from(U256::from(height + 100)),
                timestamp: expected.timestamp,
                beneficiary: expected.beneficiary,
                extra_data: expected.extra_data,
                parent_beacon_block_root: Some(expected.parent_beacon_block_root),
                gas_limit: expected.gas_limit,
                base_fee_per_gas: Some(expected.base_fee),
                mix_hash: expected.mix_hash,
                withdrawals_root: Some(EMPTY_ROOT_HASH),
                blob_gas_used: Some(0),
                excess_blob_gas: Some(0),
                requests_hash: Some(EMPTY_REQUESTS_HASH),
                ommers_hash: EMPTY_OMMER_ROOT_HASH,
                ..Default::default()
            };
            let mut pair = pair_with_envelope(
                EtnaEnvelope {
                    block: ExecutionBlock { header: el.clone(), transactions: vec![] },
                    anchor: witness,
                    committee,
                },
                &committees[&schedule.epoch_of(height)],
                &keys,
                blocks.get(&(height - 1)),
            );
            pair.block.header.next_validators_hash =
                committees[&schedule.epoch_of(height + 1)].validators.hash();
            pair.commit.block_id.part_set_header = crate::validate::block_parts(&pair.block);
            super::consensus::resign(&mut pair, &committees[&schedule.epoch_of(height)], &keys);
            parent = ParentInfo {
                number: height,
                hash: el.hash_slow(),
                timestamp: el.timestamp,
                gas_limit: el.gas_limit,
                gas_used: el.gas_used,
                base_fee: el.base_fee_per_gas.unwrap(),
                difficulty: el.difficulty,
                grandparent_timestamp: parent.timestamp,
            };
            anchors.insert(height, a);
            headers.insert(height, el);
            blocks.insert(height, pair);
        }
        let last = *l1_headers.last_key_value().unwrap().0;
        let root_state = states[&last].clone();
        for number in last + 1..=15 {
            let raw = l1_header(number, &root_state, l1_headers[&(number - 1)].hash());
            l1_headers.insert(number, raw);
        }
        let landing = LandingSnapshot {
            l1_block_hash: l1_headers[&15].hash(),
            l1_block_number: 15,
            l1_chain_id: U256::from(1),
            l2_chain_id: params.l2_chain_id,
            inbox: params.inbox,
            registry: params.registry,
            generation: 0,
            checkpoint_height: checkpoint,
            checkpoint_hash: headers[&checkpoint].hash_slow(),
            genesis,
            start_committee_record_hash: record_hash(
                params.l2_chain_id,
                &committees[&0].state.record,
            ),
        };
        Self {
            params,
            snapshot: landing,
            blocks,
            committees,
            anchors,
            headers,
            l1_headers,
            mismatch_statement: AtomicBool::new(false),
        }
    }
}

#[async_trait]
impl CometSource for Fixture {
    async fn status(&self) -> Result<CometStatus> {
        Ok(CometStatus {
            chain_id: rules::chain_id_for(self.params.l2_chain_id, 0),
            height: *self.blocks.last_key_value().unwrap().0,
        })
    }
    async fn block(&self, height: u64) -> Result<CertifiedBlock> {
        self.blocks
            .get(&height)
            .cloned()
            .ok_or_else(|| LanderError::Unavailable(format!("height {height} pruned")))
    }
    async fn committee(&self, epoch: u64) -> Result<CommitteeState> {
        self.committees
            .get(&epoch)
            .map(|committee| committee.state.clone())
            .ok_or_else(|| LanderError::Unavailable(format!("committee epoch {epoch}")))
    }
}
#[async_trait]
impl LandingSource for Fixture {
    async fn snapshot(&self) -> Result<LandingSnapshot> {
        Ok(self.snapshot.clone())
    }
    async fn parent_header(&self, snapshot: &LandingSnapshot) -> Result<ParentContext> {
        Ok(ParentContext {
            header: self.headers[&snapshot.checkpoint_height].clone(),
            grandparent_timestamp: if snapshot.checkpoint_height == 0 {
                0
            } else {
                self.headers[&(snapshot.checkpoint_height - 1)].timestamp
            },
        })
    }
    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        _parent: &ParentContext,
    ) -> Result<AnchorState> {
        Ok(self.anchors[&snapshot.checkpoint_height].clone())
    }
    async fn committee_hash(&self, snapshot: &LandingSnapshot, epoch: u64) -> Result<B256> {
        Ok(if epoch == 0 || (epoch == 1 && snapshot.checkpoint_height > 0) {
            record_hash(self.params.l2_chain_id, &self.committees[&epoch].state.record)
        } else {
            B256::ZERO
        })
    }
    async fn reference(
        &self,
        _snapshot: &LandingSnapshot,
        anchors: &[AnchorState],
    ) -> Result<Vec<RawL1Header>> {
        let min = anchors.iter().map(|anchor| anchor.number).min().unwrap();
        let headers =
            (min..=14).rev().map(|number| self.l1_headers[&number].clone()).collect::<Vec<_>>();
        verify_reference_chain(&headers, anchors)?;
        Ok(headers)
    }
    async fn statement_hash(
        &self,
        snapshot: &LandingSnapshot,
        input: &LandInput,
        reference: B256,
        blobs: &[B256],
    ) -> Result<B256> {
        Ok(if self.mismatch_statement.load(Ordering::Relaxed) {
            B256::ZERO
        } else {
            statement::hash(snapshot, input, reference, blobs)
        })
    }
    async fn canonical_hash(&self, number: u64) -> Result<B256> {
        Ok(self.l1_headers[&number].hash())
    }
    async fn validate_reference(
        &self,
        snapshot: &LandingSnapshot,
        number: u64,
        hash: B256,
    ) -> Result<()> {
        if number >= snapshot.l1_block_number || self.l1_headers[&number].hash() != hash {
            Err(LanderError::Safety("reference mismatch".into()))
        } else {
            Ok(())
        }
    }
}
