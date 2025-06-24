// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBonds2.sol";
import "./LibFork.sol";
import "./LibData2.sol";

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
        _stats2 = _verifyBatches($, _config, _stats2, _count);
        $.stats2 = _stats2;
        emit I.Stats2Updated(_stats2);
    }

    function _verifyBatches(
        I.State storage $,
        I.Config memory _config,
        I.Stats2 memory _stats2,
        uint256 _count
    )
        private
        returns (I.Stats2 memory stats2_)
    {
        stats2_ = _stats2; // make a copy for update

        // the i-th batch is the first one to verify
        uint64 i = stats2_.lastVerifiedBatchId + 1;

        if (_stats2.paused || !LibFork.isBlocksInCurrentFork(_config, i, i)) {
            return stats2_;
        }
        uint256 stopBatchId = uint256(stats2_.numBatches).min(
            _count * _config.maxBatchesToVerify + stats2_.lastVerifiedBatchId + 1
        );

        // uint256 nBatches = stopBatchId - i;

        for (; i < stopBatchId; ++i) {
            uint256 slot = i % _config.batchRingBufferSize;

            bytes32 firstTransitionParentHash = $.transitions[slot][1].parentHash; // 1 SLOAD
            if (firstTransitionParentHash == LibData2.FIRST_TRAN_PARENT_HASH_PLACEHOLDER) {
                // this batch is not proved with at least one transition
                break;
            }

            I.Batch memory batch = $.batches[slot]; // 1 SLOAD
        }
    }
}
