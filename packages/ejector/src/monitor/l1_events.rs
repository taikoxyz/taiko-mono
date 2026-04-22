use std::{
    collections::{HashMap, HashSet, VecDeque},
    sync::Arc,
    time::Duration,
};

use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256},
    providers::{Provider, ProviderBuilder},
    rpc::types::Log,
    sol_types::SolEvent,
    transports::http::reqwest::Url,
};
use event_scanner::{EventFilter, EventScannerBuilder, Notification, ScannerMessage};
use robust_provider::RobustProviderBuilder;
use tokio::{sync::RwLock, time::sleep};
use tokio_stream::StreamExt;
use tracing::{debug, info, warn};

use crate::{bindings::IPreconfWhitelist, metrics, utils::eject::initialize_eject_metrics};

const HTTP_EVENT_SCANNER_POLL_INTERVAL: Duration = Duration::from_secs(1);

const WHITELIST_EVENT_LOOKBACK_BLOCKS: u64 = 64;

fn advance_backoff(backoff: &mut Duration, max_backoff: Duration) {
    if *backoff < max_backoff {
        *backoff = std::cmp::min(max_backoff, *backoff * 2);
    }
}
const MAX_TRACKED_LOG_KEYS: usize = 2_048;

#[derive(Default)]
pub(crate) struct OperatorCache {
    proposers: HashSet<Address>,
    sequencer_to_proposer: HashMap<Address, Address>,
}

impl OperatorCache {
    pub(crate) fn upsert(&mut self, proposer: Address, sequencer: Address) {
        self.proposers.insert(proposer);
        if !sequencer.is_zero() {
            self.sequencer_to_proposer.insert(sequencer, proposer);
        }
    }

    pub(crate) fn remove_proposer(&mut self, proposer: Address) {
        self.proposers.remove(&proposer);
        self.sequencer_to_proposer.retain(|_, existing| *existing != proposer);
    }

    pub(crate) fn proposer_for(&self, addr: Address) -> Option<Address> {
        if self.proposers.contains(&addr) {
            Some(addr)
        } else {
            self.sequencer_to_proposer.get(&addr).copied()
        }
    }

