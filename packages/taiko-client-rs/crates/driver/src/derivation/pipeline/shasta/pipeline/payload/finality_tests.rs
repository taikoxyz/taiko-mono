use super::*;
use std::sync::{Arc, Mutex};

use alethia_reth_primitives::payload::attributes::RpcL1Origin;
use alloy_json_rpc::RequestPacket;
use alloy_provider::ProviderBuilder;
use alloy_rpc_client::RpcClient;
use alloy_rpc_types::eth::Block as RpcBlock;
use alloy_rpc_types_engine::ForkchoiceState;
use alloy_transport::mock::{Asserter, MockTransport};
use rpc::blob::BlobDataSource;
use tower::Service;

use super::super::ShastaSourceManifestFetcher;
use crate::{
    sync::error::EngineSubmissionError,
    test_support::{mock_client_with_asserters, sample_engine_outcome, sample_payload},
};

type RecordedRequests = Arc<Mutex<Vec<(String, serde_json::Value)>>>;

struct CanonicalRefreshFixture {
    pipeline: ShastaDerivationPipeline,
    meta: BundleMeta,
    blocks: Vec<KnownCanonicalBlock>,
    l2: Asserter,
    engine: Asserter,
    requests: RecordedRequests,
}

fn block_at(number: u64) -> RpcBlock<TxEnvelope> {
    sample_engine_outcome(number).block
}

async fn finality_fixture() -> CanonicalRefreshFixture {
    let l2 = Asserter::new();
    let engine = Asserter::new();
    let requests: RecordedRequests = Arc::default();
    let recorded = requests.clone();
    let mut inner = MockTransport::new(engine.clone());
    let transport = tower::service_fn(move |request: RequestPacket| {
        recorded.lock().unwrap().extend(request.requests().iter().map(|request| {
            let params = request.params().map_or(serde_json::Value::Null, |params| {
                serde_json::from_str(params.get()).unwrap()
            });
            (request.method().to_owned(), params)
        }));
        inner.call(request)
    });
    let mut client =
        mock_client_with_asserters(Asserter::new(), l2.clone(), engine.clone(), Address::ZERO);
    client.l2_auth_provider = ProviderBuilder::new()
        .disable_recommended_fillers()
        .connect_client(RpcClient::new(transport, true));
    l2.push_success(&0u64);
    let anchor_constructor =
        protocol::shasta::AnchorTxConstructor::new(client.l2_provider.clone(), Address::ZERO)
            .await
            .unwrap();
    let blob_source = Arc::new(BlobDataSource::new(None, None, true).await.unwrap());
    let pipeline = ShastaDerivationPipeline {
        rpc: client,
        anchor_constructor,
        derivation_source_manifest_fetcher: ShastaSourceManifestFetcher::new(blob_source),
        shasta_fork_timestamp: 0,
        min_base_fee_to_clamp: 0,
        chain_id: 0,
        initial_proposal_id: U256::ZERO,
    };
    let meta = BundleMeta {
        proposal_id: 11,
        last_finalized_proposal_id: Some(9),
        proposal_timestamp: 100,
        l1_block_number: 100,
        l1_block_hash: B256::repeat_byte(0x11),
        origin_block_number: 99,
        proposer: Address::ZERO,
        basefee_sharing_pctg: 0,
    };
    let blocks = vec![KnownCanonicalBlock {
        payload: sample_payload(20),
        outcome: sample_engine_outcome(20),
        is_final_block: true,
    }];
    CanonicalRefreshFixture { pipeline, meta, blocks, l2, engine, requests }
}

async fn canonical_refresh_fixture() -> CanonicalRefreshFixture {
    let fixture = finality_fixture().await;
    fixture.origin_updates();
    fixture
}

impl CanonicalRefreshFixture {
    fn origin_updates(&self) {
        // Origin lookup, origin update, confirmed-head update, and proposal mapping write.
        self.l2.push_success(&None::<RpcL1Origin>);
        self.engine.push_success(&None::<RpcL1Origin>);
        self.engine.push_success(&U256::from(20));
        self.engine.push_success(&U256::from(11));
    }

