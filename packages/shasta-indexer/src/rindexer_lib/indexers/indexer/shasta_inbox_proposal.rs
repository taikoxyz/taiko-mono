#![allow(non_snake_case)]
use super::super::super::typings::indexer::events::shasta_inbox_proposal::{
    no_extensions, BondInstructedEvent, ProposedEvent, ProvedEvent, ShastaInboxProposalEventType,
};
use alloy::primitives::{I256, U256, U64};
use rindexer::{
    event::callback_registry::EventCallbackRegistry, rindexer_error, rindexer_info,
    EthereumSqlTypeWrapper, PgType, RindexerColorize,
};
use std::path::PathBuf;
use std::sync::Arc;

async fn bond_instructed_handler(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    let handler = BondInstructedEvent::handler(|results, context| async move {
                                if results.is_empty() {
                                    return Ok(());
                                }



                    let mut postgres_bulk_data: Vec<Vec<EthereumSqlTypeWrapper>> = vec![];

                    for result in results.iter() {

                        let data = vec![
EthereumSqlTypeWrapper::Address(result.tx_information.address),
EthereumSqlTypeWrapper::VecU64(result.event_data.instructions.iter().cloned().map(|v| v.proposalId).map(|item| item.to()).collect::<Vec<_>>()),
EthereumSqlTypeWrapper::VecU8(result.event_data.instructions.iter().cloned().map(|v| v.bondType).map(|item| item).collect::<Vec<_>>()),
EthereumSqlTypeWrapper::VecAddress(result.event_data.instructions.iter().cloned().map(|v| v.payer).map(|item| item).collect::<Vec<_>>()),
EthereumSqlTypeWrapper::VecAddress(result.event_data.instructions.iter().cloned().map(|v| v.receiver).map(|item| item).collect::<Vec<_>>()),
EthereumSqlTypeWrapper::B256(result.tx_information.transaction_hash),
EthereumSqlTypeWrapper::U64(result.tx_information.block_number),
EthereumSqlTypeWrapper::DateTimeNullable(result.tx_information.block_timestamp_to_datetime()),
EthereumSqlTypeWrapper::B256(result.tx_information.block_hash),
EthereumSqlTypeWrapper::String(result.tx_information.network.to_string()),
EthereumSqlTypeWrapper::U64(result.tx_information.transaction_index),
EthereumSqlTypeWrapper::U256(result.tx_information.log_index)
];
                        postgres_bulk_data.push(data);
                    }



                    if postgres_bulk_data.is_empty() {
                        return Ok(());
                    }

                    let rows = ["contract_address".to_string(), "instructions_proposal_id".to_string(), "instructions_bond_type".to_string(), "instructions_payer".to_string(), "instructions_receiver".to_string(), "tx_hash".to_string(), "block_number".to_string(), "block_timestamp".to_string(), "block_hash".to_string(), "network".to_string(), "tx_index".to_string(), "log_index".to_string()];

                    if postgres_bulk_data.len() > 100 {
                        let result = context
                            .database
                            .bulk_insert_via_copy(
                                "indexer_shasta_inbox_proposal.bond_instructed",
                                &rows,
                                &postgres_bulk_data
                                    .first()
                                    .ok_or("No first element in bulk data, impossible")?
                                    .iter()
                                    .map(|param| param.to_type())
                                    .collect::<Vec<PgType>>(),
                                &postgres_bulk_data,
                            )
                            .await;

                        if let Err(e) = result {
                            rindexer_error!("ShastaInboxProposalEventType::BondInstructed inserting bulk data via COPY: {:?}", e);
                            return Err(e.to_string());
                        }
                        } else {
                            let result = context
                                .database
                                .bulk_insert(
                                    "indexer_shasta_inbox_proposal.bond_instructed",
                                    &rows,
                                    &postgres_bulk_data,
                                )
                                .await;

                            if let Err(e) = result {
                                rindexer_error!("ShastaInboxProposalEventType::BondInstructed inserting bulk data via INSERT: {:?}", e);
                                return Err(e.to_string());
                            }
                    }


                                rindexer_info!(
                                    "ShastaInboxProposal::BondInstructed - {} - {} events",
                                    "INDEXED".green(),
                                    results.len(),
                                );

                                Ok(())
                            },
                            no_extensions(),
                          )
                          .await;

    ShastaInboxProposalEventType::BondInstructed(handler)
        .register(manifest_path, registry)
        .await;
}

