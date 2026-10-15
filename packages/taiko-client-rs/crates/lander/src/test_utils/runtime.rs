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
    let block =
        super::consensus::pair(1, request.batch.snapshot.checkpoint_hash, &committee, &keys, None);
    let first_header = abci::EtnaEnvelope::decode(&block.block.data[0]).unwrap().block.header;
    let second =
        super::consensus::pair(2, first_header.hash_slow(), &committee, &keys, Some(&block));
    let last_header = abci::EtnaEnvelope::decode(&second.block.data[0]).unwrap().block.header;
    request.batch.input.lastHeight = 2;
    request.batch.input.lastBlockHash = last_header.hash_slow();
    request.batch.input.lastStateRoot = last_header.state_root;
    // Block 2 carries height 1's canonical commit: the batch (0, 2]'s only participation.
    let signed = crate::validate::verify_commit(
        second.block.last_commit.as_ref().unwrap(),
        &block.block.header,
        &committee,
        "taiko-etna-167001-g0",
    )
    .unwrap();
    let participation = crate::participation::build(
        &abci::Schedule::from_genesis(&request.batch.snapshot.genesis),
        &params,
        0,
        2,
        &[crate::participation::CommitSigners { height: 1, signed }],
        &std::collections::BTreeMap::from([(0, committee.clone())]),
    )
    .unwrap();
    request.batch.participation = participation.parts;
    request.batch.settlements = participation.settlements;
    request.batch.blocks = vec![block, second];
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
        max_blocks: 2,
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
        &request.batch.participation,
        reference.hash(),
        &request.batch.blobs.versioned_hashes,
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
            _participation: batch.participation.clone(),
            _settlements: batch.settlements.clone(),
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
