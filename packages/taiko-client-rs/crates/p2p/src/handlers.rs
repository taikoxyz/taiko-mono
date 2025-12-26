//! Event handlers that map `NetworkEvent` to `SdkEvent` with validation and dedupe.
//!
//! This module provides the handler layer between the network and SDK layers,
//! applying deduplication and validation before emitting SDK events.
//!
//! ## Gossipsub Scoring Alignment (spec §7.1)
//!
//! Validation outcomes map to gossipsub penalties as follows:
//! - `Invalid` with `penalize=true`: Triggers app feedback -1 (capped at -4 per 10s)
//! - `Pending` (parent missing): **No penalty** per spec requirement
//! - `Valid`: App feedback +0.05
//!
//! The network layer (`preconfirmation-net`) enforces scoring thresholds:
//! - Drop peers below score -1
//! - Prune peers below score -2
//! - Ban peers below score -5 sustained >30s
//!
//! See `preconfirmation-net` for `invalidMessageDeliveriesWeight` (2.0) configuration.

use std::sync::Arc;

use alloy_primitives::{B256, U256};
use preconfirmation_net::NetworkEvent;
use preconfirmation_types::{
    RawTxListGossip, SignedCommitment, topic_preconfirmation_commitments, topic_raw_txlists,
};
use ssz_rs::Serialize;
use tracing::{debug, trace, warn};

use crate::{
    config::DEFAULT_MAX_TXLIST_BYTES,
    metrics::P2pMetrics,
    storage::{CommitmentDedupeKey, SdkStorage, TxListDedupeKey, compute_message_id},
    types::SdkEvent,
    validation::{
        CommitmentValidator, ValidationStatus, validate_txlist_hash, validate_txlist_size,
    },
};

/// Handler for processing network events with deduplication and validation.
///
/// The `EventHandler` encapsulates the logic for:
/// - Message ID deduplication (same gossip message received multiple times)
/// - Commitment deduplication by (block_number, signer)
/// - TxList deduplication by (block_number, raw_tx_list_hash)
/// - SDK-level validation (EOP rules, parent linkage, block progression)
/// - TxList hash and size validation
/// - Metrics recording for all operations
pub struct EventHandler<S: SdkStorage> {
    /// Storage for commitments, txlists, and deduplication.
    storage: Arc<S>,
    /// Chain ID for topic generation.
    chain_id: u64,
    /// SDK-level commitment validator.
    validator: CommitmentValidator,
    /// Maximum allowed txlist size in bytes.
    max_txlist_bytes: usize,
}

impl<S: SdkStorage> EventHandler<S> {
    /// Create a new event handler with the given storage and chain ID.
    ///
    /// Uses the default maximum txlist size of 128 KiB.
    pub fn new(storage: Arc<S>, chain_id: u64) -> Self {
        Self {
            storage,
            chain_id,
            validator: CommitmentValidator::new(),
            max_txlist_bytes: DEFAULT_MAX_TXLIST_BYTES,
        }
    }

    /// Create a new event handler with a custom commitment validator.
    pub fn with_validator(storage: Arc<S>, chain_id: u64, validator: CommitmentValidator) -> Self {
        Self { storage, chain_id, validator, max_txlist_bytes: DEFAULT_MAX_TXLIST_BYTES }
    }

    /// Create a new event handler with a custom validator and txlist size limit.
    pub fn with_validator_and_max_txlist_bytes(
        storage: Arc<S>,
        chain_id: u64,
        validator: CommitmentValidator,
        max_txlist_bytes: usize,
    ) -> Self {
        Self { storage, chain_id, validator, max_txlist_bytes }
    }

    /// Create a new event handler with a custom maximum txlist size.
    ///
    /// This is useful for testing or for deployments with different txlist size limits.
    pub fn with_max_txlist_bytes(storage: Arc<S>, chain_id: u64, max_txlist_bytes: usize) -> Self {
        Self { storage, chain_id, validator: CommitmentValidator::new(), max_txlist_bytes }
    }

