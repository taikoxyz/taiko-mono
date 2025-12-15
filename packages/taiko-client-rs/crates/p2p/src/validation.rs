//! Validation layer for preconfirmation gossip and req/resp payloads.
//!
//! This module provides sidecar-friendly validation routines that wrap the
//! lower-level `preconfirmation_types` helpers and add lookahead schedule checks,
//! parent linkage verification, and size/hash limits. Each validator returns a
//! rich [`ValidationOutcome`] so callers can map results into scoring, metrics,
//! and backpressure policies without guessing intent.

use std::{
    sync::Arc,
    time::{Duration, SystemTime},
};

use libp2p::PeerId;
use preconfirmation_service::LookaheadResolver;
use preconfirmation_types::{
    Bytes20, Bytes32, MAX_TXLIST_BYTES, Preconfirmation, RawTxListGossip, SignedCommitment,
    Uint256, keccak256_bytes, preconfirmation_hash, validate_preconfirmation_basic,
};

use crate::metrics::{record_gossip, record_validation};

/// Result of validating a network payload.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ValidationOutcome {
    /// Message is valid and should be propagated/processed.
    Accept,
    /// Parent is unknown locally; caller may cache and retry when parent arrives.
    PendingParent {
        /// Expected parent preconfirmation hash.
        parent_hash: Bytes32,
    },
    /// Message is dropped without penalizing the peer (e.g., missing context).
    SoftReject {
        /// Machine-readable reason label.
        reason: &'static str,
        /// Optional human-friendly detail for logging.
        detail: Option<String>,
    },
    /// Message is invalid and should be counted against the peer.
    RejectPeer {
        /// Machine-readable reason label.
        reason: &'static str,
        /// Optional human-friendly detail for logging.
        detail: Option<String>,
    },
    /// Message originated from self; ignore silently.
    IgnoreSelf,
}

/// Context required to validate commitments and txlists.
#[derive(Clone)]
pub struct ValidationContext {
    /// Optional self peer ID; if provided, self-originating gossip is ignored.
    pub self_peer: Option<PeerId>,
    /// Optional expected slasher address; mismatch triggers rejection.
    pub expected_slasher: Option<Bytes20>,
    /// Optional lookahead resolver for slot/signature checks.
    pub lookahead: Option<Arc<dyn LookaheadResolver>>,
    /// Allowed drift when comparing submission window end vs lookahead schedule.
    pub executor_slot_grace: Duration,
    /// Maximum raw txlist payload size (compressed bytes).
    pub max_txlist_bytes: usize,
    /// Maximum total gossip payload size (outer bytes); set to same as txlist for now.
    pub max_gossip_bytes: usize,
    /// Optional parent preconfirmation to validate parent hash linkage.
    pub parent_preconfirmation: Option<Preconfirmation>,
    /// Clock source used for staleness checks; injectable for tests.
    pub now: fn() -> SystemTime,
    /// When true, lookahead failures are treated as soft rejects instead of hard rejects.
    pub soft_fail_lookahead: bool,
}

