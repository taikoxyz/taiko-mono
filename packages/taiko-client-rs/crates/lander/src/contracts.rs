//! Types generated from a provenance-checked projection of the pinned real Inbox ABI.
//! The full interface snapshot and unmodified real artifacts remain available for verification.

use alloy::sol;

sol!(
    #[sol(all_derives)]
    IEtnaInbox,
    "contracts/EtnaInbox.json"
);

// A standalone event retains its exact types and indexed layout without Alloy's generated
// eight-argument Events enum builder. The generator records the projection's provenance.
sol!(
    #[sol(all_derives)]
    "contracts/BatchRewardRecorded.sol"
);

/// The generated Inbox revert for an invalid zero L1 forced-fee recipient.
pub use IEtnaInbox::ZeroFeeRecipient;

/// Protocol revision from which the interface and contract fixtures are generated.
pub const PROTOCOL_REVISION: &str = "8b5f8f4ff26178ca6bbc21d55cf01297a1820e6e";

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
