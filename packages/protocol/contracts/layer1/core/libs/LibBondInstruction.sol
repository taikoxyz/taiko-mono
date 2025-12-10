// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibBondInstruction
/// @notice Library for calculating bond instructions based on proof timing
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
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
    /// @param _proposalAge Time elapsed since the proposal became ready
    ///        (block.timestamp - readyTimestamp).
    /// @param _proposer The proposer address.
    /// @param _designatedProver The designated prover address.
    /// @param _actualProver The actual prover address.
    /// @param _provingWindow The proving window in seconds.
    /// @param _extendedProvingWindow The extended proving window in seconds.
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function calculateBondInstruction(
        uint48 _proposalId,
        uint256 _proposalAge,
        address _proposer,
        address _designatedProver,
        address _actualProver,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow
    )
        internal
        pure
        returns (LibBonds.BondInstruction memory bondInstruction_)
    {
        // On-time proof - no bond transfer needed.
        if (_proposalAge <= _provingWindow) {
            return bondInstruction_;
        }

        bool isWithinExtendedWindow = _proposalAge <= _extendedProvingWindow;
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
