// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/vault/ERC20Vault.sol";

import "./MainnetERC20Vault_Layout.sol"; // DO NOT DELETE

/// @title MainnetERC20Vault
/// @dev Deployed on Ethereum for Taiko mainnet. Behavior is identical to the parent contract
/// since the transient-storage reentry lock became the {EssentialContract} default; the contract
/// is retained for deployment identity.
/// @notice See the documentation in {ERC20Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC20Vault is ERC20Vault {
    constructor(address _resolver, address _quotaManager) ERC20Vault(_resolver, _quotaManager) { }
}
