// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox2 as I } from "../ITaikoInbox2.sol";

/// @title LibState
/// @notice Library for read/write state data.addmod
/// @custom:security-contact security@taiko.xyz
library LibState {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Structure containing function pointers for read and write operations
    /// @dev This pattern allows libraries to interact with external contracts
    ///      without direct dependencies
    struct ReadWrite {
        // Read functions
        /// @notice Loads a batch metadata hash
        function (I.Config memory, uint256) view returns (bytes32) loadBatchMetaHash;
        /// @notice Checks if a signal has been sent
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        /// @notice Gets the blob hash for a given index
        function(uint256) view returns (bytes32) getBlobHash;
        function (I.Config memory, bytes32, uint256) view returns (bytes32 , bool)
            loadTransitionMetaHash;
        // Write functions
        /// @notice Saves a transition
        function(I.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        /// @notice Transfers fees between addresses
        function(address, address, address, uint256) transferFee;
        /// @notice Credits bond to a user
        function(address, uint256) creditBond;
        /// @notice Debits bond from a user
        function(I.Config memory, address, uint256) debitBond;
        /// @notice Syncs chain data
        function(I.Config memory, uint64, bytes32) syncChainData;
        /// @notice Saves a batch metadata hash
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
    }
}
