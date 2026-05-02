//! Payload build/signing helpers used by `build_preconf_block`.

use crate::codec::decompress_tx_list;

use super::*;

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build driver payload attributes from the RPC request.
    pub(super) fn build_driver_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
        signature: [u8; 65],
    ) -> Result<TaikoPayloadAttributes> {
        let tx_list = decompress_tx_list(request.transactions.as_ref())?;

        let block_metadata = TaikoBlockMetadata {
            beneficiary: request.fee_recipient,
            gas_limit: request.gas_limit,
            timestamp: U256::from(request.timestamp),
            mix_hash: prev_randao,
            tx_list: Some(tx_list.into()),
            extra_data: request.extra_data.clone(),
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: request.timestamp,
            prev_randao,
            suggested_fee_recipient: request.fee_recipient,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: None,
            slot_number: None,
        };

        let mut payload = TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::from(request.base_fee_per_gas),
            block_metadata,
            l1_origin: RpcL1Origin {
                block_id: U256::from(request.block_number),
                l2_block_hash: B256::ZERO,
                l1_block_height: None,
                l1_block_hash: None,
                build_payload_args_id: [0u8; 8],
                is_forced_inclusion: request.is_forced_inclusion.unwrap_or(false),
                signature,
            },
            anchor_transaction: None,
        };

        let payload_id = payload_id_taiko(&request.parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
        payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);
        Ok(payload)
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
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
    ) -> Result<()> {
        let payload = ExecutionPayloadV1 {
            parent_hash: request.parent_hash,
            fee_recipient: request.fee_recipient,
            state_root: B256::ZERO,
            receipts_root: B256::ZERO,
            logs_bloom: Bloom::default(),
            prev_randao,
            block_number: request.block_number,
            gas_limit: request.gas_limit,
            gas_used: 0,
            timestamp: request.timestamp,
            extra_data: request.extra_data.clone(),
            base_fee_per_gas: U256::from(request.base_fee_per_gas),
            block_hash: B256::ZERO,
            transactions: vec![request.transactions.clone()],
        };

        validate_execution_payload_for_preconf(
            &payload,
            self.chain_id,
            *self.rpc.shasta.anchor.address(),
        )
    }

    /// Update highest unsafe block tracking on each insertion/reorg point.
    pub(super) async fn update_highest_unsafe(&self, block_number: u64) {
        *self.highest_unsafe_l2_payload_block_id.lock().await = block_number;
    }
}
