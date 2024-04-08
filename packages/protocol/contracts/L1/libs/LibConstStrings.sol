// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibConstStrings
/// @custom:security-contact security@taiko.xyz
library LibConstStrings {
    /// @notice bytes32 representation of the string "tier_provider".
    bytes32 internal constant BYTES32_STR_TIER_PROVIDER = bytes32("tier_provider");

    /// @notice bytes32 representation of the string "proposer".
    bytes32 internal constant BYTES32_STR_PROPOSER = bytes32("proposer");

    /// @notice bytes32 representation of the string "taiko_token".
    bytes32 internal constant BYTES32_STR_TKO = bytes32("taiko_token");

    /// @notice Keccak hash of the string "RETURN_LIVENESS_BOND".
    bytes32 internal constant HASH_STR_RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");

    /// @notice The tier name for optimistic proofs - expected to only be used for testnets. For
    /// production we do not plan to have optimistic type of proving first, but future will tell if
    /// L3s, app-chains or other 3rd parties would be willing to do so.
    bytes32 internal constant BYTES32_STR_TIER_OP = bytes32("tier_optimistic");

    /// @notice bytes32 representation of the string "PROVER_ASSIGNMENT".
    bytes32 public constant BYTES32_STR_PROVER_ASSIGNMENT = bytes32("PROVER_ASSIGNMENT");
}
