use std::{
    collections::{HashSet, VecDeque},
    sync::Arc,
    time::{Duration, Instant},
};

use alloy::{
    primitives::{Address, B256},
    providers::{Provider, ProviderBuilder, WsConnect},
    transports::http::reqwest::Url,
};
use eyre::Result;
use futures_util::StreamExt;
use tokio::{
    sync::{Mutex, RwLock},
    time::{interval, sleep},
};
use tracing::{debug, error, info, warn};

use crate::{
    beacon::BeaconClient,
    bindings::TaikoWrapper,
    metrics,
    utils::{
        eject::{eject_operator, eject_operator_by_address, initialize_eject_metrics},
        lookahead::{Responsibility, responsibility_for_slot},
    },
};

const MAX_REORG_HISTORY: usize = 768;

#[derive(Clone, Debug, PartialEq, Eq)]
struct TrackedBlock {
    number: u64,
    hash: B256,
    parent_hash: B256,
    proposer: Address,
}

#[derive(Default)]
struct ApplyOutcome {
    reorged: Vec<TrackedBlock>,
    parent_not_found: bool,
    duplicate: bool,
}

impl ApplyOutcome {
    fn duplicate() -> Self {
        Self { duplicate: true, ..Self::default() }
    }
}

struct ChainReorgTracker {
    history: VecDeque<TrackedBlock>,
    max_depth: usize,
}

impl ChainReorgTracker {
    fn new(max_depth: usize) -> Self {
        Self { history: VecDeque::with_capacity(max_depth.max(1)), max_depth: max_depth.max(1) }
    }

