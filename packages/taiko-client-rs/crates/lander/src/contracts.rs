//! Types generated from a provenance-checked projection of the pinned real Inbox ABI.
//! The full interface snapshot and unmodified real artifacts remain available for verification.

use alloy::sol;

sol!(
    #[sol(all_derives)]
    IEtnaInbox,
    "contracts/EtnaInbox.json"
);

/// Protocol revision from which the interface and contract fixtures are generated.
pub const PROTOCOL_REVISION: &str = "1b14b634c8d213b5b30d8fc61ca6f6dcec344389";

/// Journal representation of the generated eight-field `LandInput` as canonical ABI bytes.
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
