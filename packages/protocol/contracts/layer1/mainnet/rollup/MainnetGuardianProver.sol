// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/provers/GuardianProver.sol";
import "../reentrylock/LibFasterReentryLock.sol";
/// @title MainnetGuardianProver
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {GuardianProver}.
/// @custom:security-contact security@taiko.xyz

contract MainnetGuardianProver is GuardianProver {
    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
