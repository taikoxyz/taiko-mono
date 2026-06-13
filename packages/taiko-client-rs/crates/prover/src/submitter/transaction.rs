//! Builds `Inbox.prove` transactions from aggregated batch proofs
//! (Go `proof_submitter/transaction/builder.go`).

use std::sync::Arc;

use alloy::{
    eips::BlockNumberOrTag,
    providers::Provider,
    sol,
    sol_types::{SolCall, SolValue},
};
use alloy_primitives::{Address, B256, Bytes, U256, aliases::U48};
use base_tx_manager::TxCandidate;
use bindings::inbox::{
    IInbox::{Commitment, ProveInput, Transition},
    Inbox,
};
use rpc::{RpcClientError, client::ClientWithWallet};

use crate::{
    error::{ProverError, Result},
    producer::BatchProofs,
};

sol! {
    /// One sub-proof entry consumed by the ComposeVerifier
    /// (Go `bindings/encoding.SubProofShasta`).
    struct SubProof {
        /// On-chain verifier id for this sub-proof.
        uint8 verifierId;
        /// Raw proof bytes.
        bytes proof;
    }
}

/// ABI-encode the sub-proof array exactly like Go's `EncodeBatchesSubProofs`
/// (`abi.Arguments.Pack` of one `(uint8,bytes)[]` argument: leading offset
/// word, length, then items). Pinned byte-for-byte by a `cast abi-encode`
/// fixture test below.
pub(crate) fn encode_sub_proofs(sub_proofs: &[SubProof]) -> Bytes {
    sub_proofs.abi_encode().into()
}

/// Chain-fetched commitment pieces that the batch itself doesn't carry.
#[derive(Debug, Clone)]
pub(crate) struct FetchedCommitmentParts {
    /// Parent hash of the first proposal's first L2 block — i.e. the previous
    /// proposal's last block hash (Go `builder.go:71-79`).
    pub first_proposal_parent_block_hash: B256,
    /// `inbox.getProposalHash` of the last proposal in the batch.
    pub last_proposal_hash: B256,
}

/// Assemble the `ProveInput` commitment (Go `builder.go:41-116`): validates
/// consecutive proposal ids and fills the first/last/transition fields.
pub(crate) fn assemble_prove_input(
    batch: &BatchProofs,
    actual_prover: Address,
    parts: &FetchedCommitmentParts,
) -> Result<ProveInput> {
    let responses = &batch.responses;
    if responses.is_empty() {
        return Err(ProverError::Other(anyhow::anyhow!("no proof responses in batch proof")));
    }
    for pair in responses.windows(2) {
        if pair[1].proposal_id() != pair[0].proposal_id() + 1 {
            return Err(ProverError::Other(anyhow::anyhow!(
                "non-consecutive proposals: {} -> {}",
                pair[0].proposal_id(),
                pair[1].proposal_id(),
            )));
        }
    }

    let first = &responses[0].request;
    let last = &responses[responses.len() - 1].request;
    let transitions = responses
        .iter()
        .map(|response| Transition {
            proposer: response.request.proposer,
            timestamp: U48::from(response.request.proposal_timestamp),
            blockHash: response.request.end_block_hash,
        })
        .collect();

    Ok(ProveInput {
        commitment: Commitment {
            firstProposalId: U48::from(first.proposal_id),
            firstProposalParentBlockHash: parts.first_proposal_parent_block_hash,
            lastProposalHash: parts.last_proposal_hash,
            actualProver: actual_prover,
            endBlockNumber: U48::from(last.end_block_number),
            endStateRoot: last.end_state_root,
            transitions,
        },
    })
}

/// Named inputs for [`build_prove_batches_tx`].
#[derive(Debug)]
pub struct BuildProveTxInput<'a> {
    /// Wallet-bound RPC client (inbox calls + L2 block lookups).
    pub rpc: &'a ClientWithWallet,
    /// Inbox contract address (transaction destination).
    pub inbox_address: Address,
    /// The aggregated batch to submit.
    pub batch: &'a BatchProofs,
    /// `commitment.actualProver` — this prover's address.
    pub actual_prover: Address,
    /// Gas limit override; 0 lets the tx-manager estimate.
    pub gas_limit: u64,
}

