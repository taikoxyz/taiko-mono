// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/ITaikoInbox.sol";

/// @title IVerifier
/// @notice Defines the function that handles proof verification.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
interface IVerifier {
    struct Context {
        uint64 batchId;
        bytes32 metaHash;
        ITaikoInbox.Transition transition;
        address prover;
    }

    /// @notice Verifies multiple proofs. This function must throw if the proof cannot be verified.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyProof(Context[] calldata _ctxs, bytes calldata _proof) external;
}

interface IVerifier2 {
    /// @notice Verifies multiple proofs. This function must throw if the proof cannot be verified.
    /// @param aggregatedProvingHash The hash of the context for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyProof(bytes32 aggregatedProvingHash, bytes calldata _proof) external;
}
