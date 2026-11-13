//! Types generated from the pinned real Inbox artifact (`tests/fixtures/contracts/EtnaInbox.json`,
//! reproduced by `script/gen_lander_artifacts.sh` at its `PINNED_REVISION`).

use alloy::sol;

sol!(
    #[sol(all_derives)]
    IEtnaInbox,
    "tests/fixtures/contracts/EtnaInbox.json"
);

/// Journal representation of the generated nine-field `LandInput` as canonical ABI bytes.
pub(crate) mod abi_serde {
    use alloy::sol_types::{SolType, SolValue};
    use alloy_primitives::Bytes;
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Serialize without hand-writing or duplicating the generated ABI fields.
    pub fn serialize<T: SolValue, S: Serializer>(
        value: &T,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        Bytes::from(value.abi_encode()).serialize(serializer)
    }

    /// Reject noncanonical ABI bytes while restoring the generated type.
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
