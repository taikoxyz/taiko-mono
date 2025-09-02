// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibBondsL1
/// @notice Library for L1-specific bond instruction calculations
/// @dev This library contains L1-specific bond logic that depends on IInbox interfaces
/// @custom:security-contact security@taiko.xyz
library LibBondsL1 {
    /// @notice Calculates bond instructions based on proof timing and prover identity
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs from designated
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover differs from proposer
    /// @param _config Configuration containing timing windows
    /// @param _proposal Proposal with timestamp and proposer address
    /// @param _transition Transition with designated and actual prover addresses
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same prover)
    function calculateBondInstructions(
        IInbox.Config memory _config,
        IInbox.Proposal memory _proposal,
        IInbox.Transition memory _transition
    )
        internal
        view
        returns (LibBonds.BondInstruction[] memory bondInstructions_)
    {
        unchecked {
            uint256 proofTimestamp = block.timestamp;
            uint256 windowEnd = _proposal.timestamp + _config.provingWindow;

            // On-time proof - no bond instructions needed
            if (proofTimestamp <= windowEnd) {
                return new LibBonds.BondInstruction[](0);
            }

            // Late or very late proof - determine bond type and parties
            uint256 extendedWindowEnd = _proposal.timestamp + _config.extendedProvingWindow;
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