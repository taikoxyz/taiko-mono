//! Shared Unzen boundary corpus exercised through the production derivation pipeline.

use super::*;
use std::{
    collections::{HashMap, HashSet},
    path::PathBuf,
    sync::Arc,
};

use alethia_reth_consensus::anchor_constants::anchorV4Call;
use alloy::{
    primitives::hex,
    sol_types::{
        SolCall,
        private::primitives::aliases::{U24, U48},
    },
};
use alloy_consensus::{BlobTransactionSidecar, SidecarBuilder, Transaction};
use alloy_eips::eip4844::{BYTES_PER_BLOB, Blob};
use alloy_rpc_types::{Log, eth::Block as RpcBlock};
use alloy_transport::mock::Asserter;
use anyhow::{Context, Result, ensure};
use bindings::inbox::Inbox::Proposed;
use protocol::shasta::{
    AnchorTxConstructor, BlobCoder,
    constants::{min_base_fee_for_chain, shasta_fork_timestamp_for_chain},
    validate_anchor_transaction,
};
use rpc::blob::BlobDataSource;
use serde_json::{Value, json};

use super::super::{
    ProposedEventContext, ShastaProposalBundle, ShastaSourceManifestFetcher, build_manifest_bundle,
};
use crate::test_support::{mock_client_with_asserters, sample_derivation_source};

fn boundary_corpus() -> Result<Vec<Value>> {
    shared_corpus("TAIKO_BOUNDARY_CORPUS", "boundary_cases.json")
}

fn shared_corpus(env: &str, filename: &str) -> Result<Vec<Value>> {
    let path = std::env::var_os(env).map_or_else(
        || {
            PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../../../../testdata/derivation_vectors")
                .join(filename)
        },
        PathBuf::from,
    );
    let contents = std::fs::read_to_string(&path)
        .with_context(|| format!("read shared boundary corpus {}", path.display()))?;
    let corpus: Value = serde_json::from_str(&contents)?;
    ensure!(corpus["schema_version"] == 1, "unsupported boundary schema");
    let cases = corpus["cases"].as_array().context("boundary cases must be an array")?;
    ensure!(!cases.is_empty(), "boundary corpus must not be empty");
    let mut names = HashSet::new();
    for case in cases {
        ensure!(names.insert(case["name"].as_str().context("case name")?), "duplicate case");
    }
    Ok(cases.clone())
}

#[tokio::test]
async fn unzen_boundary_vectors_client_fork_selection() -> Result<()> {
    let cases = shared_corpus("TAIKO_FORK_SELECTION_CORPUS", "fork_selection_cases.json")?;
    ensure!(cases.len() == 12, "expected 12 client-only extraction-cap fixtures");
    for case in cases {
        let chain_id = number(&case, "chain_id");
        let sidecars = source_sidecars(&case)?;
        let hashes: Vec<B256> =
            (0..sidecars.len()).map(|index| B256::repeat_byte((index + 1) as u8)).collect();
        let mut source = sample_derivation_source(hashes.clone(), false);
        // Blob time and candidate block timestamps predate Unzen. The extraction cap must
        // come from the proposal timestamp, independently of these other clocks.
        source.blobSlice.timestamp = U48::from(7);
        let event = ProposedEventContext {
            event: Proposed {
                id: U48::from(8),
                proposer: Address::ZERO,
                parentProposalHash: B256::ZERO,
                endOfSubmissionWindowTimestamp: U48::ZERO,
                basefeeSharingPctg: 0,
                sources: vec![source],
            },
            l1_block_number: 1,
            l1_block_hash: B256::ZERO,
            l1_timestamp: number(&case, "proposal_timestamp"),
        };
        let bundle = build_manifest_bundle(&event, None, chain_id, |timestamp, requested| {
            assert_eq!(timestamp, 7, "blob lookup timestamp");
            assert_eq!(requested, hashes, "blob lookup hashes");
            let sidecars = sidecars.clone();
            async move { Ok(sidecars) }
        })
        .await
        .with_context(|| text(&case, "name").to_owned())?;
        ensure!(bundle.sources.len() == 1, "one extraction source");
        ensure!(!bundle.sources[0].is_forced_inclusion, "ordinary extraction source");
        // Deliberately stop at extraction: pre-Unzen fixtures do not claim metadata,
        // payload preparation, or execution-engine equivalence.
        let actual = hex::encode(alloy_rlp::encode(&bundle.sources[0].manifest));
        ensure!(
            actual == text(&case, "expected_manifest_rlp_hex"),
            "client fork-selection {} extraction mismatch",
            text(&case, "name")
        );
    }
    Ok(())
}

fn number(value: &Value, field: &str) -> u64 {
    value[field].as_u64().unwrap_or_else(|| panic!("missing u64 {field}: {value}"))
}

