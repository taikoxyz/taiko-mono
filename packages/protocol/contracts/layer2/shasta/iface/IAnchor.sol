// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBondOperation } from "contracts/shared/shasta/libs/LibBondOperation.sol";

/// @title IAnchor
/// @notice Interface for the Anchor contract that manages L2 state synchronization with L1
/// @dev This contract stores critical state information for L2 block production and gas management
/// @custom:security-contact security@taiko.xyz
interface IAnchor {
    /// @notice State structure containing L2 synchronization data
    /// @dev Packed struct to optimize storage usage
    struct State {
        /// @notice The ID of the proposal this state belongs to
        uint48 proposalId;
        /// @notice The total number of blocks in the batch
        uint16 batchSize;
        /// @notice The index of this block within the batch
        uint16 indexInBatch;
        /// @notice Gas issuance rate per second for L2 gas management
        uint32 gasIssuancePerSecond;
        /// @notice The number of the anchor block
        uint48 anchorBlockNumber;
        /// @notice The hash of the anchor block
        bytes32 anchorBlockHash;
        /// @notice The state root of the anchor block
        bytes32 anchorStateRoot;
        /// @notice The hash of the bond operations for the current proposal
        bytes32 bondOperationsHash;
    }

    /// @notice Emitted when the anchor state is updated
    /// @param state The new state that has been set
    event StateUpdated(State state);

    /// @notice Retrieves the current anchor state
    /// @return The current State struct containing synchronization data
    function getState() external view returns (State memory);

    /// @notice Updates the anchor state with new values
    /// @param _newState The new state to be set
    /// @param _bondOperations The bond operations to be performed
    /// @dev Only callable by the authorized anchor transactor address
    function setState(
        State memory _newState,
        LibBondOperation.BondOperation[] memory _bondOperations
    )
        external;

    /// @notice Returns the address of the authorized anchor transactor
    /// @return The address that is authorized to update the anchor state
    function anchorTransactor() external view returns (address);
}
