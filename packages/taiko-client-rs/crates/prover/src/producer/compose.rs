//! Compose proof producer: every batch gets an sgxgeth execution proof plus a
//! base (sgx) or ZK (risc0/sp1 via zk_any) proof, requested in parallel
//! (Go `compose_proof_producer.go`).

use std::collections::HashMap;

use alloy_primitives::Bytes;

use super::{
    BatchProofs, DummyProofProducer, ProofProducer, ProofRequest, ProofResponse, RISC0_VERIFIER_ID,
    SGX_GETH_VERIFIER_ID, SGX_RETH_VERIFIER_ID, SP1_VERIFIER_ID, SgxGethProofProducer,
    decode_proof_payload, prover_hex, raiko_proposals, request_validated,
};
use crate::{
    error::{ProverError, Result},
    raiko::{ProofType, RaikoClient, types::RaikoBatchProofRequest},
};

/// Compose producer pairing sgxgeth with a configured base/zk proof type.
#[derive(Debug, Clone)]
pub struct ComposeProofProducer {
    /// raiko client for this producer's host (`--raiko.host` or `--raiko.host.zkvm`).
    raiko: RaikoClient,
    /// The sgxgeth side (always requested against the base host).
    sgx_geth: SgxGethProofProducer,
    /// Requested base type: [`ProofType::Sgx`] or [`ProofType::ZkAny`].
    proof_type: ProofType,
    /// Verifier id per drawable proof type (Go `init.go:46-75`).
    verifier_ids: HashMap<ProofType, u8>,
    /// Produce filler proofs instead of calling raiko (`--prover.dummy`).
    dummy: bool,
}

impl ComposeProofProducer {
    /// Base SGX producer: requests `sgx` proofs (Go `init.go:46-56`).
    #[must_use]
    pub fn new_sgx(raiko: RaikoClient, sgx_geth: SgxGethProofProducer, dummy: bool) -> Self {
        Self {
            raiko,
            sgx_geth,
            proof_type: ProofType::Sgx,
            verifier_ids: HashMap::from([(ProofType::Sgx, SGX_RETH_VERIFIER_ID)]),
            dummy,
        }
    }

    /// ZKVM producer: requests `zk_any` and lets raiko draw risc0 or sp1
    /// (Go `init.go:65-75`).
    #[must_use]
    pub fn new_zkvm(raiko: RaikoClient, sgx_geth: SgxGethProofProducer, dummy: bool) -> Self {
        Self {
            raiko,
            sgx_geth,
            proof_type: ProofType::ZkAny,
            verifier_ids: HashMap::from([
                (ProofType::Risc0, RISC0_VERIFIER_ID),
                (ProofType::Sp1, SP1_VERIFIER_ID),
            ]),
            dummy,
        }
    }
}

#[async_trait::async_trait]
impl ProofProducer for ComposeProofProducer {
    async fn request_proof(&self, request: &mut ProofRequest) -> Result<ProofResponse> {
        tracing::info!(
            proposal_id = request.proposal_id,
            proof_type = ?self.proof_type,
            dummy = self.dummy,
            "request proof from raiko-host service"
        );

        if self.dummy {
            return Ok(DummyProofProducer.request_proof(request, self.proof_type));
        }

        let (base_result, geth_result) = {
            let request = &*request;
            let base_future = async {
                let body = RaikoBatchProofRequest {
                    proposals: raiko_proposals(&[request]),
                    prover: prover_hex(request.prover_address),
                    aggregate: false,
                    proof_type: self.proof_type,
                };
                let response = request_validated(&self.raiko, &body, request.reth_proof_generated)
                    .await
                    .map_err(ProverError::from)?;
                // The drawn type decides decoding: single sp1 proof bodies are
                // null (Go `compose_proof_producer.go:101-104`).
                let drawn = response.proof_type.ok_or_else(|| {
                    ProverError::Other(anyhow::anyhow!("raiko response missing proof_type"))
                })?;
                let proof = if drawn == ProofType::Sp1 {
                    Bytes::new()
                } else {
                    decode_proof_payload(&response)?
                };
                Ok::<_, ProverError>((drawn, proof))
            };
            tokio::join!(base_future, self.sgx_geth.request_proof(request))
        };

        // Mark first-generation flags individually, like Go's errgroup
        // closures: a successful side stays marked even when the other fails.
        if geth_result.is_ok() {
            request.geth_proof_generated = true;
        }
        if base_result.is_ok() {
            request.reth_proof_generated = true;
        }

        // Base errors take priority so `RaikoError::ZkAnyNotDrawn` stays
        // matchable by the submitter's fallback logic.
        let (drawn, proof) = match (base_result, geth_result) {
            (Err(base_err), geth_result) => {
                if let Err(geth_err) = geth_result {
                    tracing::debug!(error = %geth_err, "sgxgeth proof request also failed");
                }
                return Err(base_err);
            }
            (Ok(_), Err(geth_err)) => return Err(geth_err),
            (Ok(base), Ok(())) => base,
        };

        Ok(ProofResponse { request: request.clone(), proof, proof_type: drawn })
    }