fn text<'a>(value: &'a Value, field: &str) -> &'a str {
    value[field].as_str().unwrap_or_else(|| panic!("missing string {field}: {value}"))
}

fn flag(value: &Value, field: &str) -> bool {
    value[field].as_bool().unwrap_or_else(|| panic!("missing bool {field}: {value}"))
}

fn parent_projection(state: &ParentState) -> Value {
    json!({
        "number": state.header.number,
        "timestamp": state.header.timestamp,
        "gas_limit": state.header.gas_limit,
        "anchor_block_number": state.anchor_block_number,
    })
}

fn source_sidecars(input: &Value) -> Result<Vec<BlobTransactionSidecar>> {
    let bytes = input["payload_hex"].as_str().map(hex::decode).transpose()?;
    let blobs = if let Some(bytes) = bytes {
        let mut blobs = SidecarBuilder::<BlobCoder>::from_slice(&bytes).take();
        if blobs.is_empty() {
            blobs.push(Blob::from([0u8; BYTES_PER_BLOB]));
        }
        blobs
    } else {
        // null means undecodable blob content, never a retriable fetch failure.
        // A nonzero byte past the zero-length Kona header is invalid encoding.
        let mut raw = [0u8; BYTES_PER_BLOB];
        raw[6] = 2;
        vec![Blob::from(raw)]
    };
    Ok(blobs
        .into_iter()
        .map(|blob| BlobTransactionSidecar {
            blobs: vec![blob],
            commitments: Vec::new(),
            proofs: Vec::new(),
        })
        .collect())
}

