// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "../IInbox.sol";

/// @title LibBinding
/// @notice Library for read/write state and encoding/decoding functions.
/// @custom:security-contact security@taiko.xyz
library LibBinding {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    /// @notice Structure containing function pointers for read and write operations
    /// @dev This pattern allows libraries to interact with external contracts
    ///      without direct dependencies
    struct Bindings {
        // Read functions ------------------------------------------------------

        /// @notice Loads a batch metadata hash
        /// @dev Assume 1 SLOAD is needed
        function(I.Config memory, uint256) view returns (bytes32) loadBatchMetaHash;
        /// @notice Checks if a signal has been sent
        /// @dev Assume 1 SLOAD is needed
        function(I.Config memory, bytes32) view returns (bool) isSignalSent;
        /// @notice Gets the blob hash for a given index
        function(uint256) view returns (bytes32) getBlobHash;
        /// @notice Gets a block's hash
        function (uint256) view returns(bytes32) getBlockHash;
        /// @notice Loads a transition metadata hash
        /// @dev Assume 1 SLOAD is needed
        function (I.Config memory, bytes32, uint256) view returns (bytes32 , bool)
            loadTransitionMetaHash;
        // Write functions -----------------------------------------------------

        /// @notice Saves a transition
        /// @dev Assume 1 SSTORE is needed
        function(I.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        /// @notice Syncs chain data
        /// @dev Assume 1 SSTORE is needed
        function(I.Config memory, uint64, bytes32) syncChainData;
        /// @notice Saves a batch metadata hash
        /// @dev Assume 1 SSTORE is needed
        function(I.Config memory, uint256, bytes32) saveBatchMetaHash;
        /// @notice Transfers fees between addresses
        function(address, address, address, uint256) transferFee;
        /// @notice Credits bond to a user
        function(address, uint256) creditBond;
        /// @notice Debits bond from a user
        function(I.Config memory, address, uint256) debitBond;
        // Encoding functions -----------------------------------------------------
        function(I.BatchContext memory) pure returns (bytes memory) encodeBatchContext;
        function(I.TransitionMeta[] memory) pure returns (bytes memory) encodeTransitionMetas;
        function(I.Summary memory) pure returns (bytes memory) encodeSummary;
        // Decoding functions -----------------------------------------------------
        function(bytes memory) pure returns (
            I.Summary memory, I.Batch[] memory,
            I.BatchProposeMetadataEvidence memory,
            I.TransitionMeta[] memory) decodeProposeBatchesInputs;
        function(bytes memory) pure returns (I.ProverAuth memory) decodeProverAuth;
        function(bytes memory) pure returns (I.Summary memory) decodeSummary;
        function(bytes memory) pure returns (I.BatchProveInput[] memory) decodeProveBatchesInputs;
    }
}