    async fn aggregate(&self, items: &mut [ProofResponse]) -> Result<BatchProofs> {
        if items.is_empty() {
            return Err(ProverError::Other(anyhow::anyhow!("empty proof aggregation items")));
        }
        let drawn_type = items[0].proof_type;
        let verifier_id = *self.verifier_ids.get(&drawn_type).ok_or_else(|| {
            ProverError::Other(anyhow::anyhow!("unknown proof type from raiko {drawn_type:?}"))
        })?;
        let batch_ids: Vec<u64> = items.iter().map(ProofResponse::proposal_id).collect();

        tracing::info!(
            proof_type = ?drawn_type,
            batch_size = items.len(),
            first_id = batch_ids.first(),
            last_id = batch_ids.last(),
            "aggregate batch proofs from raiko-host service"
        );

        if self.dummy {
            let sgx_geth_batch_proof = self.sgx_geth.aggregate(items).await?;
            return Ok(BatchProofs {
                responses: items.to_vec(),
                batch_proof: DummyProofProducer.request_batch_proofs(),
                sgx_geth_batch_proof,
                batch_ids,
                // Go reassigns the aggregation type to the producer's own type
                // in dummy mode (`compose_proof_producer.go:184-187`).
                proof_type: self.proof_type,
                verifier_id,
                sgx_geth_verifier_id: SGX_GETH_VERIFIER_ID,
            });
        }

        let (base_result, geth_result) = {
            let items = &*items;
            let base_future = async {
                let requests: Vec<&ProofRequest> = items.iter().map(|item| &item.request).collect();
                let body = RaikoBatchProofRequest {
                    proposals: raiko_proposals(&requests),
                    prover: prover_hex(items[0].request.prover_address),
                    aggregate: true,
                    proof_type: drawn_type,
                };
                let response = request_validated(
                    &self.raiko,
                    &body,
                    items[0].request.reth_aggregation_generated,
                )
                .await
                .map_err(ProverError::from)?;
                decode_proof_payload(&response)
            };
            tokio::join!(base_future, self.sgx_geth.aggregate(items))
        };

        if geth_result.is_ok() {
            items[0].request.geth_aggregation_generated = true;
        }
        if base_result.is_ok() {
            items[0].request.reth_aggregation_generated = true;
        }

        let (batch_proof, sgx_geth_batch_proof) = match (base_result, geth_result) {
            (Err(base_err), geth_result) => {
                if let Err(geth_err) = geth_result {
                    tracing::debug!(error = %geth_err, "sgxgeth aggregation also failed");
                }
                return Err(base_err);
            }
            (Ok(_), Err(geth_err)) => return Err(geth_err),
            (Ok(base), Ok(geth)) => (base, geth),
        };

        Ok(BatchProofs {
            responses: items.to_vec(),
            batch_proof,
            sgx_geth_batch_proof,
            batch_ids,
            proof_type: drawn_type,
            verifier_id,
            sgx_geth_verifier_id: SGX_GETH_VERIFIER_ID,
        })
    }
}

#[cfg(test)]
mod tests {
    use std::{net::SocketAddr, sync::Arc, time::Duration};

    use alloy_primitives::{Address, B256};
    use tokio::sync::Mutex;

    use super::ComposeProofProducer;
    use crate::{
        error::ProverError,
        producer::{
            ProofProducer, ProofRequest, ProofResponse, SGX_GETH_VERIFIER_ID, SGX_RETH_VERIFIER_ID,
            SP1_VERIFIER_ID, SgxGethProofProducer,
        },
        raiko::{ProofType, RaikoClient, RaikoClientConfig, RaikoError},
    };

    /// Requests seen by the stub raiko server.
    type SeenRequests = Arc<Mutex<Vec<serde_json::Value>>>;

    /// Spawn a stub raiko server; `respond` maps a request body to a response body.
    async fn spawn_raiko<F>(seen: SeenRequests, respond: F) -> SocketAddr
    where
        F: Fn(&serde_json::Value) -> serde_json::Value + Clone + Send + Sync + 'static,
    {
        let app = axum::Router::new().route(
            "/v3/proof/batch/shasta",
            axum::routing::post(move |body: String| {
                let seen = seen.clone();
                let respond = respond.clone();
                async move {
                    let request: serde_json::Value = serde_json::from_str(&body).unwrap();
                    let response = respond(&request);
                    seen.lock().await.push(request);
                    axum::Json(response)
                }
            }),
        );
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
        addr
    }

