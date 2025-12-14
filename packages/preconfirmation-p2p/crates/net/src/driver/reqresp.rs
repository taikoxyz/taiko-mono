use std::task::{Context, Poll};

use libp2p::request_response as rr;
use preconfirmation_types::{
    GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, GetHeadRequest,
    GetRawTxListRequest, GetRawTxListResponse, PreconfHead, TxListBytes, bytes32_to_b256,
    uint256_to_u256,
};

use super::*;

impl NetworkDriver {
    /// Record the start time of an outbound req/resp exchange for latency metrics.
    pub(super) fn push_outbound_start(&mut self, kind: ReqRespKind) {
        let now = tokio::time::Instant::now();
        match kind {
            ReqRespKind::Commitments => self.commitments_out.push_back(now),
            ReqRespKind::RawTxList => self.raw_txlists_out.push_back(now),
            ReqRespKind::Head => self.head_out.push_back(now),
        }
    }

    /// Pop the previously recorded start time (if any) for an outbound exchange.
    pub(super) fn pop_outbound_start(&mut self, kind: ReqRespKind) -> Option<tokio::time::Instant> {
        match kind {
            ReqRespKind::Commitments => self.commitments_out.pop_front(),
            ReqRespKind::RawTxList => self.raw_txlists_out.pop_front(),
            ReqRespKind::Head => self.head_out.pop_front(),
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
        let proto = match kind {
            ReqRespKind::Commitments => "commitments",
            ReqRespKind::RawTxList => "raw_txlists",
            ReqRespKind::Head => "head",
        };
        metrics::histogram!("p2p_reqresp_rtt_seconds", "protocol" => proto, "outcome" => outcome)
            .record(elapsed);
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
                    if self.reputation.is_banned(&peer) {
                        metrics::counter!("p2p_reqresp_dropped", "kind" => "commitments", "reason" => "banned").increment(1);
                        return;
                    }
                    match self.request_limiter.poll_allow(peer, ReqRespKind::Commitments, cx) {
                        Poll::Ready(true) => {}
                        _ => {
                            metrics::counter!("p2p_reqresp_rate_limited", "kind" => "commitments")
                                .increment(1);
                            self.emit_error(
                                NetworkErrorKind::ReqRespRateLimited,
                                "commitments request rate-limited",
                            );
                            self.apply_reputation(peer, PeerAction::Timeout);
                            return;
                        }
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
                    let correlation = self.commitments_req_ids.remove(&request_id);
                    if self.validator.validate_commitments_response(&peer, &response).is_ok() {
                        metrics::counter!("p2p_reqresp_success", "kind" => "commitments", "direction" => "outbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        if let Some(start) = self.pop_outbound_start(ReqRespKind::Commitments) {
                            self.record_reqresp_rtt(ReqRespKind::Commitments, "success", start);
                        }
                        let _ = self.events_tx.try_send(NetworkEvent::ReqRespCommitments {
                            from: peer,
                            msg: response,
                            request_id: correlation,
                        });
                    } else {
                        metrics::counter!("p2p_reqresp_error", "kind" => "commitments", "reason" => "validation").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespError);
                        if let Some(start) = self.pop_outbound_start(ReqRespKind::Commitments) {
                            self.record_reqresp_rtt(ReqRespKind::Commitments, "error", start);
                        }
                        self.emit_error_with_request(
                            NetworkErrorKind::ReqRespValidation,
                            format!("invalid commitments response from {peer}"),
                            correlation,
                        );
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, request_id, .. } => {
                let correlation = self.commitments_req_ids.remove(&request_id);
                metrics::counter!("p2p_reqresp_error", "kind" => "commitments", "reason" => "outbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                if let Some(start) = self.pop_outbound_start(ReqRespKind::Commitments) {
                    let outcome = match error {
                        rr::OutboundFailure::Timeout => "timeout",
                        _ => "error",
                    };
                    self.record_reqresp_rtt(ReqRespKind::Commitments, outcome, start);
                }
                self.emit_error_with_request(
                    NetworkErrorKind::ReqRespFailure,
                    format!("req-resp commitments with {peer}: {error}"),
                    correlation,
                );
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "commitments", "reason" => "inbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                if let Some(start) = self.pop_outbound_start(ReqRespKind::Commitments) {
                    self.record_reqresp_rtt(ReqRespKind::Commitments, "error", start);
                }
                self.emit_error(
                    NetworkErrorKind::ReqRespFailure,
                    format!("req-resp commitments with {peer}: {error}"),
                );
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
                    if self.reputation.is_banned(&peer) {
                        metrics::counter!("p2p_reqresp_dropped", "kind" => "raw_txlists", "reason" => "banned").increment(1);
                        return;
                    }
                    match self.request_limiter.poll_allow(peer, ReqRespKind::RawTxList, cx) {
                        Poll::Ready(true) => {}
                        _ => {
                            metrics::counter!("p2p_reqresp_rate_limited", "kind" => "raw_txlists")
                                .increment(1);
                            self.emit_error(
                                NetworkErrorKind::ReqRespRateLimited,
                                "raw txlist request rate-limited",
                            );
                            self.apply_reputation(peer, PeerAction::Timeout);
                            return;
                        }
                    }

                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::InboundRawTxListRequest { from: peer });
                    let hash = bytes32_to_b256(&request.raw_tx_list_hash);
                    if let Some(msg) = self.storage.get_txlist(&hash) {
                        let resp = GetRawTxListResponse {
                            raw_tx_list_hash: msg.raw_tx_list_hash.clone(),
                            anchor_block_number: preconfirmation_types::Uint256::default(),
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
                            anchor_block_number: preconfirmation_types::Uint256::default(),
                            txlist: TxListBytes::default(),
                        };
                        let _ =
                            self.swarm.behaviour_mut().raw_txlists_rr.send_response(channel, resp);
                        metrics::counter!("p2p_reqresp_not_found", "kind" => "raw_txlists")
                            .increment(1);
                    }
                }
                rr::Message::Response { request_id, response } => {
                    let correlation = self.raw_txlists_req_ids.remove(&request_id);
                    if self.validator.validate_raw_txlist_response(&peer, &response).is_ok() {
                        let not_found = response.txlist.is_empty();
                        if let Some(start) = self.pop_outbound_start(ReqRespKind::RawTxList) {
                            let outcome = if not_found { "not_found" } else { "success" };
                            self.record_reqresp_rtt(ReqRespKind::RawTxList, outcome, start);
                        }
                        if not_found {
                            metrics::counter!("p2p_reqresp_not_found", "kind" => "raw_txlists", "direction" => "outbound").increment(1);
                        } else {
                            metrics::counter!("p2p_reqresp_success", "kind" => "raw_txlists", "direction" => "outbound").increment(1);
                            self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        }
                        let _ = self.events_tx.try_send(NetworkEvent::ReqRespRawTxList {
                            from: peer,
                            msg: response,
                            request_id: correlation,
                        });
                    } else {
                        metrics::counter!("p2p_reqresp_error", "kind" => "raw_txlists", "reason" => "validation").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespError);
                        if let Some(start) = self.pop_outbound_start(ReqRespKind::RawTxList) {
                            self.record_reqresp_rtt(ReqRespKind::RawTxList, "error", start);
                        }
                        self.emit_error_with_request(
                            NetworkErrorKind::ReqRespValidation,
                            format!("invalid raw txlist response from {peer}"),
                            correlation,
                        );
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, request_id, .. } => {
                let correlation = self.raw_txlists_req_ids.remove(&request_id);
                metrics::counter!("p2p_reqresp_error", "kind" => "raw_txlists", "reason" => "outbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                if let Some(start) = self.pop_outbound_start(ReqRespKind::RawTxList) {
                    let outcome = match error {
                        rr::OutboundFailure::Timeout => "timeout",
                        _ => "error",
                    };
                    self.record_reqresp_rtt(ReqRespKind::RawTxList, outcome, start);
                }
                self.emit_error_with_request(
                    NetworkErrorKind::ReqRespFailure,
                    format!("req-resp raw-txlist with {peer}: {error}"),
                    correlation,
                );
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "raw_txlists", "reason" => "inbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                if let Some(start) = self.pop_outbound_start(ReqRespKind::RawTxList) {
                    self.record_reqresp_rtt(ReqRespKind::RawTxList, "error", start);
                }
                self.emit_error(
                    NetworkErrorKind::ReqRespFailure,
                    format!("req-resp raw-txlist with {peer}: {error}"),
                );
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
                    if self.reputation.is_banned(&peer) {
                        metrics::counter!("p2p_reqresp_dropped", "kind" => "head", "reason" => "banned").increment(1);
                        return;
                    }
                    match self.request_limiter.poll_allow(peer, ReqRespKind::Head, cx) {
                        Poll::Ready(true) => {}
                        _ => {
                            metrics::counter!("p2p_reqresp_rate_limited", "kind" => "head")
                                .increment(1);
                            self.emit_error(
                                NetworkErrorKind::ReqRespRateLimited,
                                "head request rate-limited",
                            );
                            self.apply_reputation(peer, PeerAction::Timeout);
                            return;
                        }
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
                    let correlation = self.head_req_ids.remove(&request_id);
                    if self.validator.validate_head_response(&peer, &response).is_ok() {
                        metrics::counter!("p2p_reqresp_success", "kind" => "head", "direction" => "outbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        if let Some(start) = self.pop_outbound_start(ReqRespKind::Head) {
                            self.record_reqresp_rtt(ReqRespKind::Head, "success", start);
                        }
                        let _ = self.events_tx.try_send(NetworkEvent::ReqRespHead {
                            from: peer,
                            head: response,
                            request_id: correlation,
                        });
                    } else {
                        metrics::counter!("p2p_reqresp_error", "kind" => "head", "reason" => "validation").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespError);
                        if let Some(start) = self.pop_outbound_start(ReqRespKind::Head) {
                            self.record_reqresp_rtt(ReqRespKind::Head, "error", start);
                        }
                        self.emit_error_with_request(
                            NetworkErrorKind::ReqRespValidation,
                            format!("invalid head response from {peer}"),
                            correlation,
                        );
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, request_id, .. } => {
                let correlation = self.head_req_ids.remove(&request_id);
                metrics::counter!("p2p_reqresp_error", "kind" => "head", "reason" => "outbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                if let Some(start) = self.pop_outbound_start(ReqRespKind::Head) {
                    let outcome = match error {
                        rr::OutboundFailure::Timeout => "timeout",
                        _ => "error",
                    };
                    self.record_reqresp_rtt(ReqRespKind::Head, outcome, start);
                }
                self.emit_error_with_request(
                    NetworkErrorKind::ReqRespFailure,
                    format!("req-resp head with {peer}: {error}"),
                    correlation,
                );
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "head", "reason" => "inbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                if let Some(start) = self.pop_outbound_start(ReqRespKind::Head) {
                    self.record_reqresp_rtt(ReqRespKind::Head, "error", start);
                }
                self.emit_error(
                    NetworkErrorKind::ReqRespFailure,
                    format!("req-resp head with {peer}: {error}"),
                );
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
