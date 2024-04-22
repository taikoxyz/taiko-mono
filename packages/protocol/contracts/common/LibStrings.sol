// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title LibStrings
/// @custom:security-contact security@taiko.xyz
library LibStrings {
    bytes32 internal constant B_CHAIN_PAUSER = bytes32("chain_pauser");

    bytes32 internal constant B_WITHDRAWER = bytes32("withdrawer");

    bytes32 internal constant B_PROPOSER = bytes32("proposer");

    bytes32 internal constant B_PROPOSER_ONE = bytes32("proposer_one");

    bytes32 internal constant B_SIGNAL_SERVICE = bytes32("signal_service");

    bytes32 internal constant B_TAIKO_TOKEN = bytes32("taiko_token");

    bytes32 internal constant B_TAIKO = bytes32("taiko");

    bytes32 internal constant B_BRIDGE = bytes32("bridge");

    bytes32 internal constant B_ERC20_VAULT = bytes32("erc20_vault");

    bytes32 internal constant B_BRIDGED_ERC20 = bytes32("bridged_erc20");

    bytes32 internal constant B_ERC1155_VAULT = bytes32("erc1155_vault");

    bytes32 internal constant B_BRIDGED_ERC1155 = bytes32("bridged_erc1155");

    bytes32 internal constant B_ERC721_VAULT = bytes32("erc721_vault");

    bytes32 internal constant B_BRIDGED_ERC721 = bytes32("bridged_erc721");

    bytes32 internal constant B_BRIDGE_WATCHDOG = bytes32("bridge_watchdog");

    bytes32 internal constant B_ROLLUP_WATCHDOG = bytes32("rollup_watchdog");

    bytes32 internal constant B_TIER_PROVIDER = bytes32("tier_provider");

    /// @notice The tier name for optimistic proofs - expected to only be used for testnets. For
    /// production we do not plan to have optimistic type of proving first, but future will tell if
    /// L3s, app-chains or other 3rd parties would be willing to do so.
    bytes32 internal constant B_TIER_OP = bytes32("tier_optimistic");

    bytes32 internal constant B_GUARDIAN_PROVER = bytes32("guardian_prover");

    bytes32 internal constant B_AUTOMATA_DCAP_ATTESTATION = bytes32("automata_dcap_attestation");

    bytes32 internal constant B_PROVER_ASSIGNMENT = bytes32("PROVER_ASSIGNMENT");

    bytes32 internal constant H_RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");

    bytes32 internal constant H_STATE_ROOT = keccak256("STATE_ROOT");

    bytes32 internal constant H_SIGNAL_ROOT = keccak256("SIGNAL_ROOT");

    string internal constant S_SIGNAL = "SIGNAL";
}
