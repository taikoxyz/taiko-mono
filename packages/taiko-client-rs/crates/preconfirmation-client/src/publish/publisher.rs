//! Preconfirmation publisher implementation.
//!
//! This module provides the `PreconfirmationPublisher` for broadcasting
//! commitments and txlists to the P2P network.

use tokio::sync::mpsc::Sender;
use tracing::debug;

use preconfirmation_net::NetworkCommand;
use preconfirmation_types::{RawTxListGossip, SignedCommitment};

use crate::error::{PreconfirmationClientError, Result};

/// Publisher for preconfirmation messages.
///
/// This component handles publishing signed commitments and raw txlists
/// to the P2P gossip network. It is used by preconfirmers to broadcast
/// their preconfirmations.
pub struct PreconfirmationPublisher {
    /// Command sender for the P2P driver.
    command_sender: Sender<NetworkCommand>,
}

impl PreconfirmationPublisher {
    /// Create a new publisher from a command sender.
    pub fn new(command_sender: Sender<NetworkCommand>) -> Self {
        Self { command_sender }
    }

    /// Publish a signed commitment to the network.
    pub async fn publish_commitment(&self, commitment: SignedCommitment) -> Result<()> {
        // Emit a debug log for observability.
        debug!("publishing commitment");
        self.command_sender
            .send(NetworkCommand::PublishCommitment(commitment))
            .await
            .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;
        Ok(())
    }

    /// Publish a raw txlist to the network.
    pub async fn publish_raw_txlist(&self, txlist: RawTxListGossip) -> Result<()> {
        // Emit a debug log for observability.
        debug!("publishing txlist");
        self.command_sender
            .send(NetworkCommand::PublishRawTxList(txlist))
            .await
            .map_err(|err| PreconfirmationClientError::Network(err.to_string()))?;
        Ok(())
    }

    /// Publish a txlist followed by its commitment (recommended ordering).
    pub async fn publish_commitment_with_txlist(
        &self,
        commitment: SignedCommitment,
        txlist: RawTxListGossip,
    ) -> Result<()> {
        // Publish the txlist first.
        self.publish_raw_txlist(txlist).await?;
        // Publish the commitment next.
        self.publish_commitment(commitment).await?;
        Ok(())
    }
}

#[cfg(test)]
/// Tests for the publisher module.
mod tests {
    /// Placeholder test to verify module compiles.
    #[test]
    fn publisher_compiles() {
        assert!(true);
    }
}
