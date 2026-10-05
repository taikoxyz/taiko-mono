//! Payload build/signing helpers used by `build_preconf_block`.

use crate::codec::decompress_tx_list;

use super::*;

/// Build the execution-payload view of a build request used for validation and
/// driver-payload construction. Hash and post-execution fields are zeroed.
fn request_execution_payload(data: &ExecutableData, prev_randao: B256) -> ExecutionPayloadV1 {
    ExecutionPayloadV1 {
        parent_hash: data.parent_hash,
        fee_recipient: data.fee_recipient,
        state_root: B256::ZERO,
        receipts_root: B256::ZERO,
        logs_bloom: Bloom::default(),
        prev_randao,
        block_number: data.block_number,
        gas_limit: data.gas_limit,
        gas_used: 0,
        timestamp: data.timestamp,
        extra_data: data.extra_data.clone(),
        base_fee_per_gas: U256::from(data.base_fee_per_gas),
        block_hash: B256::ZERO,
        transactions: vec![data.transactions.clone()],
    }
}

/// Build the envelope gossiped for a block this node inserted from a REST request.
///
/// The envelope carries the request's compressed transaction list and `parentBeaconBlockRoot`
/// (a zero root is carried as `None`; both encode as the same 32 zero bytes on the wire), the
/// inserted header's fields, and the header difficulty only when it is nonzero. The base fee
/// falls back to the request's when the header has none.
pub(super) fn published_envelope(
    data: &ExecutableData,
    inserted_header: &RpcHeader,
    end_of_sequencing: Option<bool>,
    is_forced_inclusion: Option<bool>,
    signature: [u8; 65],
) -> WhitelistExecutionPayloadEnvelope {
    let base_fee_per_gas = inserted_header.base_fee_per_gas.unwrap_or(data.base_fee_per_gas);
    WhitelistExecutionPayloadEnvelope {
        end_of_sequencing,
        is_forced_inclusion,
        parent_beacon_block_root: data.parent_beacon_block_root.filter(|root| !root.is_zero()),
        header_difficulty: (!inserted_header.difficulty.is_zero())
            .then_some(inserted_header.difficulty),
        execution_payload: crate::payload::execution_payload_from_header(
            inserted_header,
            base_fee_per_gas,
            vec![data.transactions.clone()],
        ),
        signature: Some(signature),
    }
}

/// Build driver payload attributes from the requested executable data, including its
/// `parentBeaconBlockRoot` (an absent one is sent as the zero root).
pub(super) fn driver_payload_from_request(
    data: &ExecutableData,
    is_forced_inclusion: Option<bool>,
    prev_randao: B256,
    signature: [u8; 65],
) -> Result<TaikoPayloadAttributes> {
    let tx_list = decompress_tx_list(data.transactions.as_ref())?;
    Ok(crate::payload::build_driver_payload(
        &request_execution_payload(data, prev_randao),
        tx_list,
        data.parent_beacon_block_root,
        is_forced_inclusion.unwrap_or(false),
        signature,
    ))
}

impl WhitelistApiService {
    /// Build a 65-byte signature from a digest.
    pub(super) fn sign_digest(&self, digest: B256) -> Result<[u8; 65]> {
        let signature = self
            .signer
            .sign_hash_sync(&digest)
            .map_err(|e| WhitelistPreconfirmationDriverError::Signing(e.to_string()))?;

        Ok(signature.as_rsy())
    }

    /// Derive the mix-hash / prev-randao from the parent block.
    pub(super) async fn derive_prev_randao(
        &self,
        parent_hash: B256,
        block_number: u64,
    ) -> Result<B256> {
        let parent = self
            .rpc
            .l2_provider
            .get_block_by_hash(parent_hash)
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?
            .ok_or_else(|| {
                WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                    "parent block not found for hash {parent_hash}"
                ))
            })?;

        let expected_block_number = parent.header.number.saturating_add(1);
        if block_number != expected_block_number {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "block number {block_number} must follow parent number {}",
                parent.header.number
            )));
        }

        let parent_mix_hash = B256::from(parent.header.difficulty.to_be_bytes::<32>());
        Ok(calculate_shasta_mix_hash(parent_mix_hash, block_number))
    }

    /// Validate request payload shape, under the fork rules of its timestamp, before expensive
    /// insertion and signing operations.
    pub(super) fn validate_request_payload(
        &self,
        data: &ExecutableData,
        prev_randao: B256,
    ) -> Result<()> {
        validate_execution_payload_for_preconf(
            &request_execution_payload(data, prev_randao),
            data.parent_beacon_block_root,
            self.etna_fork_timestamp,
            self.chain_id,
            *self.rpc.shasta.anchor.address(),
        )
    }
}
