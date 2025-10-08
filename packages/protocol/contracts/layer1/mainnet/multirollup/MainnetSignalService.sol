// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/SignalService.sol";
import "../libs/LibFasterReentryLock.sol";

/// @title MainnetSignalService
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost. In theory, the contract can also be deployed on Taiko L2 but this is
/// not well testee nor necessary.
/// @notice See the documentation in {SignalService}.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
contract MainnetSignalService is SignalService {
    constructor(address _resolver) SignalService(_resolver) { }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
