// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/mainnet/LibFasterReentryLock.sol";
import "src/shared/signal/SignalService.sol";

import "./MainnetSignalService_Layout.sol"; // auto-generated, do not edit

/// @title MainnetSignalService
/// @dev This contract shall be deployed to replace its parent contract on Ethereum for Taiko
/// mainnet to reduce gas cost.
/// @notice See the documentation in {SignalService}.
/// @custom:security-contact security@taiko.xyz
contract MainnetSignalService is SignalService {
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address authorizedSyncer,
        address remoteSignalService
    )
        SignalService(authorizedSyncer, remoteSignalService)
    { }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
