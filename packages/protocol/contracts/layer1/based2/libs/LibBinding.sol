// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IInbox.sol";
import "src/layer1/forced-inclusion/IForcedInclusionStore.sol";

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
        //
        /// @notice Loads a batch metadata hash
        /// @dev Assume 1 SLOAD is needed
        function(IInbox.Config memory, uint256) view returns (bytes32) loadBatchMetaHash;
        /// @notice Checks if a signal has been sent
        /// @dev Assume 1 SLOAD is needed
        function(IInbox.Config memory, bytes32) view returns (bool) isSignalSent;
        /// @notice Gets the blob hash for a given index
        function(uint256) view returns (bytes32) getBlobHash;
        /// @notice Gets a block's hash
        function (uint256) view returns(bytes32) getBlockHash;
        /// @notice Loads a transition metadata hash
        /// @dev Assume 1 SLOAD is needed
        function (IInbox.Config memory, bytes32, uint256) view returns (bytes32 , bool)
            loadTransitionMetaHash;
        /// @notice Gets the current preconfer operator address
        function() view returns (address) getCurrentPreconfer;
        /// @notice Gets the fallback preconfer address
        function() view returns (address) getFallbackPreconfer;
        /// @notice Checks if forced inclusion is due for a batch
        function(uint48) view returns (bool) isForcedInclusionDue;
        //
        // Write functions -----------------------------------------------------
        //
        /// @notice Saves a transition
        /// @dev Assume 1 SSTORE is needed
        function(IInbox.Config memory, uint48, bytes32, bytes32) returns (bool) saveTransition;
        /// @notice Syncs chain data
        /// @dev Assume 1 SSTORE is needed
        function(IInbox.Config memory, uint64, bytes32) syncChainData;
        /// @notice Saves a batch metadata hash
        /// @dev Assume 1 SSTORE is needed
        function(IInbox.Config memory, uint256, bytes32) saveBatchMetaHash;
        /// @notice Transfers fees between addresses
        function(address, address, address, uint256) transferFee;
        /// @notice Credits bond to a user
        function(address, uint256) creditBond;
        /// @notice Debits bond from a user
        function(IInbox.Config memory, address, uint256) debitBond;
        /// @notice Consumes the oldest forced inclusion
        function(address, uint64) returns (IForcedInclusionStore.ForcedInclusion memory)
            consumeForcedInclusion;
        //
        // Encoding functions -----------------------------------------------------
        //
        function(IInbox.BatchContext[] memory) pure returns (bytes memory) encodeBatchContexts;
        function(IInbox.TransitionMeta[] memory) pure returns (bytes memory) encodeTransitionMetas;
        function(IInbox.Summary memory) pure returns (bytes memory) encodeSummary;
        // Decoding functions -----------------------------------------------------
        function(bytes memory) pure returns (
            IInbox.Summary memory, IInbox.Batch[] memory,
            IInbox.ProposeBatchEvidence memory,
            IInbox.TransitionMeta[] memory) decodeProposeBatchesInputs;
        function(bytes memory) pure returns (IInbox.ProverAuth memory) decodeProverAuth;
        function(bytes memory) pure returns (IInbox.Summary memory) decodeSummary;
        function(bytes memory) pure returns (IInbox.ProveBatchInput[] memory)
            decodeProveBatchesInputs;
    }
}
