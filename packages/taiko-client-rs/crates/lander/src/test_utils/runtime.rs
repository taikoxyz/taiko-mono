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
    request.batch.snapshot.start_committee_record_hash =
        abci::committee::record_hash(params.l2_chain_id, &committee.state.record);
    let block =
        super::consensus::pair(1, request.batch.snapshot.checkpoint_hash, &committee, &keys, None);
    let first_header = abci::EtnaEnvelope::decode(&block.block.data[0]).unwrap().block.header;
    let second =
        super::consensus::pair(2, first_header.hash_slow(), &committee, &keys, Some(&block));
    let last_header = abci::EtnaEnvelope::decode(&second.block.data[0]).unwrap().block.header;
    request.batch.input.lastHeight = 2;
    request.batch.input.lastBlockHash = last_header.hash_slow();
    request.batch.input.lastStateRoot = last_header.state_root;
    request.batch.blocks = vec![block, second];
    request.batch.committees = vec![committee.state];
    let reference = RawL1Header::from(&Header { number: 15, ..Default::default() });
    request.batch.reference_headers = vec![reference.raw().clone()];
    let limits = Limits {
        max_blocks: 2,
        max_blobs: 2,
        max_payload_bytes: 1_000_000,
        max_message_bytes: 500_000,
    };
    let payload = codec::encode(&request.batch.blocks, &limits).unwrap();
    request.batch.blobs = blob::build(&payload, &limits, SidecarMode::Eip4844).unwrap();
    request.batch.statement_hash = statement::hash(
        &request.batch.snapshot,
        &request.batch.input,
        reference.hash(),
        &request.batch.blobs.versioned_hashes,
    );
    request
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
        input: landCall { _input: batch.input.clone(), _proof: proof.clone() }.abi_encode().into(),
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
