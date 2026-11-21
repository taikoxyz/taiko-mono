//! Core scanner types and subscription management.
//!
//! This module defines [`EventScanner`], [`EventSubscription`], and [`StartProof`] which together
//! provide the main interface for subscribing to and streaming blockchain events.

use alloy::network::{Ethereum, Network};
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;

use crate::{
    block_range_scanner::BlockRangeScanner,
    event_scanner::{
        EventScannerResult, Unspecified, filter::EventFilter, listener::EventListener,
    },
};

/// An event scanner configured in mode `Mode` and bound to network `N`.
///
/// Create an instance via [`EventScannerBuilder`](crate::EventScannerBuilder), register
/// subscriptions with [`EventScanner::subscribe`], then start the scanner with the mode-specific
/// `start()` method.
///
/// # Starting the scanner
///
/// All scanner modes follow the same general startup pattern:
///
/// - **Register subscriptions first**: call [`EventScanner::subscribe`] before starting the scanner
///   with `start()`. The scanner sends events only to subscriptions that have already been
///   registered.
/// - **Non-blocking start**: `start()` returns immediately after spawning background tasks.
///   Subscription streams yield events asynchronously.
/// - **Errors after startup**: most runtime failures are delivered through subscription streams as
///   [`ScannerError`](crate::ScannerError) items, rather than being returned from `start()`.
#[derive(Debug)]
pub struct EventScanner<Mode = Unspecified, N: Network = Ethereum> {
    pub(crate) config: Mode,
    pub(crate) block_range_scanner: BlockRangeScanner<N>,
    pub(crate) listeners: Vec<EventListener>,
}

impl<Mode, N: Network> EventScanner<Mode, N> {
    pub fn new(config: Mode, block_range_scanner: BlockRangeScanner<N>) -> Self {
        Self { config, block_range_scanner, listeners: Vec::new() }
    }
}

/// A subscription to scanner events that requires proof the scanner has started.
///
/// Created by [`EventScanner::subscribe()`](crate::EventScanner::subscribe), this type holds the
/// underlying stream but prevents access until [`stream()`](EventSubscription::stream) is called
/// with a valid [`StartProof`].
///
/// This pattern ensures at compile time that `EventScanner::start()` is called before attempting to
/// read from the event stream.
///
/// # Example
///
/// ```no_run
/// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
/// # use event_scanner::{EventFilter, EventScannerBuilder, Message};
/// # use robust_provider::RobustProviderBuilder;
/// # use tokio_stream::StreamExt;
/// #
/// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
/// # let contract_address = alloy::primitives::address!("0xd8dA6BF26964af9d7eed9e03e53415d37aa96045");
/// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
/// # let provider = RobustProviderBuilder::new(provider).build().await?;
/// let mut scanner = EventScannerBuilder::live().connect(provider).await?;
///
/// let filter = EventFilter::new().contract_address(contract_address);
///
/// // Create subscription (cannot access stream yet)
/// let subscription = scanner.subscribe(filter);
///
/// // Start scanner and get proof of it starting
/// let proof = scanner.start().await?;
///
/// // Now access the stream with the proof
/// let mut stream = subscription.stream(&proof);
///
/// while let Some(msg) = stream.next().await {
///     // process events
/// }
/// # Ok(())
/// # }
/// ```
pub struct EventSubscription {
    inner: ReceiverStream<EventScannerResult>,
}

impl EventSubscription {
    /// Creates a new subscription wrapping the given stream.
    pub(crate) fn new(inner: ReceiverStream<EventScannerResult>) -> Self {
        Self { inner }
    }

    /// Access the event stream.
    ///
    /// Requires a reference to a [`StartProof`] as proof that the scanner
    /// has been started. The proof is obtained by calling
    /// `EventScanner::start()`.
    ///
    /// # Arguments
    ///
    /// * `_proof` - Proof that the scanner has been started
    #[must_use]
    pub fn stream(self, _proof: &StartProof) -> ReceiverStream<EventScannerResult> {
        self.inner
    }
}

impl<Mode, N: Network> EventScanner<Mode, N> {
    /// Returns the configured stream buffer capacity.
    #[must_use]
    pub fn buffer_capacity(&self) -> usize {
        self.block_range_scanner.buffer_capacity()
    }

    /// Registers an event subscription.
    ///
    /// Each call creates a separate subscription with its own buffer.
    ///
    /// # Ordering
    ///
    /// Ordering is guaranteed only within a single returned subscription. There is no ordering
    /// guarantee across subscriptions created by multiple calls to this method.
    #[must_use]
    pub fn subscribe(&mut self, filter: EventFilter) -> EventSubscription {
        let (sender, receiver) =
            mpsc::channel::<EventScannerResult>(self.block_range_scanner.buffer_capacity());
        self.listeners.push(EventListener { filter, sender });
        EventSubscription::new(ReceiverStream::new(receiver))
    }
}

/// Proof that the scanner has been started.
///
/// This proof is returned by `EventScanner::start()` and must be passed to
/// [`EventSubscription::stream()`] to access the event stream. This ensures at compile
/// time that the scanner is started before attempting to read events.
///
/// # Example
///
/// ```no_run
/// # use alloy::{network::Ethereum, providers::{Provider, ProviderBuilder}};
/// # use event_scanner::{EventFilter, EventScannerBuilder, Message};
/// # use robust_provider::RobustProviderBuilder;
/// # use tokio_stream::StreamExt;
/// #
/// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
/// # let contract_address = alloy::primitives::address!("0xd8dA6BF26964af9d7eed9e03e53415d37aa96045");
/// # let provider = ProviderBuilder::new().connect("ws://localhost:8545").await?;
/// # let provider = RobustProviderBuilder::new(provider).build().await?;
/// let mut scanner = EventScannerBuilder::sync().from_block(0).connect(provider).await?;
///
/// let filter = EventFilter::new().contract_address(contract_address);
///
/// // Create subscription (cannot access stream yet)
/// let subscription = scanner.subscribe(filter);
///
/// // Start scanner and get proof of it starting
/// let proof = scanner.start().await?;
///
/// // Now access the stream with the proof
/// let mut stream = subscription.stream(&proof);
///
/// while let Some(msg) = stream.next().await {
///     // process events
/// }
/// # Ok(())
/// # }
/// ```
#[derive(Debug, Clone)]
pub struct StartProof {
    /// Private field prevents construction outside this crate
    _private: (),
}

impl StartProof {
    /// Creates a new start proof.
    #[must_use]
    pub(crate) fn new() -> Self {
        Self { _private: () }
    }
}
