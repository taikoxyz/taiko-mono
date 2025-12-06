// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @title LibBondInstruction
/// @notice Library for L1-specific bond instruction calculations under sequential proving.
/// @dev Only the first transition of a prove call can be late because later transitions become
///      proveable only after the previous one finalizes within the same transaction.
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    using LibMath for uint256;

    /// @notice Calculates all bond instructions for a sequential prove call.
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow + sequential grace): No bond changes.
    ///         - Late: Liveness bond transfer, even when the designated and actual provers are the
    ///           same address (L2 processing handles slashing/reward splits).
    /// @param _provingWindow The proving window in seconds.
    /// @param _maxProofSubmissionDelay Max delay allowed between consecutive proofs to avoid
    ///        liveness penalties.
    /// @param _priorFinalizedTimestamp Timestamp when the last proposal was finalized.
    /// @param _firstProposal The first proposal proven in the batch.
    /// @param _firstTransition The transition for the first proposal.
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function calculateBondInstruction(
        uint48 _provingWindow,
        uint48 _maxProofSubmissionDelay,
        uint48 _priorFinalizedTimestamp,
        IInbox.Proposal memory _firstProposal,
        IInbox.Transition memory _firstTransition
    )
        internal
        view
        returns (LibBonds.BondInstruction memory bondInstruction_)
    {
        unchecked {
            uint256 proofTimestamp = block.timestamp;
            uint256 proposalDeadline = uint256(_firstProposal.timestamp) + _provingWindow;
            uint256 sequentialDeadline =
                uint256(_priorFinalizedTimestamp) + _maxProofSubmissionDelay;
            uint256 livenessWindowDeadline = proposalDeadline.max(sequentialDeadline);

            // On-time proof - no bond instructions needed.
            if (proofTimestamp <= livenessWindowDeadline) {
                return bondInstruction_;
            }

            address payer = _firstTransition.designatedProver;
            address payee = _firstTransition.actualProver;

            bondInstruction_ = LibBonds.BondInstruction({
                proposalId: _firstProposal.id,
                bondType: LibBonds.BondType.LIVENESS,
                payer: payer,
                payee: payee
            });
        }
    }
}
