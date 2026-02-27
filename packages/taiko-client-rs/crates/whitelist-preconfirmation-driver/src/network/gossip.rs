//! Gossipsub construction and message-id helpers.

use libp2p::gossipsub;
use sha2::{Digest, Sha256};

use super::event_loop::to_p2p_err;
use crate::error::Result;

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
        .map_err(to_p2p_err)?;

    gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Anonymous, config).map_err(to_p2p_err)
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
