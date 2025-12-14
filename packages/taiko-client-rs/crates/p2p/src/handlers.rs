//! Adapter helpers that translate network events into client-facing events.

use preconfirmation_service::NetworkEvent;

use crate::types::SdkEvent;

/// Convert low-level network events into higher-level client events.
pub fn map_network_event(ev: NetworkEvent) -> SdkEvent {
    crate::client::P2pClient::map_event(ev)
}
