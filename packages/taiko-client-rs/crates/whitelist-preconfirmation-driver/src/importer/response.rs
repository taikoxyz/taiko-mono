use alloy_consensus::TxEnvelope;
use alloy_eips::Encodable2718;
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::eth::Transaction as RpcTransaction;
use protocol::codec::ZlibTxListCodec;
use tracing::warn;

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    error::{Result, WhitelistPreconfirmationDriverError},
    network::NetworkCommand,
};

use super::{MAX_COMPRESSED_TX_LIST_BYTES, WhitelistPreconfirmationImporter, provider_err};

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build a response envelope from local L2 state for an unsafe request hash.
    pub(super) async fn build_response_envelope_from_l2(
        &self,
        hash: B256,
    ) -> Result<Option<WhitelistExecutionPayloadEnvelope>> {
        let Some(block) = self
            .rpc
            .l2_provider
            .get_block_by_hash(hash)
            .full()
            .await
            .map_err(provider_err)?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
        else {
            return Ok(None);
        };

        if self
            .head_l1_origin_block_id()
            .await?
            .is_some_and(|head_l1_origin_block_id| block.header.number <= head_l1_origin_block_id)
        {
            return Ok(None);
        }

        let Some(l1_origin) = self.rpc.l1_origin_by_id(U256::from(block.header.number)).await?
        else {
            return Ok(None);
        };

        if l1_origin.signature == [0u8; 65] {
            return Ok(None);
        }

        let Some(transactions) = block.transactions.as_transactions() else {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
                "request-response block missing full transaction bodies".to_string(),
            ));
        };

        let raw_transactions = transactions
            .iter()
            .map(|tx: &TxEnvelope| tx.encoded_2718().to_vec())
            .collect::<Vec<_>>();
        let compressed_tx_list = ZlibTxListCodec::new(MAX_COMPRESSED_TX_LIST_BYTES)
            .encode(&raw_transactions)
            .map_err(|err| {
                WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                    "failed to encode request-response tx list: {err}"
                ))
            })?;

        let end_of_sequencing = self
            .cache
            .get(&hash)
            .and_then(|envelope| envelope.end_of_sequencing)
            .filter(|enabled| *enabled);
        let base_fee = block.header.base_fee_per_gas.ok_or_else(|| {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "request-response block {} missing base fee",
                block.header.number
            ))
        })?;

        Ok(Some(WhitelistExecutionPayloadEnvelope {
            end_of_sequencing,
            is_forced_inclusion: l1_origin.is_forced_inclusion.then_some(true),
            parent_beacon_block_root: None,
            execution_payload: alloy_rpc_types_engine::ExecutionPayloadV1 {
                parent_hash: block.header.parent_hash,
                fee_recipient: block.header.beneficiary,
                state_root: block.header.state_root,
                receipts_root: block.header.receipts_root,
                logs_bloom: block.header.logs_bloom,
                prev_randao: block.header.mix_hash,
                block_number: block.header.number,
                gas_limit: block.header.gas_limit,
                gas_used: block.header.gas_used,
                timestamp: block.header.timestamp,
                extra_data: block.header.extra_data.clone(),
                base_fee_per_gas: U256::from(base_fee),
                block_hash: block.header.hash,
                transactions: vec![Bytes::from(compressed_tx_list)],
            },
            signature: Some(l1_origin.signature),
        }))
    }

    /// Publish a block-hash request on `requestPreconfBlocks`.
    pub(super) async fn publish_unsafe_request(&self, hash: B256) {
        if let Err(err) =
            self.network_command_tx.send(NetworkCommand::PublishUnsafeRequest { hash }).await
        {
            warn!(
                hash = %hash,
                error = %err,
                "failed to queue whitelist preconfirmation request publish command"
            );
        }
    }

    /// Publish an envelope response on `responsePreconfBlocks`.
    pub(super) async fn publish_unsafe_response(
        &self,
        envelope: WhitelistExecutionPayloadEnvelope,
    ) {
        let hash = envelope.execution_payload.block_hash;
        if let Err(err) = self
            .network_command_tx
            .send(NetworkCommand::PublishUnsafeResponse { envelope: Box::new(envelope) })
            .await
        {
            warn!(
                hash = %hash,
                error = %err,
                "failed to queue whitelist preconfirmation response publish command"
            );
        }
    }
}
