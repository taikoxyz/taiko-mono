// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { EssentialContract } from "contracts/shared/common/EssentialContract.sol";
import { IAnchor } from "../iface/IAnchor.sol";
import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";
import { IBlockHashManager } from "../iface/IBlockHashManager.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";

/// @title Anchor
/// @notice Contract that manages L2 state synchronization with L1
/// @dev This contract is critical for maintaining consistency between L1 and L2 state.
///      It can only be updated by a special system address that has no private key,
///      ensuring updates come from the L2 system itself rather than external actors.
/// @custom:security-contact security@taiko.xyz
contract Anchor is EssentialContract, IAnchor {
    /// @dev The address of the anchor transactor which shall NOT have a private key
    /// @dev This is a system address that only the L2 node can use to update state

    address public immutable anchorTransactor;
    IBondManager public immutable bondManager;
    IBlockHashManager public immutable blockHashManager;

    /// @dev Private storage for the current anchor state
    State private _state;

    uint256[49] private __gap;

    constructor(
        address _anchorTransactor,
        IBondManager _bondManager,
        IBlockHashManager _blockHashManager
    )
        nonZeroAddr(_anchorTransactor)
        nonZeroAddr(address(_bondManager))
        nonZeroAddr(address(_blockHashManager))
        EssentialContract()
    {
        bondManager = _bondManager;
        anchorTransactor = _anchorTransactor;
        blockHashManager = _blockHashManager;
    }

    /// @notice Initialize the contract
    /// @param _owner The owner of the contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Retrieves the current anchor state
    /// @return The current State struct containing synchronization data
    function getState() external view returns (State memory) {
        return _state;
    }

    /// @notice Updates the anchor state with new values
    /// @param _newState The new state to be set
    /// @param _bondOperations The bond operations to be performed
    /// @dev Only the anchor transactor address can call this function
    ///      This ensures state updates come from the L2 system itself
    function setState(
        State memory _newState,
        LibBondOperation.BondOperation[] memory _bondOperations
    )
        external
        onlyFrom(anchorTransactor)
    {
        _processAnchorBlock(_newState);
        _processBondOperations(_newState, _bondOperations);
        _processGasIssuance(_newState);

        emit StateUpdated(_newState);

        uint256 parentBlockNumber = _newState.anchorBlockNumber - 1;
        blockHashManager.saveBlockHash(parentBlockNumber, blockhash(parentBlockNumber));
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    function _processAnchorBlock(State memory _newState) private {
        if (_newState.anchorBlockNumber == 0) return;
        if (_newState.anchorBlockNumber <= _state.anchorBlockNumber) {
            revert InvalidAnchorBlockNumber();
        }
        if (_newState.anchorBlockHash == bytes32(0)) revert InvalidAnchorBlockHash();

        blockHashManager.saveBlockHash(_newState.anchorBlockNumber, _newState.anchorBlockHash);
        _state.anchorBlockNumber = _newState.anchorBlockNumber;
        _state.anchorBlockHash = _newState.anchorBlockHash;
    }

    function _processBondOperations(
        State memory _newState,
        LibBondOperation.BondOperation[] memory _bondOperations
    )
        private
    {
        bytes32 bondOperationsHash = _state.bondOperationsHash;
        for (uint256 i; i < _bondOperations.length; ++i) {
            if (_bondOperations[i].receiver != address(0) && _bondOperations[i].credit != 0) {
                bondManager.creditBond(_bondOperations[i].receiver, _bondOperations[i].credit);

                bondOperationsHash =
                    LibBondOperation.aggregateBondOperation(bondOperationsHash, _bondOperations[i]);
            }
        }
        if (bondOperationsHash != _newState.bondOperationsHash) revert BondOperationsHashMismatch();
        _state.bondOperationsHash = _newState.bondOperationsHash;
    }

    function _processGasIssuance(State memory _newState) private {
        if (_newState.indexInBatch + 1 != _newState.batchSize) return;
        _state.gasIssuancePerSecond = _newState.gasIssuancePerSecond;
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error BondOperationsHashMismatch();
    error InvalidAnchorBlockNumber();
    error InvalidAnchorBlockHash();
}
