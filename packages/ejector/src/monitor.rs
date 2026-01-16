use std::{
    collections::{HashMap, HashSet},
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
    sync::{Mutex, Notify, RwLock},
    time::{interval, sleep},
};
use tracing::{debug, error, info, warn};

use crate::{
    beacon::BeaconClient,
    bindings::TaikoWrapper,
    metrics,
    monitor_reorg::{ChainReorgTracker, MAX_REORG_HISTORY, TrackedBlock},
    utils::{
        eject::{eject_operator, eject_operator_by_address, initialize_eject_metrics},
        lookahead::{Responsibility, responsibility_for_slot},
    },
};

#[derive(Default)]
struct OperatorCache {
    proposers: HashSet<Address>,
    sequencer_to_proposer: HashMap<Address, Address>,
}

impl OperatorCache {
    fn upsert(&mut self, proposer: Address, sequencer: Address) {
        self.proposers.insert(proposer);
        if !sequencer.is_zero() {
            self.sequencer_to_proposer.insert(sequencer, proposer);
        }
    }

    fn remove_proposer(&mut self, proposer: Address) {
        self.proposers.remove(&proposer);
        self.sequencer_to_proposer.retain(|_, existing| *existing != proposer);
    }

    fn proposer_for(&self, addr: Address) -> Option<Address> {
        if self.proposers.contains(&addr) {
            Some(addr)
        } else {
            self.sequencer_to_proposer.get(&addr).copied()
        }
    }

    fn clear(&mut self) {
        self.proposers.clear();
        self.sequencer_to_proposer.clear();
    }
}

async fn resolve_operator_for_coinbase<P>(
    coinbase: Address,
    whitelist: crate::bindings::IPreconfWhitelist::IPreconfWhitelistInstance<P>,
    cache: Arc<RwLock<OperatorCache>>,
) -> eyre::Result<Option<Address>>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    if coinbase.is_zero() {
        return Ok(None);
    }

    let info = whitelist.operators(coinbase).call().await?;
    let is_active = info.activeSince != 0 && info.inactiveSince == 0;
    if is_active {
        return Ok(Some(coinbase));
    }

    let cached = {
        let guard = cache.read().await;
        guard.proposer_for(coinbase)
    };

    if let Some(proposer) = cached {
        let info = whitelist.operators(proposer).call().await?;
        if info.activeSince != 0 && info.inactiveSince == 0 {
            return Ok(Some(proposer));
        }

        {
            let mut guard = cache.write().await;
            guard.remove_proposer(proposer);
        }
    }

    let refreshed = initialize_eject_metrics(&whitelist).await?;
    {
        let mut guard = cache.write().await;
        guard.clear();
        for (proposer, sequencer) in refreshed {
            guard.upsert(proposer, sequencer);
        }
    }

    let refreshed_match = {
        let guard = cache.read().await;
        guard.proposer_for(coinbase)
    };

    if let Some(proposer) = refreshed_match {
        let info = whitelist.operators(proposer).call().await?;
        if info.activeSince != 0 && info.inactiveSince == 0 {
            return Ok(Some(proposer));
        }

        {
            let mut guard = cache.write().await;
            guard.remove_proposer(proposer);
        }
    }

    Ok(None)
}

