// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title IBondProcessor
/// @notice Interface for processing L1 bond signals on L2
/// @custom:security-contact security@taiko.xyz
interface IBondProcessor {
    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bond signal is processed.
    event BondSignalProcessed(
        bytes32 indexed signal, LibBonds.BondInstruction instruction, uint256 debitedAmount
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Processes a proved bond signal from L1 with best-effort debits/credits.
    /// @param _instruction Bond instruction tied to the signal.
    /// @param _proof Merkle proof that the signal was sent on L1.
    function processBondSignal(LibBonds.BondInstruction calldata _instruction, bytes calldata _proof)
        external;
}
