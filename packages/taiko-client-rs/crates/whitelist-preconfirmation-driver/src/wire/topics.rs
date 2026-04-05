//! Go-compatible whitelist preconfirmation topic definitions.

use libp2p::gossipsub;

/// Topic suffix for signed unsafe payload gossip.
const PRECONF_BLOCKS_SUFFIX: &str = "/preconfBlocks";
/// Topic suffix for block-by-hash request gossip.
const PRECONF_REQUEST_SUFFIX: &str = "/requestPreconfBlocks";
/// Topic suffix for block-by-hash response gossip.
const PRECONF_RESPONSE_SUFFIX: &str = "/responsePreconfBlocks";
/// Topic suffix for end-of-sequencing request gossip.
const EOS_REQUEST_SUFFIX: &str = "/requestEndOfSequencingPreconfBlocks";

/// Group of Go-compatible gossipsub topics used by the whitelist preconfirmation network.
#[derive(Clone, Debug)]
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
    /// Build Go-compatible Taiko topic names for `chain_id`.
    pub(crate) fn new(chain_id: u64) -> Self {
        let prefix = format!("/taiko/{chain_id}/0");
        Self {
            preconf_blocks: gossipsub::IdentTopic::new(format!("{prefix}{PRECONF_BLOCKS_SUFFIX}")),
            preconf_request: gossipsub::IdentTopic::new(format!(
                "{prefix}{PRECONF_REQUEST_SUFFIX}"
            )),
            preconf_response: gossipsub::IdentTopic::new(format!(
                "{prefix}{PRECONF_RESPONSE_SUFFIX}"
            )),
            eos_request: gossipsub::IdentTopic::new(format!("{prefix}{EOS_REQUEST_SUFFIX}")),
        }
    }
}
