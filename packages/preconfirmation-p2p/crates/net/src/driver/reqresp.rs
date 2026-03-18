//! Request/response protocol handling for the network driver.
//!
//! This module handles the three req/resp protocols defined by the preconfirmation spec:
//! - `get_commitments_by_number`: Fetch a range of commitments by block number.
//! - `get_raw_txlist`: Fetch a raw transaction list by its hash.
//! - `get_head`: Fetch the current preconfirmation head from a peer.
//!
//! Each protocol handler processes inbound requests (serving local data), outbound
//! responses (consuming remote data), and failure events (timeouts, codec errors).

use std::task::{Context, Poll};

use libp2p::request_response as rr;
use preconfirmation_types::{
    GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, GetHeadRequest,
    GetRawTxListRequest, GetRawTxListResponse, PreconfHead, TxListBytes, bytes32_to_b256,
    uint256_to_u256,
};

use super::*;

/// Typed responder for req/resp exchanges keyed by request id.
///
/// Each variant holds a oneshot sender that delivers the result (or error) back to
/// the caller who initiated the request.
pub enum ReqRespResponder {
    /// Responder for commitments requests.
    Commitments(tokio::sync::oneshot::Sender<Result<GetCommitmentsByNumberResponse, NetworkError>>),
    /// Responder for raw transaction list requests.
    RawTxList(tokio::sync::oneshot::Sender<Result<GetRawTxListResponse, NetworkError>>),
    /// Responder for head requests.
    Head(tokio::sync::oneshot::Sender<Result<PreconfHead, NetworkError>>),
}

/// Pending outbound req/resp request details.
///
/// Tracks the responder (if any) and the start time for RTT metrics.
pub(super) struct PendingRequest {
    /// Optional responder to deliver the result to the caller.
    responder: Option<ReqRespResponder>,
    /// Timestamp when the request was sent, used for RTT measurement.
    started_at: tokio::time::Instant,
}

