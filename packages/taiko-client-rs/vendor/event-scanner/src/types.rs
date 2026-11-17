use std::fmt::Debug;

use tokio::sync::mpsc;

use crate::ScannerError;

/// Represents the state of a channel after attempting to send a message.
///
/// This enum provides explicit semantics for channel operations, making it clear
/// whether the downstream receiver is still listening or has been dropped.
#[derive(Debug, Clone, Copy)]
pub(crate) enum ChannelState {
    /// The channel is open and the message was successfully sent.
    Open,
    /// The channel is closed (receiver dropped), no further messages can be sent.
    Closed,
}

impl ChannelState {
    /// Returns `true` if the channel is closed.
    #[must_use]
    pub(crate) fn is_closed(self) -> bool {
        matches!(self, ChannelState::Closed)
    }
}

/// Messages streamed by the scanner to subscribers.
///
/// Each message represents either data or a notification about the scanner's state or behavior.
#[derive(Copy, Debug, Clone)]
pub enum ScannerMessage<T: Clone> {
    /// Data streamed to the subscriber.
    Data(T),

    /// Notification about scanner state changes or important events.
    Notification(Notification),
}

/// Notifications emitted by the scanner to signal state changes or important events.
#[derive(Copy, Debug, Clone, PartialEq)]
pub enum Notification {
    /// Emitted when transitioning from the latest events phase to live streaming mode
    /// in sync scanners.
    SwitchingToLive,

    /// When a reorg occurs, the scanner adjusts its position to re-stream events from the
    /// canonical chain state. The specific behavior depends on the scanning mode (see individual
    /// scanner mode documentation for details).
    ///
    /// # Redundant Notifications
    ///
    /// Due to the asynchronous nature of block scanning and log fetching, you may occasionally
    /// receive this notification even after the reorg has already been accounted for. This happens
    /// when:
    ///
    /// 1. `BlockRangeScanner` validates and emits a block range
    /// 2. A reorg occurs on the chain
    /// 3. `EventScanner` fetches logs for that range, but the RPC provider returns logs from the
    ///    post-reorg chain state (the provider's view has already updated)
    /// 4. `BlockRangeScanner` detects the reorg on its next check and emits
    ///    `Notification::ReorgDetected` with a new range starting from the first reorged block
    /// 5. `EventScanner` re-fetches logs for this range, which may return duplicate logs already
    ///    delivered in step 3 (the new range might also extend beyond the original range)
    ///
    /// **How to handle**: This is a benign race condition. Your application should be designed to
    /// handle duplicate logs idempotently (e.g., using transaction hashes or log indices as
    /// deduplication keys). Depending on your application semantics, you may also treat this
    /// notification as a signal to roll back application state derived from blocks after the
    /// reported common ancestor.
    ReorgDetected {
        /// The block number of the last block that is still valid on the canonical chain.
        common_ancestor: u64,
    },

    /// Emitted during the latest events phase when no matching logs are found in the
    /// scanned range.
    NoPastLogsFound,
}

impl<T: Clone> From<Notification> for ScannerMessage<T> {
    fn from(value: Notification) -> Self {
        ScannerMessage::Notification(value)
    }
}

impl<T: Clone> PartialEq<Notification> for ScannerMessage<T> {
    fn eq(&self, other: &Notification) -> bool {
        if let ScannerMessage::Notification(notification) = self {
            notification == other
        } else {
            false
        }
    }
}

/// A convenience `Result` type for scanner streams.
///
/// Successful items are [`ScannerMessage`] values; failures are [`ScannerError`].
pub type ScannerResult<T> = Result<ScannerMessage<T>, ScannerError>;

/// Conversion helper for streaming either data, notifications, or errors.
pub trait IntoScannerResult<T: Clone> {
    fn into_scanner_message_result(self) -> ScannerResult<T>;
}

impl<T: Clone> IntoScannerResult<T> for ScannerResult<T> {
    fn into_scanner_message_result(self) -> ScannerResult<T> {
        self
    }
}

impl<T: Clone> IntoScannerResult<T> for ScannerMessage<T> {
    fn into_scanner_message_result(self) -> ScannerResult<T> {
        Ok(self)
    }
}

impl<T: Clone, E: Into<ScannerError>> IntoScannerResult<T> for E {
    fn into_scanner_message_result(self) -> ScannerResult<T> {
        Err(self.into())
    }
}

impl<T: Clone> IntoScannerResult<T> for Notification {
    fn into_scanner_message_result(self) -> ScannerResult<T> {
        Ok(ScannerMessage::Notification(self))
    }
}

/// Internal helper for attempting to forward a stream item through an `mpsc` channel.
pub(crate) trait TryStream<T: Clone> {
    async fn try_stream<M: IntoScannerResult<T>>(&self, msg: M) -> ChannelState;
}

impl<T: Clone + Debug> TryStream<T> for mpsc::Sender<ScannerResult<T>> {
    async fn try_stream<M: IntoScannerResult<T>>(&self, msg: M) -> ChannelState {
        let item = msg.into_scanner_message_result();
        if self.send(item).await.is_err() {
            return ChannelState::Closed;
        }
        ChannelState::Open
    }
}