    pub(crate) fn clear(&mut self) {
        self.proposers.clear();
        self.sequencer_to_proposer.clear();
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub(crate) struct ProcessedLogKey {
    pub(crate) block_number: u64,
    pub(crate) transaction_hash: B256,
    pub(crate) log_index: u64,
}

pub(crate) struct ProcessedLogTracker {
    seen: HashSet<ProcessedLogKey>,
    order: VecDeque<ProcessedLogKey>,
    max_entries: usize,
}

impl Default for ProcessedLogTracker {
    fn default() -> Self {
        Self { seen: HashSet::new(), order: VecDeque::new(), max_entries: MAX_TRACKED_LOG_KEYS }
    }
}

impl ProcessedLogTracker {
    fn insert_if_new(&mut self, key: ProcessedLogKey) -> bool {
        if !self.seen.insert(key.clone()) {
            return false;
        }

        self.order.push_back(key);
        while self.order.len() > self.max_entries {
            if let Some(expired) = self.order.pop_front() {
                self.seen.remove(&expired);
            }
        }

        true
    }

    fn clear(&mut self) {
        self.seen.clear();
        self.order.clear();
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) enum WhitelistCacheUpdate {
    OperatorAdded { key: ProcessedLogKey, proposer: Address, sequencer: Address },
    OperatorRemoved { key: ProcessedLogKey, proposer: Address, sequencer: Address },
    ReorgDetected { common_ancestor: u64 },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum CacheUpdateOutcome {
    Applied,
    DuplicateIgnored,
    RefreshFromChain,
}

pub(crate) fn apply_cache_update(
    cache: &mut OperatorCache,
    tracker: &mut ProcessedLogTracker,
    update: WhitelistCacheUpdate,
) -> CacheUpdateOutcome {
    match update {
        WhitelistCacheUpdate::OperatorAdded { key, proposer, sequencer } => {
            if !tracker.insert_if_new(key) {
                return CacheUpdateOutcome::DuplicateIgnored;
            }
            cache.upsert(proposer, sequencer);
            CacheUpdateOutcome::Applied
        }
        WhitelistCacheUpdate::OperatorRemoved { key, proposer, sequencer: _ } => {
            if !tracker.insert_if_new(key) {
                return CacheUpdateOutcome::DuplicateIgnored;
            }
            cache.remove_proposer(proposer);
            CacheUpdateOutcome::Applied
        }
        WhitelistCacheUpdate::ReorgDetected { common_ancestor: _ } => {
            CacheUpdateOutcome::RefreshFromChain
        }
    }
}

fn reseed_cache_from_entries<I>(
    cache: &mut OperatorCache,
    tracker: &mut ProcessedLogTracker,
    entries: I,
) where
    I: IntoIterator<Item = (Address, Address)>,
{
    cache.clear();
    tracker.clear();
    for (proposer, sequencer) in entries {
        cache.upsert(proposer, sequencer);
    }
}

pub(crate) async fn refresh_cache_from_chain<P>(
    whitelist: &IPreconfWhitelist::IPreconfWhitelistInstance<P>,
    operator_cache: &Arc<RwLock<OperatorCache>>,
    tracker: Option<&mut ProcessedLogTracker>,
) -> eyre::Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let initialized = initialize_eject_metrics(whitelist).await?;
    let mut cache = operator_cache.write().await;
    if let Some(tracker) = tracker {
        reseed_cache_from_entries(&mut cache, tracker, initialized);
    } else {
        cache.clear();
        for (proposer, sequencer) in initialized {
            cache.upsert(proposer, sequencer);
        }
    }
    Ok(())
}

pub(crate) async fn run_operator_event_scanner(
    l1_http_url: Url,
    whitelist_address: Address,
    operator_cache: Arc<RwLock<OperatorCache>>,
) {
    let mut tracker = ProcessedLogTracker::default();
    let mut backoff = Duration::from_secs(1);
    let max_backoff = Duration::from_secs(30);

    loop {
        info!("Starting HTTP whitelist event scanner at {}", l1_http_url);

        let provider = ProviderBuilder::new().connect_http(l1_http_url.clone());
        let whitelist = IPreconfWhitelist::new(whitelist_address, provider.clone());

        if let Err(err) =
            refresh_cache_from_chain(&whitelist, &operator_cache, Some(&mut tracker)).await
        {
            warn!("Failed to refresh whitelist cache before scanner start: {err:?}");
        }

        let latest = match provider.get_block_number().await {
            Ok(block_number) => block_number,
            Err(err) => {
                warn!("Failed to fetch L1 head for whitelist scanner: {err:?}");
                metrics::inc_l1_event_scanner_restarts();
                sleep(backoff).await;
                advance_backoff(&mut backoff, max_backoff);
                continue;
            }
        };

        let robust_provider = match RobustProviderBuilder::new(provider)
            .allow_http_subscriptions(true)
            .poll_interval(HTTP_EVENT_SCANNER_POLL_INTERVAL)
            .build()
            .await
        {
            Ok(provider) => provider,
            Err(err) => {
                warn!("Failed to build robust provider for whitelist scanner: {err:?}");
                metrics::inc_l1_event_scanner_restarts();
                sleep(backoff).await;
                advance_backoff(&mut backoff, max_backoff);
                continue;
            }
        };

        let start_block = latest.saturating_sub(WHITELIST_EVENT_LOOKBACK_BLOCKS);
        let mut scanner = match EventScannerBuilder::sync()
            .from_block(BlockNumberOrTag::Number(start_block))
            .connect(robust_provider)
            .await
        {
            Ok(scanner) => scanner,
            Err(err) => {
                warn!("Failed to initialize whitelist event scanner: {err:?}");
                metrics::inc_l1_event_scanner_restarts();
                sleep(backoff).await;
                advance_backoff(&mut backoff, max_backoff);
                continue;
            }
        };

        let filter = EventFilter::new().contract_address(whitelist_address).events([
            IPreconfWhitelist::OperatorAdded::SIGNATURE,
            IPreconfWhitelist::OperatorRemoved::SIGNATURE,
        ]);
        let subscription = scanner.subscribe(filter);

        let proof = match scanner.start().await {
            Ok(proof) => proof,
            Err(err) => {
                warn!("Whitelist event scanner failed to start: {err:?}");
                metrics::inc_l1_event_scanner_restarts();
                sleep(backoff).await;
                advance_backoff(&mut backoff, max_backoff);
                continue;
            }
        };

        backoff = Duration::from_secs(1);
        let mut stream = subscription.stream(&proof);

        while let Some(message) = stream.next().await {
            match message {
                Ok(ScannerMessage::Data(logs)) => {
                    for log in logs {
                        match decode_cache_update(log) {
                            Ok(Some(update)) => {
                                let proposer_for_metrics = match &update {
                                    WhitelistCacheUpdate::OperatorAdded { proposer, .. }
                                    | WhitelistCacheUpdate::OperatorRemoved { proposer, .. } => {
                                        Some(*proposer)
                                    }
                                    WhitelistCacheUpdate::ReorgDetected { .. } => None,
                                };

                                let outcome = {
                                    let mut cache = operator_cache.write().await;
                                    apply_cache_update(&mut cache, &mut tracker, update)
                                };

                                match outcome {
                                    CacheUpdateOutcome::Applied => {
                                        if let Some(proposer) = proposer_for_metrics {
                                            metrics::ensure_eject_metric_labels(&format!(
                                                "{proposer:#x}"
                                            ));
                                        }
                                    }
                                    CacheUpdateOutcome::DuplicateIgnored => {
                                        debug!("Ignoring duplicate whitelist log replay");
                                    }
                                    CacheUpdateOutcome::RefreshFromChain => {
                                        if let Err(err) = refresh_cache_from_chain(
                                            &whitelist,
                                            &operator_cache,
                                            Some(&mut tracker),
                                        )
                                        .await
                                        {
                                            warn!(
                                                "Failed to refresh whitelist cache after reorg: {err:?}"
                                            );
                                        }
                                    }
                                }
                            }
                            Ok(None) => {}
                            Err(err) => {
                                warn!("Failed to decode whitelist event log: {err:?}");
                                if let Err(refresh_err) = refresh_cache_from_chain(
                                    &whitelist,
                                    &operator_cache,
                                    Some(&mut tracker),
                                )
                                .await
                                {
                                    warn!(
                                        "Failed to refresh whitelist cache after decode error: {refresh_err:?}"
                                    );
                                }
                            }
                        }
                    }
                }
                Ok(ScannerMessage::Notification(Notification::SwitchingToLive)) => {
                    info!("Whitelist event scanner switched to live mode");
                }
                Ok(ScannerMessage::Notification(Notification::NoPastLogsFound)) => {
                    debug!("Whitelist event scanner found no past logs in lookback window");
                }
                Ok(ScannerMessage::Notification(Notification::ReorgDetected {
                    common_ancestor,
                })) => {
                    info!(common_ancestor, "Whitelist event scanner detected L1 reorg");
                    let outcome = {
                        let mut cache = operator_cache.write().await;
                        apply_cache_update(
                            &mut cache,
                            &mut tracker,
                            WhitelistCacheUpdate::ReorgDetected { common_ancestor },
                        )
                    };

                    if matches!(outcome, CacheUpdateOutcome::RefreshFromChain)
                        && let Err(err) = refresh_cache_from_chain(
                            &whitelist,
                            &operator_cache,
                            Some(&mut tracker),
                        )
                        .await
                    {
                        warn!("Failed to refresh whitelist cache after L1 reorg: {err:?}");
                    }
                }
                Err(err) => {
                    warn!("Whitelist event scanner stream error: {err:?}");
                    break;
                }
            }
        }

        metrics::inc_l1_event_scanner_restarts();
        warn!("Whitelist event scanner disconnected. Restarting after {:?}", backoff);
        sleep(backoff).await;
        advance_backoff(&mut backoff, max_backoff);
    }
}

fn decode_cache_update(log: Log) -> eyre::Result<Option<WhitelistCacheUpdate>> {
    let key = match processed_log_key(&log) {
        Some(key) => key,
        None => {
            warn!(
                block = ?log.block_number,
                tx_hash = ?log.transaction_hash,
                log_index = ?log.log_index,
                "Whitelist event log missing metadata; refreshing from chain instead of applying incrementally"
            );
            return Ok(Some(WhitelistCacheUpdate::ReorgDetected { common_ancestor: 0 }));
        }
    };

    if let Ok(decoded) = log.log_decode::<IPreconfWhitelist::OperatorAdded>() {
        return Ok(Some(WhitelistCacheUpdate::OperatorAdded {
            key,
            proposer: decoded.data().proposer,
            sequencer: decoded.data().sequencer,
        }));
    }

    if let Ok(decoded) = log.log_decode::<IPreconfWhitelist::OperatorRemoved>() {
        return Ok(Some(WhitelistCacheUpdate::OperatorRemoved {
            key,
            proposer: decoded.data().proposer,
            sequencer: decoded.data().sequencer,
        }));
    }

    Ok(None)
}

fn processed_log_key(log: &Log) -> Option<ProcessedLogKey> {
    Some(ProcessedLogKey {
        block_number: log.block_number?,
        transaction_hash: log.transaction_hash?,
        log_index: log.log_index?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(block_number: u64, tx_suffix: u8, log_index: u64) -> ProcessedLogKey {
        ProcessedLogKey {
            block_number,
            transaction_hash: B256::with_last_byte(tx_suffix),
            log_index,
        }
    }

    #[test]
    fn reseed_clears_tracker_before_replaying_window() {
        let proposer = Address::with_last_byte(0x11);
        let sequencer = Address::with_last_byte(0x22);
        let other = Address::with_last_byte(0x33);

        let mut cache = OperatorCache::default();
        let mut tracker =
            ProcessedLogTracker { seen: HashSet::new(), order: VecDeque::new(), max_entries: 2 };

        assert_eq!(
            apply_cache_update(
                &mut cache,
                &mut tracker,
                WhitelistCacheUpdate::OperatorAdded { key: key(10, 0xA1, 0), proposer, sequencer },
            ),
            CacheUpdateOutcome::Applied
        );
        assert_eq!(
            apply_cache_update(
                &mut cache,
                &mut tracker,
                WhitelistCacheUpdate::OperatorRemoved {
                    key: key(11, 0xB2, 0),
                    proposer,
                    sequencer,
                },
            ),
            CacheUpdateOutcome::Applied
        );
        assert_eq!(cache.proposer_for(proposer), None);

        assert_eq!(
            apply_cache_update(
                &mut cache,
                &mut tracker,
                WhitelistCacheUpdate::OperatorAdded {
                    key: key(12, 0xC3, 0),
                    proposer: other,
                    sequencer: Address::ZERO,
                },
            ),
            CacheUpdateOutcome::Applied
        );

        reseed_cache_from_entries(&mut cache, &mut tracker, []);

        assert_eq!(
            apply_cache_update(
                &mut cache,
                &mut tracker,
                WhitelistCacheUpdate::OperatorAdded { key: key(10, 0xA1, 0), proposer, sequencer },
            ),
            CacheUpdateOutcome::Applied
        );
        assert_eq!(
            apply_cache_update(
                &mut cache,
                &mut tracker,
                WhitelistCacheUpdate::OperatorRemoved {
                    key: key(11, 0xB2, 0),
                    proposer,
                    sequencer,
                },
            ),
            CacheUpdateOutcome::Applied
        );
        assert_eq!(cache.proposer_for(proposer), None);
    }
}
