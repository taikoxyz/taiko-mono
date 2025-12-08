// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/IProofVerifier.sol";

/// @title OpVerifier
/// @notice This contract is a dummy verifier that accepts all proofs without verification.
/// @dev ONLY FOR TESTING - DO NOT USE IN PRODUCTION
/// @custom:security-contact security@taiko.xyz
contract OpVerifier is IProofVerifier {
    error InvalidHashToProve();
    error InvalidProof();

    /// @inheritdoc IProofVerifier
    /// @dev This is a dummy implementation that always succeeds
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _hashToProve,
        bytes calldata _proof
    )
        external
        pure
    {
        // Dummy verifier - no actual verification
        // Just check that we received some data to avoid misuse
        if (_hashToProve == bytes32(0)) revert InvalidHashToProve();
        if (_proof.length == 0) revert InvalidProof();
    }
}