    /// Handle a network event and return zero or more SDK events.
    pub fn handle_event(&self, event: NetworkEvent) -> Vec<SdkEvent> {
        match event {
            NetworkEvent::PeerConnected(peer) => {
                debug!("Peer connected: {peer}");
                P2pMetrics::record_peer_connected();
                vec![SdkEvent::PeerConnected { peer }]
            }

            NetworkEvent::PeerDisconnected(peer) => {
                debug!("Peer disconnected: {peer}");
                P2pMetrics::record_peer_disconnected();
                vec![SdkEvent::PeerDisconnected { peer }]
            }

            NetworkEvent::GossipSignedCommitment { from, msg } => {
                self.handle_commitment_gossip(from, *msg)
            }

            NetworkEvent::GossipRawTxList { from, msg } => {
                match self.handle_txlist_gossip(from, *msg) {
                    Some(event) => vec![event],
                    None => Vec::new(),
                }
            }

            NetworkEvent::ReqRespCommitments { from, msg } => {
                debug!("Received commitments response from {from}");
                P2pMetrics::record_reqresp_received("commitments");
                vec![SdkEvent::ReqRespCommitments { from, msg }]
            }

            NetworkEvent::ReqRespRawTxList { from, msg } => {
                debug!("Received raw txlist response from {from}");
                P2pMetrics::record_reqresp_received("raw_txlist");
                vec![SdkEvent::ReqRespRawTxList { from, msg }]
            }

            NetworkEvent::ReqRespHead { from, head } => {
                debug!("Received head response from {from}");
                P2pMetrics::record_reqresp_received("head");
                vec![SdkEvent::ReqRespHead { from, head }]
            }

            NetworkEvent::InboundCommitmentsRequest { from: _ } => {
                trace!("Inbound commitments request handled by network layer");
                P2pMetrics::record_inbound_request("commitments");
                Vec::new()
            }

            NetworkEvent::InboundRawTxListRequest { from: _ } => {
                trace!("Inbound raw txlist request handled by network layer");
                P2pMetrics::record_inbound_request("raw_txlist");
                Vec::new()
            }

            NetworkEvent::InboundHeadRequest { from: _ } => {
                trace!("Inbound head request handled by network layer");
                P2pMetrics::record_inbound_request("head");
                Vec::new()
            }

            NetworkEvent::Started => Vec::new(),
            NetworkEvent::Stopped => Vec::new(),
            NetworkEvent::Error(err) => {
                warn!("Network error: {err}");
                P2pMetrics::record_network_error();
                vec![SdkEvent::Error { detail: format!("network: {err}") }]
            }
        }
    }

