// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../tokenvault/ERC1155Vault.sol";
import "./LibSharedAddressCache.sol";

/// @title MainnetERC1155Vault
/// @notice See the documentation in {ER1155Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC1155Vault is ERC1155Vault {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        (bool found, address addr) = LibSharedAddressCache.getAddress(_chainId, _name);
        return found ? addr : super._getAddress(_chainId, _name);
    }
}
