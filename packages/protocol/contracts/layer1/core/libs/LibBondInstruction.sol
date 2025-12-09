// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibBondInstruction
/// @notice Library for calculating bond instructions based on proof timing
/// @custom:security-contact security@taiko.xyz
library LibBondInstruction {
    /// @dev Calculates bond instruction based on proof timing relative to proving windows.
    /// @param _proposalId The proposal ID.
    /// @param _proposer The proposer address.
    /// @param _designatedProver The designated prover address.
    /// @param _actualProver The actual prover address.
    /// @param _readyTimestamp Timestamp when the proposal became proveable.
    /// @param _provingWindow The proving window in seconds.
    /// @param _extendedProvingWindow The extended proving window in seconds.
    /// @return bondInstruction_ A bond transfer instruction, or a BondType.NONE instruction when
    ///         no transfer is required.
    function calculateBondInstruction(
        uint48 _proposalId,
        address _proposer,
        address _designatedProver,
        address _actualProver,
        uint48 _readyTimestamp,
        uint48 _provingWindow,
        uint48 _extendedProvingWindow
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

            address payer = isWithinExtendedWindow ? _designatedProver : _proposer;
            address payee = _actualProver;

            // If payer and payee are identical, there is no bond movement.
            if (payer == payee) {
                return bondInstruction_;
            }

            bondInstruction_ = LibBonds.BondInstruction({
                proposalId: _proposalId,
                bondType: isWithinExtendedWindow
                    ? LibBonds.BondType.LIVENESS
                    : LibBonds.BondType.PROVABILITY,
                payer: payer,
                payee: payee
            });
        }
    }
}
