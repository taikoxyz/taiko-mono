// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox as I } from "./IInbox.sol";

/// @title IProve
/// @notice Interface for proving batches in the Taiko protocol.
/// @dev This interface defines the prove4 function for batch proofs.
/// @custom:security-contact security@taiko.xyz
interface IProve {
    /// @notice Proves batches with cryptographic proof
    /// @param _summary The current summary
    /// @param _inputs The batch prove inputs
    /// @param _proof The cryptographic proof
    /// @return The updated summary
    function prove4(
        I.Summary memory _summary,
        I.BatchProveInput[] calldata _inputs,
        bytes calldata _proof
    )
        external
        returns (I.Summary memory);
}
