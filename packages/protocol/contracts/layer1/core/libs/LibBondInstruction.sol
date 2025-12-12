// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @notice Library for calculating bond instructions based on proof timing
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    using LibMath for uint256;

    /// @dev Calculates bond instruction based on proposal age and proof timing windows.
    ///
    /// Bond logic:
    /// - If proof is on-time (proposalAge <= provingWindow): No bond transfer
    /// - If proof is late but within extended window: LIVENESS bond (designatedProver pays
    ///   actualProver)
    /// - If proof is after extended window: PROVABILITY bond (proposer pays actualProver)
    /// - If payer == payee: No bond transfer
    ///
    /// @param _proposalId The proposal ID.
    /// @param _proposalTimestamp The proposal timestamp.
    /// @param _priorFinalizedTimestamp The timestamp when the last proposal was finalized.
    /// @param _proposer The proposer address.
    /// @param _designatedProver The designated prover address.
    /// @param _actualProver The actual prover address.
    /// @param _provingWindow The proving window in seconds.
    /// @param _extendedProvingWindow The extended proving window in seconds.
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function calculateBondInstruction(
        uint48 _proposalId,
        uint256 _proposalTimestamp,
        uint48 _priorFinalizedTimestamp,
        uint48 _maxProofSubmissionDelay,
        address _proposer,
        address _designatedProver,
        address _actualProver,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow
    )
        internal
        view
        returns (LibBonds.BondInstruction memory bondInstruction_)
    {
        uint256 proofTimestamp = block.timestamp;
        uint256 proposalDeadline = uint256(_proposalTimestamp) + _provingWindow;
        uint256 sequentialDeadline =
            uint256(_priorFinalizedTimestamp) + _maxProofSubmissionDelay;
        uint256 livenessWindowDeadline = proposalDeadline.max(sequentialDeadline);
        
        // On-time proof - no bond transfer needed.
        if (proofTimestamp <= livenessWindowDeadline) {
            return bondInstruction_;
        }

        
        
        // For the extended proving deadline we still allow `_extendedProvingWindow` to pass
        // to avoid excesive slashing due to a proposer not being able to submit their proof
        uint256 readyTimestamp = _proposalTimestamp.max(_priorFinalizedTimestamp);
        uint256 extendedWindowDeadline = uint256(readyTimestamp) + _extendedProvingWindow;
        bool isWithinExtendedWindow = proofTimestamp <= extendedWindowDeadline;

        address payer = isWithinExtendedWindow ? _designatedProver : _proposer;

        // If payer and payee are identical, there is no bond movement.
        if (payer == _actualProver) {
            return bondInstruction_;
        }

        bondInstruction_ = LibBonds.BondInstruction({
            proposalId: _proposalId,
            bondType: isWithinExtendedWindow
                ? LibBonds.BondType.LIVENESS
                : LibBonds.BondType.PROVABILITY,
            payer: payer,
            payee: _actualProver
        });
    }
}
