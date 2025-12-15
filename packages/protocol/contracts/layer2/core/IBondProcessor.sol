// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title IBondProcessor
/// @notice Interface for processing proved bond instructions on L2.
/// @custom:security-contact security@taiko.xyz
interface IBondProcessor {
    /// @notice Emitted when a bond instruction is processed.
    /// @param signal The L1 signal hash associated with the instruction.
    /// @param instruction The processed bond instruction.
    /// @param debitedAmount The amount debited from the payer.
    event BondInstructionProcessed(
        bytes32 indexed signal, LibBonds.BondInstruction instruction, uint256 debitedAmount
    );

    /// @notice Processes a proved bond instruction from L1 with best-effort debits/credits.
    /// @param _instruction Bond instruction tied to the signal.
    /// @param _proof Merkle proof that the signal was sent on L1.
    function processBondInstruction(
        LibBonds.BondInstruction calldata _instruction,
        bytes calldata _proof
    )
        external;
}
