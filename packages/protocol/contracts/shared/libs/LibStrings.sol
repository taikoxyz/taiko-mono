// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibStrings
/// @custom:security-contact security@taiko.xyz
library LibStrings {
    bytes32 internal constant B_AUTOMATA_DCAP_ATTESTATION = bytes32("automata_dcap_attestation");
    bytes32 internal constant B_BOND_TOKEN = bytes32("bond_token");
    bytes32 internal constant B_BRIDGE = bytes32("bridge");
    bytes32 internal constant B_BRIDGE_WATCHDOG = bytes32("bridge_watchdog");
    bytes32 internal constant B_BRIDGED_ERC1155 = bytes32("bridged_erc1155");
    bytes32 internal constant B_BRIDGED_ERC20 = bytes32("bridged_erc20");
    bytes32 internal constant B_BRIDGED_ERC721 = bytes32("bridged_erc721");
    bytes32 internal constant B_CHAIN_WATCHDOG = bytes32("chain_watchdog");
    bytes32 internal constant B_ERC1155_VAULT = bytes32("erc1155_vault");
    bytes32 internal constant B_ERC20_VAULT = bytes32("erc20_vault");
    bytes32 internal constant B_ERC721_VAULT = bytes32("erc721_vault");
    bytes32 internal constant B_FORCED_INCLUSION_STORE = bytes32("forced_inclusion_store");
    bytes32 internal constant B_PRECONF_WHITELIST = bytes32("preconf_whitelist");
    bytes32 internal constant B_PRECONF_WHITELIST_OWNER = bytes32("preconf_whitelist_owner");
    bytes32 internal constant B_PROOF_VERIFIER = bytes32("proof_verifier");
    bytes32 internal constant B_PROVER_SET = bytes32("prover_set");
    bytes32 internal constant B_QUOTA_MANAGER = bytes32("quota_manager");
    bytes32 internal constant B_SIGNAL_SERVICE = bytes32("signal_service");
    bytes32 internal constant B_TAIKO = bytes32("taiko");
    bytes32 internal constant B_TAIKO_TOKEN = bytes32("taiko_token");
    bytes32 internal constant B_WITHDRAWER = bytes32("withdrawer");
    bytes32 internal constant H_SIGNAL_ROOT = keccak256("SIGNAL_ROOT");
    bytes32 internal constant H_STATE_ROOT = keccak256("STATE_ROOT");
}
