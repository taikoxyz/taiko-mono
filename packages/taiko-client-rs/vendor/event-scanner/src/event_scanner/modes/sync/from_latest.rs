//! Collects recent events, then transitions to live streaming.
//!
//! Collects a specified number of the most recent events, then automatically continues
//! with live streaming. See [`EventScannerBuilder::sync().from_latest()`][from_latest]
//! for usage details.
//!
//! [from_latest]: crate::EventScannerBuilder::from_latest

use alloy::{eips::BlockNumberOrTag, network::Network};

use crate::{
    ScannerError,
    event_scanner::{
        EventScanner, StartProof,
        block_range_handler::{BlockRangeHandler, LatestEventsHandler, StreamHandler},
        builder::{EventScannerBuilder, SyncFromLatestEvents},
    },
    types::TryStream,
};

use robust_provider::IntoRobustProvider;

impl EventScannerBuilder<SyncFromLatestEvents> {
    /// Sets the number of confirmations required before a block is considered stable enough to
    /// scan in the live phase.
    ///
    /// This affects the post-sync live streaming phase; higher values reduce reorg risk at the
    /// cost of increased event delivery latency.
    #[must_use]
    pub fn block_confirmations(mut self, confirmations: u64) -> Self {
        self.config.block_confirmations = confirmations;
        self
    }

    /// Sets the maximum number of block-range fetches to process concurrently when
    /// fetching the latest events before switching to live streaming.
    ///
    /// Increasing this value can improve catch-up throughput by issuing multiple
    /// RPC requests concurrently, at the cost of additional load on the provider.
    ///
    /// **Note**: This limit applies **per listener**. With N listeners and a limit of M,
    /// up to N × M concurrent RPC requests may be in-flight simultaneously.
    ///
    /// Must be greater than 0.
    ///
    /// Defaults to [`DEFAULT_MAX_CONCURRENT_FETCHES`][default].
    ///
    /// [default]: crate::event_scanner::builder::DEFAULT_MAX_CONCURRENT_FETCHES
    #[must_use]
    pub fn max_concurrent_fetches(mut self, max_concurrent_fetches: usize) -> Self {
        self.config.max_concurrent_fetches = max_concurrent_fetches;
        self
    }

    /// Connects to an existing provider.
    ///
    /// # Errors
    ///
    /// Returns an error if:
    /// * The provider connection fails
    /// * The event count is zero
    /// * The max block range is zero
    pub async fn connect<N: Network>(
        self,
        provider: impl IntoRobustProvider<N>,
    ) -> Result<EventScanner<SyncFromLatestEvents, N>, ScannerError> {
        if self.config.count == 0 {
            return Err(ScannerError::InvalidEventCount);
        }
        if self.config.max_concurrent_fetches == 0 {
            return Err(ScannerError::InvalidMaxConcurrentFetches);
        }
        self.build(provider).await
    }
}

impl<N: Network> EventScanner<SyncFromLatestEvents, N> {
    /// Starts the scanner in [`SyncFromLatestEvents`] mode.
    ///
    /// See [`EventScanner`] for general startup notes.
    ///
    /// # Errors
    ///
    /// * [`ScannerError::Timeout`] - if an RPC call required for startup times out.
    /// * [`ScannerError::RpcError`] - if an RPC call required for startup fails.
    #[allow(clippy::missing_panics_doc)]
    pub async fn start(self) -> Result<StartProof, ScannerError> {
        info!(
            event_count = self.config.count,
            block_confirmations = self.config.block_confirmations,
            listener_count = self.listeners.len(),
            "Starting EventScanner in SyncFromLatestEvents mode"
        );

        let count = self.config.count;
        let provider = self.block_range_scanner.provider().clone();
        let listeners = self.listeners.clone();
        let broadcast_channel_capacity = self.buffer_capacity();

        // Fetch the latest block number.
        // This is used to determine the starting point for the rewind stream and the live
        // stream. We do this before starting the streams to avoid a race condition
        // where the latest block changes while we're setting up the streams.
        let latest_block = provider.get_block_number().await?;

        // Setup rewind and live streams to run in parallel.
        let rewind_stream = self
            .block_range_scanner
            .stream_rewind(latest_block, BlockNumberOrTag::Earliest)
            .await?;

        let collection_handler = LatestEventsHandler::new(
            self.block_range_scanner.provider().clone(),
            listeners.clone(),
            self.config.max_concurrent_fetches,
            count,
            broadcast_channel_capacity,
        );
        let stream_handler = StreamHandler::new(
            self.block_range_scanner.provider().clone(),
            listeners.clone(),
            self.config.max_concurrent_fetches,
            broadcast_channel_capacity,
        );

        // Start streaming...
        tokio::spawn(async move {
            debug!(
                latest_block = latest_block,
                count = count,
                "Phase 1: Collecting latest events via rewind"
            );

            // Since both rewind and live log consumers are ultimately streaming to the same
            // channel, we must ensure that all latest events are streamed before
            // consuming the live stream, otherwise the log consumers may send events out
            // of order.
            collection_handler.handle(rewind_stream).await;

            debug!(
                start_block = latest_block + 1,
                "Phase 2: Catching up and transitioning to live mode"
            );

            // We actually rely on the sync mode for the live stream, as more blocks could have been
            // minted while the scanner was collecting the latest `count` events.
            // Note: Sync mode will notify the client when it switches to live streaming.
            let sync_stream = match self
                .block_range_scanner
                .stream_from(latest_block + 1, self.config.block_confirmations)
                .await
            {
                Ok(stream) => stream,
                Err(e) => {
                    error!("Failed to setup sync stream after collecting latest events");
                    // notify all active listeners about the error before dropping the stream
                    for listener in listeners {
                        _ = listener.sender.try_stream(e.clone()).await;
                    }
                    return;
                }
            };

            // Start the live (sync) stream.
            stream_handler.handle(sync_stream).await;

            debug!("SyncFromLatestEvents stream ended");
        });

        Ok(StartProof::new())
    }
}
