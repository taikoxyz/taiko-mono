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

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build driver payload attributes from the requested executable data.
    pub(super) fn build_driver_payload(
        &self,
        data: &ExecutableData,
        is_forced_inclusion: Option<bool>,
        prev_randao: B256,
        signature: [u8; 65],
    ) -> Result<TaikoPayloadAttributes> {
        let tx_list = decompress_tx_list(data.transactions.as_ref())?;
        Ok(crate::payload::build_driver_payload(
            &request_execution_payload(data, prev_randao),
            tx_list,
            None,
            is_forced_inclusion.unwrap_or(false),
            signature,
        ))
    }

    /// Build a 65-byte signature from a digest.
    pub(super) fn sign_digest(&self, digest: B256) -> Result<[u8; 65]> {
        let sig_result = self
            .signer
            .sign_with_predefined_k(digest.as_ref())
            .map_err(|e| WhitelistPreconfirmationDriverError::Signing(e.to_string()))?;

        let mut sig_bytes = [0u8; 65];
        sig_bytes[..32].copy_from_slice(&sig_result.signature.r().to_be_bytes::<32>());
        sig_bytes[32..64].copy_from_slice(&sig_result.signature.s().to_be_bytes::<32>());
        sig_bytes[64] = sig_result.recovery_id;
        Ok(sig_bytes)
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

    /// Validate request payload shape before expensive insertion and signing operations.
    pub(super) fn validate_request_payload(
        &self,
        data: &ExecutableData,
        prev_randao: B256,
    ) -> Result<()> {
        validate_execution_payload_for_preconf(
            &request_execution_payload(data, prev_randao),
            self.chain_id,
            *self.rpc.shasta.anchor.address(),
        )
    }
}
