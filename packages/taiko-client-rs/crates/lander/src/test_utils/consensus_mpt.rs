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
    committee::{
        Snapshot, committee_config_hash, derive, entries_root, record_hash, snapshot_slots,
    },
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
    pub reject_committee_hints: bool,
    pub witness_mutation: Option<u8>,
    pub starting_proof_mutation: Option<u8>,
    pub parent_anchor_override: Option<AnchorState>,
    states: BTreeMap<u64, State>,
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
    genesis: &GenesisRecord,
) -> State {
    state_with_queue(params, entries, height, hash, committees, genesis, (0, 0))
}
/// As [`state`], with the forced inclusion queue's `(head, tail)` planted at slot 281.
fn state_with_queue(
    params: &ChainParams,
    entries: &[RegistryEntry],
    height: u64,
    hash: B256,
    committees: &BTreeMap<u64, AuthenticatedCommittee>,
    genesis: &GenesisRecord,
    (head, tail): (u64, u64),
) -> State {
    let mut slots = vec![
        (inbox::slot(inbox::STATUS), U256::from(3)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height)),
        (inbox::slot(inbox::LAST_CHECKPOINT_HASH), hash.into()),
        (
            inbox::slot(inbox::GENESIS_COMMITTEE_HASH),
            record_hash(params.l2_chain_id, &committees[&0].state.record).into(),
        ),
    ];
    slots.extend([
        (inbox::slot(inbox::COMMITTEE_CONFIG_HASH), genesis.committee_config_hash.into()),
        (
            inbox::slot(inbox::GENESIS_PACKED),
            U256::from(genesis.l1_0) << 64 |
                U256::from(genesis.epoch_len) << 128 |
                U256::from(genesis.epoch_len_l1) << 192,
        ),
        (inbox::slot(inbox::GENESIS_BLOCK_HASH), genesis.genesis_hash.into()),
        (inbox::slot(inbox::GENESIS_STATE_ROOT), genesis.genesis_state_root.into()),
        (inbox::slot(inbox::GENESIS_CUTOFF), U256::from(genesis.genesis_cutoff)),
        (
            inbox::slot(inbox::FORCED_INCLUSION_CONFIG),
            U256::from(genesis.forced_inclusion_delay) | U256::from(genesis.max_anchor_age) << 64,
        ),
        (inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL), U256::from(head) | U256::from(tail) << 48),
    ]);
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
fn anchor(raw: &RawL1Header, height: u64, hash: B256) -> AnchorState {
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
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
        },
    }
}

impl Fixture {
    /// The landing snapshot re-planted with the genesis record `genesis` and the forced
    /// inclusion queue's `(head, tail)` at slot 281: the same checkpoint in a fresh snapshot block
    /// over the same parent, with its proof.
    pub fn snapshot_with_forced_queue(
        &self,
        genesis: GenesisRecord,
        head: u64,
        tail: u64,
    ) -> LandingSnapshot {
        let state = state_with_queue(
            &self.params,
            &self.registry_entries(),
            self.snapshot.checkpoint_height,
            self.snapshot.checkpoint_hash,
            &self.committees,
            &genesis,
            (head, tail),
        );
        let number = self.snapshot.l1_block_number;
        let header = l1_header(number, &state, self.l1_headers[&(number - 1)].hash());
        LandingSnapshot {
            l1_block_hash: header.hash(),
            forced_inclusion_head: head,
            forced_inclusion_tail: tail,
            inbox_witness: state.witness(self.params.inbox, &crate::l1::snapshot_slots()),
            l1_header: header,
            genesis,
            ..self.snapshot.clone()
        }
    }

    fn registry_entries(&self) -> Vec<RegistryEntry> {
        [1u8, 2]
            .into_iter()
            .enumerate()
            .map(|(index, seed)| RegistryEntry {
                pubkey: B256::from(SigningKey::from_bytes(&[seed; 32]).verifying_key().to_bytes()),
                eff_stake: U256::from(if index == 0 { 3 } else { 1 }),
                active_from_l1: if index == 0 { 1 } else { 10 },
                exit_effective_l1: u64::MAX,
                last_heartbeat_at: 1,
                last_heartbeat_seq: 1,
            })
            .collect()
    }
    pub fn new(checkpoint: u64, tip: u64) -> Self {
        Self::with_calldata(checkpoint, tip, 0)
    }