pub struct Monitor {
    beacon_client: BeaconClient,
    l1_signer: alloy::signers::local::PrivateKeySigner,
    l2_ws_url: Url,
    l2_http_url: Url,
    l1_ws_url: Url,
    l1_http_url: Url,
    eject_after: Duration,
    taiko_wrapper_address: Address,
    whitelist_address: Address,
    handover_slots: u64,
    preconf_router_address: Address,
    min_operators: u64,
    min_reorg_depth_for_eject: usize,
    reorg_ejection_enabled: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum SyncStatusClass {
    NotSyncing,
    Syncing,
    Unknown,
}

fn classify_sync_status(value: &serde_json::Value) -> SyncStatusClass {
    match value {
        serde_json::Value::Bool(false) | serde_json::Value::Null => SyncStatusClass::NotSyncing,
        serde_json::Value::Object(_) => SyncStatusClass::Syncing,
        _ => SyncStatusClass::Unknown,
    }
}

fn should_skip_for_sync_class(class: SyncStatusClass) -> bool {
    matches!(class, SyncStatusClass::Syncing | SyncStatusClass::Unknown)
}

impl Monitor {
    // Returns true if the node appears to be syncing or if the sync status cannot be determined.
    async fn should_skip_due_to_sync_status<P>(provider: &P, node_label: &str) -> bool
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
        match provider.syncing().await {
            Ok(syncing) => match serde_json::to_value(&syncing) {
                Ok(value) => {
                    let class = classify_sync_status(&value);
                    match class {
                        SyncStatusClass::NotSyncing => {}
                        SyncStatusClass::Syncing => {
                            warn!(node = node_label, "Node is syncing; skipping eject this tick");
                        }
                        SyncStatusClass::Unknown => {
                            warn!(
                                node = node_label,
                                "Unexpected sync status format: {value:?}; skipping eject this tick"
                            );
                        }
                    }
                    should_skip_for_sync_class(class)
                }
                Err(e) => {
                    warn!(
                        node = node_label,
                        "Failed to process sync status: {e:?}; skipping eject this tick"
                    );
                    true
                }
            },
            Err(e) => {
                warn!(
                    node = node_label,
                    "Failed to query sync status: {e:?}; skipping eject this tick"
                );
                true
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn new(
        beacon_client: BeaconClient,
        l1_signer: alloy::signers::local::PrivateKeySigner,
        l2_ws_url: Url,
        l2_http_url: Url,
        l1_ws_url: Url,
        l1_http_url: Url,
        eject_after_seconds: u64,
        taiko_wrapper_address: Address,
        whitelist_address: Address,
        handover_slots: u64,
        preconf_router_address: Address,
        min_operators: u64,
        min_reorg_depth_for_eject: usize,
        reorg_ejection_enabled: bool,
    ) -> Self {
        let eject_after = Duration::from_secs(eject_after_seconds);

        Self {
            beacon_client,
            l1_signer,
            l2_ws_url,
            l2_http_url,
            l1_ws_url,
            l1_http_url,
            eject_after,
            taiko_wrapper_address,
            whitelist_address,
            handover_slots,
            preconf_router_address,
            min_operators,
            min_reorg_depth_for_eject,
            reorg_ejection_enabled,
        }
    }

    // run starts a loop to watch for new blocks and run a callback on eject time reached.
    // it will update per epoch and handle reconnections, as well as check if preconfs are enabled
    // before starting the ejector. It will however monitor the block stream regardless.
    pub async fn run(&self) -> Result<()> {
        info!("Running block watcher at {}", self.l2_ws_url);

        let last_seen = Arc::new(Mutex::new(Instant::now()));
        let last_block_seen = Arc::new(Mutex::new(Instant::now()));
        let last_l2_head_number = Arc::new(Mutex::new(None::<u64>));
        let reconnect_notify = Arc::new(Notify::new());
        metrics::set_last_seen_drift_seconds(0);
        metrics::set_last_block_age_seconds(0);
        // Align watchdog tick with beacon slots to avoid spamming identical responsibility logs.
        let tick = Duration::from_secs(self.beacon_client.seconds_per_slot);
        let max = self.eject_after;
        let last_seen_for_watch = last_seen.clone();
        let last_block_for_watch = last_block_seen.clone();
        let last_l2_head_for_watch = last_l2_head_number.clone();
        let reconnect_notify_for_watch = reconnect_notify.clone();

        let l1_http_url = self.l1_http_url.clone();
        let l1_ws_url = self.l1_ws_url.clone();
        let l2_http_url = self.l2_http_url.clone();
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
        let l2_http_provider = ProviderBuilder::new().connect_http(l2_http_url.clone());
        let preconf_whitelist =
            crate::bindings::IPreconfWhitelist::new(self.whitelist_address, http_provider.clone());
        let operator_cache = Arc::new(RwLock::new(OperatorCache::default()));
        match initialize_eject_metrics(&preconf_whitelist).await {
            Ok(initialized) => {
                let mut cache = operator_cache.write().await;
                cache.clear();
                for (proposer, sequencer) in initialized {
                    cache.upsert(proposer, sequencer);
                }
            }
            Err(e) => {
                warn!("Failed to initialize eject metrics: {e:?}");
                let retry_cache = operator_cache.clone();
                let retry_whitelist = preconf_whitelist.clone();
                let _retry_handle = tokio::spawn(async move {
                    let mut backoff = Duration::from_secs(5);
                    let max_backoff = Duration::from_secs(60);
                    loop {
                        sleep(backoff).await;
                        match initialize_eject_metrics(&retry_whitelist).await {
                            Ok(initialized) => {
                                let mut cache = retry_cache.write().await;
                                cache.clear();
                                for (proposer, sequencer) in initialized {
                                    cache.upsert(proposer, sequencer);
                                }
                                info!("Initialized eject metrics after retry");
                                break;
                            }
                            Err(err) => {
                                warn!("Failed to initialize eject metrics (retry): {err:?}");
                                backoff = std::cmp::min(max_backoff, backoff * 2);
                            }
                        }
                    }
                });
            }
        }
        let preconf_router =
            crate::bindings::PreconfRouter::new(self.preconf_router_address, http_provider.clone());
        let _operator_added_listener = tokio::spawn(Self::operator_added_listener(
            l1_ws_url.clone(),
            whitelist_address,
            operator_cache.clone(),
        ));

        // watchdog task
        let watchdog_l1_http_url = l1_http_url.clone();
        let watchdog_signer = signer.clone();
        let mut shared_l2_http_provider = l2_http_provider;
        let _watchdog = tokio::spawn(async move {
            let mut ticker = interval(tick);
            let mut l2_block_query_failures: u32 = 0;
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

                    // L2 sanity check: if the L2 node is syncing or its head is advancing, avoid
                    // ejecting based solely on a stalled WS subscription.
                    let mut skip_due_to_l2 =
                        Self::should_skip_due_to_sync_status(&shared_l2_http_provider, "L2").await;

                    if !skip_due_to_l2 {
                        match shared_l2_http_provider.get_block_number().await {
                            Ok(l2_head) => {
                                l2_block_query_failures = 0;
                                let mut guard = last_l2_head_for_watch.lock().await;
                                match *guard {
                                    Some(prev) if l2_head > prev => {
                                        let ws_staleness =
                                            last_block_for_watch.lock().await.elapsed();
                                        warn!(
                                            prev_l2_head = prev,
                                            current_l2_head = l2_head,
                                            ws_staleness_secs = ws_staleness.as_secs(),
                                            "L2 head advanced while no WS block headers were observed; skipping eject and forcing resubscribe"
                                        );
                                        *guard = Some(l2_head);
                                        skip_due_to_l2 = true;
                                    }
                                    Some(prev) if l2_head < prev => {
                                        warn!(
                                            prev_l2_head = prev,
                                            current_l2_head = l2_head,
                                            "L2 head number decreased; skipping eject and forcing resubscribe"
                                        );
                                        *guard = Some(l2_head);
                                        skip_due_to_l2 = true;
                                    }
                                    None => {
                                        *guard = Some(l2_head);
                                    }
                                    _ => {}
                                }
                            }
                            Err(e) => {
                                // Recreate the provider on failure to avoid sticking with a bad client.
                                shared_l2_http_provider =
                                    ProviderBuilder::new().connect_http(l2_http_url.clone());
                                l2_block_query_failures = l2_block_query_failures.saturating_add(1);
                                warn!(
                                    "Failed to query L2 block number: {e:?}; skipping eject this tick"
                                );
                                if l2_block_query_failures == 5 {
                                    error!(
                                        failures = l2_block_query_failures,
                                        "Repeated L2 block number failures; check L2 HTTP configuration"
                                    );
                                }
                                skip_due_to_l2 = true;
                            }
                        }
                    }

                    if skip_due_to_l2 {
                        reconnect_notify_for_watch.notify_one();
                        *last_seen_for_watch.lock().await = Instant::now();
                        *last_block_for_watch.lock().await = Instant::now();
                        metrics::set_last_seen_drift_seconds(0);
                        continue;
                    }

                    // Query L1 sync state and decide whether to skip this tick.
                    let skip_due_to_l1 =
                        Self::should_skip_due_to_sync_status(&http_provider, "L1").await;

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
                        Ok(bn) => {
                            info!("WS get_block_number() = {bn}");
                            *last_l2_head_number.lock().await = Some(bn);
                        }
                        Err(e) => warn!("WS RPC get_block_number failed: {e}"),
                    }

                    match provider.subscribe_blocks().await {
                        Ok(sub) => {
                            let mut stream = sub.into_stream();
                            info!("Subscribed to block stream at {}", self.l2_ws_url);

                            loop {
                                tokio::select! {
                                    _ = reconnect_notify.notified() => {
                                        warn!("Reconnect requested; resubscribing to L2 block stream");
                                        break;
                                    }
                                    maybe_header = stream.next() => match maybe_header {
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
                                            coinbase: header.beneficiary,
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
                                        {
                                            let mut guard = last_l2_head_number.lock().await;
                                            *guard = Some(tracked_block.number);
                                        }
                                        backoff = Duration::from_secs(1);

                                        if outcome.parent_not_found {
                                            warn!(
                                                block_number,
                                                parent_hash = ?tracked_block.parent_hash,
                                                "Parent not found in local history; tracker was reset"
                                            );
                                            continue;
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

                                            if let Some(reverted_height) = outcome.reverted_to {
                                                metrics::note_reorg(reorg_depth, reverted_height);
                                            } else {
                                                warn!(
                                                    block_number,
                                                    depth = reorg_depth,
                                                    "Reorg detected but revert height missing; revert height metric set to -1"
                                                );
                                                metrics::note_reorg(reorg_depth, u64::MAX);
                                            }

                                            if !self.reorg_ejection_enabled {
                                                info!(
                                                    block_number,
                                                    depth = reorg_depth,
                                                    "Reorg ejection disabled via flag; skipping operator eject"
                                                );
                                                metrics::inc_reorg_skipped();
                                                continue;
                                            }

                                            if reorg_depth < self.min_reorg_depth_for_eject {
                                                info!(
                                                    block_number,
                                                    depth = reorg_depth,
                                                    threshold = self.min_reorg_depth_for_eject,
                                                    "Reorg depth below eject threshold; skipping operator eject"
                                                );
                                                metrics::inc_reorg_skipped();
                                                continue;
                                            }

                                            for removed in removed_blocks.iter() {
                                                debug!(
                                                    block_number = removed.number,
                                                    block_hash = ?removed.hash,
                                                    "Block removed due to reorg"
                                                );
                                            }

                                            let culprit = tracked_block.clone();
                                            let coinbase = culprit.coinbase;
                                            if coinbase.is_zero() {
                                                warn!(
                                                    block_number = culprit.number,
                                                    block_hash = ?culprit.hash,
                                                    "Culprit block has zero coinbase; skipping operator lookup"
                                                );
                                                continue;
                                            }

                                            let whitelist_for_lookup = preconf_whitelist.clone();
                                            let cache_for_lookup = operator_cache.clone();

                                            match resolve_operator_for_coinbase(
                                                coinbase,
                                                whitelist_for_lookup.clone(),
                                                cache_for_lookup.clone(),
                                            )
                                            .await
                                            {
                                                Ok(Some(operator_to_eject)) => {
                                                    info!(
                                                        block_number = culprit.number,
                                                        block_hash = ?culprit.hash,
                                                        coinbase = ?coinbase,
                                                        operator = ?operator_to_eject,
                                                        "Ejecting operator responsible for reorg"
                                                    );

                                                    let result = eject_operator_by_address(
                                                        l1_http_url.clone(),
                                                        signer.clone(),
                                                        whitelist_address,
                                                        operator_to_eject,
                                                        min_operators,
                                                    )
                                                    .await;

                                                    match result {
                                                        Ok(()) => {
                                                            let mut cache =
                                                                operator_cache.write().await;
                                                            cache
                                                                .remove_proposer(operator_to_eject);
                                                        }
                                                        Err(err) => {
                                                            error!(
                                                                block_number = culprit.number,
                                                                block_hash = ?culprit.hash,
                                                                coinbase = ?coinbase,
                                                                operator = ?operator_to_eject,
                                                                "Failed to eject operator for reorged block: {err:?}"
                                                            );
                                                        }
                                                    }
                                                }
                                                Ok(None) => {
                                                    warn!(
                                                        block_number = culprit.number,
                                                        block_hash = ?culprit.hash,
                                                        coinbase = ?coinbase,
                                                        "Unable to map coinbase to active operator; skipping eject"
                                                    );
                                                }
                                                Err(err) => {
                                                    error!(
                                                            block_number = culprit.number,
                                                            block_hash = ?culprit.hash,
                                                            coinbase = ?coinbase,
                                                        "Failed to resolve operator for reorged block: {err:?}"
                                                    );
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
        operator_cache: Arc<RwLock<OperatorCache>>,
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

                                        {
                                            let mut cache = operator_cache.write().await;
                                            cache.upsert(event.proposer, event.sequencer);
                                        }

                                        metrics::ensure_eject_metric_labels(&proposer_hex);
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
    use super::Monitor;
    use super::{SyncStatusClass, classify_sync_status, should_skip_for_sync_class};
    use alloy::providers::ProviderBuilder;
    use serde_json::json;
    use wiremock::matchers::{body_partial_json, method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    async fn run_sync_status_check_with_response(response: ResponseTemplate) -> bool {
        let server = MockServer::start().await;
        let expected_body = json!({ "method": "eth_syncing" });

        Mock::given(method("POST"))
            .and(path("/"))
            .and(body_partial_json(&expected_body))
            .respond_with(response)
            .mount(&server)
            .await;

        let url = alloy::transports::http::reqwest::Url::parse(&server.uri())
            .expect("mock server url should parse");
        let provider = ProviderBuilder::new().connect_http(url);

        Monitor::should_skip_due_to_sync_status(&provider, "L2").await
    }

    #[test]
    fn classify_sync_status_cases() {
        assert_eq!(classify_sync_status(&json!(false)), SyncStatusClass::NotSyncing);
        assert_eq!(classify_sync_status(&serde_json::Value::Null), SyncStatusClass::NotSyncing);
        assert_eq!(
            classify_sync_status(&json!({"startingBlock": "0x1"})),
            SyncStatusClass::Syncing
        );
        assert_eq!(classify_sync_status(&json!("weird")), SyncStatusClass::Unknown);
        assert_eq!(classify_sync_status(&json!(123)), SyncStatusClass::Unknown);
    }

    #[test]
    fn should_skip_for_sync_class_returns_expected() {
        assert!(!should_skip_for_sync_class(SyncStatusClass::NotSyncing));
        assert!(should_skip_for_sync_class(SyncStatusClass::Syncing));
        assert!(should_skip_for_sync_class(SyncStatusClass::Unknown));
    }

    #[tokio::test]
    async fn should_skip_when_syncing_response_is_object() {
        let response = ResponseTemplate::new(200).set_body_json(json!({
            "jsonrpc": "2.0",
            "id": 1,
            "result": {
                "startingBlock": "0x1",
                "currentBlock": "0x2",
                "highestBlock": "0x3"
            }
        }));
        let skip = run_sync_status_check_with_response(response).await;
        assert!(skip);
    }

    #[tokio::test]
    async fn should_skip_on_rpc_error() {
        let response = ResponseTemplate::new(200).set_body_json(json!({
            "jsonrpc": "2.0",
            "id": 1,
            "error": {
                "code": -32000,
                "message": "boom"
            }
        }));
        let skip = run_sync_status_check_with_response(response).await;
        assert!(skip);
    }

    #[tokio::test]
    async fn should_skip_on_malformed_json() {
        let response = ResponseTemplate::new(200)
            .set_body_raw("not-json", "application/json");
        let skip = run_sync_status_check_with_response(response).await;
        assert!(skip);
    }
}
