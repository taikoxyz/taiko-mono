//! Sidecar-facing client façade over the preconfirmation P2P service.

use std::{
    collections::{HashMap, VecDeque},
    sync::Arc,
    time::{Duration, Instant},
};

use parking_lot::Mutex;
use tokio::sync::{broadcast, mpsc};

use crate::{
    catchup::{Catchup, CatchupAction, CatchupEvent},
    config::P2pClientConfig,
    error::{P2pClientError, Result},
    metrics::{record_gossip, record_reqresp_latency, record_reqresp_outcome},
    storage::{InMemoryStorage, SdkStorage},
    types::{
        Bytes32, HeadSyncStatus, MessageId, RawTxListGossip, SdkEvent, SignedCommitment, Uint256,
    },
    validation::{
        ValidationContext, ValidationOutcome, validate_raw_txlist, validate_signed_commitment,
    },
};
use alloy_primitives::B256;
use libp2p::PeerId;
use preconfirmation_service::{NetworkCommand, NetworkEvent, P2pService, PreconfStorage};
use preconfirmation_types::preconfirmation_hash;

/// High-level client entry point wrapping `P2pService`.
///
/// This façade will gain catch-up orchestration and storage integration; today it
/// maps network events into client events and exposes convenience publish/request
/// helpers suitable for the sidecar.
pub struct P2pClient {
    /// Owned network service handle.
    service: P2pService,
    /// Receiver for raw network events (internally mapped to `SdkEvent`).
    events: broadcast::Receiver<NetworkEvent>,
    /// Sender for bounded client event queue exposed to consumers.
    event_tx: mpsc::Sender<SdkEvent>,
    /// Receiver side of the bounded client event queue.
    event_rx: Mutex<mpsc::Receiver<SdkEvent>>,
    /// Bounded command channel enforcing client-level backpressure before reaching the driver.
    cmd_tx: mpsc::Sender<NetworkCommand>,
    /// Application-visible storage backend (in-memory by default).
    storage: Arc<dyn SdkStorage>,
    /// Validation context applied to inbound gossip.
    validation_ctx: ValidationContext,
    /// Catch-up orchestrator for head sync.
    catchup: Catchup,
    /// Pending head request start time for latency metrics.
    pending_head: Mutex<Option<Instant>>,
    /// Pending commitments request start time for latency metrics.
    pending_commitments: Mutex<Option<Instant>>,
    /// Pending raw txlist requests keyed by requested hash for latency metrics.
    pending_raw: Mutex<HashMap<[u8; 32], Instant>>,
    /// TTL for message-id deduplication entries.
    message_id_ttl: Duration,
    /// Per-peer rate limiter for inbound req/resp.
    rate_limiter: RateLimiter,
}

impl P2pClient {
    /// Start the client with the provided configuration and return a handle.
    pub async fn start(config: P2pClientConfig) -> Result<Self> {
        let storage = Arc::new(InMemoryStorage::with_caps_and_ids(
            config.commitment_cache,
            config.raw_txlist_cache_bytes,
            config.message_id_cache,
            config.message_id_ttl,
        ));
        let service = P2pService::start_with_lookahead_and_storage(
            config.network,
            None,
            Some(storage.clone() as Arc<dyn PreconfStorage>),
        )
        .map_err(|e| P2pClientError::Other(e.to_string()))?;
        let events = service.events();
        let (event_tx, event_rx) = mpsc::channel(config.event_buffer.max(1));
        let (cmd_tx, mut cmd_rx) = mpsc::channel(config.command_buffer);
        let cmd_sender = service.command_sender();
        tokio::spawn(async move {
            while let Some(cmd) = cmd_rx.recv().await {
                if cmd_sender.send(cmd).await.is_err() {
                    break;
                }
            }
        });
        let storage_trait: Arc<dyn SdkStorage> = storage.clone();
        let validation_ctx = ValidationContext {
            max_txlist_bytes: config.raw_txlist_cache_bytes,
            max_gossip_bytes: config.raw_txlist_cache_bytes,
            executor_slot_grace: config.executor_slot_grace,
            soft_fail_lookahead: config.gossipsub_validation_soft_fail,
            ..Default::default()
        };
        let mut catchup = Catchup::new(Uint256::from(0u64));
        catchup.set_page_size(config.max_commitments_per_page);
        catchup.configure_backoff(
            config.catchup_backoff_min,
            config.catchup_backoff_max,
            config.catchup_retry_budget,
        );

        Ok(Self {
            service,
            events,
            event_tx,
            event_rx: Mutex::new(event_rx),
            cmd_tx,
            storage: storage_trait,
            validation_ctx,
            catchup,
            pending_head: Mutex::new(None),
            pending_commitments: Mutex::new(None),
            pending_raw: Mutex::new(HashMap::new()),
            message_id_ttl: config.message_id_ttl,
            rate_limiter: RateLimiter::new(config.reqresp_rate_limit, config.reqresp_rate_window),
        })
    }