    fn apply(&mut self, block: TrackedBlock) -> ApplyOutcome {
        if self.history.iter().any(|stored| stored.hash == block.hash) {
            return ApplyOutcome::duplicate();
        }

        let mut outcome = ApplyOutcome::default();

        while let Some(last) = self.history.back() {
            if last.number >= block.number {
                let removed = self.history.pop_back().expect("history.pop_back failed");
                if removed.hash == block.hash {
                    // identical block already tracked; restore state and treat as duplicate
                    self.history.push_back(removed);
                    return ApplyOutcome::duplicate();
                }
                outcome.reorged.push(removed);
                continue;
            }

            if last.hash != block.parent_hash {
                let removed = self.history.pop_back().expect("history.pop_back failed");
                outcome.reorged.push(removed);
                continue;
            }

            break;
        }

        let parent_missing = match self.history.back() {
            Some(last) => last.hash != block.parent_hash,
            None => !outcome.reorged.is_empty(),
        };

        if parent_missing {
            outcome.parent_not_found = true;
            while let Some(removed) = self.history.pop_back() {
                outcome.reorged.push(removed);
            }
        }

        self.history.push_back(block);

        while self.history.len() > self.max_depth {
            self.history.pop_front();
        }

        outcome
    }
}

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
    min_reorg_depth_for_eject: usize,
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
        min_reorg_depth_for_eject: usize,
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
            min_reorg_depth_for_eject,
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
        let known_operators = Arc::new(RwLock::new(HashSet::new()));
        match initialize_eject_metrics(&preconf_whitelist).await {
            Ok(initialized) => {
                *known_operators.write().await = initialized;
            }
            Err(e) => {
                warn!("Failed to initialize eject metrics: {e:?}");
            }
        }
        let preconf_router =
            crate::bindings::PreconfRouter::new(self.preconf_router_address, http_provider.clone());
        let _operator_added_listener = tokio::spawn(Self::operator_added_listener(
            l1_ws_url.clone(),
            whitelist_address,
            known_operators.clone(),
        ));

        // watchdog task
        let watchdog_l1_http_url = l1_http_url.clone();
        let watchdog_signer = signer.clone();
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

                match are_preconfs_enabled(&watchdog_l1_http_url, taiko_wrapper_address).await {
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
                        watchdog_l1_http_url.clone(),
                        watchdog_signer.clone(),
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
        let mut reorg_tracker = ChainReorgTracker::new(MAX_REORG_HISTORY);
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
                                        info!(
                                            "New block header: number={:?} hash={:?}, coinbase={:?}",
                                            header.number, header.hash, header.beneficiary
                                        );

                                        let block_number = header.number;
                                        let block_hash = header.hash;

                                        let tracked_block = TrackedBlock {
                                            number: block_number,
                                            hash: block_hash,
                                            parent_hash: header.parent_hash,
                                            proposer: header.beneficiary,
                                        };

                                        let outcome = reorg_tracker.apply(tracked_block.clone());

                                        if outcome.duplicate {
                                            debug!(block_number, block_hash = ?tracked_block.hash, "Duplicate block notification received; skipping");
                                            continue;
                                        }

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
                                        backoff = Duration::from_secs(1);

                                        if outcome.parent_not_found {
                                            warn!(
                                                block_number,
                                                parent_hash = ?tracked_block.parent_hash,
                                                "Parent not found in local history; tracker was reset"
                                            );
                                        }

                                        if !outcome.reorged.is_empty() {
                                            let reorg_depth = outcome.reorged.len();
                                            let removed_blocks = outcome.reorged;

                                            warn!(
                                                block_number,
                                                new_head = ?tracked_block.hash,
                                                depth = reorg_depth,
                                                "Detected L2 reorg"
                                            );

                                            metrics::note_reorg(reorg_depth);

                                            if reorg_depth < self.min_reorg_depth_for_eject {
                                                info!(
                                                    block_number,
                                                    depth = reorg_depth,
                                                    threshold = self.min_reorg_depth_for_eject,
                                                    "Reorg depth below eject threshold; skipping operator eject"
                                                );
                                                metrics::inc_reorg_skipped();
                                            } else {
                                                for removed in removed_blocks {
                                                    if removed.proposer.is_zero() {
                                                        warn!(
                                                            block_number = removed.number,
                                                            block_hash = ?removed.hash,
                                                            "Reorged block has zero proposer; skipping eject"
                                                        );
                                                        continue;
                                                    }

                                                    info!(
                                                        block_number = removed.number,
                                                        block_hash = ?removed.hash,
                                                        proposer = ?removed.proposer,
                                                        "Ejecting operator due to reorged block"
                                                    );

                                                    if let Err(err) = eject_operator_by_address(
                                                        l1_http_url.clone(),
                                                        signer.clone(),
                                                        whitelist_address,
                                                        removed.proposer,
                                                        min_operators,
                                                    )
                                                    .await
                                                    {
                                                        error!(
                                                            block_number = removed.number,
                                                            block_hash = ?removed.hash,
                                                            proposer = ?removed.proposer,
                                                            "Failed to eject operator for reorged block: {err:?}"
                                                        );
                                                    }
                                                }
                                            }
                                        }
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

    async fn operator_added_listener(
        l1_ws_url: Url,
        whitelist_address: Address,
        known_operators: Arc<RwLock<HashSet<(Address, Address)>>>,
    ) {
        let mut backoff = Duration::from_secs(1);
        let max_backoff = Duration::from_secs(30);

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

                                        let key = (event.proposer, event.sequencer);
                                        let is_new = {
                                            let mut guard = known_operators.write().await;
                                            guard.insert(key)
                                        };

                                        if is_new {
                                            metrics::ensure_eject_metric_labels(&sequencer_hex);
                                        } else {
                                            debug!(
                                                %proposer_hex,
                                                %sequencer_hex,
                                                "Operator already initialized; skipping metric setup"
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

#[cfg(test)]
mod tests {
    use super::*;

    fn hash(id: u64) -> B256 {
        let mut bytes = [0u8; 32];
        bytes[24..].copy_from_slice(&id.to_be_bytes());
        B256::from(bytes)
    }

    fn addr(id: u64) -> Address {
        let mut bytes = [0u8; 20];
        bytes[12..].copy_from_slice(&id.to_be_bytes());
        Address::from(bytes)
    }

    fn block(number: u64, parent_id: u64, hash_id: u64, proposer_id: u64) -> TrackedBlock {
        TrackedBlock {
            number,
            parent_hash: hash(parent_id),
            hash: hash(hash_id),
            proposer: addr(proposer_id),
        }
    }

    #[test]
    fn tracker_accepts_linear_progression() {
        let mut tracker = ChainReorgTracker::new(8);

        let genesis = block(1, 0, 1, 10);
        let outcome = tracker.apply(genesis.clone());
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);

        let second = block(2, 1, 2, 11);
        let outcome = tracker.apply(second.clone());
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);

        let third = block(3, 2, 3, 12);
        let outcome = tracker.apply(third);
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);
    }

    #[test]
    fn tracker_detects_single_block_reorg() {
        let mut tracker = ChainReorgTracker::new(8);

        let genesis = block(1, 0, 1, 10);
        tracker.apply(genesis.clone());
        let block2 = block(2, 1, 2, 11);
        tracker.apply(block2.clone());
        let block3_old = block(3, 2, 30, 12);
        tracker.apply(block3_old.clone());

        let block3_new = block(3, 2, 31, 99);
        let outcome = tracker.apply(block3_new);

        assert_eq!(outcome.reorged.len(), 1);
        assert_eq!(outcome.reorged[0].hash, block3_old.hash);
        assert_eq!(outcome.reorged[0].proposer, block3_old.proposer);
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);
    }

    #[test]
    fn tracker_detects_multi_block_reorg() {
        let mut tracker = ChainReorgTracker::new(8);

        let genesis = block(1, 0, 1, 10);
        tracker.apply(genesis.clone());
        let block2_old = block(2, 1, 20, 11);
        tracker.apply(block2_old.clone());
        let block3_old = block(3, 20, 30, 12);
        tracker.apply(block3_old.clone());

        let block2_new = block(2, 1, 21, 55);
        let outcome = tracker.apply(block2_new.clone());

        assert_eq!(outcome.reorged.len(), 2);
        assert_eq!(outcome.reorged[0].hash, block3_old.hash);
        assert_eq!(outcome.reorged[1].hash, block2_old.hash);
        assert!(!outcome.parent_not_found);

        let block3_new = block(3, 21, 31, 56);
        let outcome = tracker.apply(block3_new);
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
    }

    #[test]
    fn tracker_marks_parent_not_found_when_history_missing() {
        let mut tracker = ChainReorgTracker::new(2);

        let genesis = block(1, 0, 1, 10);
        tracker.apply(genesis.clone());
        let block2 = block(2, 1, 2, 11);
        tracker.apply(block2.clone());
        let block3 = block(3, 2, 3, 12);
        tracker.apply(block3.clone());

        // Parent hash does not exist in truncated history.
        let block4 = block(4, 999, 4, 13);
        let outcome = tracker.apply(block4);

        assert_eq!(outcome.reorged.len(), 2);
        assert!(outcome.parent_not_found);
    }
}
