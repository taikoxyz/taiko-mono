//! The DAO fallback key set: the key list the Inbox keeps, its hash and its ABI encoding.
//!
//! The set signs the first two blocks of every generation, and every later block whose candidate
//! is not usable, as one validator per key, each with voting power 1. Nodes and guests take a list
//! as input and accept it only when its [`FallbackKeys::hash`](crate::fallback::FallbackKeys::hash)
//! equals the hash that applies.

use crate::{
    committee::{tag, word},
    key::ConsensusKey,
    params::MAX_SET_MEMBERS,
};
use alloc::vec::Vec;
use alloy_primitives::{B256, keccak256};
use serde::{Deserialize, Serialize};

/// `bytes32("ETNA_FALLBACK_KEYS_V1")`: domain tag of the key list hash ([`FallbackKeys::hash`]).
const FALLBACK_KEYS_TAG: B256 = tag(b"ETNA_FALLBACK_KEYS_V1");

/// A fallback key list: 1 to [`MAX_SET_MEMBERS`] valid compressed keys in strictly ascending order
/// of their 33-byte big-endian value `ckPrefix ‖ ckX`, so no key repeats and the list and its hash
/// are unique.
///
/// Its JSON form is the array of keys, checked like [`FallbackKeys::new`] on deserialize.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(try_from = "Vec<ConsensusKey>", into = "Vec<ConsensusKey>")]
pub struct FallbackKeys(Vec<ConsensusKey>);

/// Why a fallback key list was refused.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum FallbackKeysError {
    /// The list holds no key.
    #[error("a fallback key list holds at least one key")]
    Empty,
    /// The list holds more than [`MAX_SET_MEMBERS`] keys; the count.
    #[error("a fallback key list holds at most {MAX_SET_MEMBERS} keys, not {0}")]
    TooMany(usize),
    /// The key at this index is not above the key before it.
    #[error("fallback key {0} is not above the key before it")]
    NotAscending(usize),
    /// The data is not the canonical ABI encoding of a list of valid keys.
    #[error("not the canonical ABI encoding of a fallback key list")]
    Abi,
}

impl FallbackKeys {
    /// The list of `keys`, refused unless it holds 1 to [`MAX_SET_MEMBERS`] keys in strictly
    /// ascending order.
    pub fn new(keys: Vec<ConsensusKey>) -> Result<Self, FallbackKeysError> {
        check_count(keys.len())?;
        if let Some(index) = keys.windows(2).position(|pair| pair[0] >= pair[1]) {
            return Err(FallbackKeysError::NotAscending(index + 1));
        }
        Ok(Self(keys))
    }

    /// Decodes `abi.encode(keys)` for a `FallbackKey[]` (`(uint8 ckPrefix, bytes32 ckX)`
    /// entries), the return data of `getFallbackKeys()` and the data of `FallbackKeysUpdated`:
    /// the offset word `0x20`, the length and two words per key, nothing more. Any other encoding,
    /// a prefix word above 255 included, and any invalid key are [`FallbackKeysError::Abi`]; the
    /// decoded list is then checked like [`FallbackKeys::new`].
    pub fn from_abi(data: &[u8]) -> Result<Self, FallbackKeysError> {
        let (head, body) = data.split_at_checked(64).ok_or(FallbackKeysError::Abi)?;
        let (entries, rest) = body.as_chunks::<64>();
        if !rest.is_empty() ||
            head[..32] != word(0x20u64)[..] ||
            head[32..] != word(entries.len())[..]
        {
            return Err(FallbackKeysError::Abi);
        }
        check_count(entries.len())?;
        let keys = entries.iter().map(decode_key).collect::<Result<Vec<_>, _>>()?;
        Self::new(keys)
    }

