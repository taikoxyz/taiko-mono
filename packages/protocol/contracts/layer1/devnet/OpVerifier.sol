// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "src/layer1/verifiers/IProofVerifier.sol";

/// @title OpVerifier
/// @notice This contract is a dummy verifier that accepts all proofs without verification.
/// @dev ONLY FOR TESTING - DO NOT USE IN PRODUCTION
/// @custom:security-contact security@taiko.xyz
contract OpVerifier is IProofVerifier {
    error OP_INVALID_TRANSITIONS_HASH();
    error OP_INVALID_PROOF();

    /// @inheritdoc IProofVerifier
    /// @dev This is a dummy implementation that always succeeds
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        pure
    {
        // Dummy verifier - no actual verification
        // Just check that we received some data to avoid misuse
        require(_commitmentHash != bytes32(0), OP_INVALID_TRANSITIONS_HASH());
        require(_proof.length > 0, OP_INVALID_PROOF());
    }
}
