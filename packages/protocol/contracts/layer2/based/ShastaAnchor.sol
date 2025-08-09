// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PacayaAnchor } from "./PacayaAnchor.sol";
import { ISyncedBlockManager } from "src/shared/shasta/iface/ISyncedBlockManager.sol";
import { IShastaBondManager } from "src/shared/shasta/iface/IBondManager.sol";
import { LibBondOperation } from "src/shared/shasta/libs/LibBondOperation.sol";

/// @title ShastaAnchor
/// @notice Anchoring functions for the Shasta fork.
/// @custom:security-contact security@taiko.xyz
abstract contract ShastaAnchor is PacayaAnchor {
    // ---------------------------------------------------------------2
    // Structs
    // ---------------------------------------------------------------2

    struct State {
        bytes32 bondOperationsHash;
        uint48 anchorBlockNumber;
    }

    // ---------------------------------------------------------------2
    // State variables
    // ---------------------------------------------------------------2

    // The v4Anchor's transaction gas limit, this value must be enforced
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    bytes32 public bondOperationsHash;
    uint48 public anchorBlockNumber;

    uint256[48] private __gap;

    // ---------------------------------------------------------------2----
    // Constructor
    // ---------------------------------------------------------------2----

    /// @notice Initializes the ShastaAnchor contract.
    /// @param _signalService The address of the signal service.
    /// @param _pacayaForkHeight The block height at which the Pacaya fork is activated.
    /// @param _shastaForkHeight The block height at which the Shasta fork is activated.
    /// @param _syncedBlockManager The address of the synced block manager.
    /// @param _bondManager The address of the bond manager.
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

    // ---------------------------------------------------------------2
    // External functions
    // ---------------------------------------------------------------2

    /// @notice Sets the state of the anchor, including the latest L1 block details and bond
    /// operations.
    /// @param _anchorBlockNumber The anchor block number.
    /// @param _anchorBlockHash The anchor block hash.
    /// @param _anchorStateRoot The anchor state root.
    /// @param _bondOperationsHash The hash of all bond operations.
    /// @param _bondOperations Array of bond operations to process.
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

        if (_bondOperationsHash != 0) {
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
    }

    /// @notice Returns the current state of the anchor.
    /// @return state_ The current state.
    function getState() external view returns (State memory state_) {
        state_ = State({
            anchorBlockNumber: anchorBlockNumber,
            bondOperationsHash: bondOperationsHash   
        });
    }

    // ---------------------------------------------------------------2
    // Errors
    // ---------------------------------------------------------------2

    error BondOperationsHashMismatch();
    error InvalidForkHeight();
    error InvalidGasIssuancePerSecond();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error ZeroAnchorBlockHash();
    error ZeroAnchorStateRoot();
}
