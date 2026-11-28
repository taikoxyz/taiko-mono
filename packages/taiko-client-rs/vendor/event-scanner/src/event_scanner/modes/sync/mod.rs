//! Catches up on historical events, then transitions to live streaming.
//!
//! Two sync variants are available:
//! - [`from_block`]: Syncs from a specific block then transitions to live mode
//! - [`from_latest`]: Collects the latest N events then transitions to live mode

use alloy::eips::BlockId;

pub(crate) mod from_block;
pub(crate) mod from_latest;

use crate::event_scanner::builder::{
    EventScannerBuilder, SyncFromBlock, SyncFromLatestEvents, Synchronize,
};

impl EventScannerBuilder<Synchronize> {
    /// Scans the latest `count` matching events per registered listener, then automatically
    /// transitions to live streaming mode.
    ///
    /// This method combines two scanning phases into a single operation:
    ///
    /// 1. **Latest events phase**: Collects up to `count` most recent events by scanning backwards
    ///    from the current chain tip. Events are delivered in chronological order.
    /// 2. **Automatic transition**: Emits [`Notification::SwitchingToLive`][switch_to_live] to
    ///    signal the mode change
    /// 3. **Live streaming phase**: Continuously monitors and streams new events as they arrive
    ///    on-chain
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
    /// // Fetch the latest 10 events, then stream new events continuously
    /// let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// let robust_provider = RobustProviderBuilder::new(provider).build().await?;
    /// let mut scanner = EventScannerBuilder::sync()
    ///     .from_latest(10)
    ///     .connect(robust_provider)
    ///     .await?;
    ///
    /// let filter = EventFilter::new().contract_address(contract_address);
    /// let subscription = scanner.subscribe(filter);
    ///
    /// let proof = scanner.start().await?;
    /// let mut stream = subscription.stream(&proof);
    ///
    /// while let Some(msg) = stream.next().await {
    ///     match msg {
    ///         Ok(Message::Data(logs)) => {
    ///             println!("Received {} events", logs.len());
    ///         }
    ///         Ok(Message::Notification(notification)) => {
    ///             println!("Notification received: {:?}", notification);
    ///             // You'll see Notification::SwitchingToLive when transitioning
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
    /// The scanner captures the latest block number before starting to establish a clear boundary
    /// between phases. The "latest events" phase scans from the current latest block to the genesis
    /// block, while the live phase starts from the block after the latest block. This design
    /// prevents duplicate events and handles race conditions where new blocks arrive during
    /// setup.
    ///
    /// # Key behaviors
    ///
    /// * **No duplicates**: Events are not delivered twice across the phase transition
    /// * **Flexible count**: If fewer than `count` events exist, returns all available events
    /// * **Concurrent log fetching**: Logs are fetched concurrently to reduce the sync phase
    ///   execution time. The maximum number of concurrent RPC calls is controlled by
    ///   [`max_concurrent_fetches`][max_concurrent_fetches]
    /// * **Reorg handling**: Both phases handle reorgs appropriately:
    ///   - Latest events phase: resets and rescans on reorg detection
    ///   - Live phase: resets stream to the first post-reorg block that satisfies the configured
    ///     block confirmations
    /// * **Continuous operation**: Live phase continues indefinitely until the scanner is dropped
    ///
    /// # Notifications
    ///
    /// During the **latest events phase**, the scanner can emit the following notification
    /// before transitioning to live mode:
    ///
    /// * **[`Notification::NoPastLogsFound`][no_logs]**: Emitted when no matching logs are found in
    ///   the scanned range
    ///
    /// After the latest events phase completes, [`Notification::SwitchingToLive`][switch_to_live]
    /// is emitted before transitioning to the live streaming phase.
    ///
    /// # Arguments
    ///
    /// * `count` - Maximum number of recent events to collect per listener before switching to live
    ///   streaming (must be greater than 0)
    ///
    /// # Important notes
    ///
    /// * The live phase continues indefinitely until the scanner is dropped or encounters an error
    ///
    /// # Detailed reorg behavior
    ///
    /// * **Latest events phase**: Restart the scanner. On detecting a reorg, emits
    ///   [`Notification::ReorgDetected`][reorg], resets the rewind start to the new tip, and
    ///   continues until collectors accumulate `count` logs. Final delivery to listeners preserves
    ///   chronological order.
    /// * **Live streaming phase**: Starts from `latest_block + 1` and respects the configured block
    ///   confirmations. On reorg, emits [`Notification::ReorgDetected`][reorg], adjusts the next
    ///   confirmed window (possibly re-emitting confirmed portions), and continues streaming.
    ///
    /// [subscribe]: crate::EventScanner::subscribe
    /// [start]: crate::event_scanner::EventScanner::start
    /// [reorg]: crate::types::Notification::ReorgDetected
    /// [switch_to_live]: crate::types::Notification::SwitchingToLive
    /// [no_logs]: crate::types::Notification::NoPastLogsFound
    /// [max_concurrent_fetches]: crate::EventScannerBuilder#method.block_confirmations-4
    #[must_use]
    pub fn from_latest(self, count: usize) -> EventScannerBuilder<SyncFromLatestEvents> {
        EventScannerBuilder::<SyncFromLatestEvents>::new(count)
    }