    fn raiko_client(addr: SocketAddr) -> RaikoClient {
        RaikoClient::new(RaikoClientConfig {
            endpoint: format!("http://{addr}").parse().unwrap(),
            api_key: None,
            request_timeout: Duration::from_secs(5),
        })
    }

    fn test_request(proposal_id: u64) -> ProofRequest {
        ProofRequest {
            proposal_id,
            proposer: Address::repeat_byte(0x11),
            proposal_timestamp: 1_000,
            event_l1_block_number: 42,
            event_l1_block_hash: B256::repeat_byte(0x22),
            prover_address: Address::repeat_byte(0x33),
            l2_block_numbers: vec![100, 101],
            end_block_number: 101,
            end_block_hash: B256::repeat_byte(0x44),
            end_state_root: B256::repeat_byte(0x55),
            last_anchor_block_number: 40,
            geth_proof_generated: false,
            reth_proof_generated: false,
            geth_aggregation_generated: false,
            reth_aggregation_generated: false,
        }
    }

    fn test_response(proposal_id: u64, proof_type: ProofType) -> ProofResponse {
        ProofResponse {
            request: test_request(proposal_id),
            proof: alloy_primitives::Bytes::from_static(&[0xaa]),
            proof_type,
        }
    }

    /// Success body echoing the requested proof type with the given proof hex.
    fn ok_body(proof_type: &str, proof_hex: &str) -> serde_json::Value {
        serde_json::json!({
            "data": { "proof": { "proof": proof_hex }, "status": "ok" },
            "proof_type": proof_type,
        })
    }

    #[tokio::test]
    async fn request_proof_pairs_sgxgeth_with_base_and_decodes_proof() {
        let seen: SeenRequests = Arc::default();
        let addr =
            spawn_raiko(seen.clone(), |request| match request["proof_type"].as_str().unwrap() {
                "sgxgeth" => ok_body("sgxgeth", "0x1111"),
                "sgx" => ok_body("sgx", "0x2222"),
                other => panic!("unexpected proof type {other}"),
            })
            .await;
        let producer = ComposeProofProducer::new_sgx(
            raiko_client(addr),
            SgxGethProofProducer::new(raiko_client(addr), false),
            false,
        );

        let mut request = test_request(7);
        let response = producer.request_proof(&mut request).await.unwrap();

        assert_eq!(response.proof_type, ProofType::Sgx);
        assert_eq!(response.proof.as_ref(), &[0x22, 0x22]);
        assert!(request.geth_proof_generated);
        assert!(request.reth_proof_generated);

        let seen = seen.lock().await;
        assert_eq!(seen.len(), 2, "exactly one sgxgeth and one sgx request");
        for body in seen.iter() {
            assert_eq!(body["aggregate"], false);
            assert_eq!(body["proposals"][0]["proposal_id"], 7);
            // Prover address is EIP-55 checksummed without 0x (Go Address.Hex()[2:]).
            assert_eq!(
                body["prover"].as_str().unwrap(),
                &Address::repeat_byte(0x33).to_checksum(None)[2..],
            );
            // Checkpoint hashes are lowercase hex without 0x.
            assert_eq!(body["proposals"][0]["checkpoint"]["block_hash"], "44".repeat(32));
        }
    }

    #[tokio::test]
    async fn zk_any_not_drawn_surfaces_as_matchable_error() {
        let seen: SeenRequests = Arc::default();
        let addr =
            spawn_raiko(seen.clone(), |request| match request["proof_type"].as_str().unwrap() {
                "sgxgeth" => ok_body("sgxgeth", "0x1111"),
                "zk_any" => serde_json::json!({
                    "data": { "proof": null, "status": "zk_any_not_drawn" },
                    "proof_type": "zk_any",
                }),
                other => panic!("unexpected proof type {other}"),
            })
            .await;
        let producer = ComposeProofProducer::new_zkvm(
            raiko_client(addr),
            SgxGethProofProducer::new(raiko_client(addr), false),
            false,
        );

        let mut request = test_request(7);
        let err = producer.request_proof(&mut request).await.unwrap_err();

        assert!(matches!(err, ProverError::Raiko(RaikoError::ZkAnyNotDrawn)), "got {err:?}");
        // The sgxgeth side succeeded and stays marked for metrics dedup.
        assert!(request.geth_proof_generated);
        assert!(!request.reth_proof_generated);
    }

