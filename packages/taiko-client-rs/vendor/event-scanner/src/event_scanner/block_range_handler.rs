//! Block-range handler implementations used by the event scanner.
//!
//! This module defines the [`BlockRangeHandler`] abstraction and concrete handlers:
//!
//! * [`StreamHandler`]
//! * [`LatestEventsHandler`]

use std::ops::RangeInclusive;

use crate::{
    Message, Notification, ScannerError, ScannerMessage,
    block_range_scanner::BlockScannerResult,
    event_scanner::{filter::EventFilter, listener::EventListener},
    types::TryStream,
};
use alloy::{
    network::Network,
    rpc::types::{Filter, Log},
};
use futures::StreamExt;
use robust_provider::{Error as RobustProviderError, RobustProvider};
use tokio::{
    sync::{
        broadcast::{self, Sender, error::RecvError},
        mpsc,
    },
    task::JoinSet,
};
use tokio_stream::{Stream, wrappers::ReceiverStream};

/// Handles a stream of scanned block ranges.
pub trait BlockRangeHandler {
    /// Consumes a stream of scanned block-range results.
    ///
    /// Implementations typically forward data and notifications to registered listeners.
    fn handle<S: Stream<Item = BlockScannerResult> + Unpin + Send>(
        self,
        stream: S,
    ) -> impl std::future::Future<Output = ()> + Send;
}

/// Streams logs to listeners as soon as each scanned block range is processed.
///
/// This handler fetches logs per listener and forwards each non-empty result immediately. It is
/// used by scanner modes that operate as continuous streams (e.g. historic/live scanning), where
/// incremental delivery is preferred over collecting a fixed-size window.
///
/// # Concurrency
///
/// The `max_concurrent_fetches` limit applies **per listener**, not globally. With N listeners
/// and a limit of M, up to N × M concurrent RPC requests may be in-flight simultaneously.
#[derive(Debug)]
pub struct StreamHandler<N: Network> {
    provider: RobustProvider<N>,
    listeners: Vec<EventListener>,
    max_concurrent_fetches: usize,
    broadcast_channel_capacity: usize,
}

impl<N: Network> StreamHandler<N> {
    /// Creates a [`StreamHandler`].
    ///
    /// # Arguments
    ///
    /// * `provider` - The robust provider for making RPC calls
    /// * `listeners` - The list of event listeners to stream logs to
    /// * `max_concurrent_fetches` - Limits how many log-fetching RPC requests can be in-flight per
    ///   listener at once.
    /// * `broadcast_channel_capacity` - Capacity for the broadcast channel used to distribute block
    ///   ranges to consumers.
    #[must_use]
    pub fn new(
        provider: RobustProvider<N>,
        listeners: Vec<EventListener>,
        max_concurrent_fetches: usize,
        broadcast_channel_capacity: usize,
    ) -> Self {
        Self { provider, listeners, max_concurrent_fetches, broadcast_channel_capacity }
    }

    fn spawn(self, range_tx: &Sender<BlockScannerResult>) -> JoinSet<()> {
        let mut join_set = JoinSet::new();

        for listener in self.listeners {
            let max_concurrent_fetches = self.max_concurrent_fetches;
            let provider = self.provider.clone();
            let mut range_rx = range_tx.subscribe();

            join_set.spawn(async move {
                // We use a channel and convert the receiver to a stream because it already has
                // a convenience function `buffered` for concurrently
                // handling block ranges, while outputting results in the
                // same order as they were received.
                let (tx, rx) = mpsc::channel::<BlockScannerResult>(max_concurrent_fetches);

                // Process block ranges concurrently in a separate thread so that the current
                // thread can continue receiving and buffering subsequent
                // block ranges while the previous ones are being processed.
                tokio::spawn(async move {
                    let mut stream = ReceiverStream::new(rx)
                        .map(async |message| match message {
                            Ok(ScannerMessage::Data(range)) => {
                                get_logs(range, &listener.filter, &provider)
                                    .await
                                    .map(Message::from)
                                    .map_err(ScannerError::from)
                            }
                            Ok(ScannerMessage::Notification(notification)) => {
                                Ok(notification.into())
                            }
                            // No need to stop the stream on an error, because there will be no
                            // more values received from the
                            // range stream.
                            Err(e) => Err(e),
                        })
                        .buffered(max_concurrent_fetches);

                    // process all of the buffered results
                    while let Some(result) = stream.next().await {
                        if let Ok(ScannerMessage::Data(logs)) = result.as_ref() &&
                            logs.is_empty()
                        {
                            continue;
                        }

                        if listener.sender.try_stream(result).await.is_closed() {
                            return;
                        }
                    }
                });

                // Receive block ranges from the broadcast channel and send them to the range
                // processor for parallel processing.
                loop {
                    match range_rx.recv().await {
                        Ok(message) => {
                            tx.send(message)
                                .await
                                .expect("receiver dropped only if we exit this loop");
                        }
                        Err(RecvError::Closed) => {
                            trace!("Block range stream closed");
                            break;
                        }
                        Err(RecvError::Lagged(skipped)) => {
                            tx.send(Err(ScannerError::Lagged(skipped)))
                                .await
                                .expect("receiver dropped only if we exit this loop");
                        }
                    }
                }
            });
        }

        join_set
    }
}

