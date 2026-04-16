use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy::{
    primitives::Address,
    providers::{Provider, ProviderBuilder},
    transports::http::reqwest::Url,
};
use eyre::Result;
use tokio::{
    sync::{Mutex, RwLock},
    time::interval,
};
use tracing::{debug, error, info, warn};

mod l1_events;
mod l2_poller;

use crate::{
    beacon::BeaconClient,
    bindings::TaikoWrapper,
    metrics,
    monitor_reorg::{ChainReorgTracker, MAX_REORG_HISTORY},
    utils::{
        eject::{eject_operator, eject_operator_by_address, initialize_eject_metrics},
        lookahead::{Responsibility, responsibility_for_slot},
    },
};

async fn resolve_operator_for_coinbase<P>(
    coinbase: Address,
    whitelist: crate::bindings::IPreconfWhitelist::IPreconfWhitelistInstance<P>,
    cache: Arc<RwLock<l1_events::OperatorCache>>,
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
    l2_http_url: Url,
    l1_http_url: Url,
    eject_after: Duration,
    taiko_wrapper_address: Address,
    whitelist_address: Address,
    handover_slots: u64,
    preconf_router_address: Address,
    anchor_address: Option<Address>,
    min_operators: u64,
    min_reorg_depth_for_eject: usize,
    reorg_ejection_enabled: bool,
}