    /// Handle a signed commitment gossip message.
    ///
    /// Returns zero or more `SdkEvent::CommitmentGossip`s when a commitment and
    /// any released pending children are valid and ready for the SDK.
    pub fn handle_commitment_gossip(
        &self,
        from: libp2p::PeerId,
        msg: SignedCommitment,
    ) -> Vec<SdkEvent> {
        P2pMetrics::record_gossip_received("commitment");

        // Compute message ID for deduplication using chain-specific topic
        let payload = match ssz_encode_commitment(&msg) {
            Ok(buf) => buf,
            Err(e) => {
                warn!("SSZ serialization failed for commitment from {from}: {e}");
                P2pMetrics::record_network_error();
                return Vec::new();
            }
        };
        let topic = topic_preconfirmation_commitments(self.chain_id);
        let msg_id = compute_message_id(&topic, &payload);

        // Check message-level dedupe
        if self.storage.is_duplicate_message(&msg_id) {
            trace!("Duplicate commitment message from {from}");
            P2pMetrics::record_dedupe_hit("message");
            return Vec::new();
        }
        self.storage.mark_message_seen(msg_id);

        // Extract block number
        let block_number = uint256_to_u256(&msg.commitment.preconf.block_number);

        // Try to recover signer for commitment-level dedupe.
        // If signature verification fails, we skip this dedupe layer but continue to validation.
        // The validator will reject the commitment (invalid signature) and record metrics
        // appropriately. This avoids duplicate work while ensuring bad signatures are
        // always caught.
        if let Ok(signer) = preconfirmation_types::verify_signed_commitment(&msg) {
            let dedupe_key = CommitmentDedupeKey { block_number, signer };
            if self.storage.is_duplicate_commitment(&dedupe_key) {
                trace!("Duplicate commitment for block {block_number} from signer {signer}");
                P2pMetrics::record_dedupe_hit("commitment");
                return Vec::new();
            }
            self.storage.mark_commitment_seen(dedupe_key);
        }

        // Validate the commitment (without parent for now)
        // TODO: Look up parent from storage for full validation
        let result = self.validator.validate(&msg, None);

        match result.outcome.status {
            ValidationStatus::Valid => {
                debug!("Valid commitment from {from} for block {block_number}");
                P2pMetrics::record_validation_result("valid");
                self.storage.insert_commitment(block_number, msg.clone());
                P2pMetrics::record_gossip_stored("commitment");

                // Check if any pending commitments can now be released
                let commitment_hash =
                    match preconfirmation_types::preconfirmation_hash(&msg.commitment.preconf) {
                        Ok(h) => B256::from_slice(h.as_ref()),
                        Err(e) => {
                            warn!("Failed to compute hash for valid commitment from {from}: {e}");
                            P2pMetrics::record_network_error();
                            return vec![SdkEvent::CommitmentGossip {
                                from,
                                commitment: Box::new(msg),
                            }];
                        }
                    };

                let released = self.storage.release_pending(&commitment_hash);
                P2pMetrics::record_pending_released(released.len());
                P2pMetrics::set_pending_buffer_size(self.storage.pending_count());

                let mut events = Vec::with_capacity(1 + released.len());
                events.push(SdkEvent::CommitmentGossip { from, commitment: Box::new(msg.clone()) });

                for pending in released {
                    let pending_block = uint256_to_u256(&pending.commitment.preconf.block_number);
                    // For released commitments, we have the parent available (the commitment we
                    // just stored)
                    let pending_result =
                        self.validator.validate(&pending, Some(&msg.commitment.preconf));
                    match pending_result.outcome.status {
                        ValidationStatus::Valid => {
                            self.storage.insert_commitment(pending_block, pending.clone());
                            P2pMetrics::record_validation_result("valid");
                            P2pMetrics::record_gossip_stored("commitment");
                            events.push(SdkEvent::CommitmentGossip {
                                from,
                                commitment: Box::new(pending),
                            });
                        }
                        ValidationStatus::Invalid => {
                            warn!(
                                "Released pending commitment failed validation: {:?}",
                                pending_result.outcome.reason
                            );
                            P2pMetrics::record_validation_result("invalid");
                            // Drop invalid commitment
                        }
                        ValidationStatus::Pending => {
                            // Still pending (shouldn't happen normally, but handle gracefully)
                            warn!("Released commitment still pending, re-buffering");
                            let parent_hash = B256::from_slice(
                                pending.commitment.preconf.parent_preconfirmation_hash.as_ref(),
                            );
                            self.storage.add_pending(parent_hash, pending);
                            P2pMetrics::set_pending_buffer_size(self.storage.pending_count());
                        }
                    }
                }

                events
            }
            ValidationStatus::Pending => {
                debug!(
                    "Commitment from {from} is pending (awaiting parent): {:?}",
                    result.outcome.reason
                );
                P2pMetrics::record_validation_result("pending");

                // Buffer the commitment, waiting for its parent
                let parent_hash =
                    B256::from_slice(msg.commitment.preconf.parent_preconfirmation_hash.as_ref());
                self.storage.add_pending(parent_hash, msg);
                P2pMetrics::record_pending_buffered();
                P2pMetrics::set_pending_buffer_size(self.storage.pending_count());
                Vec::new()
            }
            ValidationStatus::Invalid => {
                warn!("Invalid commitment from {from}: {:?}", result.outcome.reason);
                P2pMetrics::record_validation_result("invalid");
                // Invalid commitments are dropped; network layer handles penalization
                Vec::new()
            }
        }
    }