impl<N: Network> BlockRangeHandler for StreamHandler<N> {
    async fn handle<S: Stream<Item = BlockScannerResult> + Unpin + Send>(self, stream: S) {
        debug!(
            listener_count = self.listeners.len(),
            max_concurrent_fetches = self.max_concurrent_fetches,
            broadcast_channel_capacity = self.broadcast_channel_capacity,
            max_concurrent_fetches = self.max_concurrent_fetches,
            "Starting block range handler that forwards logs as they are received"
        );

        let (range_tx, _) =
            broadcast::channel::<BlockScannerResult>(self.broadcast_channel_capacity);

        let consumers = self.spawn(&range_tx);

        broadcast_stream(stream, range_tx, consumers).await;
    }
}

/// Collects the latest `count` logs per listener before streaming them.
///
/// This handler performs a reverse scan (newest-to-oldest) while buffering logs locally. Once
/// `count` matching logs are collected (or the scan finishes), it emits the collected logs in
/// chronological order (oldest-to-newest) and stops.
///
/// During reorg recovery it prepends newly fetched logs so that the newest-first buffer remains
/// correctly ordered.
///
/// # Concurrency
///
/// The `max_concurrent_fetches` limit applies **per listener**, not globally. With N listeners
/// and a limit of M, up to N × M concurrent RPC requests may be in-flight simultaneously.
#[derive(Debug)]
pub struct LatestEventsHandler<N: Network> {
    provider: RobustProvider<N>,
    listeners: Vec<EventListener>,
    max_concurrent_fetches: usize,
    count: usize,
    broadcast_channel_capacity: usize,
}

impl<N: Network> LatestEventsHandler<N> {
    /// Creates a [`LatestEventsHandler`].
    ///
    /// # Arguments
    ///
    /// * `provider` - The robust provider to use for fetching logs
    /// * `listeners` - The list of event listeners to collect logs for
    /// * `max_concurrent_fetches` - Maximum number of concurrent log-fetching RPC requests per
    ///   listener
    /// * `count` - Maximum number of logs to collect per listener before streaming
    /// * `broadcast_channel_capacity` - Capacity of the broadcast channel for forwarding results
    #[must_use]
    pub fn new(
        provider: RobustProvider<N>,
        listeners: Vec<EventListener>,
        max_concurrent_fetches: usize,
        count: usize,
        broadcast_channel_capacity: usize,
    ) -> Self {
        Self { provider, listeners, max_concurrent_fetches, count, broadcast_channel_capacity }
    }

