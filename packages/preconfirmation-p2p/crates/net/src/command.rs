use libp2p::PeerId;
use preconfirmation_types::{Bytes32, RawTxListGossip, SignedCommitment, Uint256};

/// Commands the service can issue to the network driver.
#[derive(Debug)]
pub enum NetworkCommand {
    /// Publish a signed commitment over gossipsub.
    PublishCommitment(SignedCommitment),
    /// Publish a raw tx list blob over gossipsub.
    PublishRawTxList(RawTxListGossip),
    /// Request a range of commitments starting at `start_block` (max `max_count`) via req/resp.
    RequestCommitments { start_block: Uint256, max_count: u32, peer: Option<PeerId> },
    /// Request a raw tx list by hash via req/resp.
    RequestRawTxList { raw_tx_list_hash: Bytes32, peer: Option<PeerId> },
    /// Request the peer's preconfirmation head (spec §11) via req/resp.
    RequestHead { peer: Option<PeerId> },
    /// Update the locally served preconfirmation head used to answer get_head requests.
    UpdateHead { head: preconfirmation_types::PreconfHead },
}