async fn derive_case(case: &Value) -> Result<Value> {
    let chain_id = number(case, "chain_id");
    let proposal = &case["proposal"];
    let parent = &case["parent"];
    let source_inputs = case["sources"].as_array().context("sources")?;
    let l1 = Asserter::new();
    let l2 = Asserter::new();
    let anchor_address = Address::repeat_byte(0x44);
    let client =
        mock_client_with_asserters(l1.clone(), l2.clone(), Asserter::new(), anchor_address);
    l2.push_success(&chain_id);
    let anchor_constructor =
        AnchorTxConstructor::new(client.l2_provider.clone(), anchor_address).await?;
    let shasta_fork_timestamp = shasta_fork_timestamp_for_chain(chain_id)?;
    let pipeline = ShastaDerivationPipeline {
        rpc: client,
        anchor_constructor,
        derivation_source_manifest_fetcher: ShastaSourceManifestFetcher::new(Arc::new(
            BlobDataSource::new(None, None, true).await?,
        )),
        shasta_fork_timestamp,
        min_base_fee_to_clamp: min_base_fee_for_chain(chain_id),
        chain_id,
        initial_proposal_id: U256::ZERO,
    };
    let mut source_events = Vec::new();
    let mut blob_responses = HashMap::new();
    for (index, input) in source_inputs.iter().enumerate() {
        let sidecars = source_sidecars(input)?;
        let hashes: Vec<B256> = if flag(input, "has_blobs") {
            (0..sidecars.len())
                .map(|blob_index| {
                    B256::from(
                        U256::from(((index + 1) * 16 + blob_index) as u64).to_be_bytes::<32>(),
                    )
                })
                .collect()
        } else {
            Vec::new()
        };
        let blob_timestamp = index as u64 + 1;
        let mut source =
            sample_derivation_source(hashes.clone(), flag(input, "is_forced_inclusion"));
        source.blobSlice.offset = U24::try_from(number(input, "offset"))?;
        source.blobSlice.timestamp = U48::from(blob_timestamp);
        source_events.push(source);
        if !hashes.is_empty() {
            blob_responses.insert(hashes, (blob_timestamp, sidecars));
        }
    }
    let event = ProposedEventContext {
        event: Proposed {
            id: U48::try_from(number(proposal, "proposal_id"))?,
            proposer: text(proposal, "proposer").parse()?,
            parentProposalHash: B256::ZERO,
            endOfSubmissionWindowTimestamp: U48::ZERO,
            basefeeSharingPctg: number(proposal, "basefee_sharing_pctg").try_into()?,
            sources: source_events,
        },
        l1_block_number: number(proposal, "origin_block_number") + 1,
        l1_block_hash: B256::repeat_byte(0x11),
        l1_timestamp: number(proposal, "timestamp"),
    };
    let mut state = ParentState {
        header: Header {
            number: number(parent, "number"),
            timestamp: number(parent, "timestamp"),
            gas_limit: number(parent, "gas_limit"),
            base_fee_per_gas: Some(1_000_000_000),
            ..Default::default()
        },
        anchor_block_number: number(parent, "anchor_block_number"),
        parent_block_time_delta_secs: 1,
        shasta_fork_timestamp,
        min_base_fee_to_clamp: min_base_fee_for_chain(chain_id),
        chain_id,
    };
    if event.event.id.is_zero() {
        let mut proposal_block = RpcBlock::<TxEnvelope>::default();
        proposal_block.header.timestamp = event.l1_timestamp;
        l1.push_success(&Some(proposal_block));
        let log = Log {
            inner: alloy::primitives::Log::new_from_event_unchecked(
                Address::ZERO,
                event.event.clone(),
            )
            .reserialize(),
            block_hash: Some(event.l1_block_hash),
            block_number: Some(event.l1_block_number),
            ..Default::default()
        };
        ensure!(
            pipeline.process_proposal(&log, &pipeline.rpc).await?.is_empty(),
            "activation proposal produced a payload"
        );
        ensure!(source_inputs.is_empty(), "activation fixture must not have sources");
        ensure!(
            l1.read_q().is_empty() && l2.read_q().is_empty(),
            "unused activation RPC responses"
        );
        return Ok(json!({
            "source_block_counts": [], "extracted_manifests_rlp_hex": [],
            "blocks": [], "headers": [], "next_parent": parent_projection(&state),
        }));
    }
    let bundle = build_manifest_bundle(&event, None, chain_id, |timestamp, hashes| {
        let (expected_timestamp, sidecars) = blob_responses
            .get(&hashes)
            .expect("production bundle requested unexpected source hashes");
        assert_eq!(timestamp, *expected_timestamp, "source blob lookup timestamp");
        let sidecars = sidecars.clone();
        async move { Ok(sidecars) }
    })
    .await?;
    let ShastaProposalBundle { meta, sources } = bundle;
    let segments_total = sources.len();
    let mut source_block_counts = Vec::new();
    let mut extracted_manifests_rlp_hex = Vec::new();
    let mut blocks = Vec::new();
    let mut headers = Vec::new();
    for (segment_index, segment) in sources.into_iter().enumerate() {
        let forced = segment.is_forced_inclusion;
        let manifest = segment.manifest;
        extracted_manifests_rlp_hex.push(hex::encode(alloy_rlp::encode(&manifest)));
        let manifest = pipeline
            .prepare_segment_manifest(
                manifest,
                &state,
                &meta,
                segment_index,
                segments_total,
                forced,
            )
            .await?;
        source_block_counts.push(manifest.blocks.len());
        for (block_index, block) in manifest.blocks.iter().enumerate() {
            let block_number = state.next_block_number();
            blocks.push(json!({
                "number": block_number,
                "timestamp": block.timestamp,
                "coinbase": hex::encode(block.coinbase),
                "anchor_block_number": block.anchor_block_number,
                "gas_limit": block.gas_limit,
                "transactions_rlp_hex": hex::encode(encode_transactions(&block.transactions)),
                "is_forced_inclusion": forced,
            }));
            // Replace only unavailable L1 block/nonce reads; actual anchor construction,
            // signing, anchor placement, and create_payload_attributes all run unchanged.
            let mut anchor_block = RpcBlock::<TxEnvelope>::default();
            anchor_block.header.number = block.anchor_block_number;
            l1.push_success(&Some(anchor_block));
            l2.push_success(&U256::ZERO);
            let derived = pipeline
                .prepare_block(
                    block,
                    &state,
                    BlockContext {
                        meta: &meta,
                        position: BlockPosition {
                            segment_index,
                            segments_total,
                            block_index,
                            blocks_len: manifest.blocks.len(),
                            forced_inclusion: forced,
                        },
                    },
                )
                .await?;
            let payload = &derived.payload;
            ensure!(
                payload.payload_attributes.timestamp == block.timestamp &&
                    payload.block_metadata.timestamp == U256::from(block.timestamp) &&
                    payload.payload_attributes.suggested_fee_recipient == block.coinbase &&
                    payload.block_metadata.beneficiary == block.coinbase &&
                    payload.l1_origin.block_id == U256::from(block_number),
                "payload metadata differs from prepared block"
            );
            let list =
                payload.block_metadata.tx_list.as_ref().context("payload transaction list")?;
            let transactions: Vec<TxEnvelope> = alloy_rlp::decode_exact(list)?;
            let first = transactions.first().context("missing anchor transaction")?;
            validate_anchor_transaction(first, anchor_address, chain_id)?;
            let anchor = anchorV4Call::abi_decode(first.input())?;
            let anchor_number = anchor.0.0.to::<u64>();
            let anchor_first = first == &derived.anchor_tx;
            ensure!(payload.l1_origin.is_forced_inclusion == forced, "payload forced flag");
            headers.push(json!({
                "gas_limit": payload.block_metadata.gas_limit,
                "extra_data_hex": hex::encode(&payload.block_metadata.extra_data),
                "anchor_block_number": anchor_number,
                "transactions_rlp_hex": hex::encode(encode_transactions(&transactions[1..])),
                "anchor_first": anchor_first,
            }));
            // The engine chooses other header fields. Advance the real rolling state
            // using only the fields this pre-execution payload plan determines.
            let header = Header {
                number: derived.block_number,
                timestamp: payload.payload_attributes.timestamp,
                gas_limit: payload.block_metadata.gas_limit,
                beneficiary: payload.payload_attributes.suggested_fee_recipient,
                extra_data: payload.block_metadata.extra_data.clone(),
                base_fee_per_gas: Some(payload.base_fee_per_gas.to::<u64>()),
                difficulty: U256::from_be_slice(payload.block_metadata.mix_hash.as_slice()),
                ..Default::default()
            };
            state = state.advance(header, anchor_number)?;
        }
    }
    ensure!(l1.read_q().is_empty() && l2.read_q().is_empty(), "unused mock RPC responses");
    Ok(json!({
        "source_block_counts": source_block_counts,
        "extracted_manifests_rlp_hex": extracted_manifests_rlp_hex,
        "blocks": blocks,
        "headers": headers,
        "next_parent": parent_projection(&state),
    }))
}

