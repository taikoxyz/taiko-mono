// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/SignalService.sol";
import "src/layer1/mainnet/libs/LibFasterReentryLock.sol";

/// @title SurgeSignalService
/// @notice See the documentation in {SignalService}.
/// @custom:security-contact security@nethermind.io
contract SurgeSignalService is SignalService {
    constructor(address _resolver) SignalService(_resolver) { }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
