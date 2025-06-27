// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/shared/libs/LibMath.sol";
import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";
import "./LibBonds2.sol";
import "./LibFork2.sol";
import "./LibData2.sol";
import "./LibPropose2.sol";

/// @title LibVerify2
/// @custom:security-contact security@taiko.xyz
library LibVerify2 {
    using LibMath for uint256;

    error TransitionNotProvided();
    error TransitionMetaMismatch();

    function verifyBatches(
        LibPropose2.Environment memory _env,
        I.Summary memory _summary,
        I.TransitionMeta[] calldata _trans
    )
        internal
        returns (I.Summary memory)
    {
        unchecked {
            uint48 batchId = _summary.lastVerifiedBatchId + 1;

            if (!LibFork2.isBlocksInCurrentFork(_env.conf, batchId, batchId)) {
                return _summary;
            }
            uint256 stopBatchId = uint256(_summary.numBatches).min(
                _env.conf.maxBatchesToVerify + _summary.lastVerifiedBatchId + 1
            );

            uint256 nTransitions = _trans.length;
            uint256 i;
            uint48 lastSyncedBlockId;
            bytes32 lastSyncedStateRoot;

            for (; batchId < stopBatchId; ++batchId) {
                bytes32 tranMetaHash =
                    _env.loadTransitionMetaHash(_env.conf, _summary.lastVerifiedBlockHash, batchId);

                if (tranMetaHash == 0) break;

                require(i < nTransitions, TransitionNotProvided());
                require(tranMetaHash == keccak256(abi.encode(_trans[i])), TransitionMetaMismatch());

                _summary.lastVerifiedBlockHash = _trans[i].blockHash;

                if (batchId % _env.conf.stateRootSyncInternal == 0) {
                    lastSyncedBlockId = _trans[i].lastBlockId;
                    lastSyncedStateRoot = _trans[i].stateRoot;
                }

                i++;
            }

            if (lastSyncedBlockId != 0) {
                _summary.lastSyncedBlockId = lastSyncedBlockId;
                _summary.lastSyncedAt = uint48(block.timestamp);

                _env.syncChainData(_env.conf, lastSyncedBlockId, lastSyncedStateRoot);
            }

            return _summary;
        }
    }
}
