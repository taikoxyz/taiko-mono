// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibBondsL1
/// @notice Library for L1-specific bond instruction calculations
/// @dev This library contains L1-specific bond logic that depends on IInbox interfaces
/// @custom:security-contact security@taiko.xyz
library LibBondsL1 {
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
            if (_newInstructions.length == 0) {
                return _existingInstructions;
            }

            if (_existingInstructions.length == 0) {
                return _newInstructions;
            }

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
    /// @param _transition Transition with designated and actual prover addresses
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
    function calculateBondInstructions(
        uint48 _provingWindow,
        uint48 _extendedProvingWindow,
        IInbox.Proposal memory _proposal,
        IInbox.Transition memory _transition
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
                ? (_transition.designatedProver != _transition.actualProver)
                : (_proposal.proposer != _transition.actualProver);

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
                payer: isWithinExtendedWindow ? _transition.designatedProver : _proposal.proposer,
                receiver: _transition.actualProver
            });
        }
    }
}
