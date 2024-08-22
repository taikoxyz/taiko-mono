// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../tokenvault/ERC1155Vault.sol";
import "../addrcache/SharedAddressCache.sol";

/// @title MainnetERC1155Vault
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deplyed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {ER1155Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC1155Vault is ERC1155Vault, SharedAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }
}