    #[allow(clippy::too_many_lines)]
    fn spawn(self, range_tx: &Sender<BlockScannerResult>) -> JoinSet<()> {
        let mut join_set = JoinSet::new();

        for listener in self.listeners {
            let max_concurrent_fetches = self.max_concurrent_fetches;
            let count = self.count;
            let provider = self.provider.clone();
            let mut range_rx = range_tx.subscribe();

            join_set.spawn(async move {
                // We use a channel and convert the receiver to a stream because it already has a
                // convenience function `buffered` for concurrently handling block ranges, while
                // outputting results in the same order as they were received.
                let (tx, rx) = mpsc::channel::<BlockScannerResult>(max_concurrent_fetches);

                // Process block ranges concurrently in a separate thread so that the current thread
                // can continue receiving and buffering subsequent block ranges
                // while the previous ones are being processed.
                tokio::spawn(async move {
                    let mut stream = ReceiverStream::new(rx)
                        .map(async |message| match message {
                            Ok(ScannerMessage::Data(range)) => {
                                get_logs(range, &listener.filter, &provider)
                                    .await
                                    .map(Message::from)
                                    .map_err(ScannerError::from)
                            }
                            Ok(ScannerMessage::Notification(notification)) => {
                                Ok(notification.into())
                            }
                            // No need to stop the stream on an error, because there will be no more
                            // values received from the range stream.
                            Err(e) => Err(e),
                        })
                        .buffered(max_concurrent_fetches);

                    let mut collected = Vec::with_capacity(count);

                    // Tracks common ancestor block during reorg recovery for proper log ordering
                    let mut reorg_ancestor: Option<u64> = None;

                    // process all of the buffered results
                    while let Some(result) = stream.next().await {
                        match result {
                            Ok(ScannerMessage::Data(logs)) => {
                                if logs.is_empty() {
                                    continue;
                                }

                                let last_log_block_num = logs
                                    .last()
                                    .expect("logs already confirmed not empty")
                                    .block_number
                                    .expect("pending blocks not supported");
                                // Check if in reorg recovery and past the reorg range
                                if reorg_ancestor.is_some_and(|a| last_log_block_num <= a) {
                                    trace!(
                                        ancestor = reorg_ancestor,
                                        "Reorg recovery complete, resuming normal log collection"
                                    );
                                    reorg_ancestor = None;
                                }

                                let should_prepend = reorg_ancestor.is_some();
                                if collect_logs(&mut collected, logs, count, should_prepend) {
                                    break;
                                }
                            }

                            Ok(ScannerMessage::Notification(Notification::ReorgDetected {
                                common_ancestor,
                            })) => {
                                trace!(
                                    common_ancestor = common_ancestor,
                                    "Reorg detected, rescanning new canonical blocks"
                                );
                                // Track reorg state for proper log ordering
                                reorg_ancestor = Some(common_ancestor);

                                collected =
                                    discard_logs_from_orphaned_blocks(collected, common_ancestor);

                                // Don't forward the notification to the user in this mode
                                // since logs haven't been sent yet
                            }
                            Ok(ScannerMessage::Notification(notification)) => {
                                if listener.sender.try_stream(notification).await.is_closed() {
                                    return;
                                }
                            }
                            Err(e) => {
                                if listener.sender.try_stream(e).await.is_closed() {
                                    return;
                                }
                            }
                        }
                    }

                    if collected.is_empty() {
                        trace!("No logs found");
                        _ = listener.sender.try_stream(Notification::NoPastLogsFound).await;
                        return;
                    }

                    trace!(count = collected.len(), "Logs found");
                    collected.reverse(); // restore chronological order

                    _ = listener.sender.try_stream(collected).await;
                });

                // Receive block ranges from the broadcast channel and send them to the range
                // processor for parallel processing.
                loop {
                    match range_rx.recv().await {
                        Ok(message) => {
                            if tx.send(message).await.is_err() {
                                // range processor has streamed the expected number of logs
                                break;
                            }
                        }
                        Err(RecvError::Closed) => {
                            trace!("Block range stream closed");
                            break;
                        }
                        Err(RecvError::Lagged(skipped)) => {
                            tx.send(Err(ScannerError::Lagged(skipped)))
                                .await
                                .expect("receiver dropped only if we exit this loop");
                        }
                    }
                }
            });
        }

        join_set
    }
}

impl<N: Network> BlockRangeHandler for LatestEventsHandler<N> {
    async fn handle<S: Stream<Item = BlockScannerResult> + Unpin + Send>(self, stream: S) {
        debug!(
            listener_count = self.listeners.len(),
            max_concurrent_fetches = self.max_concurrent_fetches,
            broadcast_channel_capacity = self.broadcast_channel_capacity,
            max_concurrent_fetches = self.max_concurrent_fetches,
            count = self.count,
            "Starting block range handler that collects logs before streaming them, as required by the latest events mode"
        );

        let (range_tx, _) =
            broadcast::channel::<BlockScannerResult>(self.broadcast_channel_capacity);

        let consumers = self.spawn(&range_tx);

        broadcast_stream(stream, range_tx, consumers).await;
    }
}

