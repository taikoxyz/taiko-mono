//! Codec- and KZG-bound immutable jobs and deterministic blob transaction signatures.
use crate::{
    blob, codec,
    contracts::IEtnaInbox::landCall,
    proof::ProofRequest,
    statement,
    tx::SignedTransaction,
    types::{Limits, SidecarMode},
};
use abci::l1::header::RawL1Header;
use alloy::{
    signers::{Signer, local::PrivateKeySigner},
    sol_types::SolCall,
};
use alloy_consensus::{
    Header, SignableTransaction, TxEip4844, TxEip4844Variant, TxEip4844WithSidecar, TxEnvelope,
};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{Bytes, U256};

pub(crate) fn signer() -> PrivateKeySigner {
    "0000000000000000000000000000000000000000000000000000000000000001".parse().unwrap()
}

pub(crate) fn request() -> ProofRequest {
    let mut request = super::protocol::request();
    let (params, committee, keys) = super::consensus::committee(&[3, 3, 3], 0);
    request.batch.snapshot.inbox = params.inbox;
    request.batch.snapshot.registry = params.registry;
    request.batch.snapshot.committee_config_hash = abci::committee::committee_config_hash(&params);
    request.batch.snapshot.genesis.committee_config_hash =
        request.batch.snapshot.committee_config_hash;
    request.batch.snapshot.genesis_committee_record_hash =
        abci::committee::record_hash(params.l2_chain_id, &committee.state.record);
    let mut blocks = Vec::new();
    let mut parent = request.batch.snapshot.checkpoint_hash;
    for height in 1..=12 {
        let block = super::consensus::pair(height, parent, &committee, &keys, blocks.last());
        parent = abci::EtnaEnvelope::decode(&block.block.data[0]).unwrap().block.header.hash_slow();
        blocks.push(block);
    }
    let last = blocks.last().unwrap();
    let header = abci::EtnaEnvelope::decode(&last.block.data[0]).unwrap().block.header;
    request.batch.input.lastHeight = U256::from(12);
    request.batch.input.lastBlockHash = header.hash_slow();
    request.batch.input.lastStateRoot = header.state_root;
    request.batch.input.lastCometHash =
        alloy_primitives::B256::from_slice(last.block.header.hash().as_bytes());
    request.batch.leaves = vec![statement::cut_leaf(
        6,
        abci::EtnaEnvelope::decode(&blocks[5].block.data[0]).unwrap().block.header.hash_slow(),
        alloy_primitives::B256::from_slice(blocks[5].block.header.hash().as_bytes()),
        0,
    )];
    request.batch.anchors = vec![request.batch.parent_anchor.clone(); blocks.len()];
    request.batch.blocks = blocks;
    request.batch.committees = vec![committee.state];
    let reference = RawL1Header::from(&Header { number: 15, ..Default::default() });
    request.batch.reference_headers = vec![reference.raw().clone()];
    let payload = codec::encode(&request.batch.blocks, &limits()).unwrap();
    rebind(&mut request, &payload);
    request
}

/// Limits fitting [`request`]'s two blocks.
pub(crate) fn limits() -> Limits {
    Limits {
        max_blocks: 12,
        max_blobs: 2,
        max_payload_bytes: 1_000_000,
        max_message_bytes: 500_000,
        max_decompressed_bytes: 1_000_000,
    }
}

/// Binds `request` to blobs carrying `payload`: rebuilds its sidecar and its statement hash.
pub(crate) fn rebind(request: &mut ProofRequest, payload: &[u8]) {
    request.batch.blobs = blob::build(payload, &limits(), SidecarMode::Eip4844).unwrap();
    let reference = RawL1Header::from_raw(request.batch.reference_headers[0].clone()).unwrap();
    request.batch.statement_hash = statement::hash(
        &request.batch.snapshot,
        &request.batch.input,
        reference.hash(),
        &request.batch.blobs.versioned_hashes,
        &request.batch.leaves,
    );
}

pub(crate) async fn signed(request: &ProofRequest, proof: &Bytes, nonce: u64) -> SignedTransaction {
    let batch = &request.batch;
    let tx = TxEip4844 {
        chain_id: u64::try_from(batch.snapshot.l1_chain_id).unwrap(),
        nonce,
        gas_limit: 500_000,
        max_fee_per_gas: 10,
        max_priority_fee_per_gas: 1,
        to: batch.snapshot.inbox,
        value: U256::ZERO,
        access_list: Default::default(),
        blob_versioned_hashes: batch.blobs.versioned_hashes.clone(),
        max_fee_per_blob_gas: 10,
        input: landCall {
            _input: batch.input.clone(),
            _leaves: batch.leaves.clone(),
            _proof: proof.clone(),
        }
        .abi_encode()
        .into(),
    };
    let variant: TxEip4844Variant =
        TxEip4844WithSidecar::from_tx_and_sidecar(tx, batch.blobs.sidecar.clone()).into();
    let signer = signer();
    let signature = signer.sign_hash(&variant.signature_hash()).await.unwrap();
    let signed = variant.into_signed(signature);
    SignedTransaction {
        hash: *signed.hash(),
        sender: signer.address(),
        nonce,
        network_bytes: TxEnvelope::Eip4844(signed).encoded_2718().into(),
    }
}
