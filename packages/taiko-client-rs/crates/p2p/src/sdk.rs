use tokio::sync::broadcast;

use crate::config::P2pSdkConfig;
use crate::error::{P2pSdkError, Result};
use crate::types::{SdkEvent, SignedCommitment, RawTxListGossip};
use preconfirmation_service::{NetworkCommand, NetworkEvent, P2pService};

/// High-level SDK façade. This will grow orchestration and storage wiring; for now
/// it forwards to the underlying `P2pService`.
pub struct P2pSdk {
    service: P2pService,
    events: broadcast::Receiver<NetworkEvent>,
}

impl P2pSdk {
    pub async fn start(config: P2pSdkConfig) -> Result<Self> {
        let service = P2pService::start(config.network)
            .map_err(|e| P2pSdkError::Other(e.to_string()))?;
        let events = service.events();
        Ok(Self { service, events })
    }

    pub async fn publish_commitment(&self, msg: SignedCommitment) -> Result<()> {
        self.service.publish_commitment(msg).await.map_err(P2pSdkError::from)
    }

    pub async fn publish_raw_txlist(&self, msg: RawTxListGossip) -> Result<()> {
        self.service.publish_raw_txlist(msg).await.map_err(P2pSdkError::from)
    }

    pub async fn send_command(&self, cmd: NetworkCommand) -> Result<()> {
        self.service
            .command_sender()
            .send(cmd)
            .await
            .map_err(|_| P2pSdkError::Backpressure)
    }

    pub async fn next_event(&mut self) -> Option<SdkEvent> {
        loop {
            match self.events.recv().await {
                Ok(ev) => return Some(Self::map_event(ev)),
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => return None,
            }
        }
    }

    pub async fn shutdown(&mut self) {
        self.service.shutdown().await;
    }

    pub(crate) fn map_event(ev: NetworkEvent) -> SdkEvent {
        match ev {
            NetworkEvent::GossipSignedCommitment { from, msg } => {
                SdkEvent::GossipCommitment { from, msg: *msg }
            }
            NetworkEvent::GossipRawTxList { from, msg } => {
                SdkEvent::GossipRawTxList { from, msg: *msg }
            }
            NetworkEvent::ReqRespCommitments { from, msg } => {
                SdkEvent::ReqRespCommitments { from, msg }
            }
            NetworkEvent::ReqRespRawTxList { from, msg } => {
                SdkEvent::ReqRespRawTxList { from, msg }
            }
            NetworkEvent::ReqRespHead { from, head } => SdkEvent::ReqRespHead { from, head },
            NetworkEvent::InboundCommitmentsRequest { from } => {
                SdkEvent::InboundCommitmentsRequest { from }
            }
            NetworkEvent::InboundRawTxListRequest { from } => {
                SdkEvent::InboundRawTxListRequest { from }
            }
            NetworkEvent::InboundHeadRequest { from } => SdkEvent::InboundHeadRequest { from },
            NetworkEvent::PeerConnected(peer) => SdkEvent::PeerConnected(peer),
            NetworkEvent::PeerDisconnected(peer) => SdkEvent::PeerDisconnected(peer),
            NetworkEvent::Error(err) => SdkEvent::Error(err.to_string()),
            NetworkEvent::Started => SdkEvent::Started,
            NetworkEvent::Stopped => SdkEvent::Stopped,
        }
    }
}