fn compare(case: &Value, actual: &Value) -> Result<()> {
    ensure!(
        *actual == case["expected"],
        "boundary {} mismatch\nactual: {actual}\nexpected: {}",
        text(case, "name"),
        case["expected"]
    );
    Ok(())
}

#[tokio::test]
async fn unzen_boundary_vectors() -> Result<()> {
    for case in boundary_corpus()? {
        let actual = derive_case(&case).await.with_context(|| text(&case, "name").to_owned())?;
        compare(&case, &actual)?;
    }
    Ok(())
}

#[tokio::test]
async fn unzen_boundary_vectors_reject_mutated_expectations() -> Result<()> {
    let cases = boundary_corpus()?;
    let case = cases
        .iter()
        .find(|case| case["expected"]["blocks"].as_array().is_some_and(|blocks| !blocks.is_empty()))
        .context("need a nonempty block fixture")?;
    let actual = derive_case(case).await?;
    compare(case, &actual)?;
    for pointer in [
        "/source_block_counts/0",
        "/extracted_manifests_rlp_hex/0",
        "/blocks/0/number",
        "/blocks/0/timestamp",
        "/blocks/0/coinbase",
        "/blocks/0/anchor_block_number",
        "/blocks/0/gas_limit",
        "/blocks/0/is_forced_inclusion",
        "/headers/0/gas_limit",
        "/headers/0/extra_data_hex",
        "/headers/0/anchor_block_number",
        "/headers/0/anchor_first",
        "/next_parent/number",
        "/next_parent/timestamp",
        "/next_parent/gas_limit",
        "/next_parent/anchor_block_number",
    ] {
        let mut mutated = case.clone();
        let field = mutated["expected"].pointer_mut(pointer).context("mutation target")?;
        *field = match field {
            Value::Number(n) => json!(n.as_u64().context("mutation u64")? + 1),
            Value::Bool(b) => json!(!*b),
            Value::String(s) => json!(format!("{s}00")),
            _ => anyhow::bail!("unsupported mutation {pointer}"),
        };
        ensure!(compare(&mutated, &actual).is_err(), "accepted expected-output mutation {pointer}");
    }
    // Reverse actual candidate envelopes rather than changing their count or membership.
    let ordered_case = cases
        .iter()
        .find(|case| {
            case["expected"]["blocks"].as_array().is_some_and(|blocks| {
                blocks.iter().any(|block| {
                    hex::decode(text(block, "transactions_rlp_hex"))
                        .ok()
                        .and_then(|bytes| alloy_rlp::decode_exact::<Vec<TxEnvelope>>(&bytes).ok())
                        .is_some_and(|txs| txs.len() >= 2 && txs.first() != txs.last())
                })
            })
        })
        .context("need an order-sensitive candidate fixture")?;
    let actual = derive_case(ordered_case).await?;
    compare(ordered_case, &actual)?;
    for collection in ["blocks", "headers"] {
        let mut mutated = ordered_case.clone();
        let outputs = mutated["expected"][collection].as_array_mut().context("mutation outputs")?;
        let mut changed = false;
        for output in outputs {
            let encoded = hex::decode(text(output, "transactions_rlp_hex"))?;
            let mut txs = alloy_rlp::decode_exact::<Vec<TxEnvelope>>(&encoded)?;
            if txs.len() >= 2 && txs.first() != txs.last() {
                txs.reverse();
                output["transactions_rlp_hex"] = json!(hex::encode(encode_transactions(&txs)));
                changed = true;
                break;
            }
        }
        ensure!(
            changed && compare(&mutated, &actual).is_err(),
            "accepted {collection} candidate order mutation"
        );
    }
    Ok(())
}
