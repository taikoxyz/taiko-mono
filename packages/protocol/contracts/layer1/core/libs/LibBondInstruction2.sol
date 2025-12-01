// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox2 } from "../iface/IInbox2.sol";
import { LibBonds2 } from "src/shared/libs/LibBonds2.sol";

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
    /// @return bondInstructions_ Array of bond transfer instructions (empty if on-time or same
    /// prover)
    function calculateBondInstructions(
        uint40 _provingWindow,
        uint40 _extendedProvingWindow,
        uint40 _startProposalId,
        IInbox2.ProposalProofMetadata[] memory _prposalProofMetadatas
    )
        internal
        view
        returns (LibBonds2.BondInstruction[] memory bondInstructions_)
    {
        bondInstructions_ = new LibBonds2.BondInstruction[](_prposalProofMetadatas.length);
        uint256 count;

        for (uint256 i; i < _prposalProofMetadatas.length; ++i) {
            IInbox2.ProposalProofMetadata memory proofMetadata = _prposalProofMetadatas[i];
            uint256 windowEnd = proofMetadata.proposalTimestamp + _provingWindow;
            if (block.timestamp <= windowEnd) continue;

            uint256 extendedWindowEnd = proofMetadata.proposalTimestamp + _extendedProvingWindow;
            bool isWithinExtendedWindow = block.timestamp <= extendedWindowEnd;

            bool needsBondInstruction = isWithinExtendedWindow
                ? (proofMetadata.actualProver != proofMetadata.designatedProver)
                : (proofMetadata.actualProver != proofMetadata.proposer);

            if (!needsBondInstruction) continue;

            bondInstructions_[count++] = LibBonds2.BondInstruction({
                proposalId: uint40(_startProposalId + i),
                bondType: isWithinExtendedWindow
                    ? LibBonds2.BondType.LIVENESS
                    : LibBonds2.BondType.PROVABILITY,
                payer: isWithinExtendedWindow
                    ? proofMetadata.designatedProver
                    : proofMetadata.proposer,
                payee: proofMetadata.actualProver
            });
        }
        assembly {
            mstore(bondInstructions_, count)
        }
    }
}
