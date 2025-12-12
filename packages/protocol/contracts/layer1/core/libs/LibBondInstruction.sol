// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @notice Library for calculating bond instructions based on proof timing
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    using LibMath for uint256;

    /// @notice Calculates all bond instructions for a sequential prove call.
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow + sequential grace): No bond changes.
    ///         - Late: Liveness bond transfer, even when the designated and actual provers are the
    ///           same address (L2 processing handles slashing/reward splits).
    /// @param _proposalId The proposal ID.
    /// @param _proposalTimestamp The proposal timestamp.
    /// @param _priorFinalizedTimestamp The timestamp when the last proposal was finalized.
    /// @param _designatedProver The designated prover address.
    /// @param _actualProver The actual prover address.
    /// @param _provingWindow The proving window in seconds.
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function calculateBondInstruction(
        uint48 _proposalId,
        uint256 _proposalTimestamp,
        uint48 _priorFinalizedTimestamp,
        uint48 _maxProofSubmissionDelay,
        address _designatedProver,
        address _actualProver,
        uint48 _provingWindow
    )
        internal
        view
        returns (LibBonds.BondInstruction memory bondInstruction_)
    {
        uint256 proofTimestamp = block.timestamp;
        uint256 proposalDeadline = uint256(_proposalTimestamp) + _provingWindow;
        uint256 sequentialDeadline = uint256(_priorFinalizedTimestamp) + _maxProofSubmissionDelay;
        uint256 livenessWindowDeadline = proposalDeadline.max(sequentialDeadline);

        // On-time proof - no bond transfer needed.
        if (proofTimestamp <= livenessWindowDeadline) {
            return bondInstruction_;
        }

        bondInstruction_ = LibBonds.BondInstruction({
            proposalId: _proposalId,
            bondType: LibBonds.BondType.LIVENESS,
            payer: _designatedProver,
            payee: _actualProver
        });
    }
}
