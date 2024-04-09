// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibConstStrings
/// @custom:security-contact security@taiko.xyz
library LibConstStrings {
    /// @notice Keccak hash of the string "STATE_ROOT".
    bytes32 internal constant HASH_STATE_ROOT = keccak256("STATE_ROOT");

    /// @notice Keccak hash of the string "SIGNAL_ROOT".
    bytes32 internal constant HASH_SIGNAL_ROOT = keccak256("SIGNAL_ROOT");

    /// @notice Constant string "SIGNAL".
    string internal constant SIGNAL = "SIGNAL";

    /// @notice bytes32 representation of the string "chain_pauser".
    bytes32 internal constant BYTES32_CHAIN_PAUSER = bytes32("chain_pauser");

    /// @notice bytes32 representation of the string "snapshooter".
    bytes32 internal constant BYTES32_SNAPSHOOTER = bytes32("snapshooter");

    /// @notice bytes32 representation of the string "withdrawer".
    bytes32 internal constant BYTES32_WITHDRAWER = bytes32("withdrawer");

    /// @notice bytes32 representation of the string "proposer".
    bytes32 internal constant BYTES32_PROPOSER = bytes32("proposer");

    /// @notice bytes32 representation of the string "proposer_one".
    bytes32 internal constant BYTES32_PROPOSER_ONE = bytes32("proposer_one");

    /// @notice bytes32 representation of the string "signal_service".
    bytes32 internal constant BYTES32_SIGNAL_SERVICE = bytes32("signal_service");

    /// @notice bytes32 representation of the string "taiko_token".
    bytes32 internal constant BYTES32_TAIKO_TOKEN = bytes32("taiko_token");

    /// @notice bytes32 representation of the string "taiko".
    bytes32 internal constant BYTES32_TAIKO = bytes32("taiko");

    /// @notice bytes32 representation of the string "bridge".
    bytes32 internal constant BYTES32_BRIDGE = bytes32("bridge");

    /// @notice bytes32 representation of the string "erc20_vault".
    bytes32 internal constant BYTES32_ERC20_VAULT = bytes32("erc20_vault");

    /// @notice bytes32 representation of the string "bridged_erc20".
    bytes32 internal constant BYTES32_BRIDGED_ERC20 = bytes32("bridged_erc20");

    /// @notice bytes32 representation of the string "erc1155_vault".
    bytes32 internal constant BYTES32_ERC1155_VAULT = bytes32("erc1155_vault");

    /// @notice bytes32 representation of the string "bridged_erc1155".
    bytes32 internal constant BYTES32_BRIDGED_ERC1155 = bytes32("bridged_erc1155");

    /// @notice bytes32 representation of the string "erc721_vault".
    bytes32 internal constant BYTES32_ERC721_VAULT = bytes32("erc721_vault");

    /// @notice bytes32 representation of the string "bridged_erc721".
    bytes32 internal constant BYTES32_BRIDGED_ERC721 = bytes32("bridged_erc721");

    /// @notice bytes32 representation of the string "bridge_watchdog".
    bytes32 internal constant BYTES32_BRIDGE_WATCHDOG = bytes32("bridge_watchdog");

    /// @notice bytes32 representation of the string "rollup_watchdog".
    bytes32 internal constant BYTES32_ROLLUP_WATCHDOG = bytes32("rollup_watchdog");

    /// @notice Keccak hash of the string "RETURN_LIVENESS_BOND".
    bytes32 internal constant HASH_RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");

    /// @notice bytes32 representation of the string "tier_provider".
    bytes32 internal constant BYTES32_TIER_PROVIDER = bytes32("tier_provider");

    /// @notice The tier name for optimistic proofs - expected to only be used for testnets. For
    /// production we do not plan to have optimistic type of proving first, but future will tell if
    /// L3s, app-chains or other 3rd parties would be willing to do so.
    bytes32 internal constant BYTES32_TIER_OP = bytes32("tier_optimistic");

    /// @notice bytes32 representation of the string "guardian_prover".
    bytes32 internal constant BYTES32_GUARDIAN_PROVER = bytes32("guardian_prover");

    /// @notice bytes32 representation of the string "automata_dcap_attestation".
    bytes32 internal constant BYTES32_AUTOMATA_DCAP_ATTESTATION =
        bytes32("automata_dcap_attestation");

    /// @notice bytes32 representation of the string "PROVER_ASSIGNMENT".
    bytes32 public constant BYTES32_PROVER_ASSIGNMENT = bytes32("PROVER_ASSIGNMENT");
}