async fn broadcast_stream<S: Stream<Item = BlockScannerResult> + Unpin + Send>(
    mut stream: S,
    range_tx: Sender<Result<ScannerMessage<RangeInclusive<u64>>, ScannerError>>,
    consumers: JoinSet<()>,
) {
    while let Some(message) = stream.next().await {
        if range_tx.send(message).is_err() {
            debug!("All consumers dropped, stopping stream handler");
            break;
        }
    }

    debug!("Block range stream ended, waiting for consumers");

    // Close the channel sender to signal to the log consumers that streaming is done.
    drop(range_tx);

    // ensure all consumers finish before they're dropped - this is to ensure that this
    // consumer set finishes its log processing before the next consumer set can
    // be spawned in a subsequent `handle_stream` invocation.
    consumers.join_all().await;

    debug!("All event consumers finished");
}

/// Invalidates logs from orphaned blocks.
fn discard_logs_from_orphaned_blocks(collected: Vec<Log>, common_ancestor: u64) -> Vec<Log> {
    // Logs are ordered newest -> oldest, so skip logs with
    // block_number > common_ancestor at the front
    let before_count = collected.len();
    let collected = collected
        .into_iter()
        .skip_while(|log| {
            // Pending blocks aren't supported therefore this filter
            // works for now (may need to update once they are).
            // Tracked in <https://github.com/OpenZeppelin/Event-Scanner/issues/244>
            log.block_number.is_some_and(|n| n > common_ancestor)
        })
        .collect::<Vec<_>>();
    let removed_count = before_count - collected.len();
    if removed_count > 0 {
        trace!(
            removed_count = removed_count,
            remaining_count = collected.len(),
            "Invalidated logs from orphaned blocks"
        );
    }
    collected
}

/// Collects logs into the buffer, either prepending (reorg recovery) or appending (normal).
/// Returns `true` if collection is complete (reached count limit).
fn collect_logs<T>(collected: &mut Vec<T>, logs: Vec<T>, count: usize, prepend: bool) -> bool {
    if prepend {
        // Reorg rescan ranges are sent in ascending order (oldest → latest), opposite to normal
        // rewind which sends descending (latest → oldest). This means each successive reorg batch
        // contains newer blocks, so we always prepend at position 0 to maintain newest-first order.
        // Example: reorg rescan sends 86..=95 then 96..=100
        //   - First batch (86..=95): prepend → [95, 94, ..., 86]
        //   - Second batch (96..=100): prepend → [100, 99, ..., 96, 95, 94, ..., 86]
        let new_logs = logs.into_iter().rev().take(count);
        let keep = count.saturating_sub(new_logs.len());
        collected.truncate(keep);
        collected.splice(..0, new_logs);
    } else {
        // Normal: append up to remaining capacity
        let take = count.saturating_sub(collected.len());
        if take == 0 {
            return true;
        }
        collected.extend(logs.into_iter().rev().take(take));
    }

    collected.len() >= count
}

async fn get_logs<N: Network>(
    range: RangeInclusive<u64>,
    event_filter: &EventFilter,
    provider: &RobustProvider<N>,
) -> Result<Vec<Log>, RobustProviderError> {
    let log_filter = Filter::from(event_filter).from_block(*range.start()).to_block(*range.end());

    trace!(from_block = *range.start(), to_block = *range.end(), "Fetching logs for block range");

    match provider.get_logs(&log_filter).await {
        Ok(logs) => {
            if !logs.is_empty() {
                debug!(
                    from_block = *range.start(),
                    to_block = *range.end(),
                    log_count = logs.len(),
                    "Found logs in block range"
                );
            }
            Ok(logs)
        }
        Err(e) => {
            error!(
                from_block = *range.start(),
                to_block = *range.end(),
                "Failed to get logs for block range"
            );

            Err(e)
        }
    }
}