    /// Publish a signed commitment to the preconfirmation gossip topic.
    pub async fn publish_commitment(&self, msg: SignedCommitment) -> Result<()> {
        record_gossip("outbound", "commitment", "sent", 0);
        self.service.publish_commitment(msg).await.map_err(P2pClientError::from)
    }

    /// Publish a raw txlist blob to the preconfirmation raw-txlist gossip topic.
    pub async fn publish_raw_txlist(&self, msg: RawTxListGossip) -> Result<()> {
        record_gossip("outbound", "raw_txlist", "sent", msg.txlist.len());
        self.service.publish_raw_txlist(msg).await.map_err(P2pClientError::from)
    }

    /// Send a low-level network command directly to the driver.
    pub async fn send_command(&self, cmd: NetworkCommand) -> Result<()> {
        self.cmd_tx.try_send(cmd).map_err(|_| P2pClientError::Backpressure)
    }

    /// Validate and publish a signed commitment, persisting it locally on success.
    pub async fn validate_and_publish_commitment(&self, msg: SignedCommitment) -> Result<()> {
        let peer = PeerId::random();
        match validate_signed_commitment(&peer, &msg, &self.validation_ctx).await {
            ValidationOutcome::Accept => {
                let hash = preconfirmation_hash(&msg.commitment.preconf)
                    .map_err(|e| P2pClientError::Validation(e.to_string()))?;
                let arr = b256_to_arr(&hash);
                self.storage
                    .store_commitment(
                        Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
                        msg.clone(),
                    )
                    .map_err(|e| P2pClientError::Storage(e.to_string()))?;
                let _ = self.record_message(MessageId::commitment(arr));
                self.publish_commitment(msg).await
            }
            other => Err(P2pClientError::Validation(format!("{:?}", other))),
        }
    }

    /// Validate and publish a raw txlist gossip message, persisting it locally on success.
    pub async fn validate_and_publish_raw_txlist(&self, msg: RawTxListGossip) -> Result<()> {
        let peer = PeerId::random();
        match validate_raw_txlist(&peer, &msg, &self.validation_ctx).await {
            ValidationOutcome::Accept => {
                self.storage
                    .store_raw_txlist(msg.raw_tx_list_hash.clone(), msg.clone())
                    .map_err(|e| P2pClientError::Storage(e.to_string()))?;
                let _ = self
                    .record_message(MessageId::raw_txlist(bytes32_to_arr(&msg.raw_tx_list_hash)));
                self.publish_raw_txlist(msg).await
            }
            other => Err(P2pClientError::Validation(format!("{:?}", other))),
        }
    }

    /// Validate and publish a txlist followed by its commitment atomically; aborts if any step
    /// fails.
    pub async fn publish_txlist_and_commitment(
        &self,
        tx: RawTxListGossip,
        commitment: SignedCommitment,
    ) -> Result<()> {
        // Validate txlist first.
        self.validate_and_publish_raw_txlist(tx.clone()).await?;

        // Ensure commitment references the same txlist hash.
        if commitment.commitment.preconf.raw_tx_list_hash != tx.raw_tx_list_hash {
            return Err(P2pClientError::Validation("commitment tx hash mismatch".into()));
        }

        // Publish commitment only after txlist success.
        self.validate_and_publish_commitment(commitment).await
    }

    /// Request the current preconfirmation head from a peer (or any peer if `None`).
    pub async fn request_head(&self, peer: Option<PeerId>) -> Result<()> {
        *self.pending_head.lock() = Some(Instant::now());
        self.send_command(NetworkCommand::RequestHead { peer }).await
    }