    fn checkpoint_rpc_failure(&self, mapping: bool) {
        if mapping {
            self.engine.push_failure_msg("mapping temporarily unavailable");
        } else {
            self.engine.push_success(&Some(U256::from(10)));
            self.l2.push_failure_msg("checkpoint temporarily unavailable");
        }
    }

    fn checkpoint(&self) {
        self.engine.push_success(&Some(U256::from(10)));
        self.l2.push_success(&Some(block_at(10)));
    }

    fn forkchoice_response(&self, status: &str) {
        self.engine.push_success(&serde_json::json!({
            "payloadStatus": { "status": status, "latestValidHash": null,
                "validationError": if status == "INVALID" { Some("unknown head") } else { None } },
            "payloadId": null,
        }));
    }

    fn assert_no_forkchoice(&self) {
        assert!(
            self.requests
                .lock()
                .unwrap()
                .iter()
                .all(|(method, _)| method != "engine_forkchoiceUpdatedV2")
        );
        assert!(self.engine.read_q().is_empty());
        assert!(self.l2.read_q().is_empty());
    }
}

#[tokio::test]
async fn canonical_origin_refresh_advances_finality_without_rewinding_unsafe_head() {
    let fixture = canonical_refresh_fixture().await;
    fixture.checkpoint();
    fixture.l2.push_success(&Some(block_at(8)));
    fixture.l2.push_success(&Some(block_at(30)));
    fixture.forkchoice_response("VALID");

    fixture
        .pipeline
        .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
        .await
        .unwrap();

    let requests = fixture.requests.lock().unwrap();
    let (method, params) = requests.last().unwrap();
    assert_eq!(method, "engine_forkchoiceUpdatedV2");
    let state: ForkchoiceState = serde_json::from_value(params[0].clone()).unwrap();
    assert_eq!(state.head_block_hash, block_at(30).hash());
    assert_eq!(state.safe_block_hash, block_at(10).hash());
    assert_eq!(state.finalized_block_hash, block_at(10).hash());
    assert!(params[1].is_null(), "finality refresh must not build another payload");
    assert_eq!(requests.len(), 5, "origins and mapping must be written before forkchoice");
    assert!(fixture.engine.read_q().is_empty());
    assert!(fixture.l2.read_q().is_empty());
}

#[tokio::test]
async fn canonical_origin_refresh_preserves_equal_or_newer_finality() {
    for finalized_number in [10, 12] {
        let fixture = canonical_refresh_fixture().await;
        fixture.checkpoint();
        fixture.l2.push_success(&Some(block_at(finalized_number)));
        fixture
            .pipeline
            .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
            .await
            .unwrap();
        fixture.assert_no_forkchoice();
    }
}

#[tokio::test]
async fn canonical_origin_refresh_tolerates_unresolved_checkpoints() {
    for missing in 0..3 {
        let mut fixture = canonical_refresh_fixture().await;
        match missing {
            0 => fixture.meta.last_finalized_proposal_id = None,
            1 => fixture.engine.push_success(&None::<U256>),
            _ => {
                fixture.engine.push_success(&Some(U256::from(10)));
                fixture.l2.push_success(&None::<RpcBlock<TxEnvelope>>);
            }
        }
        fixture
            .pipeline
            .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
            .await
            .unwrap();
        fixture.assert_no_forkchoice();
    }
}

