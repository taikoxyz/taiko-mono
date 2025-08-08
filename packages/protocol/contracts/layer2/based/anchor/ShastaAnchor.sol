// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/based/LibSharedData.sol";
import "./PacayaAnchor.sol";
import "src/shared/shasta/iface/ISyncedBlockManager.sol";
import { IShastaBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    error InvalidForkHeight();
    error NonZeroAnchorStateRoot();
    error ZeroAnchorStateRoot();

    // The v4Anchor's transaction gas limit, this value must be enforced by the node and prover.
    // When there are 16 signals in v4Anchor's parameter, the estimated gas cost is actually
    // around 361,579 gas.  We set the limit to 1,000,000 to be safe.
    uint256 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    IShastaBondManager immutable bondManager;
    ISyncedBlockManager immutable syncedBlockManager;
    uint48 public anchorBlockNumber;

    uint256[49] private __gap;

    constructor(
        address _signalService,
        uint64 _pacayaForkHeight,
        uint64 _shastaForkHeight,
        ISyncedBlockManager _syncedBlockManager,
        IShastaBondManager _bondManager
    )
        PacayaAnchor(_signalService, _pacayaForkHeight, _shastaForkHeight)
    {
        require(
            _shastaForkHeight == 0 || _shastaForkHeight > _pacayaForkHeight, InvalidForkHeight()
        );
        syncedBlockManager = _syncedBlockManager;
        bondManager = _bondManager;
    }

    function anchor4(
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot,
        LibBondOperation.BondOperation[] calldata _bondOperations
    )
        external
        onlyGoldenTouch
        nonReentrant
    {
        require(block.number >= shastaForkHeight, L2_FORK_ERROR());

        uint256 parentId = block.number - 1;
        _verifyAndUpdatePublicInputHash(parentId);

        // Store the parent block hash in the _blockhashes mapping.
        _blockhashes[parentId] = blockhash(parentId);

        if (_anchorBlockNumber > anchorBlockNumber) {
            // This block must be the last block in the batch.
            require(_anchorBlockHash != 0, ZeroAnchorBlockHash());
            require(_anchorStateRoot != 0, ZeroAnchorStateRoot());

            anchorBlockNumber = _anchorBlockNumber;

            syncedBlockManager.saveSyncedBlock(
                _anchorBlockNumber, _anchorBlockHash, _anchorStateRoot
            );
        } else {
            // This block must not be the last block in the batch.
            require(_anchorBlockHash == 0, NonZeroAnchorBlockHash());
            require(_anchorStateRoot == 0, NonZeroAnchorStateRoot());
        }

        // Process each bond operation
        for (uint256 i; i < _bondOperations.length; ++i) {
            LibBondOperation.BondOperation memory op = _bondOperations[i];
            bondManager.creditBond(op.receiver, op.credit);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error NonZeroAnchorBlockHash();
    error ZeroAnchorBlockHash();
}
