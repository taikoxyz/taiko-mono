//! Collects the most recent matching events.
//!
//! Performs a reverse scan to collect a specified number of the most recent matching events.
//! See [`EventScannerBuilder::latest`] for usage details.

use alloy::{
    consensus::BlockHeader,
    eips::BlockId,
    network::{BlockResponse, Network},
};

use crate::{
    ScannerError,
    event_scanner::{
        EventScanner, StartProof,
        block_range_handler::{BlockRangeHandler, LatestEventsHandler},
        builder::{EventScannerBuilder, LatestEvents},
    },
};

use robust_provider::IntoRobustProvider;

impl EventScannerBuilder<LatestEvents> {
    /// Sets the number of confirmations required before a block is considered stable enough to
    /// include when collecting the latest events.
    ///
    /// Higher values reduce the likelihood of emitting logs from blocks that are later reorged,
    /// at the cost of potentially excluding very recent events.
    #[must_use]
    pub fn block_confirmations(mut self, confirmations: u64) -> Self {
        self.config.block_confirmations = confirmations;
        self
    }

    /// Sets the starting block for the historic scan.
    ///
    /// # Note
    ///
    /// Although passing `BlockNumberOrTag::Pending` will compile, the subsequent call to
    /// `connect` will fail at runtime. See issue <https://github.com/OpenZeppelin/Event-Scanner/issues/244>
    #[must_use]
    pub fn from_block(mut self, block_id: impl Into<BlockId>) -> Self {
        self.config.from_block = block_id.into();
        self
    }

    /// Sets the starting block for the historic scan.
    ///
    /// # Note
    ///
    /// Although passing `BlockNumberOrTag::Pending` will compile, the subsequent call to
    /// `connect` will fail at runtime. See issue <https://github.com/OpenZeppelin/Event-Scanner/issues/244>
    #[must_use]
    pub fn to_block(mut self, block_id: impl Into<BlockId>) -> Self {
        self.config.to_block = block_id.into();
        self
    }

    /// Sets the maximum number of block-range fetches to process concurrently when
    /// collecting the latest events.
    ///
    /// Higher values can increase throughput by issuing multiple RPC requests
    /// concurrently, at the expense of more load on the provider.
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
    ) -> Result<EventScanner<LatestEvents, N>, ScannerError> {
        if self.config.count == 0 {
            return Err(ScannerError::InvalidEventCount);
        }
        if self.config.max_concurrent_fetches == 0 {
            return Err(ScannerError::InvalidMaxConcurrentFetches);
        }

        let scanner = self.build(provider).await?;

        let provider = scanner.block_range_scanner.provider();
        let latest_block = provider.get_block_number().await?;

        let from_num = match scanner.config.from_block {
            BlockId::Number(from_block) => {
                if from_block.is_pending() {
                    return Err(ScannerError::BlockExceedsLatest(
                        "from_block",
                        latest_block + 1,
                        latest_block,
                    ));
                }
                // can safely unwrap to 0 because any other tag < latest block
                from_block.as_number().unwrap_or(0)
            }
            BlockId::Hash(from_hash) => {
                provider.get_block_by_hash(from_hash.into()).await?.header().number()
            }
        };

        if from_num > latest_block {
            Err(ScannerError::BlockExceedsLatest("from_block", from_num, latest_block))?;
        }

        let to_num = match scanner.config.to_block {
            BlockId::Number(to_block) => {
                if to_block.is_pending() {
                    return Err(ScannerError::BlockExceedsLatest(
                        "to_block",
                        latest_block + 1,
                        latest_block,
                    ));
                }
                // can safely unwrap to 0 because any other tag < latest block
                to_block.as_number().unwrap_or(0)
            }
            BlockId::Hash(to_hash) => {
                provider.get_block_by_hash(to_hash.into()).await?.header().number()
            }
        };

        if to_num > latest_block {
            Err(ScannerError::BlockExceedsLatest("to_block", to_num, latest_block))?;
        }

        Ok(scanner)
    }
}

impl<N: Network> EventScanner<LatestEvents, N> {
    /// Starts the scanner in [`LatestEvents`] mode.
    ///
    /// See [`EventScanner`] for general startup notes.
    ///
    /// # Errors
    ///
    /// * [`ScannerError::Timeout`] - if an RPC call required for startup times out.
    /// * [`ScannerError::RpcError`] - if an RPC call required for startup fails.
    /// * [`ScannerError::BlockNotFound`] - if `from_block` or `to_block` cannot be resolved.
    pub async fn start(self) -> Result<StartProof, ScannerError> {
        info!(
            from_block = ?self.config.from_block,
            to_block = ?self.config.to_block,
            count = ?self.config.count,
            listener_count = self.listeners.len(),
            "Starting EventScanner in LatestEvents mode"
        );

        let stream = self
            .block_range_scanner
            .stream_rewind(self.config.from_block, self.config.to_block)
            .await?;

        let broadcast_channel_capacity = self.buffer_capacity();

        let handler = LatestEventsHandler::new(
            self.block_range_scanner.provider().clone(),
            self.listeners,
            self.config.max_concurrent_fetches,
            self.config.count,
            broadcast_channel_capacity,
        );

        tokio::spawn(async move {
            handler.handle(stream).await;
        });

        Ok(StartProof::new())
    }
}