    #[tokio::test]
    async fn sp1_draw_returns_empty_proof_bytes() {
        let seen: SeenRequests = Arc::default();
        let addr = spawn_raiko(seen.clone(), |request| {
            match request["proof_type"].as_str().unwrap() {
                "sgxgeth" => ok_body("sgxgeth", "0x1111"),
                // Single sp1 proof bodies are null (Go compose_proof_producer.go:101-104).
                "zk_any" => serde_json::json!({
                    "data": { "proof": null, "status": "ok" },
                    "proof_type": "sp1",
                }),
                other => panic!("unexpected proof type {other}"),
            }
        })
        .await;
        let producer = ComposeProofProducer::new_zkvm(
            raiko_client(addr),
            SgxGethProofProducer::new(raiko_client(addr), false),
            false,
        );

        let mut request = test_request(7);
        let response = producer.request_proof(&mut request).await.unwrap();

        assert_eq!(response.proof_type, ProofType::Sp1);
        assert!(response.proof.is_empty());
    }

    #[tokio::test]
    async fn aggregate_builds_batch_proofs_with_both_sub_proofs() {
        let seen: SeenRequests = Arc::default();
        let addr = spawn_raiko(seen.clone(), |request| {
            assert_eq!(request["aggregate"], true);
            match request["proof_type"].as_str().unwrap() {
                "sgxgeth" => ok_body("sgxgeth", "0x1111"),
                "sgx" => ok_body("sgx", "0x2222"),
                other => panic!("unexpected proof type {other}"),
            }
        })
        .await;
        let producer = ComposeProofProducer::new_sgx(
            raiko_client(addr),
            SgxGethProofProducer::new(raiko_client(addr), false),
            false,
        );

        let mut items = vec![test_response(1, ProofType::Sgx), test_response(2, ProofType::Sgx)];
        let batch = producer.aggregate(&mut items).await.unwrap();

        assert_eq!(batch.batch_ids, vec![1, 2]);
        assert_eq!(batch.proof_type, ProofType::Sgx);
        assert_eq!(batch.verifier_id, SGX_RETH_VERIFIER_ID);
        assert_eq!(batch.sgx_geth_verifier_id, SGX_GETH_VERIFIER_ID);
        assert_eq!(batch.batch_proof.as_ref(), &[0x22, 0x22]);
        assert_eq!(batch.sgx_geth_batch_proof.as_ref(), &[0x11, 0x11]);
        assert_eq!(batch.responses.len(), 2);
        assert!(items[0].request.geth_aggregation_generated);
        assert!(items[0].request.reth_aggregation_generated);

        let seen = seen.lock().await;
        assert_eq!(seen.len(), 2);
        for body in seen.iter() {
            assert_eq!(body["proposals"].as_array().unwrap().len(), 2);
        }
    }

    #[tokio::test]
    async fn sp1_aggregation_uses_sp1_verifier_id() {
        let seen: SeenRequests = Arc::default();
        let addr =
            spawn_raiko(seen.clone(), |request| match request["proof_type"].as_str().unwrap() {
                "sgxgeth" => ok_body("sgxgeth", "0x1111"),
                "sp1" => ok_body("sp1", "0x3333"),
                other => panic!("unexpected proof type {other}"),
            })
            .await;
        let producer = ComposeProofProducer::new_zkvm(
            raiko_client(addr),
            SgxGethProofProducer::new(raiko_client(addr), false),
            false,
        );

        let mut items = vec![test_response(3, ProofType::Sp1)];
        let batch = producer.aggregate(&mut items).await.unwrap();

        assert_eq!(batch.proof_type, ProofType::Sp1);
        assert_eq!(batch.verifier_id, SP1_VERIFIER_ID);
        assert_eq!(batch.batch_proof.as_ref(), &[0x33, 0x33]);
    }

    #[tokio::test]
    async fn dummy_mode_never_calls_raiko() {
        let seen: SeenRequests = Arc::default();
        let addr = spawn_raiko(seen.clone(), |_| panic!("raiko must not be called")).await;
        let producer = ComposeProofProducer::new_sgx(
            raiko_client(addr),
            SgxGethProofProducer::new(raiko_client(addr), true),
            true,
        );

        let mut request = test_request(5);
        let response = producer.request_proof(&mut request).await.unwrap();
        assert_eq!(response.proof_type, ProofType::Sgx);
        assert_eq!(response.proof.len(), 100);
        assert!(response.proof.iter().all(|b| *b == 0xff));

        let mut items = vec![response];
        let batch = producer.aggregate(&mut items).await.unwrap();
        assert_eq!(batch.proof_type, ProofType::Sgx);
        assert!(batch.batch_proof.iter().all(|b| *b == 0xbb));
        assert!(batch.sgx_geth_batch_proof.iter().all(|b| *b == 0xbb));
        assert_eq!(batch.verifier_id, SGX_RETH_VERIFIER_ID);

        assert!(seen.lock().await.is_empty());
    }
}