impl Default for ValidationContext {
    /// Provide conservative defaults suitable for sidecar validation.
    fn default() -> Self {
        Self {
            self_peer: None,
            expected_slasher: None,
            lookahead: None,
            executor_slot_grace: Duration::from_secs(1),
            max_txlist_bytes: MAX_TXLIST_BYTES,
            max_gossip_bytes: MAX_TXLIST_BYTES,
            parent_preconfirmation: None,
            now: SystemTime::now,
            soft_fail_lookahead: true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use libp2p::PeerId;
    use preconfirmation_types::{RawTxListGossip, SignedCommitment};

    /// Self-originated commitments should be ignored.
    #[tokio::test]
    async fn validation_ignores_self_commitment() {
        let peer = PeerId::random();
        let mut ctx = ValidationContext::default();
        ctx.self_peer = Some(peer);
        let msg = SignedCommitment::default();
        let outcome = validate_signed_commitment(&peer, &msg, &ctx).await;
        assert!(matches!(outcome, ValidationOutcome::IgnoreSelf));
    }

    /// Bad signatures are rejected with the expected reason.
    #[tokio::test]
    async fn validation_rejects_bad_signature() {
        let peer = PeerId::random();
        let ctx = ValidationContext::default();
        let msg = SignedCommitment::default();
        let outcome = validate_signed_commitment(&peer, &msg, &ctx).await;
        match outcome {
            ValidationOutcome::RejectPeer { reason, .. } => assert_eq!(reason, "bad_signature"),
            other => panic!("unexpected outcome: {:?}", other),
        }
    }

    /// Empty raw txlists are rejected by the validator.
    #[tokio::test]
    async fn validation_rejects_empty_txlist() {
        let peer = PeerId::random();
        let ctx = ValidationContext::default();
        let msg = RawTxListGossip::default();
        let outcome = validate_raw_txlist(&peer, &msg, &ctx).await;
        match outcome {
            ValidationOutcome::RejectPeer { reason, .. } => assert_eq!(reason, "empty_txlist"),
            other => panic!("unexpected outcome: {:?}", other),
        }
    }
}

/// Validate an inbound SignedCommitment gossip message according to the
/// permissionless preconfirmation spec (sections 4–6, 10).
pub async fn validate_signed_commitment(
    from: &PeerId,
    msg: &SignedCommitment,
    ctx: &ValidationContext,
) -> ValidationOutcome {
    // Ignore self-originating gossip.
    if let Some(self_peer) = ctx.self_peer &&
        &self_peer == from
    {
        let outcome = ValidationOutcome::IgnoreSelf;
        record_validation(&outcome);
        record_gossip("inbound", "commitment", "ignored", 0);
        return outcome;
    }

    // Basic signature + body invariants (SSZ, eop rules, txlist hash zeroing) via types helper.
    let recovered = match preconfirmation_types::verify_signed_commitment(msg) {
        Ok(addr) => addr,
        Err(err) => {
            return ValidationOutcome::RejectPeer {
                reason: "bad_signature",
                detail: Some(err.to_string()),
            }
        }
    };

    if let Err(err) = validate_preconfirmation_basic(&msg.commitment.preconf) {
        return ValidationOutcome::RejectPeer {
            reason: "preconf_basic",
            detail: Some(err.to_string()),
        };
    }

    // Slasher address check when provided.
    if let Some(expected) = &ctx.expected_slasher &&
        &msg.commitment.slasher_address != expected
    {
        return ValidationOutcome::RejectPeer { reason: "slasher_mismatch", detail: None };
    }

    // Parent linkage: enforce when parent is known; otherwise mark pending to allow buffering.
    if let Some(parent) = &ctx.parent_preconfirmation {
        match preconfirmation_hash(parent) {
            Ok(expected_hash) => {
                if expected_hash.as_slice() !=
                    msg.commitment.preconf.parent_preconfirmation_hash.as_ref()
                {
                    return ValidationOutcome::RejectPeer {
                        reason: "parent_hash_mismatch",
                        detail: None,
                    };
                }
            }
            Err(err) => {
                return ValidationOutcome::RejectPeer {
                    reason: "parent_hash_error",
                    detail: Some(err.to_string()),
                };
            }
        }
    } else if !msg.commitment.preconf.parent_preconfirmation_hash.as_ref().iter().all(|b| *b == 0) {
        return ValidationOutcome::PendingParent {
            parent_hash: msg.commitment.preconf.parent_preconfirmation_hash.clone(),
        };
    }

    // Lookahead: enforce slot signer and expected window end if provided.
    if let Some(resolver) = &ctx.lookahead {
        match resolver.signer_for_timestamp(&msg.commitment.preconf.submission_window_end) {
            Ok(expected) => {
                if expected != recovered {
                    return ValidationOutcome::RejectPeer {
                        reason: "wrong_slot_signer",
                        detail: None,
                    };
                }
            }
            Err(err) => {
                return if ctx.soft_fail_lookahead {
                    ValidationOutcome::SoftReject {
                        reason: "lookahead_error",
                        detail: Some(err.to_string()),
                    }
                } else {
                    ValidationOutcome::RejectPeer {
                        reason: "lookahead_error",
                        detail: Some(err.to_string()),
                    }
                };
            }
        }

        if let Ok(expected_end) =
            resolver.expected_slot_end(&msg.commitment.preconf.submission_window_end)
        {
            let actual = &msg.commitment.preconf.submission_window_end;
            if exceeds_grace(&expected_end, actual, ctx.executor_slot_grace) {
                return ValidationOutcome::RejectPeer { reason: "slot_drift", detail: None };
            }
        }
    }

    ValidationOutcome::Accept
}

/// Validate an inbound RawTxListGossip message (spec §3.4, §7).
pub async fn validate_raw_txlist(
    from: &PeerId,
    msg: &RawTxListGossip,
    ctx: &ValidationContext,
) -> ValidationOutcome {
    if let Some(self_peer) = ctx.self_peer &&
        &self_peer == from
    {
        return ValidationOutcome::IgnoreSelf;
    }

    // Size caps.
    let blob_len = msg.txlist.len();
    if blob_len == 0 {
        return ValidationOutcome::RejectPeer { reason: "empty_txlist", detail: None };
    }
    if blob_len > ctx.max_txlist_bytes {
        return ValidationOutcome::RejectPeer {
            reason: "txlist_too_large",
            detail: Some(format!("{} > {}", blob_len, ctx.max_txlist_bytes)),
        };
    }
    if blob_len > ctx.max_gossip_bytes {
        return ValidationOutcome::RejectPeer {
            reason: "gossip_too_large",
            detail: Some(format!("{} > {}", blob_len, ctx.max_gossip_bytes)),
        };
    }

    // Hash binding.
    let computed = keccak256_bytes(msg.txlist.as_ref());
    if computed.as_slice() != msg.raw_tx_list_hash.as_ref() {
        return ValidationOutcome::RejectPeer { reason: "txlist_hash_mismatch", detail: None };
    }

    // Zero hash guard: raw txlist gossip should never carry zero hash.
    if msg.raw_tx_list_hash.as_ref().iter().all(|b| *b == 0) {
        return ValidationOutcome::RejectPeer { reason: "zero_hash_txlist", detail: None };
    }

    ValidationOutcome::Accept
}

/// Summarize a validation outcome into (reason, penalize_peer) for metrics/scoring.
pub fn summarize_outcome(outcome: &ValidationOutcome) -> (&'static str, bool) {
    match outcome {
        ValidationOutcome::Accept => ("accept", false),
        ValidationOutcome::PendingParent { .. } => ("pending_parent", false),
        ValidationOutcome::SoftReject { reason, .. } => (reason, false),
        ValidationOutcome::RejectPeer { reason, .. } => (reason, true),
        ValidationOutcome::IgnoreSelf => ("ignore_self", false),
    }
}

/// Utility to check if two Uint256 values differ more than a duration in seconds.
/// Check if two timestamps differ beyond a provided grace window.
fn exceeds_grace(expected: &Uint256, actual: &Uint256, grace: Duration) -> bool {
    let grace_secs = grace.as_secs();
    if grace_secs == 0 {
        return expected != actual;
    }
    let grace_u128 = grace_secs as u128;
    match (u256_to_u128(expected), u256_to_u128(actual)) {
        (Some(e), Some(a)) => {
            if e > a {
                e - a > grace_u128
            } else {
                a - e > grace_u128
            }
        }
        _ => false,
    }
}

/// Convert a 256-bit SSZ integer into u128 if the upper bits are zero.
/// Convert Uint256 to u128 when upper bits are zero; otherwise return None.
fn u256_to_u128(value: &Uint256) -> Option<u128> {
    let bytes = value.to_bytes_le();
    if bytes[16..].iter().any(|b| *b != 0) {
        return None;
    }
    let mut buf = [0u8; 16];
    buf.copy_from_slice(&bytes[..16]);
    Some(u128::from_le_bytes(buf))
}
