//! `WhitelistApi` implementation for the API service.

use super::*;

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Send one network command and map channel failures into a consistent P2P error.
    async fn send_network_command(
        &self,
        command: NetworkCommand,
        command_name: &'static str,
    ) -> Result<()> {
        self.network_command_tx.send(command).await.map_err(|err| {
            WhitelistPreconfirmationDriverError::P2p(format!(
                "failed to send {command_name} command: {err}"
            ))
        })
    }
}

#[async_trait]
impl<P> WhitelistApi for WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build, sign, publish, and return a preconfirmation block.
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        let started_at = Instant::now();
        let _build_guard = self.build_preconf_lock.lock().await;

        // Guard against building on a genuinely syncing node, but tolerate the false-
        // positive that taiko-geth emits on genesis chains (currentBlock == highestBlock
        // == 0, txIndexRemainingBlocks = 1).  When current == highest the node is not
        // actually catching up to a remote peer, so we allow the build to proceed.
        let sync_status =
            self.rpc.l2_provider.syncing().await.map_err(super::compression::provider_err)?;
        if let SyncStatus::Info(ref info) = sync_status &&
            info.current_block < info.highest_block
        {
            return Err(WhitelistPreconfirmationDriverError::Driver(
                driver::DriverError::EngineSyncing(request.block_number),
            ));
        }

        self.ensure_fee_recipient_allowed(request.fee_recipient).await?;

        let prev_randao =
            self.derive_prev_randao(request.parent_hash, request.block_number).await?;
        self.validate_request_payload(&request, prev_randao)?;

        // Insert the preconfirmation payload locally first to
        // obtain the canonical block hash before gossiping.
        let driver_payload = self.build_driver_payload(&request, prev_randao, [0u8; 65])?;
        self.event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(driver_payload))
            .await?;

        let inserted_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(request.block_number))
            .await
            .map_err(super::compression::provider_err)?
            .ok_or(WhitelistPreconfirmationDriverError::MissingInsertedBlock(
                request.block_number,
            ))?;

        if inserted_block.header.parent_hash != request.parent_hash {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block parent hash mismatch at block {}: expected {}, got {}",
                request.block_number, request.parent_hash, inserted_block.header.parent_hash
            )));
        }
        if inserted_block.header.number != request.block_number {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block number mismatch: expected {}, got {}",
                request.block_number, inserted_block.header.number
            )));
        }

        let block_hash = inserted_block.header.hash;
        let block_number = inserted_block.header.number;
        let block_header = inserted_block.header.clone();
        let base_fee_per_gas =
            inserted_block.header.base_fee_per_gas.unwrap_or(request.base_fee_per_gas);
        let block_hash_signature =
            self.sign_digest(block_signing_hash(self.chain_id, block_hash.as_slice()))?;

        // Persist per-block signature before gossip so RPC readers can immediately resolve
        // canonical origin signatures for the inserted block.
        self.rpc
            .set_l1_origin_signature(
                U256::from(block_number),
                FixedBytes::<65>::from(block_hash_signature),
            )
            .await?;
        self.update_highest_unsafe(block_number).await;

        let execution_payload = ExecutionPayloadV1 {
            parent_hash: inserted_block.header.parent_hash,
            fee_recipient: inserted_block.header.beneficiary,
            state_root: inserted_block.header.state_root,
            receipts_root: inserted_block.header.receipts_root,
            logs_bloom: inserted_block.header.logs_bloom,
            prev_randao: inserted_block.header.mix_hash,
            block_number,
            gas_limit: inserted_block.header.gas_limit,
            gas_used: inserted_block.header.gas_used,
            timestamp: inserted_block.header.timestamp,
            extra_data: inserted_block.header.extra_data.clone(),
            base_fee_per_gas: U256::from(base_fee_per_gas),
            block_hash,
            transactions: vec![request.transactions.clone()],
        };

        let envelope = WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: request.end_of_sequencing,
            is_forced_inclusion: request.is_forced_inclusion,
            parent_beacon_block_root: None,
            execution_payload,
            signature: Some(block_hash_signature),
        };

        // Wire signature for preconfBlocks topic is over full SSZ envelope bytes.
        let ssz_bytes = encode_envelope_ssz(&envelope);
        let wire_signature = self.sign_digest(block_signing_hash(self.chain_id, &ssz_bytes))?;

        debug!(
            block_number,
            block_hash = %block_hash,
            "publishing signed whitelist preconfirmation payload"
        );

        // Publish to gossipsub.
        self.send_network_command(
            NetworkCommand::PublishUnsafePayload {
                signature: wire_signature,
                envelope: Arc::new(envelope),
            },
            "publish",
        )
        .await?;

        // If end-of-sequencing, also publish the EOS request.
        if request.end_of_sequencing.unwrap_or(false) {
            let epoch = self.beacon_client.timestamp_to_epoch(request.timestamp).map_err(|e| {
                WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                    "failed to derive epoch from block timestamp {}: {e}",
                    request.timestamp
                ))
            })?;
            self.cache_state.record_end_of_sequencing(epoch, block_hash).await;
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
            self.send_network_command(
                NetworkCommand::PublishEndOfSequencingRequest { epoch },
                "end-of-sequencing",
            )
            .await?;
        }

        histogram!(
            crate::metrics::WhitelistPreconfirmationDriverMetrics::BUILD_PRECONF_BLOCK_DURATION_SECONDS
        )
        .record(started_at.elapsed().as_secs_f64());

        Ok(BuildPreconfBlockResponse { block_header })
    }

    /// Return runtime status for the whitelist preconfirmation driver.
    async fn get_status(&self) -> Result<WhitelistStatus> {
        self.get_status_snapshot().await
    }

    /// Subscribe to end-of-sequencing websocket notifications.
    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.subscribe_end_of_sequencing_notifications()
    }
}
