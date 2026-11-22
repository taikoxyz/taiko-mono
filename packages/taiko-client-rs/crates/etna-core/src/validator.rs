//! Stock native validator protobuf and validator-set commitments.
use crate::key::{ConsensusKey, KeyError};
use alloc::vec::Vec;
use prost::Message;
/// A native validator update, including zero power for removal at H+2.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ValidatorUpdate {
    /// Validated compressed secp256k1eth key.
    pub pub_key: ConsensusKey,
    /// Stock nonnegative voting power; zero removes an existing validator.
    pub power: tendermint::vote::Power,
}

/// The stock ValidatorUpdate/SimpleValidator two-field protobuf layout.
#[derive(Clone, PartialEq, Message)]
pub struct WireValidator {
    /// Native crypto.PublicKey rather than tendermint-rs's incomplete key enum.
    #[prost(bytes = "vec", optional, tag = "1")]
    pub_key: Option<Vec<u8>>,
    /// Stock int64 nonnegative voting power.
    #[prost(int64, tag = "2")]
    power: i64,
}

impl ValidatorUpdate {
    /// Canonical stock protobuf bytes, including the secp256k1eth oneof tag5.
    pub fn encode(self) -> Vec<u8> {
        self.into_wire().encode_to_vec()
    }

    /// Converts the native update to its exact stock protobuf message.
    pub fn into_wire(self) -> WireValidator {
        WireValidator {
            pub_key: Some([&[0x2a, 33][..], self.pub_key.as_bytes()].concat()),
            power: i64::from(self.power),
        }
    }

    /// Decodes a stock validator update and rejects absent, legacy or malformed keys.
    pub fn decode(bytes: &[u8]) -> Result<Self, KeyError> {
        Self::from_wire(WireValidator::decode(bytes).map_err(|_| KeyError)?)
    }

    /// Requires exactly the supported key type and nonnegative stock voting power.
    pub fn from_wire(raw: WireValidator) -> Result<Self, KeyError> {
        let bytes = raw.pub_key.ok_or(KeyError)?;
        // Preserve the native oneof exactly; accepting another algorithm alongside tag5 could
        // disagree with stock protobuf's last-oneof-field-wins semantics.
        if bytes.len() != 35 || bytes[..2] != [0x2a, 33] {
            return Err(KeyError);
        }
        Ok(Self {
            pub_key: ConsensusKey::from_slice(&bytes[2..])?,
            power: raw.power.try_into().map_err(|_| KeyError)?,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::hex;
    #[test]
    fn validator_update_uses_tag_five_and_rejects_legacy_key_tags() {
        let bytes =
            hex!("0a232a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798100a");
        let update = ValidatorUpdate::decode(&bytes).expect("stock tag5");
        assert_eq!(update.power.value(), 10);
        assert_eq!(update.encode(), bytes);
        for tag in [0x0a, 0x12] {
            let mut legacy = bytes;
            legacy[2] = tag;
            assert!(ValidatorUpdate::decode(&legacy).is_err());
        }
    }
    #[test]
    fn ambiguous_key_algorithm_fields_are_rejected() {
        let native = hex!("2a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798");
        let legacy = [vec![0x0a, 32], vec![7; 32]].concat();
        for key in [[native.to_vec(), legacy.clone()].concat(), [legacy, native.to_vec()].concat()]
        {
            let update = [vec![0x0a, key.len() as u8], key, vec![0x10, 1]].concat();
            assert!(ValidatorUpdate::decode(&update).is_err());
        }
    }
}

/// Computes the stock Comet validator-set Merkle hash of keys and powers in any order, hashing
/// them in voting-power/address order.
pub fn validators_hash(
    members: &[(ConsensusKey, u64)],
) -> Result<alloy_primitives::B256, KeyError> {
    let mut sorted = members.to_vec();
    sorted.sort_by_cached_key(|(key, power)| (core::cmp::Reverse(*power), key.address()));
    validators_hash_in_order(sorted)
}

/// Hashes native keys/powers already in stock power-descending, address-ascending order.
/// The canonical validator-state replica maintains that order, so header checks need neither
/// sort entries nor decompress their keys again. Powers retain the wire API's int64 check.
pub fn validators_hash_in_order(
    members: impl IntoIterator<Item = (ConsensusKey, u64)>,
) -> Result<alloy_primitives::B256, KeyError> {
    let leaves = members
        .into_iter()
        .map(|(pub_key, power)| {
            let power = power.try_into().map_err(|_| KeyError)?;
            Ok(ValidatorUpdate { pub_key, power }.encode())
        })
        .collect::<Result<Vec<_>, KeyError>>()?;
    Ok(tendermint::merkle::simple_hash_from_byte_vectors::<sha2::Sha256>(&leaves).into())
}

#[cfg(test)]
mod validator_hash_tests {
    use super::*;
    #[test]
    fn validators_hash_matches_stock_native_power_address_order() {
        let oracle: serde_json::Value =
            serde_json::from_str(include_str!("../testdata/comet-wire.json")).unwrap();
        let members = oracle["members"]
            .as_array()
            .unwrap()
            .iter()
            .map(|m| {
                let key = alloy_primitives::hex::decode(m["key"].as_str().unwrap()).unwrap();
                (ConsensusKey::from_slice(&key).unwrap(), m["power"].as_u64().unwrap())
            })
            .collect::<Vec<_>>();
        let expected =
            oracle["validators_hash"].as_str().unwrap().parse::<alloy_primitives::B256>().unwrap();
        // This API accepts arbitrary member order, unlike ValSet's already canonical entries.
        for order in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]] {
            let permuted = order.map(|index| members[index]);
            assert_eq!(validators_hash(&permuted).unwrap(), expected, "order {order:?}");
        }
        let mut invalid = members;
        invalid[0].1 = 1_u64 << 63;
        assert!(validators_hash(&invalid).is_err());
    }

    #[test]
    fn empty_native_set_retains_the_stock_empty_merkle_hash() {
        assert_eq!(
            validators_hash(&[]).unwrap(),
            alloy_primitives::b256!(
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            )
        );
    }
}