    fn with_calldata(checkpoint: u64, tip: u64, bytes: usize) -> Self {
        Self::with_epoch(checkpoint, tip, bytes, 23)
    }

    pub fn with_epoch(checkpoint: u64, tip: u64, bytes: usize, epoch_len: u64) -> Self {
        Self::build(checkpoint, tip, bytes, epoch_len, 7_200)
    }

    /// As [`Fixture::new`], with the genesis `maxAnchorAge` set to `max_anchor_age` seconds.
    /// Block `h` is at `100 + h` s and anchor `n` at `n` s, so the blocks of a genesis
    /// checkpoint (all anchored at 10) are `90 + h` s younger than their anchor.
    pub fn with_max_anchor_age(checkpoint: u64, tip: u64, max_anchor_age: u64) -> Self {
        Self::build(checkpoint, tip, 0, 23, max_anchor_age)
    }

    /// Builds the decided chain up to `tip` over the genesis `maxAnchorAge` `max_anchor_age`.
    fn build(checkpoint: u64, tip: u64, bytes: usize, epoch_len: u64, max_anchor_age: u64) -> Self {
        assert!(checkpoint == 0 || checkpoint >= epoch_len - 3);
        let mut params = parameters();
        params.d_max = epoch_len - 3;
        let genesis_header = Header {
            number: 0,
            state_root: B256::repeat_byte(7),
            timestamp: 100,
            gas_limit: params.block_gas_limit,
            base_fee_per_gas: Some(1_000_000),
            ..Default::default()
        };
        let genesis = GenesisRecord {
            committee_config_hash: committee_config_hash(&params),
            genesis_height: 0,
            l1_0: 10,
            epoch_len,
            epoch_len_l1: 1,
            genesis_cutoff: 1,
            genesis_hash: genesis_header.hash_slow(),
            genesis_state_root: genesis_header.state_root,
            forced_inclusion_delay: 3_600,
            max_anchor_age,
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
        for epoch in 0..=3 {
            let cutoff = if epoch == 0 {
                genesis.genesis_cutoff
            } else if epoch == 1 {
                11
            } else {
                12
            };
            let (record, members) = derive(&snapshot, cutoff, epoch, &schedule, &params).unwrap();
            let hash = record_hash(params.l2_chain_id, &record);
            committees.insert(
                epoch,
                authenticate(CommitteeState { record, members }, epoch, hash, &params).unwrap(),
            );
        }
        let genesis_state =
            state(&params, &entries, 0, genesis.genesis_hash, &committees, &genesis);
        let raw10 = l1_header(10, &genesis_state, B256::repeat_byte(9));
        let anchor10 = anchor(&raw10, 0, genesis.genesis_hash);
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
                let s = state(&params, &entries, 1, parent.hash, &committees, &genesis);
                let raw = l1_header(11, &s, l1_headers[&10].hash());
                states.insert(11, s);
                l1_headers.insert(11, raw);
            }
            if checkpoint > 0 && height == epoch_len - 1 {
                let s = state(
                    &params,
                    &entries,
                    epoch_len - 3,
                    headers[&(epoch_len - 3)].hash_slow(),
                    &committees,
                    &genesis,
                );
                let raw = l1_header(12, &s, l1_headers[&11].hash());
                states.insert(12, s);
                l1_headers.insert(12, raw);
            }
            let number = if checkpoint == 0 || height == 1 {
                10
            } else if height < epoch_len - 1 {
                11
            } else {
                12
            };
            let cp = if number == 10 {
                0
            } else if number == 11 {
                1
            } else {
                epoch_len - 3
            };
            let cp_hash = headers[&cp].hash_slow();
            let forced = height == 1;
            let changing = anchors[&(height - 1)].number != number;
            let raw = &l1_headers[&number];
            let a = anchor(raw, cp, cp_hash);
            let witness = (forced || changing).then(|| AnchorWitness {
                l1_header: raw.clone(),
                inbox: states[&number].witness(params.inbox, &inbox::anchor_slots()),
            });
            let committee = schedule.switch_target(height).map(|target| {
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
            let transactions = if bytes == 0 {
                vec![]
            } else {
                use alloy::signers::SignerSync;
                use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope};
                use alloy_eips::eip2718::Encodable2718;
                let tx = TxEip1559 {
                    chain_id: params.l2_chain_id,
                    nonce: height - 1,
                    gas_limit: 2_000_000,
                    max_fee_per_gas: 1_000_001,
                    max_priority_fee_per_gas: 1,
                    to: alloy_primitives::TxKind::Call(params.fee_vault),
                    input: Bytes::from(vec![0x2a; bytes]),
                    ..Default::default()
                };
                let signature =
                    super::runtime::signer().sign_hash_sync(&tx.signature_hash()).unwrap();
                vec![Bytes::from(TxEnvelope::Eip1559(tx.into_signed(signature)).encoded_2718())]
            };
            let el = Header {
                transactions_root: alloy_trie::root::ordered_trie_root_encoded(&transactions),
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
                    block: ExecutionBlock { header: el.clone(), transactions },
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
        let snapshot_state = state(
            &params,
            &entries,
            checkpoint,
            headers[&checkpoint].hash_slow(),
            &committees,
            &genesis,
        );
        let snapshot_header = l1_header(15, &snapshot_state, l1_headers[&14].hash());
        l1_headers.insert(15, snapshot_header.clone());
        let landing = LandingSnapshot {
            l1_block_hash: snapshot_header.hash(),
            l1_block_number: 15,
            l1_chain_id: U256::from(1),
            l2_chain_id: params.l2_chain_id,
            inbox: params.inbox,
            registry: params.registry,
            generation: 0,
            checkpoint_height: checkpoint,
            checkpoint_hash: headers[&checkpoint].hash_slow(),
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
            committee_config_hash: genesis.committee_config_hash,
            genesis_committee_record_hash: record_hash(
                params.l2_chain_id,
                &committees[&0].state.record,
            ),
            l1_header: snapshot_header,
            inbox_witness: snapshot_state.witness(params.inbox, &crate::l1::snapshot_slots()),
            genesis,
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
            reject_committee_hints: false,
            witness_mutation: None,
            starting_proof_mutation: None,
            parent_anchor_override: None,
            states,
        }
    }
}

#[async_trait]
impl CometSource for Fixture {
    async fn status(&self) -> Result<CometStatus> {
        Ok(CometStatus {
            chain_id: rules::chain_id_for(self.params.l2_chain_id, 0),
            height: *self.headers.last_key_value().unwrap().0,
        })
    }
    async fn block(&self, height: u64) -> Result<CertifiedBlock> {
        self.blocks
            .get(&height)
            .cloned()
            .ok_or_else(|| LanderError::Unavailable(format!("height {height} pruned")))
    }
    async fn committee(&self, epoch: u64) -> Result<CommitteeState> {
        assert!(!self.reject_committee_hints, "a Comet committee hint cannot be authority");
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
    async fn execution_header(&self, number: u64) -> Result<Header> {
        self.headers.get(&number).cloned().ok_or_else(|| {
            LanderError::Unavailable(format!(
                "required execution history height {number} unavailable"
            ))
        })
    }
    async fn parent_anchor(
        &self,
        snapshot: &LandingSnapshot,
        parent: &ParentContext,
    ) -> Result<AnchorState> {
        if let Some(anchor) = &self.parent_anchor_override {
            return Ok(anchor.clone());
        }
        let number = if parent.header.number == 0 {
            snapshot.genesis.l1_0
        } else {
            let (_, generation, number) = rules::decode_extra_data(&parent.header.extra_data)
                .map_err(|e| LanderError::Safety(e.to_string()))?;
            if generation != snapshot.generation {
                return Err(LanderError::Safety("anchor generation mismatch".into()));
            }
            number
        };
        let witness = AnchorWitness {
            l1_header: self.l1_headers[&number].clone(),
            inbox: self.states[&number].witness(self.params.inbox, &inbox::anchor_slots()),
        };
        let anchor = abci::l1::verify_anchor_witness(&witness, self.params.inbox)
            .map_err(|e| LanderError::Safety(e.to_string()))?;
        if parent.header.number != 0 &&
            parent.header.parent_beacon_block_root != Some(anchor.state_root)
        {
            return Err(LanderError::Safety("parent anchor root mismatch".into()));
        }
        Ok(anchor)
    }
    async fn starting_inbox_witness(&self, anchor: &AnchorState) -> Result<AnchorWitness> {
        let mut witness =
            self.states[&anchor.number].witness(self.params.inbox, &crate::l1::snapshot_slots());
        match self.starting_proof_mutation {
            Some(0) => {
                witness.storage.retain(|s| s.slot != inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT))
            }
            Some(1) => {
                if let Some(proof) = witness
                    .storage
                    .iter_mut()
                    .find(|s| s.slot == inbox::slot(inbox::LAST_CHECKPOINT_HASH))
                {
                    proof.value += U256::from(1);
                }
            }
            _ => {}
        }
        Ok(AnchorWitness { l1_header: self.l1_headers[&anchor.number].clone(), inbox: witness })
    }
    async fn committee_witness(
        &self,
        _: &LandingSnapshot,
        anchor: &AnchorState,
        _snapshot_number: u64,
        epoch: u64,
    ) -> Result<CommitteeWitness> {
        let mut witness = CommitteeWitness {
            record: self.committees[&epoch].state.record.clone(),
            registry: self.states[&anchor.number]
                .witness(self.params.registry, &snapshot_slots(0, false)),
            entries: self.registry_entries(),
        };
        match self.witness_mutation {
            Some(0) => witness.registry.address = Address::ZERO,
            Some(1) => witness.registry.storage_root = B256::ZERO,
            Some(2) => witness.entries[0].eff_stake += U256::from(1),
            Some(3) => witness.record.cutoff_l1_block += 1,
            _ => {}
        }
        Ok(witness)
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

#[cfg(test)]
mod readiness {
    use super::*;
    use crate::{
        batch::{BatchBuilder, BatchSource},
        blob, codec,
        types::{Limits, SidecarMode},
    };
    use std::sync::Arc;

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

    fn advance_checkpoint(fixture: &mut Fixture, height: u64) {
        fixture.snapshot.checkpoint_height = height;
        fixture.snapshot.checkpoint_hash = fixture.headers[&height].hash_slow();
        // The current L1 state has advanced while the tip still consumes its older L1 anchor.
        let mut accounts = fixture.states.last_key_value().unwrap().1.accounts.clone();
        let slots = &mut accounts.get_mut(&fixture.params.inbox).unwrap().0;
        slots.insert(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(height));
        slots.insert(
            inbox::slot(inbox::LAST_CHECKPOINT_HASH),
            fixture.snapshot.checkpoint_hash.into(),
        );
        let state = State::new(
            accounts
                .into_iter()
                .map(|(address, (slots, _))| (address, slots.into_iter().collect()))
                .collect(),
        );
        let number = fixture.snapshot.l1_block_number;
        let raw = l1_header(number, &state, fixture.l1_headers[&(number - 1)].hash());
        fixture.snapshot.l1_block_hash = raw.hash();
        fixture.snapshot.l1_header = raw.clone();
        fixture.snapshot.inbox_witness =
            state.witness(fixture.params.inbox, &crate::l1::snapshot_slots());
        fixture.states.insert(number, state);
        fixture.l1_headers.insert(number, raw);
    }

    #[tokio::test]
    async fn no_backlog_has_no_publishable_blocks_or_urgent_flags() {
        for checkpoint in [0, 20] {
            let fixture = Arc::new(Fixture::new(checkpoint, checkpoint));
            let observed =
                builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
            assert_eq!(observed.decided_height, checkpoint);
            assert_eq!(observed.publishable_blocks, 0);
            assert!(!observed.force_backpressure);
            assert!(!observed.force_epoch);
        }
    }

    #[tokio::test]
    async fn epoch_first_height_has_no_publication_urgency() {
        let mut fixture = Fixture::new(0, 3);
        fixture.l1_headers.remove(&14);
        fixture.mismatch_statement.store(true, Ordering::Relaxed);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.decided_height, 3);
        assert_eq!(observed.publishable_blocks, 3);
        assert!(!observed.force_backpressure);
        assert!(!observed.force_epoch);
    }

    #[tokio::test]
    async fn pressure_uses_tip_authenticated_anchor_instead_of_latest_checkpoint() {
        let mut fixture = Fixture::new(20, 20);
        advance_checkpoint(&mut fixture, 19);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.publishable_blocks, 1);
        // U=20, tip=20, tip anchor CP=1: depth 19 forces publication despite latest CP=19.
        assert!(observed.force_backpressure);
        assert!(!observed.force_epoch);
    }

    #[tokio::test]
    async fn pressure_below_unsettled_cap_minus_one_allows_waiting() {
        let mut fixture = Fixture::new(20, 20);
        fixture.blocks.remove(&20);
        fixture.headers.remove(&20);
        advance_checkpoint(&mut fixture, 18);
        let fixture = Arc::new(fixture);
        let observed =
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await.unwrap();
        // U=20, tip=19, tip anchor CP=1: depth 18 stays below the urgent threshold.
        assert_eq!(observed.decided_height, 19);
        assert_eq!(observed.publishable_blocks, 1);
        assert!(!observed.force_backpressure);
        assert!(!observed.force_epoch);
    }

    #[tokio::test]
    async fn epoch_first_height_outside_blob_prefix_forces_publication_without_pressure() {
        let fixture = Arc::new(Fixture::with_calldata(20, 26, 70_000));
        let mut bound = limits(6);
        bound.max_blobs = 1;
        let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.decided_height, 26);
        assert_eq!(observed.publishable_blocks, 1);
        assert!(observed.force_epoch); // h_first(1)=24 is beyond the single-block prefix at 21.
        assert!(!observed.force_backpressure); // The tip anchor CP=20 gives depth 6 < 19.
        let request = builder(fixture.clone(), bound)
            .prepare(fixture.snapshot.clone())
            .await
            .unwrap()
            .unwrap();
        assert_eq!(request.batch.input.lastHeight, 21);
    }

    #[tokio::test]
    async fn observation_counts_the_same_blob_and_codec_bounded_prefix_as_prepare() {
        let fixture = Arc::new(Fixture::with_calldata(0, 3, 70_000));
        let mut bound = limits(3);
        bound.max_blobs = 1;
        let observed = builder(fixture.clone(), bound).observe(&fixture.snapshot).await.unwrap();
        assert_eq!(observed.publishable_blocks, 1);
        let first = codec::encode(&[fixture.blocks[&1].clone()], &bound).unwrap();
        assert_eq!(blob::required_blobs(first.len()), 1);
        bound.max_payload_bytes = first.len() - 1;
        assert!(matches!(
            builder(fixture.clone(), bound).observe(&fixture.snapshot).await,
            Err(LanderError::Capacity(_))
        ));
        bound = limits(3);
        bound.max_blocks = 2;
        assert_eq!(
            builder(fixture.clone(), bound)
                .observe(&fixture.snapshot)
                .await
                .unwrap()
                .publishable_blocks,
            2
        );
        bound.max_message_bytes = 1;
        assert!(matches!(
            builder(fixture.clone(), bound).observe(&fixture.snapshot).await,
            Err(LanderError::Capacity(_))
        ));
    }

    #[tokio::test]
    async fn tip_body_and_certificate_are_authenticated_beyond_selected_prefix() {
        let mut fixture = Fixture::new(20, 26);
        fixture.blocks.get_mut(&26).unwrap().block.data[0].push(0);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
        let mut fixture = Fixture::new(20, 26);
        fixture
            .blocks
            .get_mut(&26)
            .unwrap()
            .commit
            .signatures
            .fill(tendermint::block::CommitSig::BlockIdFlagAbsent);
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }

    #[tokio::test]
    async fn observation_rejects_certified_rpc_block_from_another_height() {
        let mut fixture = Fixture::new(20, 26);
        fixture.blocks.insert(21, fixture.blocks[&22].clone());
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(1)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
        assert!(matches!(
            builder(fixture.clone(), limits(1)).prepare(fixture.snapshot.clone()).await,
            Err(LanderError::Safety(_))
        ));
    }

    #[tokio::test]
    async fn pressure_rejects_anchor_mpt_root_that_differs_from_certified_tip() {
        let mut fixture = Fixture::new(20, 20);
        advance_checkpoint(&mut fixture, 19);
        let state = fixture.states[&10].clone();
        fixture.states.insert(11, state.clone());
        fixture.l1_headers.insert(11, l1_header(11, &state, fixture.l1_headers[&10].hash()));
        let fixture = Arc::new(fixture);
        assert!(matches!(
            builder(fixture.clone(), limits(3)).observe(&fixture.snapshot).await,
            Err(LanderError::Safety(_))
        ));
    }
}
