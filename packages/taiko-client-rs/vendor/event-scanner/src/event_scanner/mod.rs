//! Event scanner, its builders, and scanner mode marker types.
//!
//! This module defines [`EventScannerBuilder`] and the mode marker types used to configure an
//! [`EventScanner`]. Calling [`EventScannerBuilder::historic`], [`EventScannerBuilder::live`],
//! [`EventScannerBuilder::latest`] or [`EventScannerBuilder::sync`] selects a mode and exposes the
//! mode-specific configuration methods.
//!
//! # Streams
//!
//! Consumers register event subscriptions via [`EventScanner::subscribe`]. Each subscription
//! produces an independent stream of [`EventScannerResult`].
//!
//! ## Ordering
//!
//! Ordering is preserved *per subscription stream*. There is no global ordering guarantee across
//! different subscriptions.
//!
//! ## Backpressure and lag
//!
//! Subscription streams are buffered. If a consumer processes events too slowly and the
//! internal buffer fills up, the stream yields [`ScannerError::Lagged`] and some events
//! may be skipped.
//!
//! # Reorgs and finality
//!
//! When scanning non-finalized blocks, the scanner may detect chain reorganizations and will emit
//! [`Notification::ReorgDetected`]. Consumers should assume the same events might be delivered more
//! than once around reorgs (i.e. benign duplicates are possible).
//!
//! In live mode, `block_confirmations` delays emission so that shallow reorganizations that do not
//! affect the confirmed boundary do not trigger reorg notifications.
//!
//! [`Notification::ReorgDetected`]: crate::Notification::ReorgDetected

pub mod block_range_handler;

mod builder;
mod filter;
mod listener;
mod message;
mod modes;
mod scanner;

pub use builder::{
    DEFAULT_MAX_CONCURRENT_FETCHES, EventScannerBuilder, Historic, LatestEvents, Live,
    SyncFromBlock, SyncFromLatestEvents, Unspecified,
};
pub use filter::EventFilter;
pub use message::{EventScannerResult, Message};
pub use scanner::{EventScanner, EventSubscription, StartProof};
