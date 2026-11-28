//! Types generated from the pinned real Inbox artifact (`tests/fixtures/contracts/EtnaInbox.json`,
//! reproduced by `script/gen_lander_artifacts.sh` at its `PINNED_REVISION`). The lander calls,
//! decodes and binds `land` with its seven-field `LandInput`, the `Landed` event, the deployment
//! getters and the record views. It reads the fallback key list through `abci::fallback`, not
//! through this declaration.

use alloy::sol;

sol!(
    #[sol(all_derives)]
    IEtnaInbox,
    "tests/fixtures/contracts/EtnaInbox.json"
);

/// Journal representation of the seven-field `LandInput` as canonical ABI bytes.
pub(crate) mod abi_serde {
    use alloy::sol_types::{SolType, SolValue};
    use alloy_primitives::Bytes;
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Serialize without hand-writing or duplicating the ABI fields.
    pub fn serialize<T: SolValue, S: Serializer>(
        value: &T,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        Bytes::from(value.abi_encode()).serialize(serializer)
    }

    /// Reject noncanonical ABI bytes while restoring the ABI type.
    pub fn deserialize<'de, T, D>(deserializer: D) -> Result<T, D::Error>
    where
        T: SolValue + From<<T::SolType as SolType>::RustType>,
        D: Deserializer<'de>,
    {
        let bytes = Bytes::deserialize(deserializer)?;
        let value = T::abi_decode(&bytes).map_err(serde::de::Error::custom)?;
        if value.abi_encode().as_slice() != bytes.as_ref() {
            return Err(serde::de::Error::custom("noncanonical ABI journal value"));
        }
        Ok(value)
    }
}

#[cfg(test)]
mod tests {
    use super::IEtnaInbox::{Landed, configHashCall};
    use crate::test_utils::vectors;
    use alloy::sol_types::{SolCall, SolEvent};
    use alloy_primitives::{B256, LogData};

    /// The generated `Landed` event and `configHash()` view are the ones the shared vectors spell
    /// out: signature, topic and selector, and the recorded log decodes and re-encodes exactly.
    #[test]
    fn generated_abi_matches_the_shared_vectors() {
        let landed = "/governance_events/landed";
        assert_eq!(Landed::SIGNATURE, vectors::str_at(&format!("{landed}/signature")));
        assert_eq!(Landed::SIGNATURE_HASH, vectors::b256_at(&format!("{landed}/topic0")));
        let mut topics = vec![Landed::SIGNATURE_HASH];
        topics.extend(vectors::b256s_at(&format!("{landed}/indexed_topics")));
        let data = vectors::bytes_at(&format!("{landed}/data"));
        let log = LogData::new(topics.clone(), data.clone()).unwrap();
        let event = Landed::decode_log_data(&log).unwrap();
        assert_eq!(event.encode_topics().into_iter().map(B256::from).collect::<Vec<_>>(), topics);
        assert_eq!(event.encode_data(), data.to_vec());

        assert_eq!(configHashCall::SIGNATURE, vectors::str_at("/view_abi/config_hash/signature"));
        assert_eq!(
            configHashCall::SELECTOR.as_slice(),
            vectors::bytes_at("/view_abi/config_hash/selector").as_ref()
        );
    }
}
