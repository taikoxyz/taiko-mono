//! Types yielded by event subscription streams.
//!
//! Defines [`Message`] and [`EventScannerResult`], along with conversions and comparisons
//! for working with logs.

use alloy::{rpc::types::Log, sol_types::SolEvent};

use crate::{
    ScannerMessage,
    types::{IntoScannerResult, ScannerResult},
};

/// The item type yielded by event subscription streams.
///
/// This is a [`ScannerMessage`] whose data payload is a batch of [`Log`] values.
pub type Message = ScannerMessage<Vec<Log>>;

/// The `Result` type yielded by event subscription streams.
///
/// Successful items are [`Message`] values; failures are [`crate::ScannerError`].
pub type EventScannerResult = ScannerResult<Vec<Log>>;

impl From<Vec<Log>> for Message {
    fn from(logs: Vec<Log>) -> Self {
        Message::Data(logs)
    }
}

impl IntoScannerResult<Vec<Log>> for Vec<Log> {
    fn into_scanner_message_result(self) -> EventScannerResult {
        Ok(Message::Data(self))
    }
}

impl<E: SolEvent> PartialEq<Vec<E>> for Message {
    fn eq(&self, other: &Vec<E>) -> bool {
        self.eq(&other.as_slice())
    }
}

impl<E: SolEvent> PartialEq<&Vec<E>> for Message {
    fn eq(&self, other: &&Vec<E>) -> bool {
        self.eq(&other.as_slice())
    }
}

impl<E: SolEvent, const N: usize> PartialEq<&[E; N]> for Message {
    fn eq(&self, other: &&[E; N]) -> bool {
        self.eq(&other.as_slice())
    }
}

impl<E: SolEvent> PartialEq<&[E]> for Message {
    fn eq(&self, other: &&[E]) -> bool {
        if let Message::Data(logs) = self {
            logs.iter().map(|l| l.data().clone()).eq(other.iter().map(SolEvent::encode_log_data))
        } else {
            false
        }
    }
}
