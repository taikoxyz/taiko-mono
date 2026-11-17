//! Builder pattern for constructing [`EventScanner`] instances.
//!
//! This module provides [`EventScannerBuilder`] which allows configuring an event scanner
//! in different modes (historic, live, latest, or sync) with various options before connecting
//! to a provider.

use alloy::{
    eips::{BlockId, BlockNumberOrTag},
    network::Network,
};

use crate::{
    BlockRangeScannerBuilder, DEFAULT_BLOCK_CONFIRMATIONS, EventScanner, RingBufferCapacity,
    ScannerError,
};

use robust_provider::IntoRobustProvider;

/// Default number of maximum concurrent fetches for each scanner mode.
pub const DEFAULT_MAX_CONCURRENT_FETCHES: usize = 24;

/// Marker indicating that a scanner mode has not been selected yet.
#[derive(Default, Debug)]
pub struct Unspecified;

/// Mode marker for historical range scanning.
///
/// For more details on this scanner mode, see [`EventScannerBuilder::historic`].
#[derive(Debug)]
pub struct Historic {
    pub(crate) from_block: BlockId,
    pub(crate) to_block: BlockId,
    pub(crate) max_concurrent_fetches: usize,
}

/// Mode marker for live streaming.
///
/// For more details on this scanner mode, see [`EventScannerBuilder::live`].
#[derive(Debug)]
pub struct Live {
    pub(crate) block_confirmations: u64,
    pub(crate) max_concurrent_fetches: usize,
}

/// Mode marker for latest-events collection.
///
/// For more details on this scanner mode, see [`EventScannerBuilder::latest`].
#[derive(Debug)]
pub struct LatestEvents {
    pub(crate) count: usize,
    pub(crate) from_block: BlockId,
    pub(crate) to_block: BlockId,
    pub(crate) block_confirmations: u64,
    pub(crate) max_concurrent_fetches: usize,
}

/// Marker indicating that a sync mode must be selected.
#[derive(Default, Debug)]
pub struct Synchronize;

/// Mode marker for scanning by syncing from the specified count of latest events and then switching
/// to live mode.
///
/// For more details on this scanner mode, see
/// [`EventScannerBuilder::sync().from_latest(count)`](crate::EventScannerBuilder::from_latest).
#[derive(Debug)]
pub struct SyncFromLatestEvents {
    pub(crate) count: usize,
    pub(crate) block_confirmations: u64,
    pub(crate) max_concurrent_fetches: usize,
}

/// Mode marker for scanning by syncing from the specified block and then switching to live mode.
///
/// For more details on this scanner mode, see
/// [`EventScannerBuilder::sync().from_block(block_id)`][sync from block].
///
/// [sync from block]: crate::EventScannerBuilder#method.from_block-2
#[derive(Debug)]
pub struct SyncFromBlock {
    pub(crate) from_block: BlockId,
    pub(crate) block_confirmations: u64,
    pub(crate) max_concurrent_fetches: usize,
}

impl Default for Historic {
    fn default() -> Self {
        Self {
            from_block: BlockNumberOrTag::Earliest.into(),
            to_block: BlockNumberOrTag::Latest.into(),
            max_concurrent_fetches: DEFAULT_MAX_CONCURRENT_FETCHES,
        }
    }
}

impl Default for Live {
    fn default() -> Self {
        Self {
            block_confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
            max_concurrent_fetches: DEFAULT_MAX_CONCURRENT_FETCHES,
        }
    }
}

/// Builder for constructing an [`EventScanner`] in a particular mode.
#[derive(Default, Debug)]
pub struct EventScannerBuilder<Mode> {
    pub(crate) config: Mode,
    pub(crate) block_range_scanner: BlockRangeScannerBuilder,
}

