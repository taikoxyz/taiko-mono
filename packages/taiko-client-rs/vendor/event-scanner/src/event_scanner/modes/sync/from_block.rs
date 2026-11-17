//! Syncs from a starting block, then transitions to live streaming.
//!
//! Streams events from a specified starting block to the present, then automatically
//! continues with live streaming. See [`EventScannerBuilder::sync().from_block()`][from_block]
//! for usage details.
//!
//! [from_block]: crate::EventScannerBuilder#method.from_block-2

use alloy::{eips::BlockId, network::Network};

use crate::{
    ScannerError,
    event_scanner::{
        EventScanner, StartProof,
        block_range_handler::{BlockRangeHandler, StreamHandler},
        builder::{EventScannerBuilder, SyncFromBlock},
    },
};
use robust_provider::IntoRobustProvider;

impl EventScannerBuilder<SyncFromBlock> {
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
    /// synchronizing from a specific block.
    ///
    /// Higher values can improve throughput by issuing multiple RPC requests
    /// concurrently, at the cost of additional load on the provider.
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
    ) -> Result<EventScanner<SyncFromBlock, N>, ScannerError> {
        if self.config.max_concurrent_fetches == 0 {
            return Err(ScannerError::InvalidMaxConcurrentFetches);
        }

        let scanner = self.build(provider).await?;

        let provider = scanner.block_range_scanner.provider();

        if let BlockId::Hash(from_hash) = scanner.config.from_block {
            provider.get_block_by_hash(from_hash.into()).await?;
        }

        Ok(scanner)
    }
}

impl<N: Network> EventScanner<SyncFromBlock, N> {
    /// Starts the scanner in [`SyncFromBlock`] mode.
    ///
    /// See [`EventScanner`] for general startup notes.
    ///
    /// # Errors
    ///
    /// * [`ScannerError::Timeout`] - if an RPC call required for startup times out.
    /// * [`ScannerError::RpcError`] - if an RPC call required for startup fails.
    /// * [`ScannerError::BlockNotFound`] - if `from_block` cannot be resolved.
    pub async fn start(self) -> Result<StartProof, ScannerError> {
        info!(
            from_block = ?self.config.from_block,
            block_confirmations = self.config.block_confirmations,
            listener_count = self.listeners.len(),
            "Starting EventScanner in SyncFromBlock mode"
        );

        let stream = self
            .block_range_scanner
            .stream_from(self.config.from_block, self.config.block_confirmations)
            .await?;

        let buffer_capacity = self.buffer_capacity();

        let handler = StreamHandler::new(
            self.block_range_scanner.provider().clone(),
            self.listeners,
            self.config.max_concurrent_fetches,
            buffer_capacity,
        );

        tokio::spawn(async move {
            handler.handle(stream).await;
        });

        Ok(StartProof::new())
    }
}
