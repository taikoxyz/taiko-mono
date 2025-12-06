// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibBondInstruction
/// @notice Library for L1-specific bond instruction calculations under sequential proving.
/// @dev Only the first transition of a prove call can be late because later transitions become
///      proveable only after the previous one finalizes within the same transaction.
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    /// @notice Calculates all bond instructions for a sequential prove call.
    /// @dev Bond instruction rules:
    ///         - On-time (within provingWindow): No bond changes.
    ///         - Late (within extendedProvingWindow): Liveness bond transfer if prover differs
    ///           from designated prover of the first transition.
    ///         - Very late (after extendedProvingWindow): Provability bond transfer if prover
    ///           differs from proposer of the first transition.
    /// @param _provingWindow The proving window in seconds.
    /// @param _extendedProvingWindow The extended proving window in seconds.
    /// @param _firstProposal The first proposal proven in the batch.
    /// @param _firstTransition The transition for the first proposal.
    /// @param _readyTimestamp Timestamp when the first proposal became proveable (max of the first
    ///        proposal timestamp and the parent finalization time).
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function calculateBondInstruction(
        uint48 _provingWindow,
        uint48 _extendedProvingWindow,
        IInbox.Proposal memory _firstProposal,
        IInbox.Transition memory _firstTransition,
        uint48 _readyTimestamp
    )
        internal
        view
        returns (LibBonds.BondInstruction memory bondInstruction_)
    {
        unchecked {
            uint256 proofTimestamp = block.timestamp;
            uint256 windowEnd = uint256(_readyTimestamp) + _provingWindow;

            // On-time proof - no bond instructions needed.
            if (proofTimestamp <= windowEnd) {
                return bondInstruction_;
            }

            uint256 extendedWindowEnd = uint256(_readyTimestamp) + _extendedProvingWindow;
            bool isWithinExtendedWindow = proofTimestamp <= extendedWindowEnd;

            address payer = isWithinExtendedWindow
                ? _firstTransition.designatedProver
                : _firstProposal.proposer;
            address payee = _firstTransition.actualProver;

            // If payer and payee are identical, there is no bond movement.
            if (payer == payee) {
                return bondInstruction_;
            }

            bondInstruction_ = LibBonds.BondInstruction({
                proposalId: _firstProposal.id,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: payer,
                payee: payee
            });
        }
    }
}
