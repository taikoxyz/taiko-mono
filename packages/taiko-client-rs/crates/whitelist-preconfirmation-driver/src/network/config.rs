//! Gossipsub configuration and message-ID helpers.
//!
//! Uses [`kona_gossip::default_config_builder`] for gossipsub parameters (mesh sizes,
//! heartbeat, duplicate cache, etc.) and overrides only the `message_id_fn` with
//! Taiko's topic-inclusive message ID function for Go client interop.

use libp2p::gossipsub;
use sha2::{Digest, Sha256};

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Maximum allowed gossip payload size after decompression.
const MAX_GOSSIP_SIZE_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;

/// Domain prefix used in message-ID hashing when snappy decompression succeeds.
const MESSAGE_ID_PREFIX_VALID_SNAPPY: [u8; 4] = [1, 0, 0, 0];

/// Domain prefix used in message-ID hashing when snappy decompression fails.
const MESSAGE_ID_PREFIX_INVALID_SNAPPY: [u8; 4] = [0, 0, 0, 0];

/// Build the gossipsub behaviour using kona's default config with Taiko's message-ID function.
///
/// Kona's [`kona_gossip::default_config_builder`] sets mesh params (D=8, Dlo=6, Dhi=12,
/// Dlazy=6), heartbeat (500ms), fanout TTL (60s), history (length=12, gossip=3),
/// flood_publish=false, floodsub support, max_transmit_size (10 MiB), duplicate_cache_time
/// (120s), and `ValidationMode::None` with `validate_messages`.
///
/// We override ONLY `message_id_fn` because kona's `compute_message_id` omits the topic from
/// the hash. Taiko's Go client includes the topic, so we must match that for interop:
/// `SHA-256(domain(4B) + topicLen(8B LE) + topic + data)[:20]`.
pub(crate) fn build_gossipsub() -> Result<gossipsub::Behaviour> {
    let config = kona_gossip::default_config_builder()
        .message_id_fn(taiko_message_id)
        .build()
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;

    gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Anonymous, config)
        .map_err(WhitelistPreconfirmationDriverError::p2p)
}

/// Compute a gossipsub message ID that includes the topic in the hash.
///
/// Format: `SHA-256(domain(4B) + topicLen(8B LE) + topic + data)[:20]`
///
/// The domain prefix is `[1,0,0,0]` when snappy decompression succeeds or `[0,0,0,0]`
/// when it fails. This matches the Taiko Go client's message-ID computation.
pub(crate) fn taiko_message_id(message: &gossipsub::Message) -> gossipsub::MessageId {
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
///
/// If decoding fails or the decompressed length exceeds [`MAX_GOSSIP_SIZE_BYTES`],
/// the original compressed bytes are returned alongside `false`.
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

    /// Valid vs invalid snappy produces different message IDs.
    #[test]
    fn message_id_changes_with_snappy_validity() {
        let raw_data = vec![1u8, 2, 3, 4, 5];
        let compressed =
            snap::raw::Encoder::new().compress_vec(&raw_data).expect("snappy compress");

        let topic = libp2p::gossipsub::TopicHash::from_raw("test-topic");

        // Message with valid snappy payload.
        let valid_msg = gossipsub::Message {
            source: None,
            data: compressed,
            sequence_number: None,
            topic: topic.clone(),
        };

        // Message with invalid snappy payload (raw bytes that aren't valid snappy).
        let invalid_msg =
            gossipsub::Message { source: None, data: raw_data, sequence_number: None, topic };

        let id_valid = taiko_message_id(&valid_msg);
        let id_invalid = taiko_message_id(&invalid_msg);

        assert_ne!(
            id_valid, id_invalid,
            "valid and invalid snappy payloads must produce different message IDs"
        );
    }

    /// Same payload on different topics produces different message IDs.
    #[test]
    fn message_id_includes_topic_in_hash() {
        let data = vec![10u8, 20, 30];

        let msg_a = gossipsub::Message {
            source: None,
            data: data.clone(),
            sequence_number: None,
            topic: libp2p::gossipsub::TopicHash::from_raw("topic-alpha"),
        };

        let msg_b = gossipsub::Message {
            source: None,
            data,
            sequence_number: None,
            topic: libp2p::gossipsub::TopicHash::from_raw("topic-beta"),
        };

        let id_a = taiko_message_id(&msg_a);
        let id_b = taiko_message_id(&msg_b);

        assert_ne!(
            id_a, id_b,
            "identical payloads on different topics must produce different message IDs"
        );
    }

    /// Gossipsub config builds without error.
    #[test]
    fn build_gossipsub_config_succeeds() {
        let result = build_gossipsub();
        assert!(result.is_ok(), "build_gossipsub must succeed: {:?}", result.err());
    }
}
