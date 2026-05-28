//! Payload normalization helpers for building driver payload attributes.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::Bytes;
use alloy_provider::Provider;

use crate::{
    codec::{WhitelistExecutionPayloadEnvelope, decompress_tx_list},
    error::{Result, WhitelistPreconfirmationDriverError},
    payload_build::{DriverPayloadInputs, build_driver_payload},
};

use super::WhitelistPreconfirmationImporter;

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
            WhitelistPreconfirmationDriverError::invalid_payload("missing transactions list")
        })?;
        let tx_list = decompress_tx_list(compressed_tx_list)?;

        let signature = envelope.signature.unwrap_or([0u8; 65]);

        Ok(build_driver_payload(DriverPayloadInputs {
            parent_hash: execution_payload.parent_hash,
            block_number: execution_payload.block_number,
            fee_recipient: execution_payload.fee_recipient,
            gas_limit: execution_payload.gas_limit,
            timestamp: execution_payload.timestamp,
            prev_randao: execution_payload.prev_randao,
            extra_data: &execution_payload.extra_data,
            base_fee_per_gas: execution_payload.base_fee_per_gas,
            tx_list: Bytes::from(tx_list),
            signature,
            parent_beacon_block_root: envelope.parent_beacon_block_root,
            is_forced_inclusion: envelope.is_forced_inclusion.unwrap_or(false),
        }))
    }
}
