// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IShadow } from "./IShadow.sol";

/// @title IShadowVerifier
/// @notice Verifies Shadow ZK proofs against checkpointed state roots.
/// @custom:security-contact security@taiko.xyz
interface IShadowVerifier {
    error CheckpointNotFound(uint48 blockNumber);
    error ProofVerificationFailed();
    error StateRootMismatch(bytes32 expected, bytes32 actual);
    error ZeroAddress();

    /// @notice Verifies a ZK proof against checkpointed state.
    /// @param _proof The serialized ZK proof.
    /// @param _input The public inputs for verification.
    /// @return _isValid_ True if valid, reverts otherwise.
    function verifyProof(
        bytes calldata _proof,
        IShadow.PublicInput calldata _input
    )
        external
        view
        returns (bool _isValid_);
}
