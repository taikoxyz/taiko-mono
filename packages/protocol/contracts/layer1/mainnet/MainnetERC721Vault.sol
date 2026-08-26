// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/vault/ERC721Vault.sol";

import "./MainnetERC721Vault_Layout.sol"; // DO NOT DELETE

/// @title MainnetERC721Vault
/// @dev Deployed on Ethereum for Taiko mainnet. Behavior is identical to the parent contract
/// since the transient-storage reentry lock became the {EssentialContract} default; the contract
/// is retained for deployment identity.
/// @notice See the documentation in {ERC721Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC721Vault is ERC721Vault {
    constructor(address _resolver) ERC721Vault(_resolver) { }
}
