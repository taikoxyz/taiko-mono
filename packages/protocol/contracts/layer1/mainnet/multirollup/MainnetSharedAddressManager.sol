// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/AddressManager.sol";
import "src/shared/common/LibStrings.sol";
import "../addrcache/SharedAddressCache.sol";
import "../reentrylock/LibFasterReentryLock.sol";

/// @title MainnetSharedAddressManager
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {IAddressManager}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSharedAddressManager is AddressManager, SharedAddressCache {
    function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address) {
        return getAddress(_chainId, _name, super._getAddress);
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