    /// Request a page of commitments starting at `start_block` (inclusive).
    pub async fn request_commitments(
        &self,
        start_block: Uint256,
        max_count: u32,
        peer: Option<PeerId>,
    ) -> Result<()> {
        *self.pending_commitments.lock() = Some(Instant::now());
        self.send_command(NetworkCommand::RequestCommitments { start_block, max_count, peer }).await
    }

    /// Request a raw txlist by its hash from a peer (or any peer if `None`).
    pub async fn request_raw_txlist(
        &self,
        raw_tx_list_hash: Bytes32,
        peer: Option<PeerId>,
    ) -> Result<()> {
        self.pending_raw.lock().insert(bytes32_to_arr(&raw_tx_list_hash), Instant::now());
        self.send_command(NetworkCommand::RequestRawTxList { raw_tx_list_hash, peer }).await
    }

    /// Expose the current head-sync status as tracked by the catch-up controller.
    pub fn head_sync_status(&self) -> HeadSyncStatus {
        self.catchup.status()
    }

    /// Receive the next client event, skipping over lagged slots automatically.
    pub async fn next_event(&mut self) -> Option<SdkEvent> {
        loop {
            // Drain any queued events first.
            if let Ok(ev) = self.event_rx.lock().try_recv() {
                return Some(ev);
            }

            match self.events.recv().await {
                Ok(ev) => {
                    if let Some(out) = self.process_event(ev).await {
                        if self.event_tx.try_send(out.clone()).is_err() {
                            return Some(SdkEvent::Error("backpressure: event queue full".into()));
                        }
                        return Some(out);
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(broadcast::error::RecvError::Closed) => return None,
            }
        }
    }

    /// Obtain a fresh subscription to raw network events (advanced use).
    pub fn subscribe_raw(&self) -> broadcast::Receiver<NetworkEvent> {
        self.service.subscribe()
    }

    /// Stop the underlying network service gracefully.
    pub async fn shutdown(&mut self) {
        self.service.shutdown().await;
    }

    /// Map low-level network events into higher-level client events.
    pub(crate) fn map_event(ev: NetworkEvent) -> SdkEvent {
        match ev {
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
            // Gossip is handled in process_event to include validation/storage/dedupe.
            NetworkEvent::GossipSignedCommitment { from, msg } => {
                SdkEvent::GossipCommitment { from, msg: *msg }
            }
            NetworkEvent::GossipRawTxList { from, msg } => {
                SdkEvent::GossipRawTxList { from, msg: *msg }
            }
        }
    }

    /// Internal processor: validates, deduplicates, persists, and maps events.
    pub(crate) async fn process_event(&mut self, ev: NetworkEvent) -> Option<SdkEvent> {
        match ev {
            NetworkEvent::GossipSignedCommitment { from, msg } => {
                let signed = (*msg).clone();
                let hash = match preconfirmation_hash(&signed.commitment.preconf) {
                    Ok(h) => h,
                    Err(err) => {
                        return Some(SdkEvent::Error(format!("preconf_hash: {err}")));
                    }
                };
                let key = b256_to_arr(&hash);
                let msg_id = MessageId::commitment(key);
                if !self.record_message(msg_id) {
                    record_gossip("inbound", "commitment", "duplicate", 0);
                    return None;
                }
                match validate_signed_commitment(&from, &signed, &self.validation_ctx).await {
                    ValidationOutcome::Accept => {
                        let _ = self
                            .storage
                            .store_commitment(
                                Bytes32::try_from(key.to_vec()).unwrap(),
                                signed.clone(),
                            )
                            .ok();
                        Some(SdkEvent::GossipCommitment { from, msg: signed })
                    }
                    ValidationOutcome::SoftReject { .. } | ValidationOutcome::IgnoreSelf => None,
                    ValidationOutcome::RejectPeer { reason, detail } => {
                        record_gossip("inbound", "commitment", "rejected", 0);
                        Some(SdkEvent::Error(format!("{reason}: {}", detail.unwrap_or_default())))
                    }
                }
            }
            NetworkEvent::GossipRawTxList { from, msg } => {
                let raw = (*msg).clone();
                let key = bytes32_to_arr(&raw.raw_tx_list_hash);
                let msg_id = MessageId::raw_txlist(key);
                if !self.record_message(msg_id) {
                    record_gossip("inbound", "raw_txlist", "duplicate", raw.txlist.len());
                    return None;
                }
                match validate_raw_txlist(&from, &raw, &self.validation_ctx).await {
                    ValidationOutcome::Accept => {
                        let _ = self
                            .storage
                            .store_raw_txlist(raw.raw_tx_list_hash.clone(), raw.clone())
                            .ok();
                        Some(SdkEvent::GossipRawTxList { from, msg: raw })
                    }
                    ValidationOutcome::SoftReject { .. } | ValidationOutcome::IgnoreSelf => None,
                    ValidationOutcome::RejectPeer { reason, detail } => {
                        record_gossip("inbound", "raw_txlist", "rejected", raw.txlist.len());
                        Some(SdkEvent::Error(format!("{reason}: {}", detail.unwrap_or_default())))
                    }
                }
            }
            NetworkEvent::ReqRespHead { from: _, head } => {
                let actions = self.catchup.step(CatchupEvent::HeadObserved(head), Instant::now());
                let (commands, status_event) = Self::plan_catchup_actions(actions);
                for cmd in commands {
                    let _ = self.send_command(cmd).await;
                }
                if let Some(start) = self.pending_head.lock().take() {
                    record_reqresp_latency("head", "success", start.elapsed().as_secs_f64());
                }
                record_reqresp_outcome("head", "success");
                let status =
                    status_event.unwrap_or_else(|| SdkEvent::HeadSync(self.catchup.status()));
                Some(status)
            }
            NetworkEvent::ReqRespCommitments { from: _, msg } => {
                let last_block = msg
                    .commitments
                    .iter()
                    .map(|c| c.commitment.preconf.block_number.clone())
                    .max()
                    .unwrap_or_else(|| Uint256::from(0u64));
                let hashes = msg
                    .commitments
                    .iter()
                    .map(|c| c.commitment.preconf.raw_tx_list_hash.clone())
                    .collect();
                let actions = self.catchup.step(
                    CatchupEvent::CommitmentsPage { last_block, tx_hashes: hashes },
                    Instant::now(),
                );
                let (commands, status_event) = Self::plan_catchup_actions(actions);
                for cmd in commands {
                    let _ = self.send_command(cmd).await;
                }
                if let Some(start) = self.pending_commitments.lock().take() {
                    record_reqresp_latency("commitments", "success", start.elapsed().as_secs_f64());
                }
                record_reqresp_outcome("commitments", "success");
                status_event
            }
            NetworkEvent::ReqRespRawTxList { from, msg } => {
                let gossip_view = RawTxListGossip {
                    raw_tx_list_hash: msg.raw_tx_list_hash.clone(),
                    txlist: msg.txlist.clone(),
                };
                match validate_raw_txlist(&from, &gossip_view, &self.validation_ctx).await {
                    ValidationOutcome::Accept => {
                        let _ = self.storage.store_raw_txlist(
                            gossip_view.raw_tx_list_hash.clone(),
                            gossip_view.clone(),
                        );
                        let actions = self.catchup.step(
                            CatchupEvent::RawTxListReceived {
                                raw_tx_list_hash: bytes32_to_arr(&gossip_view.raw_tx_list_hash),
                            },
                            Instant::now(),
                        );
                        let (commands, status_event) = Self::plan_catchup_actions(actions);
                        for cmd in commands {
                            let _ = self.send_command(cmd).await;
                        }
                        if let Some(start) = self
                            .pending_raw
                            .lock()
                            .remove(&bytes32_to_arr(&gossip_view.raw_tx_list_hash))
                        {
                            record_reqresp_latency(
                                "raw_txlist",
                                "success",
                                start.elapsed().as_secs_f64(),
                            );
                        }
                        record_reqresp_outcome("raw_txlist", "success");
                        status_event.or(Some(SdkEvent::ReqRespRawTxList { from, msg }))
                    }
                    other => Some(SdkEvent::Error(format!("raw_txlist_validation: {:?}", other))),
                }
            }
            NetworkEvent::InboundCommitmentsRequest { from } => {
                if !self.rate_limiter.allow(&from, Instant::now()) {
                    record_reqresp_outcome("commitments", "rate_limited");
                    return Some(SdkEvent::Error("rate limited inbound commitments".into()));
                }
                record_reqresp_outcome("commitments", "inbound_request");
                Some(SdkEvent::InboundCommitmentsRequest { from })
            }
            NetworkEvent::InboundRawTxListRequest { from } => {
                if !self.rate_limiter.allow(&from, Instant::now()) {
                    record_reqresp_outcome("raw_txlist", "rate_limited");
                    return Some(SdkEvent::Error("rate limited inbound raw txlist".into()));
                }
                record_reqresp_outcome("raw_txlist", "inbound_request");
                Some(SdkEvent::InboundRawTxListRequest { from })
            }
            NetworkEvent::InboundHeadRequest { from } => {
                if !self.rate_limiter.allow(&from, Instant::now()) {
                    record_reqresp_outcome("head", "rate_limited");
                    return Some(SdkEvent::Error("rate limited inbound head".into()));
                }
                record_reqresp_outcome("head", "inbound_request");
                Some(SdkEvent::InboundHeadRequest { from })
            }
            NetworkEvent::PeerDisconnected(peer) => {
                // Restart catch-up when disconnected during sync to avoid stalls.
                if !matches!(
                    self.catchup.status(),
                    HeadSyncStatus::Live { .. } | HeadSyncStatus::Idle
                ) {
                    let _ = self.catchup.cancel();
                    let (commands, status) = Self::plan_catchup_actions(self.catchup.start());
                    for cmd in commands {
                        let _ = self.send_command(cmd).await;
                    }
                    if let Some(ev) = status {
                        return Some(ev);
                    }
                }
                Some(SdkEvent::PeerDisconnected(peer))
            }
            other => Some(Self::map_event(other)),
        }
    }

    /// Test-only wrapper to drive the internal event processor from integration tests.
    #[doc(hidden)]
    pub async fn process_event_test(&mut self, ev: NetworkEvent) -> Option<SdkEvent> {
        self.process_event(ev).await
    }

    /// Translate `CatchupAction`s into concrete side effects (network commands and
    /// optional client events) without changing the public client API. Unsafe or
    /// unimplemented actions are intentionally ignored.
    pub(crate) fn plan_catchup_actions(
        actions: Vec<CatchupAction>,
    ) -> (Vec<NetworkCommand>, Option<SdkEvent>) {
        let mut commands = Vec::new();
        let mut status = None;

        for action in actions {
            match action {
                CatchupAction::RequestHead => {
                    commands.push(NetworkCommand::RequestHead { peer: None });
                }
                CatchupAction::RequestCommitments { from_height, max } => {
                    commands.push(NetworkCommand::RequestCommitments {
                        start_block: from_height,
                        max_count: max,
                        peer: None,
                    });
                }
                CatchupAction::EmitStatus(s) => {
                    status = Some(SdkEvent::HeadSync(s));
                }
                CatchupAction::RequestRawTxList { raw_tx_list_hash, .. } => {
                    commands.push(NetworkCommand::RequestRawTxList {
                        raw_tx_list_hash: arr32_to_bytes32(raw_tx_list_hash),
                        peer: None,
                    });
                }
                CatchupAction::CancelInflight => {
                    // Will hook cancel semantics later.
                }
            }
        }

        (commands, status)
    }

    /// Record a message id and return true if it has not been seen recently.
    fn record_message(&self, id: MessageId) -> bool {
        self.storage.record_message_id(id, Instant::now(), self.message_id_ttl)
    }
}

/// Convert a Bytes32-like value into a fixed array for hashing/dedupe.
/// Convert a Bytes32 into an array for LRU/dedupe keys.
fn bytes32_to_arr(bytes: &Bytes32) -> [u8; 32] {
    let mut out = [0u8; 32];
    out.copy_from_slice(bytes.as_ref());
    out
}

/// Convert a B256-like value into a fixed array for hashing/dedupe.
/// Convert an alloy B256 into an array for LRU/dedupe keys.
fn b256_to_arr(hash: &B256) -> [u8; 32] {
    let mut out = [0u8; 32];
    out.copy_from_slice(hash.as_slice());
    out
}

/// Convert a raw 32-byte array into an SSZ Bytes32, defaulting on conversion failure.
fn arr32_to_bytes32(bytes: [u8; 32]) -> Bytes32 {
    Bytes32::try_from(bytes.to_vec()).unwrap_or_default()
}

/// Simple sliding-window rate limiter keyed by peer id.
struct RateLimiter {
    limit: u32,
    window: Duration,
    buckets: Mutex<HashMap<PeerId, VecDeque<Instant>>>,
}

impl RateLimiter {
    fn new(limit: u32, window: Duration) -> Self {
        Self { limit: limit.max(1), window, buckets: Mutex::new(HashMap::new()) }
    }

    /// Returns true when the request is allowed, false when rate limited.
    fn allow(&self, peer: &PeerId, now: Instant) -> bool {
        let mut buckets = self.buckets.lock();
        let bucket = buckets.entry(*peer).or_default();
        // prune expired entries
        while let Some(front) = bucket.front() {
            if now.duration_since(*front) > self.window {
                bucket.pop_front();
            } else {
                break;
            }
        }

        if (bucket.len() as u32) < self.limit {
            bucket.push_back(now);
            true
        } else {
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::catchup::CatchupAction;
    use preconfirmation_types::{
        GetCommitmentsByNumberResponse, GetRawTxListResponse, PreconfHead,
    };
    use std::time::{Duration, Instant};

    /// Convenience helper to construct `Uint256` in tests.
    fn u256(n: u64) -> Uint256 {
        Uint256::from(n)
    }

    #[test]
    /// Mapping helper should preserve peer and payload for non-gossip events.
    fn map_event_translates_non_gossip() {
        let peer = PeerId::random();
        let head = PreconfHead::default();

        let ev = NetworkEvent::ReqRespHead { from: peer, head: head.clone() };
        match P2pClient::map_event(ev) {
            SdkEvent::ReqRespHead { from, head: h } => {
                assert_eq!(from, peer);
                assert_eq!(h, head);
            }
            other => panic!("unexpected event: {:?}", other),
        }

        let ev = NetworkEvent::ReqRespCommitments {
            from: peer,
            msg: GetCommitmentsByNumberResponse::default(),
        };
        if let SdkEvent::ReqRespCommitments { .. } = P2pClient::map_event(ev) {
        } else {
            panic!("expected commitments event");
        }

        let ev =
            NetworkEvent::ReqRespRawTxList { from: peer, msg: GetRawTxListResponse::default() };
        if let SdkEvent::ReqRespRawTxList { .. } = P2pClient::map_event(ev) {
        } else {
            panic!("expected raw txlist event");
        }
    }

    #[test]
    /// Planner should map head request and status emission correctly.
    fn plan_catchup_actions_maps_head_request_and_status() {
        let actions = vec![
            CatchupAction::RequestHead,
            CatchupAction::EmitStatus(HeadSyncStatus::Live { head: u256(9) }),
        ];

        let (commands, event) = P2pClient::plan_catchup_actions(actions);

        assert_eq!(commands.len(), 1);
        match &commands[0] {
            NetworkCommand::RequestHead { peer } => assert!(peer.is_none()),
            other => panic!("unexpected command: {:?}", other),
        }

        match event {
            Some(SdkEvent::HeadSync(HeadSyncStatus::Live { head })) => {
                assert_eq!(head, u256(9));
            }
            other => panic!("unexpected event: {:?}", other),
        }
    }

    #[test]
    /// Planner should map commitments request into a network command.
    fn plan_catchup_actions_maps_commitments_request() {
        let actions = vec![CatchupAction::RequestCommitments { from_height: u256(5), max: 42 }];

        let (commands, event) = P2pClient::plan_catchup_actions(actions);

        assert!(event.is_none());
        assert_eq!(commands.len(), 1);
        match &commands[0] {
            NetworkCommand::RequestCommitments { start_block, max_count, peer } => {
                assert_eq!(*start_block, u256(5));
                assert_eq!(*max_count, 42);
                assert!(peer.is_none());
            }
            other => panic!("unexpected command: {:?}", other),
        }
    }

    #[test]
    /// Planner should map raw txlist request into a network command.
    fn plan_catchup_actions_maps_raw_txlist_request() {
        let hash = [9u8; 32];
        let actions = vec![CatchupAction::RequestRawTxList { peer: None, raw_tx_list_hash: hash }];

        let (commands, event) = P2pClient::plan_catchup_actions(actions);

        assert!(event.is_none());
        assert_eq!(commands.len(), 1);
        match &commands[0] {
            NetworkCommand::RequestRawTxList { raw_tx_list_hash, peer } => {
                assert_eq!(raw_tx_list_hash.as_ref(), &hash);
                assert!(peer.is_none());
            }
            other => panic!("unexpected command: {:?}", other),
        }
    }

    #[test]
    /// Pending latency trackers clear when corresponding responses arrive.
    fn pending_latency_entries_clear_on_responses() {
        let rt = tokio::runtime::Runtime::new().unwrap();
        let mut sdk = rt.block_on(P2pClient::start(P2pClientConfig::default())).unwrap();

        // Seed pending timers manually.
        *sdk.pending_head.lock() = Some(Instant::now());
        *sdk.pending_commitments.lock() = Some(Instant::now());

        let _ = rt.block_on(sdk.process_event(NetworkEvent::ReqRespHead {
            from: PeerId::random(),
            head: PreconfHead::default(),
        }));
        assert!(sdk.pending_head.lock().is_none());

        let _ = rt.block_on(sdk.process_event(NetworkEvent::ReqRespCommitments {
            from: PeerId::random(),
            msg: GetCommitmentsByNumberResponse::default(),
        }));
        assert!(sdk.pending_commitments.lock().is_none());

        let mut txlist = preconfirmation_types::TxListBytes::default();
        let _ = txlist.push(1u8);
        let hash = preconfirmation_types::keccak256_bytes(txlist.as_ref());
        let resp = preconfirmation_types::GetRawTxListResponse {
            raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
            anchor_block_number: Uint256::default(),
            txlist,
        };
        sdk.pending_raw.lock().insert(bytes32_to_arr(&resp.raw_tx_list_hash), Instant::now());
        let _ =
            rt.block_on(sdk.process_event(NetworkEvent::ReqRespRawTxList {
                from: PeerId::random(),
                msg: resp,
            }));
        assert!(sdk.pending_raw.lock().is_empty());
    }

    #[test]
    /// Rate limiter enforces windowed limits per peer.
    fn rate_limiter_enforces_window() {
        let rl = RateLimiter::new(2, Duration::from_secs(1));
        let peer = PeerId::random();
        let now = Instant::now();

        assert!(rl.allow(&peer, now));
        assert!(rl.allow(&peer, now));
        assert!(!rl.allow(&peer, now));

        // After window passes, allowance resets.
        assert!(rl.allow(&peer, now + Duration::from_secs(2)));
    }

    /// Commitments response should advance catch-up and emit a live status when remote == local.
    #[tokio::test]
    async fn process_commitments_advances_catchup() {
        let mut sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();
        // Move catchup into syncing state by simulating a head response.
        let head = PreconfHead { block_number: u256(3), submission_window_end: u256(0) };
        let _ = sdk.process_event(NetworkEvent::ReqRespHead { from: PeerId::random(), head }).await;

        let mut resp = GetCommitmentsByNumberResponse::default();
        let mut commit = SignedCommitment::default();
        commit.commitment.preconf.block_number = u256(3);
        let _ = resp.commitments.push(commit);

        let ev = sdk
            .process_event(NetworkEvent::ReqRespCommitments { from: PeerId::random(), msg: resp })
            .await;

        // Status should now be live at block 3 and surfaced as HeadSync.
        match ev {
            Some(SdkEvent::HeadSync(HeadSyncStatus::Live { head })) => assert_eq!(head, u256(3)),
            other => panic!("unexpected event: {:?}", other),
        }
    }

    #[tokio::test]
    /// Valid raw txlist is validated, stored, and propagated as event.
    async fn reqresp_raw_txlist_is_validated_and_stored() {
        let mut sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();

        let mut txlist = preconfirmation_types::TxListBytes::default();
        let _ = txlist.push(1u8);
        let hash = alloy_primitives::keccak256(txlist.as_ref());
        let raw = preconfirmation_types::GetRawTxListResponse {
            raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
            anchor_block_number: Uint256::default(),
            txlist,
        };

        let ev = sdk
            .process_event(NetworkEvent::ReqRespRawTxList {
                from: PeerId::random(),
                msg: raw.clone(),
            })
            .await;

        assert!(matches!(ev, Some(SdkEvent::ReqRespRawTxList { .. })));

        let store = sdk.storage.as_any().downcast_ref::<InMemoryStorage>().unwrap();
        assert_eq!(store.get_raw_txlist(&raw.raw_tx_list_hash).unwrap().txlist, raw.txlist);
    }

    /// Build a small txlist and matching signed commitment for test scenarios.
    fn build_txlist_and_commitment() -> (RawTxListGossip, SignedCommitment) {
        use preconfirmation_types::{keccak256_bytes, sign_commitment};
        use secp256k1::SecretKey;

        let mut txlist = preconfirmation_types::TxListBytes::default();
        let _ = txlist.push(1u8);
        let hash = keccak256_bytes(txlist.as_ref());
        let tx = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
            txlist,
        };

        let mut preconf = preconfirmation_types::Preconfirmation::default();
        preconf.eop = false;
        preconf.raw_tx_list_hash = tx.raw_tx_list_hash.clone();

        let mut commitment = preconfirmation_types::PreconfCommitment::default();
        commitment.preconf = preconf;

        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();

        let signed = SignedCommitment { commitment, signature: sig };

        (tx, signed)
    }

    #[tokio::test]
    /// Raw txlist helper validates, stores, and publishes successfully.
    async fn validate_and_publish_raw_txlist_stores_and_succeeds() {
        let sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();
        let (tx, _) = build_txlist_and_commitment();

        sdk.validate_and_publish_raw_txlist(tx.clone()).await.unwrap();

        let store = sdk.storage.as_any().downcast_ref::<InMemoryStorage>().unwrap();
        assert_eq!(store.get_raw_txlist(&tx.raw_tx_list_hash).unwrap(), tx);
    }

    #[tokio::test]
    /// Commitment helper validates, stores, and publishes successfully.
    async fn validate_and_publish_commitment_stores_and_succeeds() {
        let sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();
        let (tx, signed) = build_txlist_and_commitment();

        // Seed txlist so commitment parent/tx hash reference is satisfied downstream.
        sdk.validate_and_publish_raw_txlist(tx).await.unwrap();
        sdk.validate_and_publish_commitment(signed.clone()).await.unwrap();

        let store = sdk.storage.as_any().downcast_ref::<InMemoryStorage>().unwrap();
        let hash = preconfirmation_types::preconfirmation_hash(&signed.commitment.preconf).unwrap();
        let key = Bytes32::try_from(hash.as_slice().to_vec()).unwrap();
        assert_eq!(store.get_commitment(&key).unwrap(), signed);
    }

    #[tokio::test]
    /// Combined publish should store and publish txlist then commitment atomically.
    async fn publish_txlist_and_commitment_runs_atomically() {
        let sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();
        let (tx, signed) = build_txlist_and_commitment();

        sdk.publish_txlist_and_commitment(tx.clone(), signed.clone()).await.unwrap();

        let store = sdk.storage.as_any().downcast_ref::<InMemoryStorage>().unwrap();
        let hash = preconfirmation_types::preconfirmation_hash(&signed.commitment.preconf).unwrap();
        let key = Bytes32::try_from(hash.as_slice().to_vec()).unwrap();
        assert!(store.get_raw_txlist(&tx.raw_tx_list_hash).is_some());
        assert_eq!(store.get_commitment(&key).unwrap(), signed);
    }

    #[tokio::test]
    /// Duplicate gossip commitments are dropped via message-id dedupe.
    async fn duplicate_commitment_is_deduped() {
        let mut sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();
        let (_, signed) = build_txlist_and_commitment();
        let peer = PeerId::random();
        let first = sdk
            .process_event(NetworkEvent::GossipSignedCommitment {
                from: peer,
                msg: Box::new(signed.clone()),
            })
            .await;
        assert!(matches!(first, Some(SdkEvent::GossipCommitment { .. })));

        let second = sdk
            .process_event(NetworkEvent::GossipSignedCommitment {
                from: peer,
                msg: Box::new(signed),
            })
            .await;
        assert!(second.is_none());
    }

    #[tokio::test]
    /// Duplicate raw txlist gossip is dropped via message-id dedupe.
    async fn duplicate_raw_txlist_is_deduped() {
        let mut sdk = P2pClient::start(P2pClientConfig::default()).await.unwrap();
        let (tx, _) = build_txlist_and_commitment();
        let peer = PeerId::random();

        let first = sdk
            .process_event(NetworkEvent::GossipRawTxList { from: peer, msg: Box::new(tx.clone()) })
            .await;
        assert!(matches!(first, Some(SdkEvent::GossipRawTxList { .. })));

        let second = sdk
            .process_event(NetworkEvent::GossipRawTxList { from: peer, msg: Box::new(tx) })
            .await;
        assert!(second.is_none());
    }
}
