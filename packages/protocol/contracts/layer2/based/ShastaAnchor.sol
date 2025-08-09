// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { PacayaAnchor } from "./PacayaAnchor.sol";
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
        bytes32 bondOperationsHash;
        uint48 anchorBlockNumber;
    }

    struct ProverAuth {
        uint48 proposalId;
        address proposer;
        bytes signature;
    }

    // ---------------------------------------------------------------
    // State variables
    // ---------------------------------------------------------------

    // The v4Anchor's transaction gas limit, this value must be enforced
    uint64 public constant ANCHOR_GAS_LIMIT = 1_000_000;

    uint48 public immutable livenessBondGwei;
    uint48 public immutable provabilityBondGwei;

    IShastaBondManager public immutable bondManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    bytes32 public bondOperationsHash;
    uint48 public anchorBlockNumber;

    uint256[48] private __gap;

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

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

    // ---------------------------------------------------------------
    // External functions
    // ---------------------------------------------------------------

    /// @notice Sets the state of the anchor, including the latest L1 block details and bond
    /// operations.
    /// @param _proposalId The proposal ID.
    /// @param _blockIndex The index of the block in the proposal.
    /// @param _blockCount The total number of blocks in the proposal.
    /// @param _proposer The address of the proposer.
    /// @param _anchorBlockNumber The anchor block number.
    /// @param _anchorBlockHash The anchor block hash.
    /// @param _anchorStateRoot The anchor state root.
    /// @param _bondOperationsHash The hash of all bond operations.
    /// @param _bondOperations Array of bond operations to process.
    function setState(
        uint48 _proposalId,
        uint32 _blockIndex,
        uint32 _blockCount,
        address _proposer,
        uint48 _anchorBlockNumber,
        bytes32 _anchorBlockHash,
        bytes32 _anchorStateRoot,
        bytes32 _bondOperationsHash,
        LibBondOperation.BondOperation[] calldata _bondOperations,
        ProverAuth calldata _proverAuth
    )
        external
        onlyGoldenTouch
        nonReentrant
        returns (address designatedProver_)
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

            if (_blockIndex == 0) {
                designatedProver_ = _verifyProverAuth(_proposalId, _proposer, _proverAuth);
            }
        }
    }

    /// @notice Returns the current state of the anchor.
    /// @return state_ The current state.
    function getState() external view returns (State memory state_) {
        state_ =
            State({ anchorBlockNumber: anchorBlockNumber, bondOperationsHash: bondOperationsHash });
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _verifyProverAuth(
        uint48 _proposalId,
        address _proposer,
        ProverAuth calldata _proverAuth
    )
        private
        returns (address)
    {
        if (_proverAuth.proposalId == 0) {
            require(_proverAuth.proposer == address(0), InvalidProverAuth());
            require(_proverAuth.signature.length == 0, InvalidProverAuth());
            return address(0);
        }
        if (_proverAuth.proposalId != _proposalId) return address(0);
        if (_proverAuth.proposer != _proposer) return address(0);

        bytes32 message = keccak256(abi.encode(_proverAuth.proposalId, _proverAuth.proposer));
        address signer = ECDSA.recover(message, _proverAuth.signature);

        if (signer == address(0) || signer != _proposer) return address(0);

        uint48 totalBondRequired = provabilityBondGwei + livenessBondGwei;
        if (bondManager.getBondBalance(signer) < totalBondRequired) return address(0);

        bondManager.debitBond(signer, totalBondRequired);
        return signer;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error BondOperationsHashMismatch();
    error InvalidForkHeight();
    error InvalidProverAuth();
    error NonZeroAnchorBlockHash();
    error NonZeroAnchorStateRoot();
    error ZeroAnchorBlockHash();
    error ZeroAnchorStateRoot();
}