impl NetworkDriver {
    /// Returns the metric/error label for a req/resp kind.
    fn reqresp_label(kind: ReqRespKind) -> &'static str {
        match kind {
            ReqRespKind::Commitments => "commitments",
            ReqRespKind::RawTxList => "raw_txlists",
            ReqRespKind::Head => "head",
        }
    }

    /// Emit req/resp RTT metrics tagged by protocol and outcome.
    pub(super) fn record_reqresp_rtt(
        &mut self,
        kind: ReqRespKind,
        outcome: &'static str,
        start: tokio::time::Instant,
    ) {
        let elapsed = start.elapsed().as_secs_f64();
        let proto = Self::reqresp_label(kind);
        metrics::histogram!("p2p_reqresp_rtt_seconds", "protocol" => proto, "outcome" => outcome)
            .record(elapsed);
    }

    /// Track outbound request responders so we can fulfill futures on completion.
    pub(super) fn track_outbound_request(
        &mut self,
        kind: ReqRespKind,
        request_id: rr::OutboundRequestId,
        responder: Option<ReqRespResponder>,
    ) {
        self.pending_requests.insert(
            (kind, request_id),
            PendingRequest { responder, started_at: tokio::time::Instant::now() },
        );
    }

    /// Remove and return the pending outbound request for a completed exchange.
    fn take_pending_request(
        &mut self,
        kind: ReqRespKind,
        request_id: rr::OutboundRequestId,
    ) -> Option<PendingRequest> {
        self.pending_requests.remove(&(kind, request_id))
    }

    /// Send an error response via the given responder.
    fn respond_with_error(responder: ReqRespResponder, err: NetworkError) {
        match responder {
            ReqRespResponder::Commitments(tx) => {
                let _ = tx.send(Err(err));
            }
            ReqRespResponder::RawTxList(tx) => {
                let _ = tx.send(Err(err));
            }
            ReqRespResponder::Head(tx) => {
                let _ = tx.send(Err(err));
            }
        }
    }

    /// Handle the case where no peers are available for a req/resp request.
    pub(super) fn handle_no_peer_available(
        &mut self,
        kind: ReqRespKind,
        responder: Option<ReqRespResponder>,
    ) {
        let kind_label = Self::reqresp_label(kind);
        let err = NetworkError::new(
            NetworkErrorKind::ReqRespBackpressure,
            format!("req-resp {kind_label}: no peers available"),
        );
        metrics::counter!("p2p_reqresp_error", "kind" => kind_label, "reason" => "no_peer")
            .increment(1);
        if let Some(responder) = responder {
            Self::respond_with_error(responder, err.clone());
        }
        self.emit_error(NetworkErrorKind::ReqRespBackpressure, err.detail.clone());
    }

    /// Apply ban checks and rate limiting for inbound req/resp requests.
    fn allow_inbound_request(
        &mut self,
        peer: &PeerId,
        kind: ReqRespKind,
        cx: &mut Context<'_>,
        rate_limited_msg: &'static str,
    ) -> bool {
        let kind_label = Self::reqresp_label(kind);
        if self.reputation.is_banned(peer) {
            metrics::counter!("p2p_reqresp_dropped", "kind" => kind_label, "reason" => "banned")
                .increment(1);
            return false;
        }
        match self.request_limiter.poll_allow(*peer, kind, cx) {
            Poll::Ready(true) => true,
            _ => {
                metrics::counter!("p2p_reqresp_rate_limited", "kind" => kind_label).increment(1);
                self.emit_error(NetworkErrorKind::ReqRespRateLimited, rate_limited_msg);
                self.apply_reputation(*peer, PeerAction::Timeout);
                false
            }
        }
    }

    /// Emit metrics, reputation changes, and an error for validation failures.
    fn handle_outbound_validation_error(
        &mut self,
        kind: ReqRespKind,
        peer: PeerId,
        request_id: rr::OutboundRequestId,
        detail: &'static str,
    ) {
        let kind_label = Self::reqresp_label(kind);
        metrics::counter!("p2p_reqresp_error", "kind" => kind_label, "reason" => "validation")
            .increment(1);
        self.apply_reputation(peer, PeerAction::ReqRespError);
        let err =
            NetworkError::new(NetworkErrorKind::ReqRespValidation, format!("{detail} from {peer}"));
        if let Some(pending) = self.take_pending_request(kind, request_id) {
            self.record_reqresp_rtt(kind, "error", pending.started_at);
            if let Some(responder) = pending.responder {
                Self::respond_with_error(responder, err.clone());
            }
        }
        self.emit_error(NetworkErrorKind::ReqRespValidation, format!("{detail} from {peer}"));
    }

    /// Handle outbound req/resp failures (timeouts, transport errors).
    fn handle_outbound_failure(
        &mut self,
        kind: ReqRespKind,
        peer: PeerId,
        error: rr::OutboundFailure,
        request_id: rr::OutboundRequestId,
    ) {
        let kind_label = Self::reqresp_label(kind);
        let err_label = Self::reqresp_label(kind);
        metrics::counter!("p2p_reqresp_error", "kind" => kind_label, "reason" => "outbound_failure")
            .increment(1);
        self.apply_reputation(peer, PeerAction::ReqRespError);
        let err = NetworkError::new(
            NetworkErrorKind::ReqRespFailure,
            format!("req-resp {err_label} with {peer}: {error}"),
        );
        if let Some(pending) = self.take_pending_request(kind, request_id) {
            let outcome = match error {
                rr::OutboundFailure::Timeout => "timeout",
                _ => "error",
            };
            self.record_reqresp_rtt(kind, outcome, pending.started_at);
            if let Some(responder) = pending.responder {
                Self::respond_with_error(responder, err.clone());
            }
        }
        self.emit_error(
            NetworkErrorKind::ReqRespFailure,
            format!("req-resp {err_label} with {peer}: {error}"),
        );
    }

    /// Handle inbound req/resp failures and emit error surfaces.
    fn handle_inbound_failure(
        &mut self,
        kind: ReqRespKind,
        peer: PeerId,
        error: rr::InboundFailure,
    ) {
        let kind_label = Self::reqresp_label(kind);
        let err_label = Self::reqresp_label(kind);
        metrics::counter!("p2p_reqresp_error", "kind" => kind_label, "reason" => "inbound_failure")
            .increment(1);
        self.apply_reputation(peer, PeerAction::ReqRespError);
        self.emit_error(
            NetworkErrorKind::ReqRespFailure,
            format!("req-resp {err_label} with {peer}: {error}"),
        );
    }

    /// Handles `request_response::Event`s for commitments.
    pub(super) fn handle_commitments_rr_event(
        &mut self,
        ev: rr::Event<GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse>,
        cx: &mut Context<'_>,
    ) {
        match ev {
            rr::Event::Message { peer, message, .. } => match message {
                rr::Message::Request { request, channel, .. } => {
                    if !self.allow_inbound_request(
                        &peer,
                        ReqRespKind::Commitments,
                        cx,
                        "commitments request rate-limited",
                    ) {
                        return;
                    }

                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::InboundCommitmentsRequest { from: peer });
                    let cap = request
                        .max_count
                        .min(preconfirmation_types::MAX_COMMITMENTS_PER_RESPONSE as u32);
                    let mut list = preconfirmation_types::CommitmentList::default();
                    let commits = self.storage.commitments_from(
                        uint256_to_u256(&request.start_block_number),
                        cap as usize,
                    );
                    for commit in commits.into_iter().take(cap as usize) {
                        list.push(commit);
                    }
                    let resp = GetCommitmentsByNumberResponse { commitments: list };
                    let _ = self.swarm.behaviour_mut().commitments_rr.send_response(channel, resp);
                    metrics::counter!("p2p_reqresp_success", "kind" => "commitments", "direction" => "inbound").increment(1);
                    self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                }
                rr::Message::Response { request_id, response } => {
                    if self.validator.validate_commitments_response(&peer, &response).is_ok() {
                        metrics::counter!("p2p_reqresp_success", "kind" => "commitments", "direction" => "outbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        if let Some(pending) =
                            self.take_pending_request(ReqRespKind::Commitments, request_id)
                        {
                            self.record_reqresp_rtt(
                                ReqRespKind::Commitments,
                                "success",
                                pending.started_at,
                            );
                            if let Some(ReqRespResponder::Commitments(tx)) = pending.responder {
                                let _ = tx.send(Ok(response.clone()));
                            }
                        }
                        let _ = self.events_tx.try_send(NetworkEvent::ReqRespCommitments {
                            from: peer,
                            msg: response,
                        });
                    } else {
                        self.handle_outbound_validation_error(
                            ReqRespKind::Commitments,
                            peer,
                            request_id,
                            "invalid commitments response",
                        );
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, request_id, .. } => {
                self.handle_outbound_failure(ReqRespKind::Commitments, peer, error, request_id);
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                self.handle_inbound_failure(ReqRespKind::Commitments, peer, error);
            }
            rr::Event::ResponseSent { .. } => {}
        }
    }

    /// Handles `request_response::Event`s for raw transaction lists.
    pub(super) fn handle_raw_txlists_rr_event(
        &mut self,
        ev: rr::Event<GetRawTxListRequest, GetRawTxListResponse>,
        cx: &mut Context<'_>,
    ) {
        match ev {
            rr::Event::Message { peer, message, .. } => match message {
                rr::Message::Request { request, channel, .. } => {
                    if !self.allow_inbound_request(
                        &peer,
                        ReqRespKind::RawTxList,
                        cx,
                        "raw txlist request rate-limited",
                    ) {
                        return;
                    }

                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::InboundRawTxListRequest { from: peer });
                    let hash = bytes32_to_b256(&request.raw_tx_list_hash);
                    if let Some(msg) = self.storage.get_txlist(&hash) {
                        let resp = GetRawTxListResponse {
                            raw_tx_list_hash: msg.raw_tx_list_hash.clone(),
                            txlist: msg.txlist.clone(),
                        };
                        let _ =
                            self.swarm.behaviour_mut().raw_txlists_rr.send_response(channel, resp);
                        metrics::counter!("p2p_reqresp_success", "kind" => "raw_txlists", "direction" => "inbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                    } else {
                        // Explicit not-found response with empty body; avoid positive/negative
                        // reputation impact.
                        let resp = GetRawTxListResponse {
                            raw_tx_list_hash: request.raw_tx_list_hash.clone(),
                            txlist: TxListBytes::default(),
                        };
                        let _ =
                            self.swarm.behaviour_mut().raw_txlists_rr.send_response(channel, resp);
                        metrics::counter!("p2p_reqresp_not_found", "kind" => "raw_txlists")
                            .increment(1);
                    }
                }
                rr::Message::Response { request_id, response } => {
                    if self.validator.validate_raw_txlist_response(&peer, &response).is_ok() {
                        let not_found = response.txlist.is_empty();
                        if not_found {
                            metrics::counter!("p2p_reqresp_not_found", "kind" => "raw_txlists", "direction" => "outbound").increment(1);
                        } else {
                            metrics::counter!("p2p_reqresp_success", "kind" => "raw_txlists", "direction" => "outbound").increment(1);
                            self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        }
                        if let Some(pending) =
                            self.take_pending_request(ReqRespKind::RawTxList, request_id)
                        {
                            let outcome = if not_found { "not_found" } else { "success" };
                            self.record_reqresp_rtt(
                                ReqRespKind::RawTxList,
                                outcome,
                                pending.started_at,
                            );
                            if let Some(ReqRespResponder::RawTxList(tx)) = pending.responder {
                                let _ = tx.send(Ok(response.clone()));
                            }
                        }
                        let _ = self
                            .events_tx
                            .try_send(NetworkEvent::ReqRespRawTxList { from: peer, msg: response });
                    } else {
                        self.handle_outbound_validation_error(
                            ReqRespKind::RawTxList,
                            peer,
                            request_id,
                            "invalid raw txlist response",
                        );
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, request_id, .. } => {
                self.handle_outbound_failure(ReqRespKind::RawTxList, peer, error, request_id);
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                self.handle_inbound_failure(ReqRespKind::RawTxList, peer, error);
            }
            rr::Event::ResponseSent { .. } => {}
        }
    }

    /// Handles `request_response::Event`s for preconfirmation head requests.
    pub(super) fn handle_head_rr_event(
        &mut self,
        ev: rr::Event<GetHeadRequest, PreconfHead>,
        cx: &mut Context<'_>,
    ) {
        match ev {
            rr::Event::Message { peer, message, .. } => match message {
                rr::Message::Request { channel, .. } => {
                    if !self.allow_inbound_request(
                        &peer,
                        ReqRespKind::Head,
                        cx,
                        "head request rate-limited",
                    ) {
                        return;
                    }
                    let _ =
                        self.events_tx.try_send(NetworkEvent::InboundHeadRequest { from: peer });
                    let _ = self
                        .swarm
                        .behaviour_mut()
                        .head_rr
                        .send_response(channel, self.head.clone());
                    metrics::counter!("p2p_reqresp_success", "kind" => "head", "direction" => "inbound").increment(1);
                    self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                }
                rr::Message::Response { request_id, response } => {
                    if self.validator.validate_head_response(&peer, &response).is_ok() {
                        metrics::counter!("p2p_reqresp_success", "kind" => "head", "direction" => "outbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        if let Some(pending) =
                            self.take_pending_request(ReqRespKind::Head, request_id)
                        {
                            self.record_reqresp_rtt(
                                ReqRespKind::Head,
                                "success",
                                pending.started_at,
                            );
                            if let Some(ReqRespResponder::Head(tx)) = pending.responder {
                                let _ = tx.send(Ok(response.clone()));
                            }
                        }
                        let _ = self
                            .events_tx
                            .try_send(NetworkEvent::ReqRespHead { from: peer, head: response });
                    } else {
                        self.handle_outbound_validation_error(
                            ReqRespKind::Head,
                            peer,
                            request_id,
                            "invalid head response",
                        );
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, request_id, .. } => {
                self.handle_outbound_failure(ReqRespKind::Head, peer, error, request_id);
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                self.handle_inbound_failure(ReqRespKind::Head, peer, error);
            }
            rr::Event::ResponseSent { .. } => {}
        }
    }

    /// Chooses a peer to send a request to.
    pub(super) fn choose_peer(&mut self, preferred: Option<PeerId>) -> Option<PeerId> {
        if preferred.is_some() {
            return preferred;
        }
        self.swarm.connected_peers().find(|p| !self.reputation.is_banned(p)).cloned()
    }
}
