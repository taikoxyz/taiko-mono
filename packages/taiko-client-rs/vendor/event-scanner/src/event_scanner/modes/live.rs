//! Streams events from newly produced blocks in real-time.
//!
//! Continuously monitors the blockchain and yields events as new blocks are confirmed.
//! See [`EventScannerBuilder::live`] for usage details.

use alloy::network::Network;

use crate::{
    ScannerError,
    event_scanner::{
        EventScanner, StartProof,
        block_range_handler::{BlockRangeHandler, StreamHandler},
        builder::{EventScannerBuilder, Live},
    },
};

use robust_provider::IntoRobustProvider;

impl EventScannerBuilder<Live> {
    /// Sets the number of confirmations required before a block is considered stable enough to
    /// scan in live mode.
    ///
    /// Higher values reduce the likelihood of emitting logs from blocks that are later reorged,
    /// at the cost of increased event delivery latency.
    #[must_use]
    pub fn block_confirmations(mut self, confirmations: u64) -> Self {
        self.config.block_confirmations = confirmations;
        self
    }

    /// Sets the maximum number of block-range fetches to process concurrently for
    /// live streaming.
    ///
    /// This knob primarily exists to handle an edge case: when the scanner
    /// falls significantly behind the head of the chain (for example due to a
    /// temporary outage or slow consumer), it can catch up faster by
    /// processing multiple block ranges in parallel. Increasing the value
    /// improves throughput at the expense of higher load on the provider.
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
    /// * The max block range is zero
    pub async fn connect<N: Network>(
        self,
        provider: impl IntoRobustProvider<N>,
    ) -> Result<EventScanner<Live, N>, ScannerError> {
        if self.config.max_concurrent_fetches == 0 {
            return Err(ScannerError::InvalidMaxConcurrentFetches);
        }

        self.build(provider).await
    }
}

impl<N: Network> EventScanner<Live, N> {
    /// Starts the scanner in [`Live`] mode.
    ///
    /// See [`EventScanner`] for general startup notes.
    ///
    /// # Errors
    ///
    /// * [`ScannerError::Timeout`] - if an RPC call required for startup times out.
    /// * [`ScannerError::RpcError`] - if an RPC call required for startup fails.
    pub async fn start(self) -> Result<StartProof, ScannerError> {
        info!(
            block_confirmations = self.config.block_confirmations,
            listener_count = self.listeners.len(),
            "Starting EventScanner in Live mode"
        );

        let stream = self.block_range_scanner.stream_live(self.config.block_confirmations).await?;
        let broadcast_channel_capacity = self.buffer_capacity();

        let handler = StreamHandler::new(
            self.block_range_scanner.provider().clone(),
            self.listeners,
            self.config.max_concurrent_fetches,
            broadcast_channel_capacity,
        );

        tokio::spawn(async move {
            handler.handle(stream).await;
        });

        Ok(StartProof::new())
    }
}
