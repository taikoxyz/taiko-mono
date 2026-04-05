//! Payload build/signing helpers used by `build_preconf_block`.

use super::*;

#[async_trait]
impl<P> PreconfBuildRuntime for ApiBuildRuntime<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Guard against building on a genuinely syncing node.
    async fn ensure_build_node_ready(&self, request: &BuildPreconfBlockRequest) -> Result<()> {
        let sync_status = self
            .rpc
            .l2_provider
            .syncing()
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?;
        if let SyncStatus::Info(ref info) = sync_status &&
            info.current_block < info.highest_block
        {
            return Err(WhitelistPreconfirmationDriverError::Driver(
                driver::DriverError::EngineSyncing(request.block_number),
            ));
        }

        Ok(())
    }

    /// Check fee recipient against current/next operator sequencing ranges.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()> {
        self.ensure_fee_recipient_allowed_for_current_slot(fee_recipient).await
    }

    /// Derive the mix-hash / prev-randao from the parent block.
    async fn derive_prev_randao(&self, parent_hash: B256, block_number: u64) -> Result<B256> {
        self.derive_prev_randao(parent_hash, block_number).await
    }

    /// Validate request payload shape before expensive insertion and signing operations.
    fn validate_request_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
    ) -> Result<()> {
        self.validate_request_payload_impl(request, prev_randao)
    }

    /// Build driver payload attributes from the RPC request.
    fn build_driver_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
        signature: [u8; 65],
    ) -> Result<TaikoPayloadAttributes> {
        let tx_list =
            crate::tx_list_codec::decode_preconfirmation_tx_list(request.transactions.as_ref())?;

        let block_metadata = TaikoBlockMetadata {
            beneficiary: request.fee_recipient,
            gas_limit: request.gas_limit,
            timestamp: U256::from(request.timestamp),
            mix_hash: prev_randao,
            tx_list: Some(tx_list),
            extra_data: request.extra_data.clone(),
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: request.timestamp,
            prev_randao,
            suggested_fee_recipient: request.fee_recipient,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: None,
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

    /// Submit one payload for local insertion through the event-sync ingress path.
    async fn submit_preconfirmation_payload(&self, payload: PreconfPayload) -> Result<()> {
        self.event_syncer.submit_preconfirmation_payload(payload).await.map_err(Into::into)
    }

    /// Load the inserted canonical block header after local insertion succeeds.
    async fn inserted_block_header(&self, block_number: u64) -> Result<alloy_rpc_types::Header> {
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?
            .map(|block| block.header)
            .ok_or(WhitelistPreconfirmationDriverError::MissingInsertedBlock(block_number))
    }

    /// Build a 65-byte signature from a digest.
    fn sign_digest(&self, digest: B256) -> Result<[u8; 65]> {
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

    /// Persist the canonical block-hash signature for RPC readers.
    async fn set_l1_origin_signature(
        &self,
        block_number: u64,
        block_hash_signature: [u8; 65],
    ) -> Result<()> {
        let _ = self
            .rpc
            .set_l1_origin_signature(
                U256::from(block_number),
                FixedBytes::<65>::from(block_hash_signature),
            )
            .await
            .map_err(WhitelistPreconfirmationDriverError::from)?;
        Ok(())
    }

    /// Update highest unsafe block tracking on each insertion/reorg point.
    async fn update_highest_unsafe(&self, block_number: u64) {
        self.shared_state.update_highest_unsafe(block_number).await;
    }

    /// Publish one network command and map channel failures into a consistent P2P error.
    async fn publish_network_command(
        &self,
        command: NetworkCommand,
        command_name: &'static str,
    ) -> Result<()> {
        self.network_command_tx.send(command).await.map_err(|err| {
            WhitelistPreconfirmationDriverError::p2p(format!(
                "failed to send {command_name} command: {err}"
            ))
        })
    }

    /// Record EOS state, notify websocket subscribers, and gossip the EOS request.
    async fn handle_end_of_sequencing(
        &self,
        request: &BuildPreconfBlockRequest,
        block_hash: B256,
    ) -> Result<()> {
        let epoch = self.beacon_client.timestamp_to_epoch(request.timestamp).map_err(|e| {
            WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "failed to derive epoch from block timestamp {}: {e}",
                request.timestamp
            ))
        })?;
        self.shared_state.record_end_of_sequencing(epoch, block_hash).await;
        if let Err(err) = self
            .eos_notification_tx
            .send(EndOfSequencingNotification { current_epoch: epoch, end_of_sequencing: true })
        {
            warn!(
                error = %err,
                current_epoch = epoch,
                "failed to deliver end-of-sequencing websocket notification"
            );
        }
        self.publish_network_command(
            NetworkCommand::PublishEndOfSequencingRequest { epoch },
            "end-of-sequencing",
        )
        .await
    }

    /// Return the chain ID used for signature domain separation.
    fn chain_id(&self) -> u64 {
        self.chain_id
    }
}

impl<P> ApiBuildRuntime<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Derive the mix-hash / prev-randao from the parent block.
    async fn derive_prev_randao(&self, parent_hash: B256, block_number: u64) -> Result<B256> {
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

        let parent_difficulty = B256::from(parent.header.difficulty.to_be_bytes::<32>());
        Ok(calculate_shasta_difficulty(parent_difficulty, block_number))
    }

    /// Validate request payload shape before expensive insertion and signing operations.
    fn validate_request_payload_impl(
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
}
