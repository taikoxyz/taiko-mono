// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../signal/ISignalService.sol";
import "./LibBonds.sol";
import "./LibUtils.sol";

/// @title LibVerifying
/// @notice A library for handling block verification in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibVerifying {
    using LibMath for uint256;

    struct Local {
        TaikoData.SlotB b;
        uint64 blockId;
        uint64 slot;
        uint64 numBlocksVerified;
        uint24 tid;
        uint24 lastVerifiedTransitionId;
        uint16 tier;
        bytes32 blockHash;
        bytes32 syncStateRoot;
        uint64 syncBlockId;
        uint24 syncTransitionId;
        address prover;
        ITierRouter tierRouter;
    }

    error L1_BLOCK_MISMATCH();
    error L1_INVALID_CONFIG();
    error L1_TRANSITION_ID_ZERO();
    error L1_TOO_LATE();

    /// @dev Verifies up to N blocks.
    function verifyBlocks(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _maxBlocksToVerify
    )
        public
    {
        if (_maxBlocksToVerify == 0) {
            return;
        }

        Local memory local;
        local.b = _state.slotB;
        local.blockId = local.b.lastVerifiedBlockId;
        local.slot = local.blockId % _config.blockRingBufferSize;

        TaikoData.Block storage blk = _state.blocks[local.slot];
        if (blk.blockId != local.blockId) revert L1_BLOCK_MISMATCH();

        local.lastVerifiedTransitionId = blk.verifiedTransitionId;
        local.tid = local.lastVerifiedTransitionId;

        // The following scenario should never occur but is included as a
        // precaution.
        if (local.tid == 0) revert L1_TRANSITION_ID_ZERO();

        // The `blockHash` variable represents the most recently trusted
        // blockHash on L2.
        local.blockHash = _state.transitions[local.slot][local.tid].blockHash;

        // Unchecked is safe:
        // - assignment is within ranges
        // - blockId and numBlocksVerified values incremented will still be OK in the
        // next 584K years if we verifying one block per every second

        unchecked {
            ++local.blockId;

            while (
                local.blockId < local.b.numBlocks && local.numBlocksVerified < _maxBlocksToVerify
            ) {
                local.slot = local.blockId % _config.blockRingBufferSize;

                blk = _state.blocks[local.slot];
                if (blk.blockId != local.blockId) revert L1_BLOCK_MISMATCH();

                local.tid = LibUtils.getTransitionId(_state, blk, local.slot, local.blockHash);
                // When `tid` is 0, it indicates that there is no proven
                // transition with its parentHash equal to the blockHash of the
                // most recently verified block.
                if (local.tid == 0) break;

                // A transition with the correct `parentHash` has been located.
                TaikoData.TransitionState storage ts = _state.transitions[local.slot][local.tid];

                // It's not possible to verify this block if either the
                // transition is contested and awaiting higher-tier proof or if
                // the transition is still within its cooldown period.
                local.tier = ts.tier;

                if (ts.contester != address(0)) {
                    break;
                } else {
                    if (local.tierRouter == ITierRouter(address(0))) {
                        local.tierRouter =
                            ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER, false));
                    }

                    uint24 cooldown = ITierProvider(local.tierRouter.getProvider(local.blockId))
                        .getTier(local.tier).cooldownWindow;

                    if (!LibUtils.isPostDeadline(ts.timestamp, local.b.lastUnpausedAt, cooldown)) {
                        // If cooldownWindow is 0, the block can theoretically
                        // be proved and verified within the same L1 block.
                        break;
                    }
                }

                // Update variables
                local.lastVerifiedTransitionId = local.tid;
                local.blockHash = ts.blockHash;
                local.prover = ts.prover;

                LibBonds.creditBond(_state, local.prover, ts.validityBond);

                // Note: We exclusively address the bonds linked to the
                // transition used for verification. While there may exist
                // other transitions for this block, we disregard them entirely.
                // The bonds for these other transitions are burned (more precisely held in custody)
                // either when the transitions are generated or proven. In such cases, both the
                // provers and contesters of those transitions forfeit their bonds.

                emit LibUtils.BlockVerifiedV2({
                    blockId: local.blockId,
                    prover: local.prover,
                    blockHash: local.blockHash,
                    tier: local.tier
                });

                if (LibUtils.shouldSyncStateRoot(_config.stateRootSyncInternal, local.blockId)) {
                    bytes32 stateRoot = ts.stateRoot;
                    if (stateRoot != 0) {
                        local.syncStateRoot = stateRoot;
                        local.syncBlockId = local.blockId;
                        local.syncTransitionId = local.tid;
                    }
                }

                ++local.blockId;
                ++local.numBlocksVerified;
            }

            if (local.numBlocksVerified != 0) {
                uint64 lastVerifiedBlockId = local.b.lastVerifiedBlockId + local.numBlocksVerified;
                local.slot = lastVerifiedBlockId % _config.blockRingBufferSize;

                _state.slotB.lastVerifiedBlockId = lastVerifiedBlockId;
                _state.blocks[local.slot].verifiedTransitionId = local.lastVerifiedTransitionId;

                if (local.syncStateRoot != 0) {
                    _state.slotA.lastSyncedBlockId = local.syncBlockId;
                    _state.slotA.lastSynecdAt = uint64(block.timestamp);

                    // We write the synced block's verifiedTransitionId to storage
                    if (local.syncBlockId != lastVerifiedBlockId) {
                        local.slot = local.syncBlockId % _config.blockRingBufferSize;
                        _state.blocks[local.slot].verifiedTransitionId = local.syncTransitionId;
                    }

                    // Ask signal service to write cross chain signal
                    ISignalService(_resolver.resolve(LibStrings.B_SIGNAL_SERVICE, false))
                        .syncChainData(
                        _config.chainId,
                        LibStrings.H_STATE_ROOT,
                        local.syncBlockId,
                        local.syncStateRoot
                    );
                }
            }
        }
    }

    function getVerifiedBlockProver(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        uint64 _blockId
    )
        internal
        view
        returns (address)
    {
        (TaikoData.Block storage blk,) = LibUtils.getBlock(_state, _config, _blockId);

        uint32 tid = blk.verifiedTransitionId;
        if (tid == 0) return address(0);

        return LibUtils.getTransition(_state, _config, _blockId, tid).prover;
    }
}
