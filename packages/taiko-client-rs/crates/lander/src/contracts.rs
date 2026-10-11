//! Types generated at compile time from the exact #22286 Solidity interface snapshot.

use alloy::sol;

sol!(
    #[sol(all_derives)]
    "contracts/IEtnaInbox.sol"
);

/// Protocol revision from which the interface and contract fixtures are generated.
pub const PROTOCOL_REVISION: &str = "639bae72ba2e69fc44387306d56f9fef7cb6703d";

/// Journal representation of generated ABI values as canonical ABI bytes.
pub(crate) mod land_input_serde {
    use super::IEtnaInbox::LandInput;
    use alloy::sol_types::SolValue;
    use alloy_primitives::Bytes;
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Serialize without hand-writing or duplicating the generated ABI fields.
    pub fn serialize<S: Serializer>(input: &LandInput, serializer: S) -> Result<S::Ok, S::Error> {
        Bytes::from(input.abi_encode()).serialize(serializer)
    }

    /// Reject noncanonical ABI bytes while restoring the generated type.
    pub fn deserialize<'de, D: Deserializer<'de>>(deserializer: D) -> Result<LandInput, D::Error> {
        let bytes = Bytes::deserialize(deserializer)?;
        let input = LandInput::abi_decode(&bytes).map_err(serde::de::Error::custom)?;
        if input.abi_encode().as_slice() != bytes.as_ref() {
            return Err(serde::de::Error::custom("noncanonical LandInput ABI"));
        }
        Ok(input)
    }
}