impl EventScannerBuilder<Unspecified> {
    /// Streams events from a historical block range.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
    /// # use event_scanner::{EventFilter, EventScannerBuilder, Message};
    /// # use tokio_stream::StreamExt;
    /// # use robust_provider::RobustProviderBuilder;
    /// #
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// # let contract_address = alloy::primitives::address!("0xd8dA6BF26964af9d7eed9e03e53415d37aa96045");
    /// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// # let provider = RobustProviderBuilder::new(provider).build().await?;
    /// // Stream all events from genesis to latest block
    /// let mut scanner = EventScannerBuilder::historic().connect(provider).await?;
    ///
    /// let filter = EventFilter::new().contract_address(contract_address);
    /// let subscription = scanner.subscribe(filter);
    /// let proof = scanner.start().await?;
    /// let mut stream = subscription.stream(&proof);
    ///
    /// while let Some(Ok(Message::Data(logs))) = stream.next().await {
    ///     println!("Received {} logs", logs.len());
    /// }
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// Specifying a custom block range:
    ///
    /// ```no_run
    /// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
    /// # use event_scanner::EventScannerBuilder;
    /// # use robust_provider::RobustProviderBuilder;
    /// #
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// # let provider = RobustProviderBuilder::new(provider).build().await?;
    /// // Stream events between blocks [1_000_000, 2_000_000]
    /// let mut scanner = EventScannerBuilder::historic()
    ///     .from_block(1_000_000)
    ///     .to_block(2_000_000)
    ///     .connect(provider)
    ///     .await?;
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// # How it works
    ///
    /// The scanner streams events in chronological order (oldest to newest) within the specified
    /// block range. Events are delivered in batches as they are fetched from the provider, with
    /// batch sizes controlled by the [`max_block_range`][max_block_range] configuration.
    ///
    /// # Key behaviors
    ///
    /// * **Continuous streaming**: Events are delivered in multiple messages as they are fetched
    /// * **Chronological order**: Events are always delivered oldest to newest
    /// * **Concurrent log fetching**: Logs are fetched concurrently to reduce the execution time.
    ///   The maximum number of concurrent RPC calls is controlled by
    ///   [`max_concurrent_fetches`][max_concurrent_fetches]
    /// * **Default range**: By default, scans from `Earliest` to `Latest` block
    /// * **Batch control**: Use [`max_block_range`][max_block_range] to control how many blocks are
    ///   queried per RPC call
    /// * **Reorg handling**:
    ///   * Blocks up to the chain's `finalized` height are streamed without reorg checks.
    ///   * For the non-finalized portion of the range, the scanner takes a snapshot of the
    ///     requested end block, streams the non-finalized portion once, and then verifies that the
    ///     end block is still the same. If a reorg is detected, it emits
    ///     [`Notification::ReorgDetected`][reorg] and re-streams the non-finalized portion of the
    ///     range from the reported common ancestor.
    ///
    ///   Consumers should be prepared to observe benign duplicate events around reorg boundaries
    ///   (e.g. by applying idempotency/deduplication).
    /// * **Completion**: The scanner completes when the entire range has been processed.
    ///
    /// [max_block_range]: crate::EventScannerBuilder::max_block_range
    /// [max_concurrent_fetches]: crate::EventScannerBuilder::max_concurrent_fetches
    /// [reorg]: crate::types::Notification::ReorgDetected
    #[must_use]
    pub fn historic() -> EventScannerBuilder<Historic> {
        EventScannerBuilder::default()
    }

