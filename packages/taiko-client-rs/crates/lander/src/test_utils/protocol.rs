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
        genesis_height: 0,
        l1_0: 10,
        epoch_len: 20,
        epoch_len_l1: 1,
        genesis_hash: B256::repeat_byte(1),
        genesis_state_root: B256::repeat_byte(2),
        genesis_cutoff: 9,
    };
    let anchor = AnchorState {
        number: 10,
        hash: B256::repeat_byte(3),
        state_root: B256::repeat_byte(4),
        timestamp: 20,
        inbox: InboxFacts {
            status: 3,
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: genesis.genesis_hash,
            committee: None,
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
                generation: 0,
                checkpoint_height: 0,
                checkpoint_hash: genesis.genesis_hash,
                genesis,
                start_committee_record_hash: B256::repeat_byte(6),
            },
            parent_header: Header::default(),
            grandparent_timestamp: 0,
            parent_anchor: anchor,
            blocks: vec![],
            anchors: vec![],
            reference_headers: vec![],
            committees: vec![],
            input: LandInput {
                lastHeight: 1,
                lastBlockHash: B256::repeat_byte(7),
                lastStateRoot: B256::repeat_byte(8),
                l1ReferenceBlockNumber: 15,
                records: vec![],
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
