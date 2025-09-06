use super::error::{HandlerError, HandlerResult};
use crate::decoder::shasta::{decode_proposed_data_shasta, ProposedEventPayload};
use crate::rindexer_lib::typings::indexer::events::shasta_inbox::{
    no_extensions, ProposedEvent, ProposedResult, ShastaInboxEventType,
};
use alloy::hex;
use rindexer::{
    event::callback_registry::EventCallbackRegistry, rindexer_error, rindexer_info, PostgresClient,
    RindexerColorize,
};
use std::path::PathBuf;
use std::sync::Arc;

async fn insert_proposed_event(
    database: &Arc<PostgresClient>,
    result: &ProposedResult,
    decoded: &ProposedEventPayload,
) -> HandlerResult<u64> {
    database.execute(
        "INSERT INTO indexer_shasta_inbox.proposed (
            data, proposal_id, proposer, proposal_timestamp, core_state_hash,
            derivation_hash, origin_block_number, origin_block_hash, is_forced_inclusion,
            basefee_sharing_pctg, blob_hashes, blob_offset, blob_timestamp,
            next_proposal_id, last_finalized_proposal_id, last_finalized_transition_hash,
            bond_instructions_hash, contract_address, tx_hash, block_number,
            block_timestamp, block_hash, network, tx_index, log_index
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25)
        ON CONFLICT (tx_hash, log_index) DO NOTHING",
        &[
            &result.event_data.data.as_ref(),
            &(decoded.proposal.id.to::<i64>()),
            &format!("0x{}", hex::encode(decoded.proposal.proposer)),
            &(decoded.proposal.timestamp.to::<i64>()),
            &format!("0x{}", hex::encode(decoded.proposal.coreStateHash)),
            &format!("0x{}", hex::encode(decoded.proposal.derivationHash)),
            &(decoded.derivation.originBlockNumber.to::<i64>()),
            &Some(format!("0x{}", hex::encode(decoded.derivation.originBlockHash))),
            &decoded.derivation.isForcedInclusion,
            &(decoded.derivation.basefeeSharingPctg as i16),
            &decoded.derivation.blobSlice.blobHashes.iter().map(|h| format!("0x{}", hex::encode(h))).collect::<Vec<String>>(),
            &(decoded.derivation.blobSlice.offset.to::<i32>()),
            &(decoded.derivation.blobSlice.timestamp.to::<i64>()),
            &(decoded.coreState.nextProposalId.to::<i64>()),
            &(decoded.coreState.lastFinalizedProposalId.to::<i64>()),
            &format!("0x{}", hex::encode(decoded.coreState.lastFinalizedTransitionHash)),
            &format!("0x{}", hex::encode(decoded.coreState.bondInstructionsHash)),
            &result.tx_information.address.to_checksum(None),
            &format!("0x{}", hex::encode(result.tx_information.transaction_hash)),
            &(result.tx_information.block_number as i64),
            &result.tx_information.block_timestamp_to_datetime(),
            &format!("0x{}", hex::encode(result.tx_information.block_hash)),
            &result.tx_information.network,
            &(result.tx_information.transaction_index as i64),
            &result.tx_information.log_index.to_string(),
        ],
    ).await.map_err(|e| HandlerError::DatabaseError(e.to_string()))
}

async fn process_proposed_event(
    database: &Arc<PostgresClient>,
    result: &ProposedResult,
) -> HandlerResult<()> {
    let decoded = decode_proposed_data_shasta(&result.event_data.data)
        .map_err(|e| HandlerError::DecodeError(e))?;
    insert_proposed_event(database, result, &decoded).await?;
    Ok(())
}

pub async fn proposed_handler(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    let handler = ProposedEvent::handler(
        |results, context| async move {
            if results.is_empty() {
                return Ok(());
            }

            for result in results.iter() {
                if let Err(e) = process_proposed_event(&context.database, result).await {
                    rindexer_error!(
                        "Failed to process proposed event at tx_hash {}: {}",
                        format!("0x{}", hex::encode(result.tx_information.transaction_hash)),
                        e
                    );

                    return Err(e.to_string());
                }
            }

            rindexer_info!(
                "ShastaInbox::Proposed - {} - {} events",
                "INDEXED".green(),
                results.len(),
            );

            Ok(())
        },
        no_extensions(),
    )
    .await;

    ShastaInboxEventType::Proposed(handler)
        .register(manifest_path, registry)
        .await;
}
