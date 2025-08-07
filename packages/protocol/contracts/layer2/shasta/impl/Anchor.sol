// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IAnchor } from "../iface/IAnchor.sol";
import { IBlockHashManager } from "../iface/IBlockHashManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { ISyncedBlockManager } from "contracts/shared/shasta/iface/ISyncedBlockManager.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";
import { LibMath } from "contracts/shared/libs/LibMath.sol";

/// @title Anchor
/// @notice Manages L2 state synchronization with L1 through a secure system-level interface
/// @dev Critical security component: Only updatable by a keyless system address to prevent external
/// manipulation.
///      Handles block anchoring, bond payments, and gas issuance rate adjustments.
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract, IAnchor {
    using LibMath for uint256;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @dev Maximum gas issuance adjustment per update (0.01% = 1/10000)
    uint32 private constant GAS_ISSUANCE_MAX_ADJUSTMENT_DIVISOR = 10_000;

    // -------------------------------------------------------------------------
    // Immutable Configuration
    // -------------------------------------------------------------------------

    /// @notice System address that anchors L1 state to L2 (must be keyless)
    address public immutable anchorTransactor;

    /// @notice Minimum allowed gas issuance rate to prevent extreme adjustments
    uint32 public immutable minGasIssuancePerSecond;

    /// @notice External contract dependencies
    IBondManager public immutable bondManager;
    IBlockHashManager public immutable blockHashManager;
    ISyncedBlockManager public immutable syncedBlockManager;

    // -------------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------------

    /// @dev Current anchor state (4 storage slots)
    State private _state;

    /// @dev Storage gap for future upgrades
    uint256[46] private __gap;

    constructor(
        address _anchorTransactor,
        uint32 _minGasIssuancePerSecond,
        IBondManager _bondManager,
        IBlockHashManager _blockHashManager,
        ISyncedBlockManager _syncedBlockManager
    )
        nonZeroAddr(_anchorTransactor)
        EssentialContract()
    {
        anchorTransactor = _anchorTransactor;
        minGasIssuancePerSecond = _minGasIssuancePerSecond;
        bondManager = _bondManager;
        blockHashManager = _blockHashManager;
        syncedBlockManager = _syncedBlockManager;
    }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the anchor contract with initial state
    /// @param _owner Contract owner address for admin functions
    /// @param _initialState Initial anchor state configuration
    function init(address _owner, State memory _initialState) external initializer {
        __Essential_init(_owner);
        _state = _initialState;
    }

    /// @notice Returns the current anchor state
    /// @return Current state including block info, gas issuance, and bond operations
    function getState() external view returns (State memory) {
        return _state;
    }

    /// @notice Atomically updates the anchor state with L1 synchronization data
    /// @param _newState New state containing L1 block info and configuration
    /// @param _bondOperations Bond credit operations to execute
    /// @dev Security: Only callable by the keyless anchor transactor address
    function setState(
        State memory _newState,
        LibBondOperation.BondOperation[] memory _bondOperations
    )
        external
        onlyFrom(anchorTransactor)
        nonReentrant
    {
        // Preserve anchor block data if not updating
        if (_newState.anchorBlockNumber == 0) {
            _newState.anchorBlockNumber = _state.anchorBlockNumber;
            _newState.anchorBlockHash = _state.anchorBlockHash;
            _newState.anchorStateRoot = _state.anchorStateRoot;
        } else {
            // Validate and save new anchor block data
            _validateAndSaveAnchorBlock(_newState);
        }

        // Process bond operations and update hash
        _newState.bondOperationsHash = _processBondOperations(_newState, _bondOperations);

        // Apply gas issuance rate adjustment with bounds
        _newState.gasIssuancePerSecond = _adjustGasIssuanceRate(_newState.gasIssuancePerSecond);

        // Atomically update state
        _state = _newState;

        // Save parent block hash for future verification
        _saveParentBlockHash(_newState.anchorBlockNumber);
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @dev Validates anchor block data and saves to synced block manager
    function _validateAndSaveAnchorBlock(State memory _newState) private {
        // Validate block data integrity
        if (_newState.anchorBlockHash == 0) revert InvalidAnchorBlockHash();
        if (_newState.anchorStateRoot == 0) revert InvalidAnchorStateRoot();

        // Ensure monotonic block progression
        if (_newState.anchorBlockNumber <= _state.anchorBlockNumber) {
            revert InvalidAnchorBlockNumber();
        }

        // Persist synced block data
        syncedBlockManager.saveSyncedBlock(
            ISyncedBlockManager.SyncedBlock({
                blockNumber: _newState.anchorBlockNumber,
                blockHash: _newState.anchorBlockHash,
                stateRoot: _newState.anchorStateRoot
            })
        );
    }

    /// @dev Processes bond credit operations and verifies hash consistency
    function _processBondOperations(
        State memory _newState,
        LibBondOperation.BondOperation[] memory _bondOperations
    )
        private
        returns (bytes32 resultHash_)
    {
        resultHash_ = _state.bondOperationsHash;

        // No operations needed if hash unchanged
        if (resultHash_ == _newState.bondOperationsHash) {
            if (_bondOperations.length != 0) revert BondOperationsNotEmpty();
            return _newState.bondOperationsHash;
        }

        // Process each bond operation
        uint256 length = _bondOperations.length;
        for (uint256 i; i < length; ++i) {
            LibBondOperation.BondOperation memory op = _bondOperations[i];

            // Validate operation
            if (op.receiver == address(0) || op.credit == 0) {
                revert InvalidBondOperation();
            }

            // Credit bond and update hash
            bondManager.creditBond(op.receiver, op.credit);
            resultHash_ = LibBondOperation.aggregateBondOperation(resultHash_, op);
        }

        // Verify final hash matches expected
        if (resultHash_ != _newState.bondOperationsHash) {
            revert BondOperationsHashMismatch();
        }
    }

    /// @dev Adjusts gas issuance rate within allowed bounds (±0.01% per update)
    function _adjustGasIssuanceRate(uint32 _proposedRate)
        private
        view
        returns (uint32 adjustedRate_)
    {
        // Keep current rate if no change proposed
        if (_proposedRate == 0) return _state.gasIssuancePerSecond;

        uint32 currentRate = _state.gasIssuancePerSecond;

        // Calculate allowed adjustment range
        uint32 maxAdjustment = currentRate / GAS_ISSUANCE_MAX_ADJUSTMENT_DIVISOR;

        // Define bounds with minimum floor
        uint256 lowerBound = uint256(currentRate - maxAdjustment).max(minGasIssuancePerSecond);
        uint256 upperBound = uint256(currentRate) + maxAdjustment;

        // Clamp proposed rate to bounds
        adjustedRate_ = uint32(LibMath.max(lowerBound, LibMath.min(_proposedRate, upperBound)));
    }

    /// @dev Saves parent block hash for verification
    function _saveParentBlockHash(uint256 _anchorBlockNumber) private {
        if (_anchorBlockNumber > 0) {
            uint256 parentNumber = _anchorBlockNumber - 1;
            blockHashManager.saveBlockHash(parentNumber, blockhash(parentNumber));
        }
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BondOperationsHashMismatch();
    error BondOperationsNotEmpty();
    error InvalidAnchorBlockHash();
    error InvalidAnchorBlockNumber();
    error InvalidAnchorStateRoot();
    error InvalidBondOperation();
}