    /// `abi.encode(keys)`: the inverse of [`FallbackKeys::from_abi`], `64 + 64n` bytes.
    pub fn abi_encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(64 * (1 + self.0.len()));
        out.extend_from_slice(word(0x20u64).as_slice());
        self.encode_array(&mut out);
        out
    }

    /// `fallbackKeysHash = keccak256(abi.encode(bytes32("ETNA_FALLBACK_KEYS_V1"), keys))`.
    pub fn hash(&self) -> B256 {
        keccak256(self.hash_preimage())
    }

    /// The keys, in ascending order.
    pub fn keys(&self) -> &[ConsensusKey] {
        &self.0
    }

    /// The validator set the list signs as: each key at voting power 1, in list order.
    pub fn validator_set(&self) -> Vec<(ConsensusKey, u64)> {
        self.0.iter().map(|key| (*key, 1)).collect()
    }

    /// The preimage of [`FallbackKeys::hash`]: the tag, the offset word `0x40`, then the list's
    /// length and two words per key, `96 + 64n` bytes.
    fn hash_preimage(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(96 + 64 * self.0.len());
        out.extend_from_slice(FALLBACK_KEYS_TAG.as_slice());
        out.extend_from_slice(word(0x40u64).as_slice());
        self.encode_array(&mut out);
        out
    }

    /// Appends the list's ABI tail to `out`: its length, then `ckPrefix` and `ckX` of each key.
    fn encode_array(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(word(self.0.len()).as_slice());
        for key in &self.0 {
            out.extend_from_slice(word(key.prefix()).as_slice());
            out.extend_from_slice(key.x().as_slice());
        }
    }
}

/// Refuses a key count outside 1 to [`MAX_SET_MEMBERS`].
fn check_count(count: usize) -> Result<(), FallbackKeysError> {
    match count {
        0 => Err(FallbackKeysError::Empty),
        count if count > MAX_SET_MEMBERS => Err(FallbackKeysError::TooMany(count)),
        _ => Ok(()),
    }
}

/// The key one ABI entry encodes: a `uint8` prefix word, whose bits above the low byte are zero,
/// and the X word, together a valid compressed key.
fn decode_key(entry: &[u8; 64]) -> Result<ConsensusKey, FallbackKeysError> {
    if entry[..31].iter().any(|byte| *byte != 0) {
        return Err(FallbackKeysError::Abi);
    }
    ConsensusKey::from_slice(&entry[31..]).map_err(|_| FallbackKeysError::Abi)
}

impl TryFrom<Vec<ConsensusKey>> for FallbackKeys {
    /// The list is empty, too long or not strictly ascending.
    type Error = FallbackKeysError;
    /// Checks the list like [`FallbackKeys::new`], also when deserializing.
    fn try_from(keys: Vec<ConsensusKey>) -> Result<Self, Self::Error> {
        Self::new(keys)
    }
}

