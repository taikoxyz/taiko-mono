use super::error::{HandlerError, HandlerResult};
use crate::rindexer_lib::typings::indexer::events::shasta_inbox::{
    no_extensions, BondInstructedEvent, BondInstructedResult, ShastaInboxEventType,
};
use alloy::hex;
use rindexer::{
    event::callback_registry::EventCallbackRegistry, rindexer_error, rindexer_info, PostgresClient,
    RindexerColorize,
};
use std::path::PathBuf;
use std::sync::Arc;

fn get_bond_type_name(bond_type: u8) -> &'static str {
    match bond_type {
        0 => "NONE",
        1 => "PROPOSER",
        2 => "CHALLENGER",
        3 => "PROVER",
        4 => "LIVENESS",
        _ => "UNKNOWN",
    }
}

async fn insert_bond_instructions(
    database: &Arc<PostgresClient>,
    result: &BondInstructedResult,
) -> HandlerResult<()> {
    let bond_instructions = &result.event_data.instructions;

    for instruction in bond_instructions.iter() {
        database
            .execute(
                "INSERT INTO indexer_shasta_inbox.bond_instructed (
                proposal_id, bond_type, bond_type_name, payer, receiver,
                contract_address, tx_hash, block_number,
                block_timestamp, block_hash, network, tx_index, log_index
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            ON CONFLICT (tx_hash, log_index) DO NOTHING",
                &[
                    &instruction.proposalId.to::<i64>(),
                    &(instruction.bondType as i16),
                    &get_bond_type_name(instruction.bondType),
                    &format!("0x{}", hex::encode(instruction.payer)),
                    &format!("0x{}", hex::encode(instruction.receiver)),
                    &result.tx_information.address.to_checksum(None),
                    &format!("0x{}", hex::encode(result.tx_information.transaction_hash)),
                    &(result.tx_information.block_number as i64),
                    &result.tx_information.block_timestamp_to_datetime(),
                    &format!("0x{}", hex::encode(result.tx_information.block_hash)),
                    &result.tx_information.network,
                    &(result.tx_information.transaction_index as i64),
                    &result.tx_information.log_index.to_string(),
                ],
            )
            .await
            .map_err(|e| HandlerError::DatabaseError(e.to_string()))?;
    }

    Ok(())
}

async fn process_bond_instructed_event(
    database: &Arc<PostgresClient>,
    result: &BondInstructedResult,
) -> HandlerResult<()> {
    insert_bond_instructions(database, result).await
}

pub async fn bond_instructed_handler(
    manifest_path: &PathBuf,
    registry: &mut EventCallbackRegistry,
) {
    let handler = BondInstructedEvent::handler(
        |results, context| async move {
            if results.is_empty() {
                return Ok(());
            }

            for result in results.iter() {
                if let Err(e) = process_bond_instructed_event(&context.database, result).await {
                    rindexer_error!(
                        "Failed to process bond instructed event at tx_hash {}: {}",
                        format!("0x{}", hex::encode(result.tx_information.transaction_hash)),
                        e
                    );
                }
            }

            rindexer_info!(
                "ShastaInbox::BondInstructed - {} - {} events",
                "INDEXED".green(),
                results.len(),
            );

            Ok(())
        },
        no_extensions(),
    )
    .await;

    ShastaInboxEventType::BondInstructed(handler)
        .register(manifest_path, registry)
        .await;
}
