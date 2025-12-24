use anyhow::Result;
use futures::Stream;
use libp2p::PeerId;
use tokio::sync::{
    mpsc::{Receiver, Sender},
    oneshot,
};

use crate::{
    command::NetworkCommand,
    driver::NetworkHandle,
    event::{NetworkError, NetworkErrorKind, NetworkEvent},
};

/// Minimal handle for sending commands and consuming events.
pub struct P2pHandle {
    commands: Sender<NetworkCommand>,
    events: Receiver<NetworkEvent>,
}

impl P2pHandle {
    pub(crate) fn new(handle: NetworkHandle) -> Self {
        Self { commands: handle.commands, events: handle.events }
    }

    pub fn command_sender(&self) -> Sender<NetworkCommand> {
        self.commands.clone()
    }

    pub fn events(&mut self) -> impl Stream<Item = NetworkEvent> + '_ {
        futures::stream::poll_fn(move |cx| self.events.poll_recv(cx))
    }

    pub async fn publish_commitment(
        &self,
        msg: preconfirmation_types::SignedCommitment,
    ) -> Result<()> {
        self.commands
            .send(NetworkCommand::PublishCommitment(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    pub async fn publish_raw_txlist(
        &self,
        msg: preconfirmation_types::RawTxListGossip,
    ) -> Result<()> {
        self.commands
            .send(NetworkCommand::PublishRawTxList(msg))
            .await
            .map_err(|e| anyhow::anyhow!("send command: {e}"))
    }

    pub async fn request_commitments(
        &mut self,
        start_block: preconfirmation_types::Uint256,
        max_count: u32,
        peer: Option<PeerId>,
    ) -> Result<preconfirmation_types::GetCommitmentsByNumberResponse, NetworkError> {
        let (tx, rx) = oneshot::channel();
        self.commands
            .send(NetworkCommand::RequestCommitments {
                respond_to: Some(tx),
                start_block,
                max_count,
                peer,
            })
            .await
            .map_err(|e| {
                NetworkError::new(NetworkErrorKind::SendCommandFailed, format!("send command: {e}"))
            })?;

        rx.await.unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before commitments response",
            ))
        })
    }

    pub async fn request_raw_txlist(
        &mut self,
        hash: preconfirmation_types::Bytes32,
        peer: Option<PeerId>,
    ) -> Result<preconfirmation_types::GetRawTxListResponse, NetworkError> {
        let (tx, rx) = oneshot::channel();
        self.commands
            .send(NetworkCommand::RequestRawTxList {
                respond_to: Some(tx),
                raw_tx_list_hash: hash,
                peer,
            })
            .await
            .map_err(|e| {
                NetworkError::new(NetworkErrorKind::SendCommandFailed, format!("send command: {e}"))
            })?;

        rx.await.unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before raw-txlist response",
            ))
        })
    }

    pub async fn request_head(
        &mut self,
        peer: Option<PeerId>,
    ) -> Result<preconfirmation_types::PreconfHead, NetworkError> {
        let (tx, rx) = oneshot::channel();
        self.commands
            .send(NetworkCommand::RequestHead { respond_to: Some(tx), peer })
            .await
            .map_err(|e| {
                NetworkError::new(NetworkErrorKind::SendCommandFailed, format!("send command: {e}"))
            })?;

        rx.await.unwrap_or_else(|_| {
            Err(NetworkError::new(
                NetworkErrorKind::ReqRespTimeout,
                "service stopped before head response",
            ))
        })
    }
}
