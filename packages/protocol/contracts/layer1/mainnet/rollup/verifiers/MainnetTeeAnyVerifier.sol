// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/compose/TeeAnyVerifier.sol";
import "src/layer1/mainnet/addrcache/RollupAddressCache.sol";
import "src/layer1/mainnet/reentrylock/LibFasterReentryLock.sol";

/// @title MainnetTeeAnyVerifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @custom:security-contact security@taiko.xyz
contract MainnetTeeAnyVerifier is TeeAnyVerifier, RollupAddressCache {
    // function _getAddress(uint64 _chainId, bytes32 _name) internal view override returns (address)
    // {
    //     return getAddress(_chainId, _name, super._getAddress);
    // }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