/// Build the `Inbox.prove(bytes _data, bytes _proof)` candidate (Go
/// `BuildProveBatchesShasta`, `builder.go:37-151`): fetch the first proposal's
/// parent block hash and the last proposal hash, assemble the commitment, let
/// the inbox contract encode it, and append the two ABI-encoded sub-proofs
/// (sgxgeth first).
pub async fn build_prove_batches_tx(input: BuildProveTxInput<'_>) -> Result<TxCandidate> {
    let batch = input.batch;
    let responses = &batch.responses;
    if responses.is_empty() {
        return Err(ProverError::Other(anyhow::anyhow!("no proof responses in batch proof")));
    }

    let first_request = &responses[0].request;
    let first_block_number = *first_request.l2_block_numbers.first().ok_or_else(|| {
        ProverError::Other(anyhow::anyhow!(
            "no L2 block numbers in proof response for proposal {}",
            first_request.proposal_id,
        ))
    })?;
    // The parent of the first proposal's first block is the previous
    // proposal's last block; reading by number works for beacon-synced blocks
    // and the genesis-parent case alike (Go `builder.go:71-79`).
    let first_block = input
        .rpc
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(first_block_number))
        .await
        .map_err(RpcClientError::from)?
        .ok_or_else(|| {
            ProverError::Other(anyhow::anyhow!("L2 block {first_block_number} not found"))
        })?;

    let last_id = responses[responses.len() - 1].proposal_id();
    let last_proposal_hash = input
        .rpc
        .shasta
        .inbox
        .getProposalHash(U256::from(last_id))
        .call()
        .await
        .map_err(|err| RpcClientError::Contract(err.to_string()))?;

    let parts = FetchedCommitmentParts {
        first_proposal_parent_block_hash: first_block.header.parent_hash,
        last_proposal_hash,
    };
    let prove_input = assemble_prove_input(batch, input.actual_prover, &parts)?;

    // The inbox contract owns the ProveInput codec (Go `EncodeProveInput`,
    // `pkg/rpc/methods.go:1130`).
    let input_data = input
        .rpc
        .shasta
        .inbox
        .encodeProveInput(prove_input)
        .call()
        .await
        .map_err(|err| RpcClientError::Contract(err.to_string()))?;

    tracing::info!(
        sgx_geth_verifier_id = batch.sgx_geth_verifier_id,
        verifier_id = batch.verifier_id,
        first_id = batch.batch_ids.first(),
        last_id = batch.batch_ids.last(),
        "build proposal proof submission transaction"
    );

    // Order matters: sgxgeth first, base/zk second (Go `builder.go:130-133`).
    let sub_proofs = encode_sub_proofs(&[
        SubProof {
            verifierId: batch.sgx_geth_verifier_id,
            proof: batch.sgx_geth_batch_proof.clone(),
        },
        SubProof { verifierId: batch.verifier_id, proof: batch.batch_proof.clone() },
    ]);

    let calldata = Inbox::proveCall { _data: input_data, _proof: sub_proofs }.abi_encode();

    Ok(TxCandidate {
        tx_data: calldata.into(),
        blobs: Arc::new(vec![]),
        to: Some(input.inbox_address),
        gas_limit: input.gas_limit,
        value: U256::ZERO,
    })
}

#[cfg(test)]
mod tests {
    use alloy::sol_types::SolCall;
    use alloy_primitives::{Address, B256, Bytes, aliases::U48, hex};
    use bindings::inbox::Inbox;

    use super::{FetchedCommitmentParts, SubProof, assemble_prove_input, encode_sub_proofs};
    use crate::{
        producer::{BatchProofs, ProofRequest, ProofResponse},
        raiko::ProofType,
    };

    fn test_response(proposal_id: u64) -> ProofResponse {
        ProofResponse {
            request: ProofRequest {
                proposal_id,
                proposer: Address::repeat_byte(u8::try_from(proposal_id).unwrap()),
                proposal_timestamp: 1_000 + proposal_id,
                event_l1_block_number: 42,
                event_l1_block_hash: B256::repeat_byte(0x22),
                prover_address: Address::repeat_byte(0x33),
                l2_block_numbers: vec![100 + proposal_id],
                end_block_number: 100 + proposal_id,
                end_block_hash: B256::repeat_byte(u8::try_from(proposal_id).unwrap()),
                end_state_root: B256::repeat_byte(0x55),
                last_anchor_block_number: 40,
                geth_proof_generated: false,
                reth_proof_generated: false,
                geth_aggregation_generated: false,
                reth_aggregation_generated: false,
            },
            proof: Bytes::from_static(&[0xaa]),
            proof_type: ProofType::Sgx,
        }
    }

