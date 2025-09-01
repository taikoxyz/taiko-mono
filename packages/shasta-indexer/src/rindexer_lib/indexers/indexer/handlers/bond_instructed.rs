use crate::rindexer_lib::typings::indexer::events::shasta_inbox::{
    no_extensions, BondInstructedEvent, ShastaInboxEventType,
};
use alloy::hex;
use rindexer::{
    event::callback_registry::EventCallbackRegistry, rindexer_error, rindexer_info,
    RindexerColorize,
};
use std::path::PathBuf;

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
                // BondInstructed event is already decoded by rindexer
                let bond_instructions = &result.event_data.instructions;

                // Insert each bond instruction as a separate row
                for instruction in bond_instructions.iter() {
                    let insert_result = context
                        .database
                        .execute(
                            "INSERT INTO indexer_shasta_inbox.bond_instructed (
                            proposal_id, bond_type, bond_type_name, payer, receiver,
                            contract_address, tx_hash, block_number,
                            block_timestamp, block_hash, network, tx_index, log_index
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)",
                            &[
                                &instruction.proposalId.to::<i64>(),
                                &(instruction.bondType as i16),
                                &get_bond_type_name(instruction.bondType),
                                &format!("0x{}", hex::encode(instruction.payer)),
                                &format!("0x{}", hex::encode(instruction.receiver)),
                                &result.tx_information.address.to_checksum(None),
                                &format!(
                                    "0x{}",
                                    hex::encode(result.tx_information.transaction_hash)
                                ),
                                &(result.tx_information.block_number as i64),
                                &result.tx_information.block_timestamp_to_datetime(),
                                &format!("0x{}", hex::encode(result.tx_information.block_hash)),
                                &result.tx_information.network,
                                &(result.tx_information.transaction_index as i64),
                                &result.tx_information.log_index.to_string(),
                            ],
                        )
                        .await;

                    if let Err(e) = insert_result {
                        rindexer_error!("Failed to insert BondInstructed instruction: {}", e);
                    }
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