    /// Streams new events as blocks are produced on-chain.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
    /// # use event_scanner::{EventFilter, EventScannerBuilder, Message};
    /// # use tokio_stream::StreamExt;
    /// # use robust_provider::RobustProviderBuilder;
    /// #
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// # let contract_address = alloy::primitives::address!("0xd8dA6BF26964af9d7eed9e03e53415d37aa96045");
    /// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// # let provider = RobustProviderBuilder::new(provider).build().await?;
    /// // Stream new events as they arrive
    /// let mut scanner = EventScannerBuilder::live()
    ///     .block_confirmations(20)
    ///     .connect(provider)
    ///     .await?;
    ///
    /// let filter = EventFilter::new().contract_address(contract_address);
    /// let subscription = scanner.subscribe(filter);
    /// let proof = scanner.start().await?;
    /// let mut stream = subscription.stream(&proof);
    ///
    /// while let Some(msg) = stream.next().await {
    ///     match msg {
    ///         Ok(Message::Data(logs)) => {
    ///             println!("Received {} new events", logs.len());
    ///         }
    ///         Ok(Message::Notification(notification)) => {
    ///             println!("Notification received: {:?}", notification);
    ///         }
    ///         Err(e) => {
    ///             eprintln!("Error: {}", e);
    ///         }
    ///     }
    /// }
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// # How it works
    ///
    /// The scanner subscribes to new blocks via WebSocket and streams events from confirmed
    /// blocks. The `block_confirmations` setting determines how many blocks to wait before
    /// considering a block confirmed, providing protection against chain reorganizations.
    ///
    /// # Key behaviors
    ///
    /// * **Real-time streaming**: Events are delivered as new blocks are confirmed
    /// * **Reorg protection**: Waits for configured confirmations before emitting events
    /// * **Continuous operation**: Runs indefinitely until the scanner is dropped or encounters an
    ///   error
    /// * **Default confirmations**: By default, waits for 12 block confirmations
    ///
    /// # Reorg behavior
    ///
    /// When a reorg is detected:
    /// 1. Emits [`Notification::ReorgDetected`][reorg] to all listeners
    /// 2. Adjusts the next confirmed range using `block_confirmations`
    /// 3. Re-emits events from the corrected confirmed block range
    /// 4. Continues streaming from the new chain state
    ///
    /// **Important**: If a reorg occurs, the scanner will only restream blocks from the new
    /// canonical chain that have block numbers greater than or equal to the block number that was
    /// the "latest block" at the time when the live stream was first started. Blocks with lower
    /// block numbers will not be restreamed, even if they are part of the new canonical chain.
    ///
    /// [reorg]: crate::types::Notification::ReorgDetected
    #[must_use]
    pub fn live() -> EventScannerBuilder<Live> {
        EventScannerBuilder::default()
    }

    /// Creates a builder for sync mode scanners that combine historical catch-up with live
    /// streaming.
    ///
    /// This method returns a builder that must be further narrowed down:
    /// ```rust,no_run
    /// # use event_scanner::EventScannerBuilder;
    /// // Sync from block mode
    /// EventScannerBuilder::sync().from_block(1_000_000);
    /// // Sync from latest events mode
    /// EventScannerBuilder::sync().from_latest(10);
    /// ```
    ///
    /// See [`from_block`](crate::EventScannerBuilder#method.from_block-2) and
    /// [`from_latest`](crate::EventScannerBuilder#method.from_latest) for details on each mode.
    #[must_use]
    pub fn sync() -> EventScannerBuilder<Synchronize> {
        EventScannerBuilder::default()
    }

