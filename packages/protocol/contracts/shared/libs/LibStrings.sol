// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibStrings
/// @custom:security-contact security@taiko.xyz
library LibStrings {
    bytes32 internal constant B_BRIDGE = bytes32("bridge");
    bytes32 internal constant B_BRIDGE_WATCHDOG = bytes32("bridge_watchdog");
    bytes32 internal constant B_BRIDGED_ERC1155 = bytes32("bridged_erc1155");
    bytes32 internal constant B_BRIDGED_ERC20 = bytes32("bridged_erc20");
    bytes32 internal constant B_BRIDGED_ERC721 = bytes32("bridged_erc721");
    bytes32 internal constant B_CHAIN_WATCHDOG = bytes32("chain_watchdog");
    bytes32 internal constant B_ERC1155_VAULT = bytes32("erc1155_vault");
    bytes32 internal constant B_ERC20_VAULT = bytes32("erc20_vault");
    bytes32 internal constant B_ERC721_VAULT = bytes32("erc721_vault");
    bytes32 internal constant B_QUOTA_MANAGER = bytes32("quota_manager");
    bytes32 internal constant B_SIGNAL_SERVICE = bytes32("signal_service");
    bytes32 internal constant B_TAIKO_INBOX = bytes32("taiko");
    
    bytes32 internal constant H_SIGNAL_ROOT = keccak256("SIGNAL_ROOT");
    bytes32 internal constant H_STATE_ROOT = keccak256("STATE_ROOT");
}