impl From<FallbackKeys> for Vec<ConsensusKey> {
    /// The keys, in ascending order.
    fn from(keys: FallbackKeys) -> Self {
        keys.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::{U256, b256, hex};

    /// The compressed public key of private key 1.
    const K1: [u8; 33] = hex!("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798");
    /// The compressed public key of private key 2.
    const K2: [u8; 33] = hex!("02c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5");

    fn key(bytes: &[u8]) -> ConsensusKey {
        ConsensusKey::from_slice(bytes).unwrap()
    }

    /// `bytes` with its first byte replaced by `prefix`.
    fn with_prefix(prefix: u8, bytes: [u8; 33]) -> ConsensusKey {
        let mut bytes = bytes;
        bytes[0] = prefix;
        key(&bytes)
    }

    /// `n` distinct valid keys in ascending order.
    fn sorted_keys(n: u64) -> Vec<ConsensusKey> {
        let mut keys: Vec<_> = (0..n).map(crate::test_utils::test_key).collect();
        keys.sort();
        keys
    }

    fn word(value: u64) -> [u8; 32] {
        U256::from(value).to_be_bytes()
    }

    #[test]
    fn hash_of_one_key() {
        let keys = FallbackKeys::new(vec![key(&K1)]).unwrap();
        assert_eq!(keys.hash_preimage().len(), 160);
        assert_eq!(
            keys.hash(),
            b256!("9dd1f7298a08cbe8d9579af09f0c713fc35137e6c534a74f8c439b63252f046f")
        );
    }

    #[test]
    fn hash_of_two_keys() {
        let keys = FallbackKeys::new(vec![key(&K1), key(&K2)]).unwrap();
        assert_eq!(keys.hash_preimage().len(), 224);
        assert_eq!(
            keys.hash(),
            b256!("2bc20cdc8e87ed785fc8f8012165afba944fd223ecf8973e165e41f4cddf0cea")
        );
    }

    #[test]
    fn order_is_the_33_byte_value() {
        // A prefix 0x02 key with the larger X precedes a prefix 0x03 key with the smaller X.
        let larger_x_even = key(&K2);
        let smaller_x_odd = with_prefix(3, K1);
        let keys = FallbackKeys::new(vec![larger_x_even, smaller_x_odd]).unwrap();
        assert_eq!(keys.keys(), [larger_x_even, smaller_x_odd]);
        // Ordering by X alone puts them the other way round, which is refused.
        assert_eq!(
            FallbackKeys::new(vec![smaller_x_odd, larger_x_even]),
            Err(FallbackKeysError::NotAscending(1))
        );
        assert_eq!(
            FallbackKeys::new(vec![key(&K2), key(&K1)]),
            Err(FallbackKeysError::NotAscending(1))
        );
        assert_eq!(
            FallbackKeys::new(vec![key(&K1), key(&K1)]),
            Err(FallbackKeysError::NotAscending(1))
        );
        let mut keys = sorted_keys(4);
        keys.swap(2, 3);
        assert_eq!(FallbackKeys::new(keys), Err(FallbackKeysError::NotAscending(3)));
    }

    #[test]
    fn size_bounds() {
        assert_eq!(FallbackKeys::new(vec![]), Err(FallbackKeysError::Empty));
        assert_eq!(FallbackKeys::new(sorted_keys(129)), Err(FallbackKeysError::TooMany(129)));
        let full = FallbackKeys::new(sorted_keys(128)).unwrap();
        assert_eq!(full.keys().len(), crate::params::MAX_SET_MEMBERS);
        assert_eq!(full.hash_preimage().len(), 8_288);
    }

    #[test]
    fn abi_round_trip_and_canonical_only() {
        let x = &K1[1..];
        let one = [&word(0x20)[..], &word(1), &word(2), x].concat();
        let decoded = FallbackKeys::from_abi(&one).unwrap();
        assert_eq!(decoded.keys(), [key(&K1)]);
        assert_eq!(decoded.abi_encode(), one);
        for keys in [vec![key(&K1), key(&K2)], sorted_keys(128)] {
            let keys = FallbackKeys::new(keys).unwrap();
            assert_eq!(FallbackKeys::from_abi(&keys.abi_encode()), Ok(keys));
        }

        let prefix_word = |prefix: u64| [&word(0x20)[..], &word(1), &word(prefix), x].concat();
        let malformed = [
            // A trailing word after the list.
            [&one[..], &word(0)].concat(),
            // The list's offset is not the one head word.
            [&word(0x40)[..], &word(1), &word(2), x].concat(),
            // A prefix that is no compressed key's.
            prefix_word(4),
            // A prefix word with bits above the uint8.
            prefix_word(0x102),
            // A length that disagrees with the words that follow.
            [&word(0x20)[..], &word(2), &word(2), x].concat(),
            // Truncated: the last key lacks its X word.
            [&word(0x20)[..], &word(1), &word(2)].concat(),
            Vec::new(),
        ];
        for data in malformed {
            assert_eq!(
                FallbackKeys::from_abi(&data),
                Err(FallbackKeysError::Abi),
                "{}",
                hex::encode(&data)
            );
        }
        assert_eq!(
            FallbackKeys::from_abi(&[&word(0x20)[..], &word(0)].concat()),
            Err(FallbackKeysError::Empty)
        );
        let descending = [&word(0x20)[..], &word(2), &word(2), &K2[1..], &word(2), x].concat();
        assert_eq!(FallbackKeys::from_abi(&descending), Err(FallbackKeysError::NotAscending(1)));
    }

    #[test]
    fn validator_set_is_power_one() {
        let keys = FallbackKeys::new(vec![key(&K1), key(&K2)]).unwrap();
        assert_eq!(keys.validator_set(), [(key(&K1), 1), (key(&K2), 1)]);
    }

    #[test]
    fn json_is_an_array_of_keys_validated_on_deserialize() {
        let keys = FallbackKeys::new(vec![key(&K1), key(&K2)]).unwrap();
        let json = serde_json::to_value(&keys).unwrap();
        assert_eq!(
            json,
            serde_json::json!([format!("0x{}", hex::encode(K1)), format!("0x{}", hex::encode(K2))])
        );
        assert_eq!(serde_json::from_value::<FallbackKeys>(json).unwrap(), keys);
        for refused in [
            serde_json::json!([]),
            serde_json::json!([format!("0x{}", hex::encode(K2)), format!("0x{}", hex::encode(K1))]),
        ] {
            assert!(serde_json::from_value::<FallbackKeys>(refused).is_err());
        }
    }
}