    /// Streams the latest `count` matching events per registered listener.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
    /// # use event_scanner::{EventFilter, EventScannerBuilder, Message};
    /// # use tokio_stream::StreamExt;
    /// # use robust_provider::RobustProviderBuilder;
    /// #
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// # let contract_address = alloy::primitives::address!("0xd8dA6BF26964af9d7eed9e03e53415d37aa96045");
    /// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// # let provider = RobustProviderBuilder::new(provider).build().await?;
    /// // Collect the latest 10 events across Earliest..=Latest
    /// let mut scanner = EventScannerBuilder::latest(10).connect(provider).await?;
    ///
    /// let filter = EventFilter::new().contract_address(contract_address);
    /// let subscription = scanner.subscribe(filter);
    /// let proof = scanner.start().await?;
    /// let mut stream = subscription.stream(&proof);
    ///
    /// // Expect a single message with up to 10 logs, then the stream ends
    /// while let Some(Ok(Message::Data(logs))) = stream.next().await {
    ///     println!("Latest logs: {}", logs.len());
    /// }
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// Restricting to a specific block range:
    ///
    /// ```no_run
    /// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
    /// # use event_scanner::EventScannerBuilder;
    /// # use robust_provider::RobustProviderBuilder;
    /// #
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// # let provider = RobustProviderBuilder::new(provider).build().await?;
    /// // Collect the latest 5 events between blocks [1_000_000, 1_100_000]
    /// let mut scanner = EventScannerBuilder::latest(5)
    ///     .from_block(1_000_000)
    ///     .to_block(1_100_000)
    ///     .connect(provider)
    ///     .await?;
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// # How it works
    ///
    /// The scanner performs a reverse-ordered scan (newest to oldest) within the specified block
    /// range, collecting up to `count` events per registered listener. Once the target count is
    /// reached or the range is exhausted, it delivers the events in chronological order (oldest to
    /// newest) and completes.
    ///
    /// When using a custom block range, the scanner automatically normalizes the range boundaries.
    /// This means you can specify `from_block` and `to_block` in any order - the scanner will
    /// always scan from the higher block number down to the lower one, regardless of which
    /// parameter holds which value.
    ///
    /// # Key behaviors
    ///
    /// * **Single delivery**: Each registered stream receives at most `count` logs in a single
    ///   message, chronologically ordered
    /// * **One-shot operation**: The scanner completes after delivering messages; it does not
    ///   continue streaming
    /// * **Concurrent log fetching**: Logs are fetched concurrently to reduce the execution time.
    ///   The maximum number of concurrent RPC calls is controlled by
    ///   [`max_concurrent_fetches`][max_concurrent_fetches]
    /// * **Flexible count**: If fewer than `count` events exist in the range, returns all available
    ///   events
    /// * **Default range**: By default, scans from `Earliest` to `Latest` block
    /// * **Reorg handling**: Periodically checks the tip to detect reorgs during the scan
    ///
    /// # Notifications
    ///
    /// The scanner can emit the following notifications:
    ///
    /// * [`Notification::NoPastLogsFound`][no_logs]: Emitted when no matching logs are found in the
    ///   scanned range.
    /// * [`Notification::ReorgDetected`][reorg]: Emitted when a reorg is detected during the scan.
    ///
    /// # Arguments
    ///
    /// * `count` - Maximum number of recent events to collect per listener (must be greater than 0)
    ///
    /// # Reorg behavior
    ///
    /// The scanner can detect reorgs during the scan by periodically checking that the range tip
    /// has not changed. This is done only when the specified range tip is not a finalized
    /// block.
    ///
    /// On reorg detection:
    /// 1. Emits [`Notification::ReorgDetected`][reorg] to all listeners
    /// 2. Resets to the updated tip
    /// 3. Reloads logs from the block range affected by the reorg
    /// 4. Continues until `count` events are collected
    ///
    /// Final delivery to log listeners preserves chronological order regardless of reorgs.
    ///
    /// # Notes
    ///
    /// For continuous streaming after collecting latest events, use
    /// [`EventScannerBuilder::sync().from_latest(count)`][sync_from_latest] instead
    ///
    /// [subscribe]: EventScanner::subscribe
    /// [start]: EventScanner::start
    /// [sync_from_latest]: EventScannerBuilder::from_latest
    /// [reorg]: crate::Notification::ReorgDetected
    /// [no_logs]: crate::Notification::NoPastLogsFound
    /// [max_concurrent_fetches]: crate::EventScannerBuilder#method.max_concurrent_fetches-1
    #[must_use]
    pub fn latest(count: usize) -> EventScannerBuilder<LatestEvents> {
        EventScannerBuilder::<LatestEvents>::new(count)
    }
}

