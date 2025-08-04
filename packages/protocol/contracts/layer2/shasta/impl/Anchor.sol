// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IAnchor } from "../iface/IAnchor.sol";
import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";

/// @title Anchor
/// @notice Contract that manages L2 state synchronization with L1
/// @dev This contract is critical for maintaining consistency between L1 and L2 state.
///      It can only be updated by a special system address that has no private key,
///      ensuring updates come from the L2 system itself rather than external actors.
/// @custom:security-contact security@taiko.xyz
contract Anchor is IAnchor {
    /// @dev The address of the anchor transactor which shall NOT have a private key
    /// @dev This is a system address that only the L2 node can use to update state

    address public immutable anchorTransactor;
    IBondManager public immutable bondManager;

    /// @dev Private storage for the current anchor state
    State private _state;

    /// @dev Restricts function access to only the authorized anchor transactor
    modifier onlyAuthorized() {
        if (msg.sender != anchorTransactor) revert Unauthorized();
        _;
    }

    constructor(address _anchorTransactor, IBondManager _bondManager) {
        bondManager = _bondManager;
        anchorTransactor = _anchorTransactor;
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
        BondOperation[] memory _bondOperations
    )
        external
        onlyAuthorized
    {
        bytes32 bondOperationsHash = _state.bondOperationsHash;
        for (uint256 i; i < _bondOperations.length; ++i) {
            bondOperationsHash = keccak256(abi.encode(bondOperationsHash, _bondOperations[i]));
            bondManager.creditBond(_bondOperations[i].receiver, _bondOperations[i].credit);
        }
        if (bondOperationsHash != _newState.bondOperationsHash) revert BondOperationsHashMismatch();

        _newState.gasIssuancePerSecond = _newState.indexInBatch + 1 == _newState.batchSize
            ? _newState.gasIssuancePerSecond
            : _state.gasIssuancePerSecond;

        _state = _newState;
        emit StateUpdated(_newState);
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error Unauthorized();
    error BondOperationsHashMismatch();
}
