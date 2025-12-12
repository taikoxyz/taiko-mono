use preconfirmation_service::NetworkEvent;

use crate::types::SdkEvent;

/// Convert low-level network events into higher-level SDK events.
pub fn map_network_event(ev: NetworkEvent) -> SdkEvent {
    crate::sdk::P2pSdk::map_event(ev)
}

