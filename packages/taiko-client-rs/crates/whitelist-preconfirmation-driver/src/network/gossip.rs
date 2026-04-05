//! Gossipsub construction, message-id helpers, and deterministic response jitter.

use std::time::Duration;

use alloy_primitives::B256;
use libp2p::{PeerId, gossipsub};
use sha2::{Digest, Sha256};

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Maximum allowed gossip payload size after decompression.
const MAX_GOSSIP_SIZE_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;
/// Prefix used in message-id hashing for valid snappy payloads.
const MESSAGE_ID_PREFIX_VALID_SNAPPY: [u8; 4] = [1, 0, 0, 0];
/// Prefix used in message-id hashing for invalid snappy payloads.
const MESSAGE_ID_PREFIX_INVALID_SNAPPY: [u8; 4] = [0, 0, 0, 0];

/// Build the gossipsub behaviour.
pub(crate) fn build_gossipsub() -> Result<gossipsub::Behaviour> {
    let config = gossipsub::ConfigBuilder::default()
        .validation_mode(gossipsub::ValidationMode::Permissive)
        .heartbeat_interval(*kona_gossip::GOSSIP_HEARTBEAT)
        .duplicate_cache_time(*kona_gossip::SEEN_MESSAGES_TTL)
        .message_id_fn(message_id)
        .max_transmit_size(MAX_GOSSIP_SIZE_BYTES)
        .build()
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;

    gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Anonymous, config)
        .map_err(WhitelistPreconfirmationDriverError::p2p)
}

/// Compute gossipsub message IDs.
pub(crate) fn message_id(message: &gossipsub::Message) -> gossipsub::MessageId {
    let (valid_snappy, data) = try_decompress_snappy(&message.data);

    let topic = message.topic.as_str().as_bytes();
    let topic_len = (topic.len() as u64).to_le_bytes();

    let prefix = if valid_snappy {
        MESSAGE_ID_PREFIX_VALID_SNAPPY
    } else {
        MESSAGE_ID_PREFIX_INVALID_SNAPPY
    };

    let mut hasher = Sha256::new();
    hasher.update(prefix);
    hasher.update(topic_len);
    hasher.update(topic);
    hasher.update(&data);

    let hash = hasher.finalize();
    gossipsub::MessageId::from(hash[..20].to_vec())
}

/// Compute deterministic response jitter from the local peer ID and block hash.
pub(crate) fn deterministic_jitter(self_peer: PeerId, hash: B256, max: Duration) -> Duration {
    if max.is_zero() {
        return Duration::ZERO;
    }

    let mut hasher = Sha256::new();
    hasher.update(self_peer.to_bytes());
    hasher.update(hash.as_slice());

    let digest = hasher.finalize();
    let value = u64::from_le_bytes(digest[..8].try_into().expect("sha256 output is long enough"));
    Duration::from_nanos(value % max.as_nanos() as u64)
}

/// Try to decompress snappy data. Returns `(is_valid_snappy, data)`.
fn try_decompress_snappy(compressed: &[u8]) -> (bool, Vec<u8>) {
    let Ok(decoded_len) = snap::raw::decompress_len(compressed) else {
        return (false, compressed.to_vec());
    };

    if decoded_len > MAX_GOSSIP_SIZE_BYTES {
        return (false, compressed.to_vec());
    }

    snap::raw::Decoder::new()
        .decompress_vec(compressed)
        .map(|data| (true, data))
        .unwrap_or_else(|_| (false, compressed.to_vec()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_jitter_is_stable_and_bounded() {
        let peer = PeerId::random();
        let hash = B256::from([0x42u8; 32]);
        let max = Duration::from_secs(1);

        let first = deterministic_jitter(peer, hash, max);
        let second = deterministic_jitter(peer, hash, max);

        assert_eq!(first, second);
        assert!(first < max);
        assert_eq!(deterministic_jitter(peer, hash, Duration::ZERO), Duration::ZERO);
    }
}
