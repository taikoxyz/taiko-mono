//! Codec- and KZG-bound immutable jobs and deterministic blob transaction signatures.
use crate::{
    blob, codec,
    contracts::IEtnaInbox::landCall,
    proof::ProofRequest,
    statement,
    tx::SignedTransaction,
    types::{CertifiedBlock, Limits, SidecarMode},
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
    let (params, committee, keys) = super::consensus::committee(&[3, 3, 3]);
    request.batch.snapshot.inbox = params.inbox;
    request.batch.snapshot.config_hash = params.config_hash();
    request.batch.snapshot.genesis.config_hash = request.batch.snapshot.config_hash;
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
    request.batch.leaves = leaves(&blocks);
    request.batch.anchors = vec![request.batch.parent_anchor.clone(); blocks.len()];
    request.batch.blocks = blocks;
    let reference = RawL1Header::from(&Header { number: 15, ..Default::default() });
    request.batch.reference_headers = vec![reference.raw().clone()];
    let payload = codec::encode(&request.batch.blocks, &limits()).unwrap();
    rebind(&mut request, &payload);
    request
}

/// The cut leaves of `blocks`, a batch with no forced inclusion: one for every block but the
/// terminal one, from its EL hash, Comet hash and cursor 0.
pub(crate) fn leaves(blocks: &[CertifiedBlock]) -> Vec<alloy_primitives::B256> {
    blocks[..blocks.len() - 1]
        .iter()
        .map(|pair| {
            let header = abci::EtnaEnvelope::decode(&pair.block.data[0]).unwrap().block.header;
            statement::cut_leaf(
                header.number,
                header.hash_slow(),
                alloy_primitives::B256::from_slice(pair.block.header.hash().as_bytes()),
                0,
            )
        })
        .collect()
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
    signed_by(&signer(), request, proof, nonce).await
}

/// [`signed`] under another account's key.
pub(crate) async fn signed_by(
    signer: &PrivateKeySigner,
    request: &ProofRequest,
    proof: &Bytes,
    nonce: u64,
) -> SignedTransaction {
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
    let signature = signer.sign_hash(&variant.signature_hash()).await.unwrap();
    let signed = variant.into_signed(signature);
    SignedTransaction {
        hash: *signed.hash(),
        sender: signer.address(),
        nonce,
        network_bytes: TxEnvelope::Eip4844(signed).encoded_2718().into(),
    }
}
