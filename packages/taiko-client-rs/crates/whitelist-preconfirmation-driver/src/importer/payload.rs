use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
use protocol::shasta::{PAYLOAD_ID_VERSION_V2, payload_id_to_bytes};

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    error::{Result, WhitelistPreconfirmationDriverError},
};

use super::{WhitelistPreconfirmationImporter, decompress_tx_list};

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build the driver payload from the whitelist envelope.
    pub(super) fn build_driver_payload(
        &self,
        envelope: &WhitelistExecutionPayloadEnvelope,
    ) -> Result<TaikoPayloadAttributes> {
        let execution_payload = &envelope.execution_payload;
        let compressed_tx_list = execution_payload.transactions.first().ok_or_else(|| {
            WhitelistPreconfirmationDriverError::InvalidPayload(
                "missing transactions list".to_string(),
            )
        })?;
        let tx_list = decompress_tx_list(compressed_tx_list)?;

        let signature = envelope.signature.unwrap_or([0u8; 65]);

        let block_metadata = TaikoBlockMetadata {
            beneficiary: execution_payload.fee_recipient,
            gas_limit: execution_payload.gas_limit,
            timestamp: U256::from(execution_payload.timestamp),
            mix_hash: execution_payload.prev_randao,
            tx_list: Some(Bytes::from(tx_list)),
            extra_data: execution_payload.extra_data.clone(),
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: execution_payload.timestamp,
            prev_randao: execution_payload.prev_randao,
            suggested_fee_recipient: execution_payload.fee_recipient,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: envelope.parent_beacon_block_root,
        };

        let l1_origin = RpcL1Origin {
            block_id: U256::from(execution_payload.block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: None,
            l1_block_hash: None,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion: envelope.is_forced_inclusion.unwrap_or(false),
            signature,
        };

        let mut payload = TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: execution_payload.base_fee_per_gas,
            block_metadata,
            l1_origin,
            anchor_transaction: None,
        };

        let payload_id =
            payload_id_taiko(&execution_payload.parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
        payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);

        Ok(payload)
    }
}
