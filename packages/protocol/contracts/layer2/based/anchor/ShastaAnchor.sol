// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PacayaAnchor.sol";
import { ISyncedBlockManager } from "src/shared/shasta/iface/ISyncedBlockManager.sol";
import { IShastaBondManager } from "src/shared/shasta/iface/IBondManager.sol";
import { LibBondOperation } from "src/shared/shasta/libs/LibBondOperation.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    struct State {
        uint48 anchorBlockNumber;
        bytes32 bondOperationsHash;
        uint64 anchorGasLimit;
        address anchorTransactor;
    }

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    // The v4Anchor's transaction gas limit, this value must be enforced
    uint64 private constant _ANCHOR_GAS_LIMIT = 200_000;

    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;
    
    uint48 public anchorBlockNumber;
    bytes32 public bondOperationsHash;

    uint256[48] private __gap;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

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

    // ---------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------

    function setState(
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot,
        bytes32 _bondOperationsHash,
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
        bytes32 h = bondOperationsHash;
        for (uint256 i; i < _bondOperations.length; ++i) {
            LibBondOperation.BondOperation memory op = _bondOperations[i];
            bondManager.creditBond(op.receiver, op.credit);
            h = LibBondOperation.aggregateBondOperation(h, op);
        }
        require(h == _bondOperationsHash, BondOperationsHashMismatch());
        bondOperationsHash = _bondOperationsHash;
    }

    function getState() external view returns (State memory) {
        return State({
            anchorBlockNumber: anchorBlockNumber,
            bondOperationsHash: bondOperationsHash,
            anchorGasLimit: _ANCHOR_GAS_LIMIT,
            anchorTransactor: GOLDEN_TOUCH_ADDRESS
        });
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BondOperationsHashMismatch();
    error InvalidForkHeight();
    error InvalidGasIssuancePerSecond();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error ZeroAnchorBlockHash();
    error ZeroAnchorStateRoot();
}
