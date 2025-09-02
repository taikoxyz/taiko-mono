use crate::decoder::{
    error::DecodeError,
    shasta::{decode_proved_data_shasta, BondInstruction, ProvedEventPayload},
};
use crate::rindexer_lib::typings::indexer::events::shasta_inbox::{
    no_extensions, ProvedEvent, ProvedResult, ShastaInboxEventType,
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

async fn insert_proved_event(
    database: &Arc<PostgresClient>,
    result: &ProvedResult,
    decoded: &ProvedEventPayload,
) -> Result<u64, Box<dyn std::error::Error + Send + Sync>> {
    database.execute(
        "INSERT INTO indexer_shasta_inbox.proved (
            data, proposal_id, proposal_hash, parent_transition_hash,
            end_block_number, end_block_hash, end_block_state_root,
            designated_prover, actual_prover, span, transition_hash,
            end_block_mini_header_hash, contract_address, tx_hash, block_number,
            block_timestamp, block_hash, network, tx_index, log_index
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
        ON CONFLICT (tx_hash, log_index) DO NOTHING
        RETURNING id",
        &[
            &result.event_data.data.as_ref(),
            &(decoded.proposalId.to::<i64>()),
            &format!("0x{}", hex::encode(decoded.transition.proposalHash)),
            &format!("0x{}", hex::encode(decoded.transition.parentTransitionHash)),
            &(decoded.transition.endBlockMiniHeader.number.to::<i64>()),
            &format!("0x{}", hex::encode(decoded.transition.endBlockMiniHeader.hash)),
            &format!("0x{}", hex::encode(decoded.transition.endBlockMiniHeader.stateRoot)),
            &format!("0x{}", hex::encode(decoded.transition.designatedProver)),
            &format!("0x{}", hex::encode(decoded.transition.actualProver)),
            &(decoded.transitionRecord.span as i16),
            &format!("0x{}", hex::encode(decoded.transitionRecord.transitionHash)),
            &format!("0x{}", hex::encode(decoded.transitionRecord.endBlockMiniHeaderHash)),
            &result.tx_information.address.to_checksum(None),
            &format!("0x{}", hex::encode(result.tx_information.transaction_hash)),
            &(result.tx_information.block_number as i64),
            &result.tx_information.block_timestamp_to_datetime(),
            &format!("0x{}", hex::encode(result.tx_information.block_hash)),
            &result.tx_information.network,
            &(result.tx_information.transaction_index as i64),
            &result.tx_information.log_index.to_string(),
        ],
    ).await.map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
}

async fn insert_bond_instruction(
    database: &Arc<PostgresClient>,
    proved_id: i64,
    instruction: &BondInstruction,
    tx_hash: &str,
    block_number: i64,
) -> Result<u64, Box<dyn std::error::Error + Send + Sync>> {
    database
        .execute(
            "INSERT INTO indexer_shasta_inbox.proved_bond_instructions (
            proved_id, proposal_id, bond_type, bond_type_name,
            payer, receiver, tx_hash, block_number
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
            &[
                &proved_id,
                &instruction.proposalId.to::<i64>(),
                &(instruction.bondType as i16),
                &get_bond_type_name(instruction.bondType),
                &format!("0x{}", hex::encode(instruction.payer)),
                &format!("0x{}", hex::encode(instruction.receiver)),
                &tx_hash,
                &block_number,
            ],
        )
        .await
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
}

async fn get_proved_id(
    database: &Arc<PostgresClient>,
    tx_hash: &str,
    log_index: &str,
) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    let row = database
        .query_one(
            "SELECT id FROM indexer_shasta_inbox.proved WHERE tx_hash = $1 AND log_index = $2",
            &[&tx_hash, &log_index],
        )
        .await
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
    Ok(row.get(0))
}

async fn process_proved_event(
    database: &Arc<PostgresClient>,
    result: &ProvedResult,
    decoded: &ProvedEventPayload,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // Start transaction
    database.execute("BEGIN", &[]).await?;

    // Insert proved event
    let rows_affected = insert_proved_event(database, result, decoded).await?;

    if rows_affected > 0 {
        let tx_hash = format!("0x{}", hex::encode(result.tx_information.transaction_hash));
        let log_index = result.tx_information.log_index.to_string();

        // Get proved_id
        match get_proved_id(database, &tx_hash, &log_index).await {
            Ok(proved_id) => {
                // Insert bond instructions
                for instruction in decoded.transitionRecord.bondInstructions.iter() {
                    if let Err(e) = insert_bond_instruction(
                        database,
                        proved_id,
                        instruction,
                        &tx_hash,
                        result.tx_information.block_number as i64,
                    )
                    .await
                    {
                        rindexer_error!("Failed to insert bond instruction: {}", e);
                        database.execute("ROLLBACK", &[]).await?;
                        return Err(e);
                    }
                }
                // Commit transaction
                database.execute("COMMIT", &[]).await?;
            }
            Err(e) => {
                database.execute("ROLLBACK", &[]).await?;
                return Err(e);
            }
        }
    } else {
        // No rows inserted (conflict)
        database.execute("ROLLBACK", &[]).await?;
    }

    Ok(())
}

pub async fn proved_handler(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    let handler = ProvedEvent::handler(
        |results, context| async move {
            if results.is_empty() {
                return Ok(());
            }

            for result in results.iter() {
                match decode_proved_data_shasta(&result.event_data.data) {
                    Ok(decoded) => {
                        if let Err(e) =
                            process_proved_event(&context.database, result, &decoded).await
                        {
                            rindexer_error!(
                                "Failed to process proved event at tx_hash {}: {}",
                                format!(
                                    "0x{}",
                                    hex::encode(result.tx_information.transaction_hash)
                                ),
                                e
                            );
                        }
                    }
                    Err(e) => {
                        rindexer_error!(
                            "Failed to decode Proved event data at tx_hash: {}, error: {:?}",
                            format!("0x{}", hex::encode(result.tx_information.transaction_hash)),
                            e
                        );
                    }
                }
            }

            rindexer_info!(
                "ShastaInbox::Proved - {} - {} events",
                "INDEXED".green(),
                results.len(),
            );

            Ok(())
        },
        no_extensions(),
    )
    .await;

    ShastaInboxEventType::Proved(handler)
        .register(manifest_path, registry)
        .await;
}
