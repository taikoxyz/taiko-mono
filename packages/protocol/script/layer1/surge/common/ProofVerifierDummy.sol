// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";

/// @title ProofVerifierDummy
/// @dev Dummy verifier that accepts ECDSA signatures from a trusted signer
/// @custom:security-contact security@nethermind.io
contract ProofVerifierDummy is IProofVerifier {
    using ECDSA for bytes32;

    /// @notice The trusted signer address
    address public immutable signer;

    /// @param _signer The trusted signer address
    constructor(address _signer) {
        if (_signer == address(0)) revert InvalidSigner();
        signer = _signer;
    }

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256, /*_proposalAge*/
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        view
    {
        address recoveredSigner = _commitmentHash.recover(_proof);
        if (recoveredSigner != signer) revert InvalidSignature();
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidSigner();
    error InvalidSignature();
}
