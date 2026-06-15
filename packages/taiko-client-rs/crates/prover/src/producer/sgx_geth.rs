//! The sgxgeth proof producer: the execution sub-proof that always accompanies
//! the base/zk proof in the compose model (Go `sgx_geth_proof_producer.go`).

use std::time::Instant;

use alloy_primitives::Bytes;

use super::{
    DummyProofProducer, ProofRequest, ProofResponse, decode_proof_payload, prover_hex,
    raiko_proposals, request_validated,
};
use crate::{
    error::{ProverError, Result},
    raiko::{ProofType, RaikoClient, types::RaikoBatchProofRequest},
};

/// Producer for `sgxgeth` proofs against the base raiko host.
#[derive(Debug, Clone)]
pub struct SgxGethProofProducer {
    /// raiko client for the base host (`--raiko.host`).
    raiko: RaikoClient,
    /// Produce filler proofs instead of calling raiko (`--prover.dummy`).
    dummy: bool,
}

impl SgxGethProofProducer {
    /// Build the producer.
    #[must_use]
    pub fn new(raiko: RaikoClient, dummy: bool) -> Self {
        Self { raiko, dummy }
    }

    /// Request the single sgxgeth proof for one proposal. The compose flow
    /// discards the proof bytes of the single sgxgeth proof (only the
    /// aggregation bytes go on chain), so success is all that matters here
    /// (Go `compose_proof_producer.go:110-118`).
    pub async fn request_proof(&self, request: &ProofRequest, request_at: Instant) -> Result<()> {
        if self.dummy {
            return Ok(());
        }
        let body = RaikoBatchProofRequest {
            proposals: raiko_proposals(&[request]),
            prover: prover_hex(request.prover_address),
            aggregate: false,
            proof_type: ProofType::SgxGeth,
        };
        request_validated(&self.raiko, &body, request.geth_proof_generated, request_at)
            .await
            .map_err(ProverError::from)?;
        Ok(())
    }

    /// Request the sgxgeth aggregation over the given single proofs and return
    /// its proof bytes (Go `sgx_geth_proof_producer.go:69-120`).
    pub async fn aggregate(&self, items: &[ProofResponse], request_at: Instant) -> Result<Bytes> {
        if items.is_empty() {
            return Err(ProverError::Other(anyhow::anyhow!("empty proof aggregation items")));
        }
        if self.dummy {
            return Ok(DummyProofProducer.request_batch_proofs());
        }
        let requests: Vec<&ProofRequest> = items.iter().map(|item| &item.request).collect();
        let body = RaikoBatchProofRequest {
            proposals: raiko_proposals(&requests),
            prover: prover_hex(items[0].request.prover_address),
            aggregate: true,
            proof_type: ProofType::SgxGeth,
        };
        let response = request_validated(
            &self.raiko,
            &body,
            items[0].request.geth_aggregation_generated,
            request_at,
        )
        .await
        .map_err(ProverError::from)?;
        decode_proof_payload(&response)
    }
}
