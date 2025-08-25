// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { InboxOptimized1 } from "src/layer1/shasta/impl/InboxOptimized1.sol";
import { InboxOptimized2 } from "src/layer1/shasta/impl/InboxOptimized2.sol";
import { InboxOptimized3 } from "src/layer1/shasta/impl/InboxOptimized3.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title TestInbox
/// @notice Test wrapper for Inbox contract with configurable behavior
contract TestInbox is Inbox {
    Config private config;

    address private immutable _bondToken;
    address private immutable _syncedBlockManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;
    address private immutable _forcedInclusionStore;

    constructor(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) {
        _bondToken = bondToken;
        _syncedBlockManager = syncedBlockManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
        _forcedInclusionStore = forcedInclusionStore;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: _bondToken,
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            maxFinalizationCount: 16,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            syncedBlockManager: _syncedBlockManager,
            proofVerifier: _proofVerifier,
            proposerChecker: _proposerChecker,
            forcedInclusionStore: _forcedInclusionStore
        });
    }
}

/// @title TestInboxOptimized1
/// @notice Test wrapper for TestInboxOptimized1 contract with configurable behavior
contract TestInboxOptimized1 is InboxOptimized1 {
    Config private config;

    address private immutable _bondToken;
    address private immutable _syncedBlockManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;
    address private immutable _forcedInclusionStore;

    constructor(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) {
        _bondToken = bondToken;
        _syncedBlockManager = syncedBlockManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
        _forcedInclusionStore = forcedInclusionStore;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: _bondToken,
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            maxFinalizationCount: 16,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            syncedBlockManager: _syncedBlockManager,
            proofVerifier: _proofVerifier,
            proposerChecker: _proposerChecker,
            forcedInclusionStore: _forcedInclusionStore
        });
    }
}

/// @title TestInboxOptimized2
/// @notice Test wrapper for TestInboxOptimized2 contract with configurable behavior
contract TestInboxOptimized2 is InboxOptimized2 {
    Config private config;

    address private immutable _bondToken;
    address private immutable _syncedBlockManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;
    address private immutable _forcedInclusionStore;

    constructor(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) {
        _bondToken = bondToken;
        _syncedBlockManager = syncedBlockManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
        _forcedInclusionStore = forcedInclusionStore;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: _bondToken,
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            maxFinalizationCount: 16,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            syncedBlockManager: _syncedBlockManager,
            proofVerifier: _proofVerifier,
            proposerChecker: _proposerChecker,
            forcedInclusionStore: _forcedInclusionStore
        });
    }
}

/// @title TestInboxOptimized3
/// @notice Test wrapper for TestInboxOptimized3 contract with configurable behavior
contract TestInboxOptimized3 is InboxOptimized3 {
    Config private config;

    address private immutable _bondToken;
    address private immutable _syncedBlockManager;
    address private immutable _proofVerifier;
    address private immutable _proposerChecker;
    address private immutable _forcedInclusionStore;

    constructor(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    ) {
        _bondToken = bondToken;
        _syncedBlockManager = syncedBlockManager;
        _proofVerifier = proofVerifier;
        _proposerChecker = proposerChecker;
        _forcedInclusionStore = forcedInclusionStore;
    }

    function getConfig() public view override returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: _bondToken,
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            maxFinalizationCount: 16,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            syncedBlockManager: _syncedBlockManager,
            proofVerifier: _proofVerifier,
            proposerChecker: _proposerChecker,
            forcedInclusionStore: _forcedInclusionStore
        });
    }
}