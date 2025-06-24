// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBonds2.sol";

/// @title LibVerify2
/// @custom:security-contact security@taiko.xyz
library LibVerify2 {
    using LibMath for uint256;

    struct SyncBlock {
        uint64 batchId;
        uint64 blockId;
        uint24 tid;
        bytes32 stateRoot;
    }

    struct Env {
        address signalService;
        I.Config config;
    }

    function verifyBatches(
        I.State storage $,
        I.Config memory _config,
        I.Stats2 memory _stats2,
        uint8 _count
    )
        internal
    {
        _stats2 = _verifyBatches();
        $.stats2 = _stats2;
        emit I.Stats2Updated(_stats2);
    }

    function _verifyBatches() private returns (I.Stats2 memory stats2_) { }
}
