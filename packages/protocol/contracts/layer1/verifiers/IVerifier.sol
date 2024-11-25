// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/ITaiko.sol";

/// @title IVerifier
/// @notice Defines the function that handles proof verification.
/// @custom:security-contact security@taiko.xyz
interface IVerifier {
    struct Context {
        bytes32 metaHash;
        ITaiko.TransitionV3 tran;
    }

    /// @notice Verifies multiple proofs.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyProof(Context[] calldata _ctxs, bytes calldata _proof) external;
}
