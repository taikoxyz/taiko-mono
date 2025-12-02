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
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
    function calculateBondInstructions(
        uint40 _provingWindow,
        uint40 _extendedProvingWindow,
        uint40 _proposalId,
        IInbox.ProposalProofMetadata memory _proofMetadata
    )
        internal
        view
        returns (LibBonds.BondInstruction[] memory bondInstructions_)
    {
        bondInstructions_ = new LibBonds.BondInstruction[](1);

            uint256 windowEnd = _proofMetadata.proposalTimestamp + _provingWindow;
            if (block.timestamp <= windowEnd) return new LibBonds.BondInstruction[](0);

            uint256 extendedWindowEnd = _proofMetadata.proposalTimestamp + _extendedProvingWindow;
            bool isWithinExtendedWindow = block.timestamp <= extendedWindowEnd;

            bool needsBondInstruction = isWithinExtendedWindow
                ? (_proofMetadata.actualProver != _proofMetadata.designatedProver)
                : (_proofMetadata.actualProver != _proofMetadata.proposer);

            if (!needsBondInstruction) return new LibBonds.BondInstruction[](0);

 bondInstructions_ = new LibBonds.BondInstruction[](1);
bondInstructions_[0] = LibBonds.BondInstruction({
                proposalId: _proposalId,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: isWithinExtendedWindow
                    ? _proofMetadata.designatedProver
                    : _proofMetadata.proposer,
                payee: _proofMetadata.actualProver
            });
    }
}
