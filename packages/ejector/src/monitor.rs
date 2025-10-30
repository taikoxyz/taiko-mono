use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy::{
    primitives::Address,
    providers::{Provider, ProviderBuilder, WsConnect},
    transports::http::reqwest::Url,
};
use eyre::Result;
use futures_util::StreamExt;
use tokio::{
    sync::Mutex,
    time::{interval, sleep},
};
use tracing::{debug, error, info, warn};

use crate::{
    beacon::BeaconClient,
    bindings::TaikoWrapper,
    metrics,
    utils::{
        eject::{eject_operator, initialize_eject_metrics},
        lookahead::{Responsibility, responsibility_for_slot},
    },
};

pub struct Monitor {
    beacon_client: BeaconClient,
    l1_signer: alloy::signers::local::PrivateKeySigner,
    l2_ws_url: Url,
    l1_ws_url: Url,
    l1_http_url: Url,
    target_block_time: Duration,
    eject_after: Duration,
    taiko_wrapper_address: Address,
    whitelist_address: Address,
    handover_slots: u64,
    preconf_router_address: Address,
    min_operators: u64,
}

impl Monitor {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        beacon_client: BeaconClient,
        l1_signer: alloy::signers::local::PrivateKeySigner,
        l2_ws_url: Url,
        l1_ws_url: Url,
        l1_http_url: Url,
        target_block_time_secs: u64,
        eject_after_n_slots_missed: u64,
        taiko_wrapper_address: Address,
        whitelist_address: Address,
        handover_slots: u64,
        preconf_router_address: Address,
        min_operators: u64,
    ) -> Self {
        let target_block_time = Duration::from_secs(target_block_time_secs);
        let eject_after_secs = target_block_time_secs.saturating_mul(eject_after_n_slots_missed);
        let eject_after = Duration::from_secs(eject_after_secs);

        Self {
            beacon_client,
            l1_signer,
            l2_ws_url,
            l1_ws_url,
            l1_http_url,
            target_block_time,
            eject_after,
            taiko_wrapper_address,
            whitelist_address,
            handover_slots,
            preconf_router_address,
            min_operators,
        }
    }

    // run starts a loop to watch for new blocks and run a callback on eject time reached.
    // it will update per epoch and handle reconnections, as well as check if preconfs are enabled
    // before starting the ejector. It will however monitor the block stream regardless.
    pub async fn run(&self) -> Result<()> {
        info!("Running block watcher at {}", self.l2_ws_url);

        let last_seen = Arc::new(Mutex::new(Instant::now()));
        let last_block_seen = Arc::new(Mutex::new(Instant::now()));
        metrics::set_last_seen_drift_seconds(0);
        metrics::set_last_block_age_seconds(0);
        let tick = self.target_block_time;
        let max = self.eject_after;
        let last_seen_for_watch = last_seen.clone();
        let last_block_for_watch = last_block_seen.clone();

        let l1_http_url = self.l1_http_url.clone();
        let l1_ws_url = self.l1_ws_url.clone();
        let taiko_wrapper_address = self.taiko_wrapper_address;
        let whitelist_address = self.whitelist_address;
        let signer = self.l1_signer.clone();

        let slots_per_epoch = self.beacon_client.slots_per_epoch;
        let mut handover_slots = self.handover_slots;

        // Track when we've last reloaded config from chain
        let mut last_config_reload_epoch = self.beacon_client.current_epoch();

        // get current operator responsibility
        let mut prev_resp = self.responsibility_now();

        let beacon_client = self.beacon_client.clone();

        // we only eject if we have at least min_operators in the whitelist.
        // that way in case of an error with the ejector we don't eject down to 0 operators.
        let min_operators = self.min_operators;

        // Reuse a single HTTP provider and PreconfRouter binding
        let http_provider = ProviderBuilder::new().connect_http(l1_http_url.clone());
        let preconf_whitelist =
            crate::bindings::IPreconfWhitelist::new(self.whitelist_address, http_provider.clone());
        if let Err(e) = initialize_eject_metrics(&preconf_whitelist).await {
            warn!("Failed to initialize eject metrics: {e:?}");
        }
        let preconf_router =
            crate::bindings::PreconfRouter::new(self.preconf_router_address, http_provider.clone());
        let _operator_added_listener = tokio::spawn(Self::operator_added_listener(
            l1_ws_url.clone(),
            l1_http_url.clone(),
            whitelist_address,
        ));

        // watchdog task
        let _watchdog = tokio::spawn(async move {
            let mut ticker = interval(tick);
            loop {
                ticker.tick().await;

                // log out epoch and slots
                let curr_epoch = beacon_client.current_epoch();
                let curr_slot = beacon_client.current_slot();
                let slot_in_epoch = beacon_client.slot_in_epoch();
                // Reload handover config from chain at epoch transitions (best-effort)
                if curr_epoch > last_config_reload_epoch {
                    tracing::info!(
                        "Epoch transition detected; reloading handover config; last_config_reload_epoch={last_config_reload_epoch}, curr_epoch={curr_epoch}",
                    );
                    match preconf_router.getConfig().call().await {
                        Ok(onchain_slots) => {
                            // Convert uint256 -> u64 (use low 64 bits)
                            let new_slots: u64 = onchain_slots.as_limbs()[0];
                            if new_slots != handover_slots {
                                tracing::info!(
                                    "Updated handover slots from on-chain config; old={handover_slots}, new={new_slots}"
                                );
                                handover_slots = new_slots;
                            }
                        }
                        Err(e) => {
                            // Allow failure: contract upgrade may not be deployed yet
                            tracing::warn!(
                                "Failed to fetch PreconfRouter config; keeping current handover slots; error={e:?}; current={handover_slots}",
                            );
                        }
                    }
                    last_config_reload_epoch = curr_epoch;
                }

                let curr_resp = responsibility_for_slot(curr_slot, slots_per_epoch, handover_slots);

                info!(
                    "Current epoch: {}, slot: {}, slot in epoch {}, responsibility {:?}",
                    curr_epoch, curr_slot, slot_in_epoch, curr_resp
                );

                if curr_resp != prev_resp {
                    *last_seen_for_watch.lock().await = Instant::now();
                    metrics::set_last_seen_drift_seconds(0);
                    tracing::info!(
                        "Preconf responsibility changed to {:?} (epoch {}). Reset timer.",
                        curr_resp.lookahead,
                        curr_resp.epoch
                    );
                    prev_resp = curr_resp;
                }

                match are_preconfs_enabled(&l1_http_url, taiko_wrapper_address).await {
                    Ok(false) => {
                        // zero out the last seen
                        *last_seen_for_watch.lock().await = Instant::now();
                        metrics::set_last_seen_drift_seconds(0);
                        debug!("Preconfs are disabled, skipping block watch and resetting timer");
                        continue;
                    }
                    Err(e) => {
                        // should rarely happen, l1 rpc error only
                        warn!("preconfs check error: {e:?}; skipping eject this tick");
                        // don't reset timer; just skip the eject decision below
                        continue;
                    }
                    Ok(true) => {}
                }

                let elapsed = last_seen_for_watch.lock().await.elapsed();
                metrics::set_last_seen_drift_seconds(elapsed.as_secs());
                let block_age = last_block_for_watch.lock().await.elapsed();
                metrics::set_last_block_age_seconds(block_age.as_secs());
                if elapsed >= max {
                    warn!("Max time reached without new blocks: {:?}", elapsed);

                    // Query L1 sync state and decide whether to skip this tick.
                    let mut skip_due_to_l1 = false;
                    match http_provider.syncing().await {
                        Ok(syncing) => match serde_json::to_value(&syncing) {
                            Ok(serde_json::Value::Bool(false)) => {
                                // Fully synced; proceed to eject
                            }
                            Ok(serde_json::Value::Object(_)) => {
                                warn!("L1 node is syncing; skipping eject this tick");
                                skip_due_to_l1 = true;
                            }
                            Ok(unexpected) => {
                                warn!(
                                    "Unexpected L1 sync status format: {unexpected:?}; skipping eject this tick"
                                );
                                skip_due_to_l1 = true;
                            }
                            Err(e) => {
                                warn!(
                                    "Failed to process L1 sync status: {e:?}; skipping eject this tick"
                                );
                                skip_due_to_l1 = true;
                            }
                        },
                        Err(e) => {
                            warn!(
                                "Failed to query L1 sync status: {e:?}; skipping eject this tick"
                            );
                            skip_due_to_l1 = true;
                        }
                    }

                    if skip_due_to_l1 {
                        // Reset timer so we don't immediately eject when node catches up
                        *last_seen_for_watch.lock().await = Instant::now();
                        metrics::set_last_seen_drift_seconds(0);
                        continue;
                    }

                    if let Err(e) = eject_operator(
                        l1_http_url.clone(),
                        signer.clone(),
                        whitelist_address,
                        curr_resp.lookahead,
                        min_operators,
                    )
                    .await
                    {
                        error!("Error during eject action: {:?}", e);
                    }
                    *last_seen_for_watch.lock().await = Instant::now();
                    metrics::set_last_seen_drift_seconds(0);
                }
            }
        });

        // reconnect loop backoff params
        let mut backoff = Duration::from_secs(1);
        let max_backoff = Duration::from_secs(30);

        loop {
            info!("Connecting to block stream...");
            match ProviderBuilder::new().connect_ws(WsConnect::new(self.l2_ws_url.clone())).await {
                Ok(provider) => {
                    info!("Connected to block stream at {}", self.l2_ws_url);
                    metrics::inc_ws_reconnections();
                    // sanity
                    match provider.get_block_number().await {
                        Ok(bn) => info!("WS get_block_number() = {bn}"),
                        Err(e) => warn!("WS RPC get_block_number failed: {e}"),
                    }

                    match provider.subscribe_blocks().await {
                        Ok(sub) => {
                            let mut stream = sub.into_stream();
                            info!("Subscribed to block stream at {}", self.l2_ws_url);

                            loop {
                                match stream.next().await {
                                    Some(header) => {
                                        // number/hash are often Option<_> → use {:?}
                                        info!(
                                            "New block header: number={:?} hash={:?}, coinbase={:?}",
                                            header.number, header.hash, header.beneficiary
                                        );

                                        metrics::inc_l2_blocks();
                                        let now = Instant::now();
                                        {
                                            let mut guard = last_seen.lock().await;
                                            *guard = now;
                                        }
                                        metrics::set_last_seen_drift_seconds(0);
                                        {
                                            let mut guard = last_block_seen.lock().await;
                                            *guard = now;
                                        }
                                        metrics::set_last_block_age_seconds(0);
                                        backoff = Duration::from_secs(1); // reset after good event
                                    }
                                    None => {
                                        warn!("Block stream ended unexpectedly, reconnecting...");
                                        break; // exit inner loop to reconnect
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            warn!("Failed to subscribe to block stream: {e}, will reconnect...");
                        }
                    }
                }
                Err(e) => {
                    warn!("Failed to connect to block stream: {e}. Retrying in {:?}...", backoff);
                }
            }

            warn!("Reconnecting after {:?}", backoff);
            sleep(backoff).await;
            if backoff < max_backoff {
                backoff = std::cmp::min(max_backoff, backoff * 2);
            }
        }
    }

    fn responsibility_now(&self) -> Responsibility {
        let slot = self.beacon_client.current_slot();
        responsibility_for_slot(slot, self.beacon_client.slots_per_epoch, self.handover_slots)
    }

    async fn operator_added_listener(l1_ws_url: Url, l1_http_url: Url, whitelist_address: Address) {
        let mut backoff = Duration::from_secs(1);
        let max_backoff = Duration::from_secs(30);

        let http_provider = ProviderBuilder::new().connect_http(l1_http_url.clone());
        let http_whitelist =
            crate::bindings::IPreconfWhitelist::new(whitelist_address, http_provider.clone());

        loop {
            info!("Connecting to OperatorAdded event stream at {}", l1_ws_url);
            match ProviderBuilder::new().connect_ws(WsConnect::new(l1_ws_url.clone())).await {
                Ok(ws_provider) => {
                    info!("Connected to OperatorAdded event stream at {}", l1_ws_url);
                    let contract = crate::bindings::IPreconfWhitelist::new(
                        whitelist_address,
                        ws_provider.clone(),
                    );

                    match contract.OperatorAdded_filter().subscribe().await {
                        Ok(subscription) => {
                            backoff = Duration::from_secs(1);
                            let mut stream = subscription.into_stream();

                            while let Some(item) = stream.next().await {
                                match item {
                                    Ok((event, log)) => {
                                        if log.removed {
                                            debug!(
                                                block = ?log.block_number,
                                                log_index = ?log.log_index,
                                                "OperatorAdded log removed; skipping"
                                            );
                                            continue;
                                        }

                                        let proposer_hex = format!("{:#x}", event.proposer);
                                        let sequencer_hex = format!("{:#x}", event.sequencer);

                                        info!(
                                            %proposer_hex,
                                            %sequencer_hex,
                                            active_since = ?event.activeSince,
                                            "OperatorAdded event received"
                                        );

                                        metrics::ensure_eject_metric_labels(&sequencer_hex);

                                        if let Err(e) =
                                            initialize_eject_metrics(&http_whitelist).await
                                        {
                                            warn!(
                                                "Failed to refresh eject metrics after OperatorAdded: {e:?}"
                                            );
                                        }
                                    }
                                    Err(e) => {
                                        warn!("OperatorAdded stream error: {e:?}");
                                        break;
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            warn!("Failed to subscribe to OperatorAdded events: {e:?}");
                        }
                    }
                }
                Err(e) => {
                    warn!(
                        "Failed to connect to OperatorAdded event stream: {e:?}. Retrying after {:?}",
                        backoff
                    );
                }
            }

            warn!("OperatorAdded subscription disconnected. Reconnecting after {:?}", backoff);
            sleep(backoff).await;
            if backoff < max_backoff {
                backoff = std::cmp::min(max_backoff, backoff * 2);
            }
        }
    }
}

pub async fn are_preconfs_enabled(
    l1_http_url: &Url,
    taiko_wrapper_address: Address,
) -> Result<bool> {
    let provider = ProviderBuilder::new().connect_http(l1_http_url.clone());

    let taiko_wrapper = TaikoWrapper::new(taiko_wrapper_address, provider);

    let preconf_router = taiko_wrapper.preconfRouter().call().await?;

    Ok(!preconf_router.is_zero())
}