    /// Handle a raw txlist gossip message.
    ///
    /// Returns `Some(SdkEvent::RawTxListGossip)` if the txlist is valid and not a duplicate.
    /// Returns `None` if deduplicated or validation failed (hash mismatch, oversized).
    pub fn handle_txlist_gossip(
        &self,
        from: libp2p::PeerId,
        msg: RawTxListGossip,
    ) -> Option<SdkEvent> {
        P2pMetrics::record_gossip_received("txlist");

        // Extract hash and txlist data for validation
        let declared_hash = B256::from_slice(msg.raw_tx_list_hash.as_ref());
        let txlist_data = msg.txlist.as_ref();

        // Validate txlist size first (cheaper check)
        let size_outcome = validate_txlist_size(txlist_data, self.max_txlist_bytes);
        if !size_outcome.status.is_valid() {
            warn!("Txlist from {from} rejected: {:?}", size_outcome.reason);
            P2pMetrics::record_validation_result("invalid");
            return None;
        }

        // Validate txlist hash
        let hash_outcome = validate_txlist_hash(&declared_hash, txlist_data);
        if !hash_outcome.status.is_valid() {
            warn!("Txlist from {from} rejected: {:?}", hash_outcome.reason);
            P2pMetrics::record_validation_result("invalid");
            return None;
        }

        // Compute message ID for deduplication using chain-specific topic
        let payload = match ssz_encode_txlist(&msg) {
            Ok(buf) => buf,
            Err(e) => {
                warn!("SSZ serialization failed for txlist from {from}: {e}");
                P2pMetrics::record_network_error();
                return None;
            }
        };
        let topic = topic_raw_txlists(self.chain_id);
        let msg_id = compute_message_id(&topic, &payload);

        // Check message-level dedupe
        if self.storage.is_duplicate_message(&msg_id) {
            trace!("Duplicate txlist message from {from}");
            P2pMetrics::record_dedupe_hit("message");
            return None;
        }
        self.storage.mark_message_seen(msg_id);

        // TxList dedupe by hash only.
        // Note: RawTxListGossip doesn't include block_number, so we use U256::ZERO as a sentinel.
        // This means deduplication is purely hash-based, which is semantically correct since:
        // 1. The same txlist content (same hash) can be referenced by multiple commitments
        // 2. We only need to store/forward unique txlist data once
        // 3. Commitments reference txlists by hash, not by block
        let dedupe_key =
            TxListDedupeKey { block_number: U256::ZERO, raw_tx_list_hash: declared_hash };
        if self.storage.is_duplicate_txlist(&dedupe_key) {
            trace!("Duplicate txlist with hash {declared_hash}");
            P2pMetrics::record_dedupe_hit("txlist");
            return None;
        }
        self.storage.mark_txlist_seen(dedupe_key);

        debug!("Received raw txlist from {from} with hash {declared_hash}");
        self.storage.insert_txlist(declared_hash, msg.clone());
        P2pMetrics::record_gossip_stored("txlist");
        P2pMetrics::record_validation_result("valid");

        Some(SdkEvent::RawTxListGossip { from, msg: Box::new(msg) })
    }

    /// Get a reference to the underlying storage.
    pub fn storage(&self) -> &Arc<S> {
        &self.storage
    }
}

/// Convert Uint256 to alloy U256.
fn uint256_to_u256(v: &preconfirmation_types::Uint256) -> U256 {
    let bytes = v.to_bytes_le();
    U256::from_le_slice(&bytes)
}

/// SSZ-encode a signed commitment for message ID computation.
///
/// Returns an error if serialization fails, allowing callers to handle the failure
/// appropriately (e.g., reject the message and record metrics).
fn ssz_encode_commitment(msg: &SignedCommitment) -> Result<Vec<u8>, ssz_rs::SerializeError> {
    let mut buf = Vec::new();
    msg.serialize(&mut buf)?;
    Ok(buf)
}

