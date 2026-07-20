//! `WhitelistApi` implementation for the API service.

use super::*;

impl WhitelistApiService {
    /// Reject build requests when this node's own P2P signer is not a registered
    /// operator in the on-chain whitelist.
    ///
    /// Peers only accept gossip from whitelisted operators, so if our signer has been
    /// deregistered any block we build would be dropped on arrival. Failing fast here
    /// avoids building blocks that can never be gossiped.
    fn ensure_node_signer_whitelisted(&self) -> Result<()> {
        let signer = self.signer.address();
        if self.operator_set.load().contains(&signer) {
            Ok(())
        } else {
            Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "node P2P signer {signer} is not a registered operator"
            )))
        }
    }

    /// Send one network command and map channel failures into a consistent P2P error.
    async fn send_network_command(
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
}

/// Emit the entry log for a preconfirmation block-building request.
fn log_build_preconf_block_entry(
    data: &ExecutableData,
    end_of_sequencing: Option<bool>,
    is_forced_inclusion: Option<bool>,
) {
    tracing::info!(
        block_id = data.block_number,
        coinbase = %data.fee_recipient,
        timestamp = data.timestamp,
        gas_limit = data.gas_limit,
        base_fee_per_gas = data.base_fee_per_gas,
        extra_data = %alloy_primitives::hex::encode(&data.extra_data),
        parent_hash = %data.parent_hash,
        end_of_sequencing = end_of_sequencing.unwrap_or(false),
        is_forced_inclusion = is_forced_inclusion.unwrap_or(false),
        "🏗️ New preconfirmation block building request"
    );
}

#[async_trait]
impl WhitelistApi for WhitelistApiService {
    /// Build, sign, publish, and return a preconfirmation block.
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        let started_at = Instant::now();
        // Record receipt before any validation so even rejected requests
        // mark this pod as the active preconfer for shutdown purposes.
        self.mark_preconf_request_received().await;

        let BuildPreconfBlockRequest { executable_data, end_of_sequencing, is_forced_inclusion } =
            request;
        let Some(data) = executable_data else {
            return Err(WhitelistPreconfirmationDriverError::invalid_payload(
                "executable data is required",
            ));
        };
        log_build_preconf_block_entry(&data, end_of_sequencing, is_forced_inclusion);

        let _build_guard = self.build_preconf_lock.lock().await;

        // Guard against building on a genuinely syncing node, but tolerate the false-
        // positive that taiko-geth emits on genesis chains (currentBlock == highestBlock
        // == 0, txIndexRemainingBlocks = 1).  When current == highest the node is not
        // actually catching up to a remote peer, so we allow the build to proceed.
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
                driver::DriverError::EngineSyncing(data.block_number),
            ));
        }

        self.ensure_node_signer_whitelisted()?;

        let prev_randao = self.derive_prev_randao(data.parent_hash, data.block_number).await?;
        self.validate_request_payload(&data, prev_randao)?;

        // Insert the preconfirmation payload locally first to
        // obtain the canonical block hash before gossiping.
        let driver_payload =
            self.driver_payload_from_request(&data, is_forced_inclusion, prev_randao, [0u8; 65])?;
        let submission_outcome = self
            .event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(driver_payload, data.parent_hash))
            .await?;
        let bound_block_hash = match submission_outcome {
            PreconfSubmissionOutcome::Inserted { block_hash } |
            PreconfSubmissionOutcome::AlreadyMaterialized { block_hash } => block_hash,
            PreconfSubmissionOutcome::Stale => {
                return Err(WhitelistPreconfirmationDriverError::invalid_payload(format!(
                    "preconfirmation block {} is stale",
                    data.block_number
                )));
            }
        };

        // Resolve the block by the hash bound to the submission outcome: a same-height sibling
        // can become canonical between submission and this read, and a height lookup would then
        // sign a hash that does not match the request's transactions.
        let inserted_block = self
            .rpc
            .l2_provider
            .get_block_by_hash(bound_block_hash)
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?
            .ok_or(WhitelistPreconfirmationDriverError::MissingInsertedBlock(data.block_number))?;

        if inserted_block.header.parent_hash != data.parent_hash {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block parent hash mismatch at block {}: expected {}, got {}",
                data.block_number, data.parent_hash, inserted_block.header.parent_hash
            )));
        }
        if inserted_block.header.number != data.block_number {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block number mismatch: expected {}, got {}",
                data.block_number, inserted_block.header.number
            )));
        }

        let block_hash = inserted_block.header.hash;
        let block_number = inserted_block.header.number;
        let block_header = inserted_block.header.clone();
        let base_fee_per_gas =
            inserted_block.header.base_fee_per_gas.unwrap_or(data.base_fee_per_gas);
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
        self.state.record_inserted_block(block_number);

        let execution_payload = crate::payload::execution_payload_from_header(
            &inserted_block.header,
            base_fee_per_gas,
            vec![data.transactions.clone()],
        );

        let envelope = WhitelistExecutionPayloadEnvelope {
            end_of_sequencing,
            is_forced_inclusion,
            parent_beacon_block_root: None,
            header_difficulty: (!inserted_block.header.difficulty.is_zero())
                .then_some(inserted_block.header.difficulty),
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

        // Cache the envelope locally before publishing so EOS catch-up and
        // request-topic lookups can serve this block even without peer echo.
        let envelope = Arc::new(envelope);
        self.state.insert_recent(envelope.clone()).await;

        // Publish to gossipsub.
        self.send_network_command(
            NetworkCommand::PublishUnsafePayload { signature: wire_signature, envelope },
            "publish",
        )
        .await?;

        // If end-of-sequencing, record the epoch marker. No `/ws` notification here:
        // matching the Go client, subscribers are only notified when a gossiped EOS
        // block is imported (the builder already learns its own EOS block from
        // this endpoint's response). Incoming sequencers that missed the gossip
        // request it on the EOS request topic, which the importer serves from the
        // recent-envelope cache.
        if end_of_sequencing.unwrap_or(false) {
            // Key the marker by the wall-clock epoch at record time (Go's build
            // path uses `CurrentEpoch()`), matching how the requesting operator
            // looks the marker up at handover.
            self.state
                .record_end_of_sequencing(self.beacon_client.current_epoch(), block_hash)
                .await;
        }

        crate::metrics::WhitelistPreconfirmationDriverMetrics::observe_build_preconf_block_duration(
            started_at.elapsed().as_secs_f64(),
        );

        Ok(BuildPreconfBlockResponse { block_header })
    }

    /// Return runtime status for the whitelist preconfirmation driver.
    async fn get_status(&self) -> Result<ApiStatus> {
        self.get_status_snapshot().await
    }

    /// Whether preconfirmation ingress is ready to serve build requests.
    fn is_sync_ready(&self) -> bool {
        self.event_syncer.is_preconf_ingress_ready()
    }

    /// Subscribe to end-of-sequencing websocket notifications.
    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.subscribe_end_of_sequencing_notifications()
    }
}
