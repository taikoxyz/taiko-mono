use crate::{
    blob::PreparedBlobs,
    contracts::IEtnaInbox::LandInput,
    proof::ProofRequest,
    types::{LandingSnapshot, PreparedBatch},
};
use abci::{AnchorState, GenesisRecord, InboxFacts, valstate::ValState};
use alloy_consensus::Header;
use alloy_eips::{eip4844::BlobTransactionSidecar, eip7594::BlobTransactionSidecarVariant};
use alloy_primitives::{Address, B256, U256};

pub(crate) fn request() -> ProofRequest {
    let genesis = GenesisRecord {
        committee_config_hash: B256::repeat_byte(3),
        genesis_height: 0,
        l1_0: 10,
        epoch_len: 20,
        genesis_hash: B256::repeat_byte(1),
        genesis_state_root: B256::repeat_byte(2),
        genesis_cutoff: 9,
        forced_inclusion_delay: 3_600,
        max_anchor_age: 7_200,
    };
    let anchor = AnchorState {
        number: 10,
        hash: B256::repeat_byte(3),
        state_root: B256::repeat_byte(4),
        timestamp: 20,
        inbox: InboxFacts {
            rules_schedule: alloy_primitives::U256::ZERO,
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: genesis.genesis_hash,
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
        },
    };
    ProofRequest {
        batch: PreparedBatch {
            snapshot: LandingSnapshot {
                l1_block_hash: B256::repeat_byte(5),
                l1_block_number: 20,
                l1_chain_id: U256::from(1),
                l2_chain_id: 167001,
                inbox: Address::repeat_byte(0x11),
                registry: Address::repeat_byte(0x22),
                recovery: None,
                recovery_witness: None,
                generation: 0,
                checkpoint_height: 0,
                checkpoint_hash: genesis.genesis_hash,
                checkpoint_comet_hash: B256::ZERO,
                checkpoint_val_state_hash: B256::ZERO,
                forced_inclusion_head: 0,
                forced_inclusion_tail: 0,
                genesis,
                committee_config_hash: B256::repeat_byte(3),
                genesis_committee_record_hash: B256::repeat_byte(6),
                l1_header: abci::RawL1Header::from(&Header::default()),
                inbox_witness: abci::AccountWitness {
                    address: alloy_primitives::Address::ZERO,
                    nonce: 0,
                    balance: U256::ZERO,
                    storage_root: B256::ZERO,
                    code_hash: B256::ZERO,
                    account_proof: vec![],
                    storage: vec![],
                },
            },
            parent_header: Header::default(),
            execution_history: vec![],
            grandparent_timestamp: 0,
            parent_anchor: anchor,
            starting_inbox_witness: abci::AnchorWitness {
                l1_header: abci::RawL1Header::from(&Header::default()),
                inbox: abci::AccountWitness {
                    address: Address::ZERO,
                    nonce: 0,
                    balance: U256::ZERO,
                    storage_root: B256::ZERO,
                    code_hash: B256::ZERO,
                    account_proof: vec![],
                    storage: vec![],
                },
            },
            blocks: vec![],
            anchors: vec![],
            reference_headers: vec![],
            committees: vec![],
            committee_witnesses: vec![],
            leaves: vec![],
            input: LandInput {
                parentHeight: U256::ZERO,
                lastCometHash: B256::repeat_byte(7),
                lastHeight: U256::from(1),
                lastBlockHash: B256::repeat_byte(7),
                lastValStateHash: B256::repeat_byte(0x0a),
                lastStateRoot: B256::repeat_byte(8),
                l1ReferenceBlockNumber: U256::from(15),
                forcedInclusionHead: U256::ZERO,
                activeCommitteeSnapshot: U256::from(9),
            },
            start_val_state: ValState::genesis(
                0,
                &[(
                    super::consensus::public_key(
                        &super::consensus::SigningKey::from_slice(&[1; 32]).unwrap(),
                    ),
                    1,
                )],
            )
            .unwrap(),
            blobs: PreparedBlobs {
                payload_bytes: 0,
                sidecar: BlobTransactionSidecarVariant::Eip4844(BlobTransactionSidecar::default()),
                versioned_hashes: vec![],
            },
            statement_hash: B256::repeat_byte(9),
        },
    }
}
