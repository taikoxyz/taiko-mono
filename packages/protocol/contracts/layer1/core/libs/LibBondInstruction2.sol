// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox2 } from "../iface/IInbox2.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibBondInstruction
/// @notice Library for L1-specific bond instruction calculations
/// @dev This library contains L1-specific bond logic that depends on IInbox2 interfaces
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction2 {
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
        IInbox2.Proposal memory _proposal,
        IInbox2.TransitionMetadata memory _metadata
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
}
