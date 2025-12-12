use libp2p::PeerId;
use preconfirmation_types::{RawTxListGossip, SignedCommitment};

use crate::error::Result;

/// Placeholder validation that will be expanded to enforce the P2P spec rules.
#[allow(clippy::unused_async)]
pub async fn validate_signed_commitment(
    _from: &PeerId,
    _msg: &SignedCommitment,
) -> Result<()> {
    Ok(())
}

#[allow(clippy::unused_async)]
pub async fn validate_raw_txlist(
    _from: &PeerId,
    _msg: &RawTxListGossip,
) -> Result<()> {
    Ok(())
}

