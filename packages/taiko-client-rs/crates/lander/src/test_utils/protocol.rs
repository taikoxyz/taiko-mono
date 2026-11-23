use crate::{
    blob::PreparedBlobs,
    contracts::IEtnaInbox::LandInput,
    proof::ProofRequest,
    types::{LandingSnapshot, PreparedBatch},
};
use abci::{AnchorState, GenesisRecord, InboxFacts};
use alloy_consensus::Header;
use alloy_eips::{eip4844::BlobTransactionSidecar, eip7594::BlobTransactionSidecarVariant};
use alloy_primitives::{Address, B256, U256};

pub(crate) fn request() -> ProofRequest {
    let genesis = GenesisRecord {
        config_hash: B256::repeat_byte(3),
        genesis_height: 0,
        l1_0: 10,
        genesis_hash: B256::repeat_byte(1),
        genesis_state_root: B256::repeat_byte(2),
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
            fallback_keys_hash: B256::ZERO,
            min_total_stake: alloy_primitives::U256::ZERO,
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
                recovery: None,
                recovery_witness: None,
                generation: 0,
                checkpoint_height: 0,
                checkpoint_hash: genesis.genesis_hash,
                checkpoint_comet_hash: B256::ZERO,
                forced_inclusion_head: 0,
                forced_inclusion_tail: 0,
                genesis,
                config_hash: B256::repeat_byte(3),
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
            p_anchor_witness: None,
            start_signal_service_witness: None,
            blocks: vec![],
            anchors: vec![],
            reference_headers: vec![],
            leaves: vec![],
            commit_heights: vec![1],
            input: LandInput {
                parentHeight: U256::ZERO,
                lastCometHash: B256::repeat_byte(7),
                lastHeight: U256::from(1),
                lastBlockHash: B256::repeat_byte(7),
                lastStateRoot: B256::repeat_byte(8),
                l1ReferenceBlockNumber: U256::from(15),
                forcedInclusionHead: U256::ZERO,
            },
            blobs: PreparedBlobs {
                payload_bytes: 0,
                sidecar: BlobTransactionSidecarVariant::Eip4844(BlobTransactionSidecar::default()),
                versioned_hashes: vec![],
            },
            statement_hash: B256::repeat_byte(9),
        },
    }
}
