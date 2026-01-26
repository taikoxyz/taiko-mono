// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IShadow} from "./IShadow.sol";

/// @custom:security-contact security@taiko.xyz
interface IShadowVerifier {
    error CheckpointNotFound(uint48 blockNumber);
    error ProofVerificationFailed();
    error StateRootMismatch(bytes32 expected, bytes32 actual);
    error ZeroAddress();

    /// @notice Verifies a proof and its public inputs.
    function verifyProof(bytes calldata _proof, IShadow.PublicInput calldata _input)
        external
        view
        returns (bool _isValid_);
}