#[tokio::test]
async fn canonical_origin_refresh_handles_first_finality() {
    for geth in [false, true] {
        let fixture = canonical_refresh_fixture().await;
        fixture.checkpoint();
        if geth {
            fixture.l2.push_failure(alloy_json_rpc::ErrorPayload {
                code: -32000,
                message: "finalized block not found".into(),
                data: None,
            });
        } else {
            fixture.l2.push_success(&None::<RpcBlock<TxEnvelope>>);
        }
        fixture.l2.push_success(&Some(block_at(30)));
        fixture.forkchoice_response("VALID");
        fixture
            .pipeline
            .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
            .await
            .unwrap();
        assert_eq!(
            fixture.requests.lock().unwrap().last().unwrap().0,
            "engine_forkchoiceUpdatedV2"
        );
        assert!(fixture.engine.read_q().is_empty());
        assert!(fixture.l2.read_q().is_empty());
    }
}

#[tokio::test]
async fn canonical_origin_refresh_retries_nonvalid_forkchoice() {
    for status in ["SYNCING", "INVALID", "ACCEPTED"] {
        let fixture = canonical_refresh_fixture().await;
        fixture.checkpoint();
        fixture.l2.push_success(&Some(block_at(8)));
        fixture.l2.push_success(&Some(block_at(30)));
        fixture.forkchoice_response(status);
        let result = fixture
            .pipeline
            .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
            .await;
        assert!(
            matches!(
                result,
                Err(DerivationError::Engine(
                    EngineSubmissionError::EngineSyncing(30) |
                        EngineSubmissionError::UnexpectedPayloadStatus(30, _)
                ))
            ),
            "forkchoice {status} must remain retryable: {result:?}"
        );
    }
}

#[tokio::test]
async fn canonical_origin_refresh_retries_missing_head() {
    let fixture = canonical_refresh_fixture().await;
    fixture.checkpoint();
    fixture.l2.push_success(&Some(block_at(8)));
    fixture.l2.push_success(&None::<RpcBlock<TxEnvelope>>);
    let result =
        fixture.pipeline.update_canonical_proposal_origins(&fixture.meta, &fixture.blocks).await;
    assert!(result.is_err(), "missing current head must not use the older proposal head");
    fixture.assert_no_forkchoice();
}

#[tokio::test]
async fn canonical_origin_refresh_retries_checkpoint_rpc_errors() {
    for mapping in [true, false] {
        let fixture = canonical_refresh_fixture().await;
        fixture.checkpoint_rpc_failure(mapping);
        let result = fixture
            .pipeline
            .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
            .await;
        assert!(
            matches!(result, Err(DerivationError::Rpc(_))),
            "checkpoint RPC error must remain retryable: {result:?}"
        );
        fixture.assert_no_forkchoice();

        // Origin persistence on the failed attempt must not prevent retrying the same proposal.
        fixture.origin_updates();
        fixture.checkpoint();
        fixture.l2.push_success(&Some(block_at(8)));
        fixture.l2.push_success(&Some(block_at(30)));
        fixture.forkchoice_response("VALID");
        fixture
            .pipeline
            .update_canonical_proposal_origins(&fixture.meta, &fixture.blocks)
            .await
            .unwrap();
        assert_eq!(
            fixture.requests.lock().unwrap().last().unwrap().0,
            "engine_forkchoiceUpdatedV2"
        );
        assert!(fixture.engine.read_q().is_empty());
        assert!(fixture.l2.read_q().is_empty());
    }
}

#[tokio::test]
async fn payload_building_tolerates_checkpoint_rpc_errors() {
    for mapping in [true, false] {
        let fixture = finality_fixture().await;
        fixture.checkpoint_rpc_failure(mapping);
        let mut state = ParentState {
            header: block_at(20).header.inner,
            parent_block_time_delta_secs: 0,
            anchor_block_number: 0,
            shasta_fork_timestamp: 0,
            min_base_fee_to_clamp: 0,
            chain_id: 0,
        };
        let result = fixture
            .pipeline
            .build_payloads_from_sources(
                Vec::new(),
                &fixture.meta,
                &mut state,
                &fixture.pipeline.rpc,
            )
            .await;
        assert!(
            result.is_ok(),
            "checkpoint RPC errors must not block payload building: {result:?}"
        );
        fixture.assert_no_forkchoice();
    }
}
