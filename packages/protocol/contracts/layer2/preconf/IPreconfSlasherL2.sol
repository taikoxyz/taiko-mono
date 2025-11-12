// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IPreconfSlasher } from "src/shared/preconf/IPreconfSlasher.sol";

/// @title IPreconfSlasherL2
/// @custom:security-contact security@taiko.xyz
interface IPreconfSlasherL2 {
    /// @notice A Commitment message binding an opaque payload to a slasher contract
    /// @dev This is extracted from URC's `ISlasher` to enable compilation to Shanghai.
    struct Commitment {
        /// The type of commitment
        uint64 commitmentType;
        /// The payload of the commitment
        bytes payload;
        /// The address of the slasher contract
        address slasher;
    }

    /// @notice A commitment message signed by a delegate's ECDSA key
    /// @dev This is extracted from URC's `ISlasher` to enable compilation to Shanghai.
    struct SignedCommitment {
        /// The commitment message
        Commitment commitment;
        /// The signature of the commitment message
        bytes signature;
    }

    error EOPOnlyPreconfirmationDoesNotRequireSubmission();
    error InvalidEOPFlag();
    error NotAMissedSubmission();
    error NotAMissingEOP();
    error NotAnInvalidEOP();
    error NotARawTxListHashOrAnchorBlockMismatch();
    error ParentRawTxListHashMismatch();
    error ParentSubmissionWindowEndMismatch();
    error SubmissionWindowMismatch();
    error UnexpectedExtraProposalsInPreviousWindow();

    /// @notice Validates if a preconfirmation is slashable and forwards the fault to the
    /// L1 preconfirmation slasher.
    /// @param _fault The fault that needs to be checked
    /// @param _registrationRoot The urc registration root of the operator being
    /// slashed
    /// @param _signedCommitment The signed preconfirmation commitment to slash
    function slash(
        IPreconfSlasher.Fault _fault,
        bytes32 _registrationRoot,
        SignedCommitment calldata _signedCommitment
    )
        external;
}
