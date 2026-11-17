//! Internal event listener for distributing scanned logs to subscribers.
//!
//! This module defines [`EventListener`] which pairs an event filter with a channel sender
//! to deliver matching logs to subscription streams.

use crate::event_scanner::{EventScannerResult, filter::EventFilter};
use tokio::sync::mpsc::Sender;

#[derive(Clone, Debug)]
pub struct EventListener {
    pub filter: EventFilter,
    pub sender: Sender<EventScannerResult>,
}
