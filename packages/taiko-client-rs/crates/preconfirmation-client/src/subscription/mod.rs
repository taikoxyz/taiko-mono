//! Subscription helpers for P2P network events.

/// Event handler implementation.
pub mod event_handler;

pub use event_handler::{EventHandler, PreconfirmationEvent};

/// Dependencies used to construct an event handler.
pub use event_handler::EventHandlerContext;