impl EventScannerBuilder<LatestEvents> {
    #[must_use]
    pub fn new(count: usize) -> Self {
        Self {
            config: LatestEvents {
                count,
                from_block: BlockNumberOrTag::Latest.into(),
                to_block: BlockNumberOrTag::Earliest.into(),
                block_confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
                max_concurrent_fetches: DEFAULT_MAX_CONCURRENT_FETCHES,
            },
            block_range_scanner: BlockRangeScannerBuilder::default(),
        }
    }
}

impl EventScannerBuilder<SyncFromLatestEvents> {
    #[must_use]
    pub fn new(count: usize) -> Self {
        Self {
            config: SyncFromLatestEvents {
                count,
                block_confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
                max_concurrent_fetches: DEFAULT_MAX_CONCURRENT_FETCHES,
            },
            block_range_scanner: BlockRangeScannerBuilder::default(),
        }
    }
}

impl EventScannerBuilder<SyncFromBlock> {
    #[must_use]
    pub fn new(from_block: impl Into<BlockId>) -> Self {
        Self {
            config: SyncFromBlock {
                from_block: from_block.into(),
                block_confirmations: DEFAULT_BLOCK_CONFIRMATIONS,
                max_concurrent_fetches: DEFAULT_MAX_CONCURRENT_FETCHES,
            },
            block_range_scanner: BlockRangeScannerBuilder::default(),
        }
    }
}

impl<Mode> EventScannerBuilder<Mode> {
    /// Sets the maximum block range per event batch.
    ///
    /// Controls how the scanner splits a large block range into smaller batches for processing.
    /// Each batch corresponds to a single RPC call to fetch logs. This prevents timeouts and
    /// respects rate limits imposed by node providers.
    ///
    /// # Arguments
    ///
    /// * `max_block_range` - Maximum number of blocks to process per batch (must be greater than 0)
    ///
    /// # Example
    ///
    /// If scanning events from blocks 1000–1099 (100 blocks total) with `max_block_range(30)`:
    /// * Batch 1: blocks 1000–1029 (30 blocks)
    /// * Batch 2: blocks 1030–1059 (30 blocks)
    /// * Batch 3: blocks 1060–1089 (30 blocks)
    /// * Batch 4: blocks 1090–1099 (10 blocks)
    #[must_use]
    pub fn max_block_range(mut self, max_block_range: u64) -> Self {
        self.block_range_scanner.max_block_range = max_block_range;
        self
    }

    /// Sets how many of past blocks to keep in memory for reorg detection.
    ///
    /// IMPORTANT: If zero, reorg detection is disabled.
    ///
    /// # Arguments
    ///
    /// * `past_blocks_storage_capacity` - Maximum number of blocks to keep in memory.
    #[must_use]
    pub fn past_blocks_storage_capacity(
        mut self,
        past_blocks_storage_capacity: RingBufferCapacity,
    ) -> Self {
        self.block_range_scanner.past_blocks_storage_capacity = past_blocks_storage_capacity;
        self
    }

    /// Sets the stream buffer capacity.
    ///
    /// Controls the maximum number of messages that can be buffered in the stream
    /// before backpressure is applied.
    ///
    /// # Arguments
    ///
    /// * `buffer_capacity` - Maximum number of messages to buffer (must be greater than 0)
    #[must_use]
    pub fn buffer_capacity(mut self, buffer_capacity: usize) -> Self {
        self.block_range_scanner.buffer_capacity = buffer_capacity;
        self
    }

    /// Builds the scanner by connecting to an existing provider.
    ///
    /// This is a shared method used internally by scanner-specific `connect()` methods.
    pub(crate) async fn build<N: Network>(
        self,
        provider: impl IntoRobustProvider<N>,
    ) -> Result<EventScanner<Mode, N>, ScannerError> {
        let block_range_scanner = self.block_range_scanner.connect::<N>(provider).await?;
        Ok(EventScanner::new(self.config, block_range_scanner))
    }
}
