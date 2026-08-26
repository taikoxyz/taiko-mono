// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/vault/ERC1155Vault.sol";

import "./MainnetERC1155Vault_Layout.sol"; // DO NOT DELETE

/// @title MainnetERC1155Vault
/// @dev Deployed on Ethereum for Taiko mainnet. Behavior is identical to the parent contract
/// since the transient-storage reentry lock became the {EssentialContract} default; the contract
/// is retained for deployment identity.
/// @notice See the documentation in {ERC1155Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC1155Vault is ERC1155Vault {
    constructor(address _resolver) ERC1155Vault(_resolver) { }
}
