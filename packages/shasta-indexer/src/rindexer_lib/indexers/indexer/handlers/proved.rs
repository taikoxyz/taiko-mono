use crate::decoder::{error::DecodeError, shasta::decode_proved_data_shasta};
use crate::rindexer_lib::typings::indexer::events::shasta_inbox::{
    no_extensions, ProvedEvent, ShastaInboxEventType,
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

pub async fn proved_handler(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    let handler = ProvedEvent::handler(
        |results, context| async move {
            if results.is_empty() {
                return Ok(());
            }

            for result in results.iter() {
                // Proved event has raw data field that needs custom decoding
                match decode_proved_data_shasta(&result.event_data.data) {
                    Ok(decoded) => {
                        // First insert the proved event
                        let proved_insert_result = context.database.execute(
                            "INSERT INTO indexer_shasta_inbox.proved (
                                data, proposal_id, proposal_hash, parent_transition_hash,
                                end_block_number, end_block_hash, end_block_state_root,
                                designated_prover, actual_prover, span, transition_hash,
                                end_block_mini_header_hash, contract_address, tx_hash, block_number,
                                block_timestamp, block_hash, network, tx_index, log_index
                            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
                            ON CONFLICT (tx_hash, log_index) DO NOTHING",
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
                        ).await;

                        match proved_insert_result {
                            Ok(_) => {
                                // Get the proved_id by querying the inserted record
                                let tx_hash = format!("0x{}", hex::encode(result.tx_information.transaction_hash));
                                let log_index = result.tx_information.log_index.to_string();

                                let proved_id_result = context.database.query_one(
                                    "SELECT id FROM indexer_shasta_inbox.proved WHERE tx_hash = $1 AND log_index = $2",
                                    &[&tx_hash, &log_index]
                                ).await;

                                match proved_id_result {
                                    Ok(row) => {
                                        let proved_id: i64 = row.get(0);

                                        // Insert each bond instruction as a separate row
                                        for instruction in decoded.transitionRecord.bondInstructions.iter() {
                                            let bond_insert_result = context.database.execute(
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
                                                    &(result.tx_information.block_number as i64),
                                                ],
                                            ).await;

                                            if let Err(e) = bond_insert_result {
                                                rindexer_error!(
                                                    "Failed to insert Proved bond instruction: {}",
                                                    e
                                                );
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        rindexer_error!(
                                            "Failed to get proved_id for bond instructions: {}",
                                            e
                                        );
                                    }
                                }
                            }
                            Err(e) => {
                                rindexer_error!(
                                    "Failed to insert Proved event: {}",
                                    e
                                );
                            }
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
