use std::time::{Duration, Instant};

use alloy::{
    providers::{Provider, ProviderBuilder, WsConnect},
    transports::http::reqwest::Url,
};
use eyre::Result;
use futures_util::StreamExt;
use tokio::time::{interval, sleep};
use tracing::{debug, info, warn};

use crate::{
    metrics,
    monitor_reorg::{ChainReorgTracker, TrackedBlock},
};

pub struct ReorgMonitor {
    l2_ws_url: Url,
    reorg_history_depth: usize,
}

impl ReorgMonitor {
    pub fn new(l2_ws_url: Url, reorg_history_depth: usize) -> Self {
        Self { l2_ws_url, reorg_history_depth: reorg_history_depth.max(1) }
    }

    pub async fn run(&self) -> Result<()> {
        info!(
            "Running reorg monitor at {} (history depth {})",
            self.l2_ws_url, self.reorg_history_depth
        );

        let mut reorg_tracker = ChainReorgTracker::new(self.reorg_history_depth);
        let mut last_block_seen = Instant::now();
        let mut backoff = Duration::from_secs(1);
        let max_backoff = Duration::from_secs(30);

        metrics::set_last_block_age_seconds(0);

        loop {
            info!("Connecting to L2 block stream...");
            match ProviderBuilder::new().connect_ws(WsConnect::new(self.l2_ws_url.clone())).await {
                Ok(provider) => {
                    info!("Connected to L2 block stream at {}", self.l2_ws_url);
                    metrics::inc_ws_reconnections();
                    backoff = Duration::from_secs(1);

                    match provider.get_block_number().await {
                        Ok(block_number) => {
                            metrics::set_last_block_number(block_number);
                            info!("Current L2 head via WS provider: {block_number}");
                        }
                        Err(error) => {
                            warn!("Failed to query block number via WS provider: {error}");
                        }
                    }

                    match provider.subscribe_blocks().await {
                        Ok(subscription) => {
                            let mut stream = subscription.into_stream();
                            let mut age_ticker = interval(Duration::from_secs(1));

                            info!("Subscribed to L2 block headers");
                            loop {
                                tokio::select! {
                                    _ = age_ticker.tick() => {
                                        metrics::set_last_block_age_seconds(last_block_seen.elapsed().as_secs());
                                    }
                                    maybe_header = stream.next() => match maybe_header {
                                        Some(header) => {
                                            let tracked_block = TrackedBlock {
                                                number: header.number,
                                                hash: header.hash,
                                                parent_hash: header.parent_hash,
                                                coinbase: header.beneficiary,
                                            };

                                            let outcome = reorg_tracker.apply(tracked_block.clone());

                                            if outcome.duplicate {
                                                metrics::inc_duplicate_block_notifications();
                                                debug!(
                                                    block_number = tracked_block.number,
                                                    block_hash = ?tracked_block.hash,
                                                    "Duplicate block header notification ignored",
                                                );
                                                continue;
                                            }

                                            metrics::inc_l2_blocks();
                                            metrics::set_last_block_number(tracked_block.number);
                                            last_block_seen = Instant::now();
                                            metrics::set_last_block_age_seconds(0);

                                            if outcome.parent_not_found {
                                                metrics::inc_parent_not_found();
                                                warn!(
                                                    block_number = tracked_block.number,
                                                    parent_hash = ?tracked_block.parent_hash,
                                                    "Parent not found in local tracker history; tracker window reset",
                                                );
                                                continue;
                                            }

                                            if !outcome.reorged.is_empty() {
                                                let reorg_depth = outcome.reorged.len();
                                                warn!(
                                                    block_number = tracked_block.number,
                                                    new_head = ?tracked_block.hash,
                                                    depth = reorg_depth,
                                                    reverted_to = ?outcome.reverted_to,
                                                    "Detected L2 reorg",
                                                );

                                                metrics::note_reorg(reorg_depth, outcome.reverted_to);

                                                for removed in outcome.reorged {
                                                    debug!(
                                                        removed_block_number = removed.number,
                                                        removed_block_hash = ?removed.hash,
                                                        removed_block_coinbase = ?removed.coinbase,
                                                        "Removed block due to reorg",
                                                    );
                                                }
                                            }
                                        }
                                        None => {
                                            warn!("L2 block stream ended unexpectedly");
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        Err(error) => {
                            warn!("Failed to subscribe to L2 block headers: {error}");
                        }
                    }
                }
                Err(error) => {
                    warn!("Failed to connect to L2 websocket {}: {error}", self.l2_ws_url,);
                }
            }

            warn!("Reconnecting to L2 websocket after {:?}", backoff);
            sleep(backoff).await;
            if backoff < max_backoff {
                backoff = std::cmp::min(max_backoff, backoff * 2);
            }
        }
    }
}