async fn proposed_handler(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    let handler = ProposedEvent::handler(|results, context| async move {
                                if results.is_empty() {
                                    return Ok(());
                                }



                    let mut postgres_bulk_data: Vec<Vec<EthereumSqlTypeWrapper>> = vec![];

                    for result in results.iter() {

                        let data = vec![
EthereumSqlTypeWrapper::Address(result.tx_information.address),
EthereumSqlTypeWrapper::Bytes(result.event_data.data.clone()),
EthereumSqlTypeWrapper::B256(result.tx_information.transaction_hash),
EthereumSqlTypeWrapper::U64(result.tx_information.block_number),
EthereumSqlTypeWrapper::DateTimeNullable(result.tx_information.block_timestamp_to_datetime()),
EthereumSqlTypeWrapper::B256(result.tx_information.block_hash),
EthereumSqlTypeWrapper::String(result.tx_information.network.to_string()),
EthereumSqlTypeWrapper::U64(result.tx_information.transaction_index),
EthereumSqlTypeWrapper::U256(result.tx_information.log_index)
];
                        postgres_bulk_data.push(data);
                    }



                    if postgres_bulk_data.is_empty() {
                        return Ok(());
                    }

                    let rows = ["contract_address".to_string(), "data".to_string(), "tx_hash".to_string(), "block_number".to_string(), "block_timestamp".to_string(), "block_hash".to_string(), "network".to_string(), "tx_index".to_string(), "log_index".to_string()];

                    if postgres_bulk_data.len() > 100 {
                        let result = context
                            .database
                            .bulk_insert_via_copy(
                                "indexer_shasta_inbox_proposal.proposed",
                                &rows,
                                &postgres_bulk_data
                                    .first()
                                    .ok_or("No first element in bulk data, impossible")?
                                    .iter()
                                    .map(|param| param.to_type())
                                    .collect::<Vec<PgType>>(),
                                &postgres_bulk_data,
                            )
                            .await;

                        if let Err(e) = result {
                            rindexer_error!("ShastaInboxProposalEventType::Proposed inserting bulk data via COPY: {:?}", e);
                            return Err(e.to_string());
                        }
                        } else {
                            let result = context
                                .database
                                .bulk_insert(
                                    "indexer_shasta_inbox_proposal.proposed",
                                    &rows,
                                    &postgres_bulk_data,
                                )
                                .await;

                            if let Err(e) = result {
                                rindexer_error!("ShastaInboxProposalEventType::Proposed inserting bulk data via INSERT: {:?}", e);
                                return Err(e.to_string());
                            }
                    }


                                rindexer_info!(
                                    "ShastaInboxProposal::Proposed - {} - {} events",
                                    "INDEXED".green(),
                                    results.len(),
                                );

                                Ok(())
                            },
                            no_extensions(),
                          )
                          .await;

    ShastaInboxProposalEventType::Proposed(handler)
        .register(manifest_path, registry)
        .await;
}

async fn proved_handler(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    let handler = ProvedEvent::handler(
        |results, context| async move {
            if results.is_empty() {
                return Ok(());
            }

            let mut postgres_bulk_data: Vec<Vec<EthereumSqlTypeWrapper>> = vec![];

            for result in results.iter() {
                let data = vec![
                    EthereumSqlTypeWrapper::Address(result.tx_information.address),
                    EthereumSqlTypeWrapper::Bytes(result.event_data.data.clone()),
                    EthereumSqlTypeWrapper::B256(result.tx_information.transaction_hash),
                    EthereumSqlTypeWrapper::U64(result.tx_information.block_number),
                    EthereumSqlTypeWrapper::DateTimeNullable(
                        result.tx_information.block_timestamp_to_datetime(),
                    ),
                    EthereumSqlTypeWrapper::B256(result.tx_information.block_hash),
                    EthereumSqlTypeWrapper::String(result.tx_information.network.to_string()),
                    EthereumSqlTypeWrapper::U64(result.tx_information.transaction_index),
                    EthereumSqlTypeWrapper::U256(result.tx_information.log_index),
                ];
                postgres_bulk_data.push(data);
            }

            if postgres_bulk_data.is_empty() {
                return Ok(());
            }

            let rows = [
                "contract_address".to_string(),
                "data".to_string(),
                "tx_hash".to_string(),
                "block_number".to_string(),
                "block_timestamp".to_string(),
                "block_hash".to_string(),
                "network".to_string(),
                "tx_index".to_string(),
                "log_index".to_string(),
            ];

            if postgres_bulk_data.len() > 100 {
                let result = context
                    .database
                    .bulk_insert_via_copy(
                        "indexer_shasta_inbox_proposal.proved",
                        &rows,
                        &postgres_bulk_data
                            .first()
                            .ok_or("No first element in bulk data, impossible")?
                            .iter()
                            .map(|param| param.to_type())
                            .collect::<Vec<PgType>>(),
                        &postgres_bulk_data,
                    )
                    .await;

                if let Err(e) = result {
                    rindexer_error!(
                        "ShastaInboxProposalEventType::Proved inserting bulk data via COPY: {:?}",
                        e
                    );
                    return Err(e.to_string());
                }
            } else {
                let result = context
                    .database
                    .bulk_insert(
                        "indexer_shasta_inbox_proposal.proved",
                        &rows,
                        &postgres_bulk_data,
                    )
                    .await;

                if let Err(e) = result {
                    rindexer_error!(
                        "ShastaInboxProposalEventType::Proved inserting bulk data via INSERT: {:?}",
                        e
                    );
                    return Err(e.to_string());
                }
            }

            rindexer_info!(
                "ShastaInboxProposal::Proved - {} - {} events",
                "INDEXED".green(),
                results.len(),
            );

            Ok(())
        },
        no_extensions(),
    )
    .await;

    ShastaInboxProposalEventType::Proved(handler)
        .register(manifest_path, registry)
        .await;
}
pub async fn shasta_inbox_proposal_handlers(
    manifest_path: &PathBuf,
    registry: &mut EventCallbackRegistry,
) {
    bond_instructed_handler(manifest_path, registry).await;

    proposed_handler(manifest_path, registry).await;

    proved_handler(manifest_path, registry).await;
}
