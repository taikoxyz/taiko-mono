use crate::types::CertifiedBlock;
use abci::{EtnaEnvelope, ExecutionBlock};
use alloy_consensus::Header as ElHeader;
use tendermint::{
    Hash, Time,
    block::{Commit, Header, Id},
};

pub(crate) fn block(height: u64) -> CertifiedBlock {
    let envelope = EtnaEnvelope {
        block: ExecutionBlock {
            header: ElHeader { number: height, ..Default::default() },
            transactions: vec![],
        },
        anchor: None,
        committee: None,
    }
    .encode()
    .to_vec();
    let header = Header {
        version: tendermint::block::header::Version { block: 11, app: 0 },
        chain_id: "taiko-etna-167001-g0".parse().unwrap(),
        height: height.try_into().unwrap(),
        time: Time::from_unix_timestamp(1_700_000_000 + height as i64, 0).unwrap(),
        last_block_id: None,
        last_commit_hash: None,
        data_hash: Some(Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<
            tendermint::crypto::default::Sha256,
        >(std::slice::from_ref(&envelope)))),
        validators_hash: Hash::Sha256([0x11; 32]),
        next_validators_hash: Hash::Sha256([0x11; 32]),
        consensus_hash: Hash::Sha256([0x22; 32]),
        app_hash: vec![0x33; 32].try_into().unwrap(),
        last_results_hash: None,
        evidence_hash: None,
        proposer_address: tendermint::account::Id::new([0x44; 20]),
    };
    let commit = Commit {
        height: header.height,
        round: 0u8.into(),
        block_id: Id { hash: header.hash(), ..Default::default() },
        signatures: vec![],
    };
    CertifiedBlock {
        block: tendermint::Block::new(header, vec![envelope], Default::default(), None),
        commit,
    }
}