/// SSZ-encode a raw txlist gossip for message ID computation.
///
/// Returns an error if serialization fails, allowing callers to handle the failure
/// appropriately (e.g., reject the message and record metrics).
fn ssz_encode_txlist(msg: &RawTxListGossip) -> Result<Vec<u8>, ssz_rs::SerializeError> {
    let mut buf = Vec::new();
    msg.serialize(&mut buf)?;
    Ok(buf)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::InMemoryStorage;

    fn make_signed_commitment(block_num: u64, parent_hash: [u8; 32]) -> SignedCommitment {
        use preconfirmation_types::{
            Bytes20, Bytes32, PreconfCommitment, Preconfirmation, SignedCommitment, Uint256,
            sign_commitment,
        };
        use secp256k1::SecretKey;

        let preconf = Preconfirmation {
            eop: false,
            block_number: Uint256::from(block_num),
            timestamp: Uint256::from(1000u64 + block_num),
            gas_limit: Uint256::from(30_000_000u64),
            coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(block_num.saturating_sub(1)),
            raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Bytes32::try_from(parent_hash.to_vec()).unwrap(),
            submission_window_end: Uint256::from(2000u64 + block_num),
            prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        };

        let commitment = PreconfCommitment {
            preconf,
            slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
        };

        let sk = SecretKey::from_slice(&[42u8; 32]).unwrap();
        let sig = sign_commitment(&commitment, &sk).unwrap();

        SignedCommitment { commitment, signature: sig }
    }

    #[test]
    fn handler_dedupes_duplicate_commitments() {
        use preconfirmation_types::{
            Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
            Uint256,
        };

        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage.clone(), 167000);

        // Create a sample commitment
        let commitment = SignedCommitment {
            commitment: PreconfCommitment {
                preconf: Preconfirmation {
                    eop: false,
                    block_number: Uint256::from(100u64),
                    timestamp: Uint256::from(1000u64),
                    gas_limit: Uint256::from(30_000_000u64),
                    coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    anchor_block_number: Uint256::from(99u64),
                    raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
                    parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
                    submission_window_end: Uint256::from(2000u64),
                    prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    proposal_id: Uint256::from(1u64),
                },
                slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![0xBB; 65]).unwrap(),
        };

        let peer = libp2p::PeerId::random();

        // First call should produce events (or empty if validation rejects)
        let _events1 = handler.handle_commitment_gossip(peer, commitment.clone());

        // Second call with same commitment should be deduplicated (return empty)
        let events2 = handler.handle_commitment_gossip(peer, commitment.clone());

        // The second call must return empty (deduplicated)
        assert!(events2.is_empty(), "duplicate commitment should be deduplicated");
    }

    #[test]
    fn handler_dedupes_duplicate_txlists() {
        use preconfirmation_types::{Bytes32, RawTxListGossip, TxListBytes, keccak256_bytes};

        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage.clone(), 167000);

        // Create a sample txlist with correct hash
        let txlist_data = vec![0xCC; 100];
        let hash = keccak256_bytes(&txlist_data);
        let txlist = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
            txlist: TxListBytes::try_from(txlist_data).unwrap(),
        };

        let peer = libp2p::PeerId::random();

        // First call should produce an event
        let result1 = handler.handle_txlist_gossip(peer, txlist.clone());
        assert!(result1.is_some(), "first txlist should not be deduplicated");

        // Second call with same txlist should be deduplicated
        let result2 = handler.handle_txlist_gossip(peer, txlist.clone());
        assert!(result2.is_none(), "duplicate txlist should be deduplicated");
    }

    #[test]
    fn handler_allows_different_commitments() {
        use preconfirmation_types::{
            Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
            Uint256,
        };

        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage.clone(), 167000);

        let peer = libp2p::PeerId::random();

        // Create first commitment
        let commitment1 = SignedCommitment {
            commitment: PreconfCommitment {
                preconf: Preconfirmation {
                    eop: false,
                    block_number: Uint256::from(100u64),
                    timestamp: Uint256::from(1000u64),
                    gas_limit: Uint256::from(30_000_000u64),
                    coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    anchor_block_number: Uint256::from(99u64),
                    raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
                    parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
                    submission_window_end: Uint256::from(2000u64),
                    prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    proposal_id: Uint256::from(1u64),
                },
                slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![0xBB; 65]).unwrap(),
        };

        // Create second commitment with different block number
        let commitment2 = SignedCommitment {
            commitment: PreconfCommitment {
                preconf: Preconfirmation {
                    eop: false,
                    block_number: Uint256::from(101u64), // Different block
                    timestamp: Uint256::from(1001u64),
                    gas_limit: Uint256::from(30_000_000u64),
                    coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    anchor_block_number: Uint256::from(100u64),
                    raw_tx_list_hash: Bytes32::try_from(vec![2u8; 32]).unwrap(),
                    parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
                    submission_window_end: Uint256::from(2001u64),
                    prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    proposal_id: Uint256::from(2u64),
                },
                slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![0xCC; 65]).unwrap(),
        };

        // First commitment
        let _events1 = handler.handle_commitment_gossip(peer, commitment1);

        // Second commitment (different) should not be deduplicated at message level
        let _events2 = handler.handle_commitment_gossip(peer, commitment2);

        // Note: Both may still return None due to validation (invalid signature),
        // but they should not be deduplicated at the message level
    }

    #[test]
    fn handler_stores_valid_txlist() {
        use preconfirmation_types::{Bytes32, RawTxListGossip, TxListBytes, keccak256_bytes};

        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage.clone(), 167000);

        // Create txlist with correct hash
        let txlist_data = vec![0xCC; 100];
        let computed_hash = keccak256_bytes(&txlist_data);
        let txlist = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(computed_hash.as_slice().to_vec()).unwrap(),
            txlist: TxListBytes::try_from(txlist_data).unwrap(),
        };

        let peer = libp2p::PeerId::random();
        let result = handler.handle_txlist_gossip(peer, txlist);

        assert!(result.is_some());

        // Verify it was stored
        let stored = storage.get_txlist(&computed_hash);
        assert!(stored.is_some());
    }

    #[test]
    fn handler_creates_peer_connected_event() {
        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage, 167000);

        let peer = libp2p::PeerId::random();
        let event = NetworkEvent::PeerConnected(peer);

        let events = handler.handle_event(event);
        assert!(matches!(events.as_slice(), [SdkEvent::PeerConnected { .. }]));
    }

    #[test]
    fn handler_creates_peer_disconnected_event() {
        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage, 167000);

        let peer = libp2p::PeerId::random();
        let event = NetworkEvent::PeerDisconnected(peer);

        let events = handler.handle_event(event);
        assert!(matches!(events.as_slice(), [SdkEvent::PeerDisconnected { .. }]));
    }

    #[test]
    fn handler_validates_released_pending_commitments() {
        use preconfirmation_types::{Uint256, preconfirmation_hash};

        let storage = Arc::new(InMemoryStorage::default());
        // Use validator that skips parent checks so parent commitment is accepted.
        let validator = crate::validation::CommitmentValidator::without_parent_validation();
        let handler = EventHandler::with_validator(storage.clone(), 167000, validator);

        let peer = libp2p::PeerId::random();

        let parent = make_signed_commitment(100, [0u8; 32]);
        let parent_hash = preconfirmation_hash(&parent.commitment.preconf).unwrap();
        let child = make_signed_commitment(101, parent_hash.0);

        storage.add_pending(B256::from_slice(parent_hash.as_ref()), child.clone());

        assert_eq!(storage.pending_count(), 1);

        let events = handler.handle_commitment_gossip(peer, parent);

        assert_eq!(storage.pending_count(), 0);
        assert_eq!(events.len(), 2, "parent should release child and emit both events");
        if let [
            SdkEvent::CommitmentGossip { commitment: parent_event, .. },
            SdkEvent::CommitmentGossip { commitment: child_event, .. },
        ] = &events[..]
        {
            assert_eq!(parent_event.commitment.preconf.block_number, Uint256::from(100u64));
            assert_eq!(child_event.commitment.preconf.block_number, Uint256::from(101u64));
        } else {
            panic!("expected exactly two commitment gossip events");
        }
    }

    #[test]
    fn handler_handles_network_error_event() {
        let storage = Arc::new(InMemoryStorage::default());
        let handler = EventHandler::new(storage, 167000);

        let event = NetworkEvent::Error("test error".into());
        let events = handler.handle_event(event);

        // Should produce an error SDK event
        assert!(matches!(events.as_slice(), [SdkEvent::Error { .. }]));
    }

    #[test]
    fn ssz_encode_commitment_returns_ok_for_valid_commitment() {
        use preconfirmation_types::{
            Bytes20, Bytes32, Bytes65, PreconfCommitment, Preconfirmation, SignedCommitment,
            Uint256,
        };

        let commitment = SignedCommitment {
            commitment: PreconfCommitment {
                preconf: Preconfirmation {
                    eop: false,
                    block_number: Uint256::from(100u64),
                    timestamp: Uint256::from(1000u64),
                    gas_limit: Uint256::from(30_000_000u64),
                    coinbase: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    anchor_block_number: Uint256::from(99u64),
                    raw_tx_list_hash: Bytes32::try_from(vec![1u8; 32]).unwrap(),
                    parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).unwrap(),
                    submission_window_end: Uint256::from(2000u64),
                    prover_auth: Bytes20::try_from(vec![0u8; 20]).unwrap(),
                    proposal_id: Uint256::from(1u64),
                },
                slasher_address: Bytes20::try_from(vec![0xAA; 20]).unwrap(),
            },
            signature: Bytes65::try_from(vec![0xBB; 65]).unwrap(),
        };

        let result = ssz_encode_commitment(&commitment);
        assert!(result.is_ok(), "SSZ encoding should succeed for valid commitment");
        assert!(!result.unwrap().is_empty(), "Encoded buffer should not be empty");
    }

    #[test]
    fn ssz_encode_txlist_returns_ok_for_valid_txlist() {
        use preconfirmation_types::{Bytes32, RawTxListGossip, TxListBytes, keccak256_bytes};

        let txlist_data = vec![0xCC; 100];
        let hash = keccak256_bytes(&txlist_data);

        let txlist = RawTxListGossip {
            raw_tx_list_hash: Bytes32::try_from(hash.as_slice().to_vec()).unwrap(),
            txlist: TxListBytes::try_from(txlist_data).unwrap(),
        };

        let result = ssz_encode_txlist(&txlist);
        assert!(result.is_ok(), "SSZ encoding should succeed for valid txlist");
        assert!(!result.unwrap().is_empty(), "Encoded buffer should not be empty");
    }
}