    fn test_batch(ids: &[u64]) -> BatchProofs {
        BatchProofs {
            responses: ids.iter().map(|id| test_response(*id)).collect(),
            batch_proof: Bytes::from_static(&[0xbb]),
            sgx_geth_batch_proof: Bytes::from_static(&[0x11, 0x11]),
            batch_ids: ids.to_vec(),
            proof_type: ProofType::Sgx,
            verifier_id: 4,
            sgx_geth_verifier_id: 1,
        }
    }

    #[test]
    fn sub_proofs_encoding_matches_cast_abi_encode() {
        let encoded = encode_sub_proofs(&[
            SubProof { verifierId: 1, proof: Bytes::from_static(&[0xff, 0x00]) },
            SubProof { verifierId: 4, proof: Bytes::from_static(&[0xbb]) },
        ]);
        // Fixture from:
        //   cast abi-encode "f((uint8,bytes)[])" "[(1,0xff00),(4,0xbb)]"
        let expected = hex::decode(
            "0x0000000000000000000000000000000000000000000000000000000000000020\
             0000000000000000000000000000000000000000000000000000000000000002\
             0000000000000000000000000000000000000000000000000000000000000040\
             00000000000000000000000000000000000000000000000000000000000000c0\
             0000000000000000000000000000000000000000000000000000000000000001\
             0000000000000000000000000000000000000000000000000000000000000040\
             0000000000000000000000000000000000000000000000000000000000000002\
             ff00000000000000000000000000000000000000000000000000000000000000\
             0000000000000000000000000000000000000000000000000000000000000004\
             0000000000000000000000000000000000000000000000000000000000000040\
             0000000000000000000000000000000000000000000000000000000000000001\
             bb00000000000000000000000000000000000000000000000000000000000000",
        )
        .unwrap();
        assert_eq!(encoded.as_ref(), expected.as_slice());
    }

    #[test]
    fn assemble_rejects_non_consecutive_proposals() {
        let batch = test_batch(&[7, 9]);
        let parts = FetchedCommitmentParts {
            first_proposal_parent_block_hash: B256::repeat_byte(0x77),
            last_proposal_hash: B256::repeat_byte(0x88),
        };
        let err = assemble_prove_input(&batch, Address::repeat_byte(0x99), &parts).unwrap_err();
        assert!(err.to_string().contains("non-consecutive"), "got {err}");
    }

    #[test]
    fn assemble_fills_commitment_from_first_last_and_transitions() {
        let batch = test_batch(&[5, 6]);
        let parts = FetchedCommitmentParts {
            first_proposal_parent_block_hash: B256::repeat_byte(0x77),
            last_proposal_hash: B256::repeat_byte(0x88),
        };
        let actual_prover = Address::repeat_byte(0x99);

        let input = assemble_prove_input(&batch, actual_prover, &parts).unwrap();
        let commitment = &input.commitment;

        assert_eq!(commitment.firstProposalId, U48::from(5u64));
        assert_eq!(commitment.firstProposalParentBlockHash, B256::repeat_byte(0x77));
        assert_eq!(commitment.lastProposalHash, B256::repeat_byte(0x88));
        assert_eq!(commitment.actualProver, actual_prover);
        assert_eq!(commitment.endBlockNumber, U48::from(106u64));
        assert_eq!(commitment.endStateRoot, B256::repeat_byte(0x55));
        assert_eq!(commitment.transitions.len(), 2);
        for (transition, id) in commitment.transitions.iter().zip([5u64, 6]) {
            assert_eq!(transition.proposer, Address::repeat_byte(u8::try_from(id).unwrap()));
            assert_eq!(transition.timestamp, U48::from(1_000 + id));
            assert_eq!(transition.blockHash, B256::repeat_byte(u8::try_from(id).unwrap()));
        }
    }

    #[test]
    fn prove_calldata_has_selector_and_roundtrips() {
        let call = Inbox::proveCall {
            _data: Bytes::from_static(b"input"),
            _proof: Bytes::from_static(b"proofs"),
        };
        let encoded = call.abi_encode();
        assert_eq!(&encoded[..4], Inbox::proveCall::SELECTOR);
        let decoded = Inbox::proveCall::abi_decode(&encoded).unwrap();
        assert_eq!(decoded._data, Bytes::from_static(b"input"));
        assert_eq!(decoded._proof, Bytes::from_static(b"proofs"));
    }
}
