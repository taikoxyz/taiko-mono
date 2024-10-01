// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../../verifiers/Risc0Verifier.sol";
import "../../addrcache/RollupAddressCache.sol";
import "../../reentrylock/LibFasterReentryLock.sol";

/// @title MainnetRisc0Verifier
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {Risc0Verifier}.
/// @custom:security-contact security@taiko.xyz
contract MainnetRisc0Verifier is Risc0Verifier, RollupAddressCache {
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
