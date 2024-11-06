// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/tokenvault/ERC20Vault.sol";
import "../addrcache/SharedAddressCache.sol";
import "../reentrylock/LibFasterReentryLock.sol";

/// @title MainnetERC20Vault
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deplyed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {ER20Vault}.
/// @custom:security-contact security@taiko.xyz
contract MainnetERC20Vault is ERC20Vault, SharedAddressCache {
       // function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
    //     return getAddress(_chainId, _name, super._getAddress);
    // }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
