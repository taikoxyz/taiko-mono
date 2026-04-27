//! Gossipsub topic definitions for the whitelist preconfirmation network.

use libp2p::gossipsub;

/// Group of gossipsub topics used by the whitelist preconfirmation driver.
#[derive(Clone)]
pub(crate) struct Topics {
    /// Topic carrying signed unsafe payload gossip.
    pub(crate) preconf_blocks: gossipsub::IdentTopic,
    /// Topic used to request a payload by block hash.
    pub(crate) preconf_request: gossipsub::IdentTopic,
    /// Topic used to answer payload-by-hash requests.
    pub(crate) preconf_response: gossipsub::IdentTopic,
    /// Topic used by peers requesting end-of-sequencing payloads.
    pub(crate) eos_request: gossipsub::IdentTopic,
}

impl Topics {
    /// Build all whitelist preconfirmation topic names for the given chain id.
    pub(crate) fn new(chain_id: u64) -> Self {
        Self {
            preconf_blocks: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/preconfBlocks"
            )),
            preconf_request: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/requestPreconfBlocks"
            )),
            preconf_response: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/responsePreconfBlocks"
            )),
            eos_request: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/requestEndOfSequencingPreconfBlocks"
            )),
        }
    }

    /// Subscribe a gossipsub behaviour to all whitelist preconfirmation topics.
    pub(crate) fn subscribe(
        &self,
        gossipsub: &mut gossipsub::Behaviour,
    ) -> Result<(), gossipsub::SubscriptionError> {
        gossipsub.subscribe(&self.preconf_blocks)?;
        gossipsub.subscribe(&self.preconf_request)?;
        gossipsub.subscribe(&self.preconf_response)?;
        gossipsub.subscribe(&self.eos_request)?;
        Ok(())
    }
}