    /// Streams events from a specific starting block to the present, then automatically
    /// transitions to live streaming mode.
    ///
    /// This method combines two scanning phases into a single operation:
    ///
    /// 1. **Historical sync phase**: Streams events from `from_block` up to the current confirmed
    ///    tip
    /// 2. **Automatic transition**: Emits [`Notification::SwitchingToLive`][switch_to_live] to
    ///    signal the mode change
    /// 3. **Live streaming phase**: Continuously monitors and streams new events as they arrive
    ///    on-chain
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
    /// // Sync from block 1_000_000 to present, then stream new events
    /// let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// let robust_provider = RobustProviderBuilder::new(provider).build().await?;
    /// let mut scanner = EventScannerBuilder::sync()
    ///     .from_block(1_000_000)
    ///     .connect(robust_provider)
    ///     .await?;
    ///
    /// let filter = EventFilter::new().contract_address(contract_address);
    /// let subscription = scanner.subscribe(filter);
    ///
    /// let proof = scanner.start().await?;
    /// let mut stream = subscription.stream(&proof);
    ///
    /// while let Some(msg) = stream.next().await {
    ///     match msg {
    ///         Ok(Message::Data(logs)) => {
    ///             println!("Received {} events", logs.len());
    ///         }
    ///         Ok(Message::Notification(notification)) => {
    ///             println!("Notification received: {:?}", notification);
    ///             // You'll see Notification::SwitchingToLive when transitioning
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
    /// Using block tags:
    ///
    /// ```no_run
    /// # use alloy::{network::Ethereum, eips::BlockNumberOrTag, providers::{Provider, ProviderBuilder}};
    /// # use event_scanner::EventScannerBuilder;
    /// # use robust_provider::RobustProviderBuilder;
    /// #
    /// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// // Sync from genesis block
    /// let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
    /// let robust_provider = RobustProviderBuilder::new(provider).build().await?;
    /// let mut scanner = EventScannerBuilder::sync()
    ///     .from_block(BlockNumberOrTag::Earliest)
    ///     .connect(robust_provider)
    ///     .await?;
    /// # Ok(())
    /// # }
    /// ```
    ///
    /// # How it works
    ///
    /// The scanner first streams all events from the specified starting block up to the current
    /// confirmed tip (respecting `block_confirmations`). Once caught up, it seamlessly transitions
    /// to live mode and continues streaming new events as blocks are produced.
    ///
    /// # Key behaviors
    ///
    /// * **No duplicates**: Events are not delivered twice across the phase transition
    /// * **Chronological order**: Historical events are delivered oldest to newest
    /// * **Concurrent log fetching**: Logs are fetched concurrently to reduce the sync phase
    ///   execution time. The maximum number of concurrent RPC calls is controlled by
    ///   [`max_concurrent_fetches`][max_concurrent_fetches]
    /// * **Seamless transition**: Automatically switches to live mode when caught up
    /// * **Continuous operation**: Live phase continues indefinitely until the scanner is dropped
    /// * **Reorg detection**: When a reorg is detected, [`Notification::ReorgDetected`][reorg] is
    ///   emitted, the next confirmed window is adjusted to stream the reorged blocks, and continues
    ///   streaming. While syncing, reorg checks are only performed for non-finalized blocks.
    ///
    /// # Arguments
    ///
    /// * `block_id` - Starting block id
    ///
    /// # Important notes
    ///
    /// The live phase continues indefinitely until the scanner is dropped or encounters an error.
    ///
    /// [subscribe]: crate::EventScanner::subscribe
    /// [start]: crate::event_scanner::EventScanner::start
    /// [reorg]: crate::types::Notification::ReorgDetected
    /// [switch_to_live]: crate::types::Notification::SwitchingToLive
    /// [max_concurrent_fetches]: crate::EventScannerBuilder#method.block_confirmations-3
    #[must_use]
    pub fn from_block(self, block_id: impl Into<BlockId>) -> EventScannerBuilder<SyncFromBlock> {
        EventScannerBuilder::<SyncFromBlock>::new(block_id.into())
    }
}
