// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { LibFasterReentryLock } from "../../mainnet/libs/LibFasterReentryLock.sol";

/// @title MainnetInbox
/// @dev This contract extends the base Inbox contract for mainnet deployment
/// with optimized reentrancy lock implementation.
/// @custom:security-contact security@taiko.xyz
contract MainnetInbox is Inbox {
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() Inbox() { }

    // ---------------------------------------------------------------
    // External/Public Functions
    // ---------------------------------------------------------------

    /// @notice Sets the core state.
    /// @param _coreState The core state.
    // TODO: what's the reinitializer(2) value, 2?
    function setCoreState(CoreState memory _coreState) external onlyOwner reinitializer(2) {
        require(_coreState.nextProposalId != 0, InvalidCoreState());

        coreStateHash = keccak256(abi.encode(_coreState));
        emit CoreStateSet(_coreState);
    }

    /// @notice Gets the configuration for this Inbox contract
    /// @return _ The configuration struct with shasta-specific settings
    // TODO: figure out these values
    function getConfig() public pure override returns (Config memory) {
        return Config({
            bondToken: address(0),
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            maxFinalizationCount: 16,
            ringBufferSize: 2400,
            basefeeSharingPctg: 0,
            syncedBlockManager: address(0),
            proofVerifier: address(0),
            proposerChecker: address(0),
            forcedInclusionStore: address(0)
        });
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidCoreState();
}
