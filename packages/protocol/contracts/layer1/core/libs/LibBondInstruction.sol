// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibBondInstruction
/// @notice Library for L1-specific bond instruction calculations
/// @dev This library contains L1-specific bond logic that depends on IInbox interfaces
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint256 private constant _ASSEMBLY_THRESHOLD = 8;

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Merges two bond instruction arrays into a single array
    /// @dev Optimized for memory allocation and copying to reduce gas costs
    /// Uses assembly bulk-copy for larger arrays, falls back to loop-based copying for smaller
    /// arrays
    /// @param _existingInstructions The existing bond instructions array
    /// @param _newInstructions The new bond instructions array to merge
    /// @return merged_ The merged bond instructions array
    function mergeBondInstructions(
        LibBonds.BondInstruction[] memory _existingInstructions,
        LibBonds.BondInstruction[] memory _newInstructions
    )
        public
        pure
        returns (LibBonds.BondInstruction[] memory merged_)
    {
        unchecked {
            uint256 totalLen = _existingInstructions.length + _newInstructions.length;

            // Break-even point: use assembly bulk-copy for arrays with more than 8 elements total
            // Below this threshold, the overhead of assembly operations outweighs the benefits
            // The constant 8 was determined through gas testing: assembly operations have fixed
            // overhead that only becomes profitable when copying larger amounts of data
            return totalLen > _ASSEMBLY_THRESHOLD
                ? _bulkCopyBondInstructions(_existingInstructions, _newInstructions)
                : _loopCopyBondInstructions(_existingInstructions, _newInstructions);
        }
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Calculates bond instructions based on proof timing and prover identity
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs from
    ///           designated
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover
    ///           differs from proposer
    /// @param _provingWindow The proving window in seconds
    /// @param _extendedProvingWindow The extended proving window in seconds
    /// @param _proposal Proposal with timestamp and proposer address
    /// @param _metadata Metadata with designated and actual prover addresses
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
    function calculateBondInstructions(
        uint48 _provingWindow,
        uint48 _extendedProvingWindow,
        IInbox.Proposal memory _proposal,
        IInbox.TransitionMetadata memory _metadata
    )
        internal
        view
        returns (LibBonds.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            uint256 proofTimestamp = block.timestamp;
            uint256 windowEnd = _proposal.timestamp + _provingWindow;

            // On-time proof - no bond instructions needed
            if (proofTimestamp <= windowEnd) {
                return new LibBonds.BondInstruction[](0);
            }

            // Late or very late proof - determine bond type and parties
            uint256 extendedWindowEnd = _proposal.timestamp + _extendedProvingWindow;
            bool isWithinExtendedWindow = proofTimestamp <= extendedWindowEnd;

            // Check if bond instruction is needed
            bool needsBondInstruction = isWithinExtendedWindow
                ? (_metadata.designatedProver != _metadata.actualProver)
                : (_proposal.proposer != _metadata.actualProver);

            if (!needsBondInstruction) {
                return new LibBonds.BondInstruction[](0);
            }

            // Create single bond instruction
            bondInstructions_ = new LibBonds.BondInstruction[](1);
            bondInstructions_[0] = LibBonds.BondInstruction({
                proposalId: _proposal.id,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: isWithinExtendedWindow ? _metadata.designatedProver : _proposal.proposer,
                payee: _metadata.actualProver
            });
        }
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Assembly-optimized bulk copy for larger arrays
    /// @param _existing The existing instructions to copy first
    /// @param _new The new instructions to append
    /// @return merged_ The merged bond instructions array
    function _bulkCopyBondInstructions(
        LibBonds.BondInstruction[] memory _existing,
        LibBonds.BondInstruction[] memory _new
    )
        private
        pure
        returns (LibBonds.BondInstruction[] memory merged_)
    {
        uint256 existingLen = _existing.length;
        uint256 newLen = _new.length;

        uint256 totalLen;
        unchecked {
            totalLen = existingLen + newLen;
        }

        merged_ = new LibBonds.BondInstruction[](totalLen);

        assembly {
            let mergedPtr := add(merged_, 0x20)
            let existingPtr := add(_existing, 0x20)
            let newPtr := add(_new, 0x20)

            // Each BondInstruction is 128 bytes (4 * 32 bytes)
            // In memory arrays, each field occupies a full 32-byte slot:
            // proposalId (uint48 -> 32 bytes), bondType (enum -> 32 bytes),
            // payer (address -> 32 bytes), receiver (address -> 32 bytes)
            let instructionSize := 0x80

            // Copy existing instructions using bulk memory copy
            if gt(existingLen, 0) {
                let existingBytes := mul(existingLen, instructionSize)

                // Use efficient word-based copying
                let words := div(add(existingBytes, 0x1f), 0x20)
                for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                    mstore(add(mergedPtr, mul(i, 0x20)), mload(add(existingPtr, mul(i, 0x20))))
                }
            }

            // Copy new instructions starting after existing ones
            if gt(newLen, 0) {
                let newBytes := mul(newLen, instructionSize)
                let destOffset := mul(existingLen, instructionSize)
                let destPtr := add(mergedPtr, destOffset)

                // Use efficient word-based copying
                let words := div(add(newBytes, 0x1f), 0x20)
                for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                    mstore(add(destPtr, mul(i, 0x20)), mload(add(newPtr, mul(i, 0x20))))
                }
            }
        }
    }

    /// @dev Loop-based copy for smaller arrays to avoid assembly overhead
    /// @param _existing The existing instructions to copy first
    /// @param _new The new instructions to append
    /// @return merged_ The merged bond instructions array
    function _loopCopyBondInstructions(
        LibBonds.BondInstruction[] memory _existing,
        LibBonds.BondInstruction[] memory _new
    )
        private
        pure
        returns (LibBonds.BondInstruction[] memory merged_)
    {
        unchecked {
            uint256 existingLen = _existing.length;
            uint256 newLen = _new.length;

            uint256 totalLen = existingLen + newLen;

            merged_ = new LibBonds.BondInstruction[](totalLen);

            // Copy existing instructions - safe to use unchecked since arrays are pre-allocated
            for (uint256 i; i < existingLen; ++i) {
                merged_[i] = _existing[i];
            }

            // Copy new instructions
            for (uint256 i; i < newLen; ++i) {
                merged_[existingLen + i] = _new[i];
            }
        }
    }
}
