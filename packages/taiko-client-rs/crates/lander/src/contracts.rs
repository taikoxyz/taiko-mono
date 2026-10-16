//! Types generated at compile time from the exact #22286 Solidity interface snapshot.

use alloy::sol;

sol!(
    #[sol(all_derives)]
    "contracts/IEtnaInbox.sol"
);

sol!(
    /// `EtnaInbox`'s revert for a `LandInput` whose `feeRecipient` is zero. Custom errors live in
    /// the implementation, not the interface snapshot above, so this one is declared here; a unit
    /// test checks it against the pinned `EtnaInbox` ABI.
    #[sol(all_derives)]
    error ZeroFeeRecipient();
);

/// Protocol revision from which the interface and contract fixtures are generated.
pub const PROTOCOL_REVISION: &str = "5787d217f508a115a171f5dafb93a8fb8950c10f";

/// Journal representation of generated ABI values (the `LandInput`, the participation parts and
/// the settlement committees) as their canonical Solidity `abi.encode` bytes.
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