pub struct MonitorParams {
    pub beacon_client: BeaconClient,
    pub l1_signer: alloy::signers::local::PrivateKeySigner,
    pub l1_http_url: Url,
    pub l2_http_url: Url,
    pub eject_after_seconds: u64,
    pub taiko_wrapper_address: Address,
    pub whitelist_address: Address,
    pub handover_slots: u64,
    pub preconf_router_address: Address,
    pub anchor_address: Option<Address>,
    pub min_operators: u64,
    pub min_reorg_depth_for_eject: usize,
    pub reorg_ejection_enabled: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum SyncStatusClass {
    NotSyncing,
    Syncing,
    Unknown,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum L2HeadProgress {
    UnknownBaseline,
    Unchanged,
    Advanced,
    Regressed,
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

fn classify_l2_head_progress(previous: Option<u64>, current: u64) -> L2HeadProgress {
    match previous {
        Some(prev) if current > prev => L2HeadProgress::Advanced,
        Some(prev) if current < prev => L2HeadProgress::Regressed,
        Some(_) => L2HeadProgress::Unchanged,
        None => L2HeadProgress::UnknownBaseline,
    }
}

fn should_mark_chain_reset(previous: Option<u64>, current: u64) -> bool {
    matches!(classify_l2_head_progress(previous, current), L2HeadProgress::Regressed)
}

/// Result of checking if a reorg is due to re-anchoring.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ReanchoringCheck {
    /// Anchor block changed - this is a re-anchoring event, skip ejection
    ReanchoringDetected { prev_anchor: u64, current_anchor: u64 },
    /// Anchor block unchanged - proceed with ejection check
    NoReanchoring,
    /// First time seeing anchor block - no previous to compare
    FirstAnchor,
}

/// Check if a reorg is due to re-anchoring by comparing anchor block numbers.
fn check_reanchoring(prev_anchor: Option<u64>, current_anchor: u64) -> ReanchoringCheck {
    match prev_anchor {
        Some(prev) if prev != current_anchor => {
            ReanchoringCheck::ReanchoringDetected { prev_anchor: prev, current_anchor }
        }
        Some(_) => ReanchoringCheck::NoReanchoring,
        None => ReanchoringCheck::FirstAnchor,
    }
}

/// Check if ejection should be skipped due to a recent chain reset.
/// Returns true if a chain reset was detected within the grace period (3x eject_after).
fn should_skip_due_to_chain_reset(chain_reset_at: Option<Instant>, eject_after: Duration) -> bool {
    chain_reset_at
        .map(|reset_time| is_within_chain_reset_grace_period(reset_time.elapsed(), eject_after))
        .unwrap_or(false)
}

/// Check if elapsed time since chain reset is within the grace period.
/// Grace period is 3x the eject_after duration.
fn is_within_chain_reset_grace_period(elapsed: Duration, eject_after: Duration) -> bool {
    let grace_period = eject_after * 3;
    elapsed < grace_period
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

    pub fn new(params: MonitorParams) -> Self {
        let eject_after = Duration::from_secs(params.eject_after_seconds);

        Self {
            beacon_client: params.beacon_client,
            l1_signer: params.l1_signer,
            l2_http_url: params.l2_http_url,
            l1_http_url: params.l1_http_url,
            eject_after,
            taiko_wrapper_address: params.taiko_wrapper_address,
            whitelist_address: params.whitelist_address,
            handover_slots: params.handover_slots,
            preconf_router_address: params.preconf_router_address,
            anchor_address: params.anchor_address,
            min_operators: params.min_operators,
            min_reorg_depth_for_eject: params.min_reorg_depth_for_eject,
            reorg_ejection_enabled: params.reorg_ejection_enabled,
        }
    }

    // run starts a loop to watch for new blocks and run a callback on eject time reached.
    // it will update per epoch and handle reconnections, as well as check if preconfs are enabled
    // before starting the ejector. It will however monitor the block stream regardless.
    pub async fn run(&self) -> Result<()> {
        info!("Running block watcher at {}", self.l2_http_url);

        let last_seen = Arc::new(Mutex::new(Instant::now()));
        let last_block_seen = Arc::new(Mutex::new(Instant::now()));
        let chain_reset_at = Arc::new(Mutex::new(None::<Instant>));
        let last_l2_poll_outcome = Arc::new(Mutex::new(l2_poller::PollOutcome::UncertainBackend));
        metrics::set_last_seen_drift_seconds(0);
        metrics::set_last_block_age_seconds(0);
        // Align watchdog tick with beacon slots to avoid spamming identical responsibility logs.
        let tick = Duration::from_secs(self.beacon_client.seconds_per_slot);
        let max = self.eject_after;
        let last_seen_for_watch = last_seen.clone();
        let last_block_for_watch = last_block_seen.clone();
        let chain_reset_for_watch = chain_reset_at.clone();
        let last_l2_poll_outcome_for_watch = last_l2_poll_outcome.clone();

        let l1_http_url = self.l1_http_url.clone();
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
        let initial_l2_head_number = match l2_http_provider.get_block_number().await {
            Ok(block_number) => Some(block_number),
            Err(err) => {
                warn!("Failed to fetch initial L2 head for watchdog sanity check: {err:?}");
                None
            }
        };
        let last_l2_head_number = Arc::new(Mutex::new(initial_l2_head_number));
        let last_l2_head_for_watch = last_l2_head_number.clone();
        // Clone for use in main loop (reorg sync status checks and anchor queries)
        let l2_http_provider_for_reorg = l2_http_provider.clone();
        // Anchor contract for detecting re-anchoring (only if reorg ejection is enabled and address is configured)
        let anchor_contract = if self.reorg_ejection_enabled {
            self.anchor_address
                .map(|addr| crate::bindings::Anchor::new(addr, l2_http_provider_for_reorg.clone()))
        } else {
            None
        };
        // Track last known anchor block number to detect re-anchoring
        let last_anchor_block = Arc::new(Mutex::new(None::<u64>));
        let preconf_whitelist =
            crate::bindings::IPreconfWhitelist::new(self.whitelist_address, http_provider.clone());
        let operator_cache = Arc::new(RwLock::new(l1_events::OperatorCache::default()));
        match l1_events::refresh_cache_from_chain(&preconf_whitelist, &operator_cache, None).await {
            Ok(()) => {}
            Err(e) => {
                warn!("Failed to initialize eject metrics: {e:?}");
                warn!("Whitelist scanner will retry cache refresh with tracker state on startup");
            }
        }
        let preconf_router =
            crate::bindings::PreconfRouter::new(self.preconf_router_address, http_provider.clone());
        let _operator_added_listener = tokio::spawn(l1_events::run_operator_event_scanner(
            l1_http_url.clone(),
            whitelist_address,
            operator_cache.clone(),
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

                    let mut skip_due_to_l2 = matches!(
                        *last_l2_poll_outcome_for_watch.lock().await,
                        l2_poller::PollOutcome::UncertainBackend | l2_poller::PollOutcome::Resynced
                    );
                    if skip_due_to_l2 {
                        warn!("Latest L2 poll result was not actionable; skipping eject this tick");
                    }

                    if !skip_due_to_l2 {
                        skip_due_to_l2 =
                            Self::should_skip_due_to_sync_status(&l2_http_provider, "L2").await;
                    }

                    if !skip_due_to_l2 {
                        match l2_http_provider.get_block_number().await {
                            Ok(current_l2_head) => {
                                let mut guard = last_l2_head_for_watch.lock().await;
                                let progress = classify_l2_head_progress(*guard, current_l2_head);
                                *guard = Some(current_l2_head);

                                match progress {
                                    L2HeadProgress::Advanced => {
                                        warn!(
                                            current_l2_head,
                                            "L2 head advanced while poller reported no progress; skipping eject this tick"
                                        );
                                        skip_due_to_l2 = true;
                                    }
                                    L2HeadProgress::Regressed => {
                                        warn!(
                                            current_l2_head,
                                            "L2 head regressed during watchdog check; skipping eject this tick"
                                        );
                                        skip_due_to_l2 = true;
                                    }
                                    L2HeadProgress::UnknownBaseline | L2HeadProgress::Unchanged => {
                                    }
                                }
                            }
                            Err(err) => {
                                warn!(
                                    "Failed to fetch L2 head for watchdog sanity check: {err:?}; skipping eject this tick"
                                );
                                skip_due_to_l2 = true;
                            }
                        }
                    }

                    if skip_due_to_l2 {
                        *last_seen_for_watch.lock().await = Instant::now();
                        *last_block_for_watch.lock().await = Instant::now();
                        metrics::set_last_seen_drift_seconds(0);
                        metrics::set_last_block_age_seconds(0);
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

                    // Skip ejection if a chain reset was detected recently (within 3x timeout).
                    // Chain resets indicate abnormal network state where ejection is inappropriate.
                    {
                        let mut guard = chain_reset_for_watch.lock().await;
                        if should_skip_due_to_chain_reset(*guard, max) {
                            info!(
                                "Skipping ejection due to recent chain reset ({:?} ago, grace period {:?})",
                                guard.map(|t| t.elapsed()),
                                max * 3
                            );
                            // Reset timer to avoid noisy "Max time reached" logs every tick
                            *last_seen_for_watch.lock().await = Instant::now();
                            metrics::set_last_seen_drift_seconds(0);
                            continue;
                        } else if guard.is_some() {
                            // Grace period expired, clear the flag
                            *guard = None;
                        }
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

        let mut reorg_tracker = ChainReorgTracker::new(MAX_REORG_HISTORY);
        let mut block_poller = l2_poller::L2BlockPoller::new(
            ProviderBuilder::new().connect_http(self.l2_http_url.clone()),
        );
        let mut poll_tick = interval(l2_poller::L2_BLOCK_POLL_INTERVAL);

        loop {
            poll_tick.tick().await;

            let poll_result = block_poller.poll_latest().await;
            {
                let mut guard = last_l2_poll_outcome.lock().await;
                *guard = poll_result.outcome;
            }

            match poll_result.outcome {
                l2_poller::PollOutcome::UncertainBackend => {
                    metrics::inc_l2_poll_uncertain();
                    warn!("L2 HTTP poll returned an uncertain backend result");
                    continue;
                }
                l2_poller::PollOutcome::Resynced => {
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
                    info!("L2 poller re-synced validated history to recent canonical window");
                    continue;
                }
                l2_poller::PollOutcome::NoProgress => continue,
                l2_poller::PollOutcome::StableProgress => {}
            }

            for tracked_block in poll_result.validated_blocks {
                let block_number = tracked_block.number;
                info!(
                    "Observed validated L2 block over HTTP: number={:?} hash={:?}, coinbase={:?}",
                    tracked_block.number, tracked_block.hash, tracked_block.coinbase
                );

                let outcome = reorg_tracker.apply(tracked_block.clone());

                if outcome.duplicate {
                    debug!(
                        block_number,
                        block_hash = ?tracked_block.hash,
                        "Duplicate block observation received; skipping"
                    );
                    continue;
                }

                let prev_block_number = {
                    let mut guard = last_l2_head_number.lock().await;
                    let previous = *guard;
                    *guard = Some(block_number);
                    previous
                };

                if outcome.parent_not_found {
                    if should_mark_chain_reset(prev_block_number, block_number) {
                        warn!(
                            block_number,
                            prev_block = ?prev_block_number,
                            parent_hash = ?tracked_block.parent_hash,
                            "Validated canonical chain regressed and did not connect to local reorg history; delaying ejection."
                        );
                        *chain_reset_at.lock().await = Some(Instant::now());
                    } else {
                        warn!(
                            block_number,
                            prev_block = ?prev_block_number,
                            parent_hash = ?tracked_block.parent_hash,
                            "Validated canonical chain did not connect to local reorg history, but no rollback was observed."
                        );
                    }
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
                            "Reorg detected but revert height missing; revert height metric set to u64::MAX sentinel"
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

                    if let Some(ref anchor) = anchor_contract {
                        match anchor.getBlockState().call().await {
                            Ok(block_state) => {
                                let current_anchor: u64 =
                                    block_state.anchorBlockNumber.try_into().unwrap_or(0);
                                let mut guard = last_anchor_block.lock().await;
                                let prev_anchor = *guard;
                                match check_reanchoring(prev_anchor, current_anchor) {
                                    ReanchoringCheck::ReanchoringDetected {
                                        prev_anchor,
                                        current_anchor,
                                    } => {
                                        info!(
                                            block_number,
                                            depth = reorg_depth,
                                            prev_anchor,
                                            current_anchor,
                                            "Anchor block changed (re-anchoring detected); skipping reorg-based eject"
                                        );
                                        *guard = Some(current_anchor);
                                        metrics::inc_reorg_skipped();
                                        continue;
                                    }
                                    ReanchoringCheck::FirstAnchor => {
                                        info!(
                                            block_number,
                                            depth = reorg_depth,
                                            current_anchor,
                                            "First anchor observation during reorg; skipping eject to establish baseline"
                                        );
                                        *guard = Some(current_anchor);
                                        metrics::inc_reorg_skipped();
                                        continue;
                                    }
                                    ReanchoringCheck::NoReanchoring => {
                                        *guard = Some(current_anchor);
                                    }
                                }
                            }
                            Err(e) => {
                                warn!(
                                    block_number,
                                    depth = reorg_depth,
                                    "Failed to query anchor block state: {e:?}; falling back to sync status check"
                                );
                                if Self::should_skip_due_to_sync_status(
                                    &l2_http_provider_for_reorg,
                                    "L2 (reorg)",
                                )
                                .await
                                {
                                    info!(
                                        block_number,
                                        depth = reorg_depth,
                                        "L2 is syncing (likely re-anchoring); skipping reorg-based eject"
                                    );
                                    metrics::inc_reorg_skipped();
                                    continue;
                                }
                            }
                        }
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
                                    let mut cache = operator_cache.write().await;
                                    cache.remove_proposer(operator_to_eject);
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
                } else if let Some(ref anchor) = anchor_contract {
                    match anchor.getBlockState().call().await {
                        Ok(block_state) => {
                            let current_anchor: u64 =
                                block_state.anchorBlockNumber.try_into().unwrap_or(0);
                            let mut guard = last_anchor_block.lock().await;
                            *guard = Some(current_anchor);
                        }
                        Err(e) => {
                            debug!(block_number, "Failed to query anchor block state: {e:?}");
                        }
                    }
                }
            }
        }
    }

    fn responsibility_now(&self) -> Responsibility {
        let slot = self.beacon_client.current_slot();
        responsibility_for_slot(slot, self.beacon_client.slots_per_epoch, self.handover_slots)
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
    use super::{
        ReanchoringCheck, SyncStatusClass, check_reanchoring, classify_sync_status,
        is_within_chain_reset_grace_period, should_skip_due_to_chain_reset,
        should_skip_for_sync_class,
    };
    use alloy::{
        primitives::{Address, B256},
        providers::ProviderBuilder,
    };
    use serde_json::json;
    use std::time::{Duration, Instant};
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
        let response = ResponseTemplate::new(200).set_body_raw("not-json", "application/json");
        let skip = run_sync_status_check_with_response(response).await;
        assert!(skip);
    }

    #[test]
    fn check_reanchoring_detects_anchor_change() {
        // When anchor changes from 100 to 200, it's a re-anchoring event
        let result = check_reanchoring(Some(100), 200);
        assert_eq!(
            result,
            ReanchoringCheck::ReanchoringDetected { prev_anchor: 100, current_anchor: 200 }
        );
    }

    #[test]
    fn check_reanchoring_no_change() {
        // When anchor stays the same, no re-anchoring
        let result = check_reanchoring(Some(100), 100);
        assert_eq!(result, ReanchoringCheck::NoReanchoring);
    }

    #[test]
    fn check_reanchoring_first_anchor() {
        // When there's no previous anchor, it's the first time we're seeing it
        let result = check_reanchoring(None, 100);
        assert_eq!(result, ReanchoringCheck::FirstAnchor);
    }

    #[test]
    fn check_reanchoring_detects_backward_anchor_change() {
        // Re-anchoring can also go backwards (e.g., reorg to earlier L1 block)
        let result = check_reanchoring(Some(200), 100);
        assert_eq!(
            result,
            ReanchoringCheck::ReanchoringDetected { prev_anchor: 200, current_anchor: 100 }
        );
    }

    #[test]
    fn check_reanchoring_zero_anchor() {
        // Zero anchor should still work
        let result = check_reanchoring(Some(100), 0);
        assert_eq!(
            result,
            ReanchoringCheck::ReanchoringDetected { prev_anchor: 100, current_anchor: 0 }
        );
    }

    #[test]
    fn check_reanchoring_from_zero() {
        // Going from zero to non-zero
        let result = check_reanchoring(Some(0), 100);
        assert_eq!(
            result,
            ReanchoringCheck::ReanchoringDetected { prev_anchor: 0, current_anchor: 100 }
        );
    }

    #[test]
    fn check_reanchoring_zero_unchanged() {
        // Zero anchor staying at zero
        let result = check_reanchoring(Some(0), 0);
        assert_eq!(result, ReanchoringCheck::NoReanchoring);
    }

    #[test]
    fn chain_reset_no_reset_should_not_skip() {
        // When there's no chain reset, should not skip ejection
        let result = should_skip_due_to_chain_reset(None, Duration::from_secs(48));
        assert!(!result);
    }

    #[test]
    fn chain_reset_recent_should_skip() {
        // When chain reset happened recently (within 3x timeout), should skip ejection
        let reset_time = Instant::now();
        let eject_after = Duration::from_secs(48);
        let result = should_skip_due_to_chain_reset(Some(reset_time), eject_after);
        assert!(result);
    }

    #[test]
    fn chain_reset_grace_period_boundary_within() {
        // Test that elapsed time just under grace period still skips
        let eject_after = Duration::from_secs(48);
        let grace_period = eject_after * 3; // 144 seconds

        // 1ms before grace period expires - should still skip
        let elapsed = grace_period - Duration::from_millis(1);
        assert!(is_within_chain_reset_grace_period(elapsed, eject_after));
    }

    #[test]
    fn chain_reset_grace_period_boundary_expired() {
        // Test that elapsed time at or beyond grace period does not skip
        let eject_after = Duration::from_secs(48);
        let grace_period = eject_after * 3; // 144 seconds

        // Exactly at grace period - should NOT skip (elapsed >= grace_period)
        assert!(!is_within_chain_reset_grace_period(grace_period, eject_after));

        // 1ms after grace period - should NOT skip
        let elapsed = grace_period + Duration::from_millis(1);
        assert!(!is_within_chain_reset_grace_period(elapsed, eject_after));
    }

    #[test]
    fn chain_reset_grace_period_is_3x_timeout() {
        // Verify the grace period calculation: should be 3x the eject_after duration
        let eject_after = Duration::from_secs(96);

        // Just under 3x should skip
        let just_under_3x = Duration::from_secs(287);
        assert!(is_within_chain_reset_grace_period(just_under_3x, eject_after));

        // Exactly 3x should NOT skip
        let exactly_3x = Duration::from_secs(288);
        assert!(!is_within_chain_reset_grace_period(exactly_3x, eject_after));

        // Over 3x should NOT skip
        let over_3x = Duration::from_secs(289);
        assert!(!is_within_chain_reset_grace_period(over_3x, eject_after));
    }

    #[test]
    fn chain_reset_zero_elapsed_should_skip() {
        // Immediately after chain reset (0 elapsed) should skip
        let eject_after = Duration::from_secs(48);
        assert!(is_within_chain_reset_grace_period(Duration::ZERO, eject_after));
    }

    #[test]
    fn whitelist_cache_updates_are_idempotent_and_replay_safe() {
        let mut cache = super::l1_events::OperatorCache::default();
        let mut tracker = super::l1_events::ProcessedLogTracker::default();
        let proposer = Address::with_last_byte(0x11);
        let sequencer = Address::with_last_byte(0x22);

        let added = super::l1_events::WhitelistCacheUpdate::OperatorAdded {
            key: super::l1_events::ProcessedLogKey {
                block_number: 10,
                transaction_hash: B256::with_last_byte(0xAA),
                log_index: 1,
            },
            proposer,
            sequencer,
        };

        assert_eq!(
            super::l1_events::apply_cache_update(&mut cache, &mut tracker, added.clone()),
            super::l1_events::CacheUpdateOutcome::Applied
        );
        assert_eq!(
            super::l1_events::apply_cache_update(&mut cache, &mut tracker, added),
            super::l1_events::CacheUpdateOutcome::DuplicateIgnored
        );
        assert_eq!(cache.proposer_for(proposer), Some(proposer));
        assert_eq!(cache.proposer_for(sequencer), Some(proposer));

        let removed = super::l1_events::WhitelistCacheUpdate::OperatorRemoved {
            key: super::l1_events::ProcessedLogKey {
                block_number: 11,
                transaction_hash: B256::with_last_byte(0xBB),
                log_index: 0,
            },
            proposer,
            sequencer,
        };

        assert_eq!(
            super::l1_events::apply_cache_update(&mut cache, &mut tracker, removed),
            super::l1_events::CacheUpdateOutcome::Applied
        );
        assert_eq!(cache.proposer_for(proposer), None);
        assert_eq!(cache.proposer_for(sequencer), None);

        assert_eq!(
            super::l1_events::apply_cache_update(
                &mut cache,
                &mut tracker,
                super::l1_events::WhitelistCacheUpdate::ReorgDetected { common_ancestor: 9 },
            ),
            super::l1_events::CacheUpdateOutcome::RefreshFromChain
        );
    }

    #[test]
    fn l2_poller_classifies_progress_and_uncertainty() {
        let proposer = Address::with_last_byte(0x44);
        let parent = super::l2_poller::ObservedHead {
            block: crate::monitor_reorg::TrackedBlock {
                number: 100,
                hash: B256::with_last_byte(0x10),
                parent_hash: B256::with_last_byte(0x09),
                coinbase: proposer,
            },
        };

        assert_eq!(
            super::l2_poller::classify_head_update(
                Some(&parent),
                Some(super::l2_poller::ObservedHead {
                    block: crate::monitor_reorg::TrackedBlock {
                        number: 100,
                        hash: B256::with_last_byte(0x10),
                        parent_hash: B256::with_last_byte(0x09),
                        coinbase: proposer,
                    },
                }),
            ),
            super::l2_poller::PollOutcome::NoProgress
        );

        assert_eq!(
            super::l2_poller::classify_head_update(
                Some(&parent),
                Some(super::l2_poller::ObservedHead {
                    block: crate::monitor_reorg::TrackedBlock {
                        number: 100,
                        hash: B256::with_last_byte(0x10),
                        parent_hash: B256::with_last_byte(0x09),
                        coinbase: proposer,
                    },
                }),
            ),
            super::l2_poller::PollOutcome::NoProgress
        );

        assert_eq!(
            super::l2_poller::classify_head_update(Some(&parent), None),
            super::l2_poller::PollOutcome::UncertainBackend
        );
    }

    #[test]
    fn l2_head_advance_skips_watchdog_eject() {
        assert_eq!(
            super::classify_l2_head_progress(Some(100), 101),
            super::L2HeadProgress::Advanced
        );
    }

    #[test]
    fn parent_disconnect_marks_chain_reset_only_on_regression() {
        assert!(super::should_mark_chain_reset(Some(100), 99));
        assert!(!super::should_mark_chain_reset(Some(100), 100));
        assert!(!super::should_mark_chain_reset(Some(100), 101));
        assert!(!super::should_mark_chain_reset(None, 99));
    }
}
