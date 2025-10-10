// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../iface/IProofVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is IProofVerifier {
    struct SubProof {
        address verifier;
        bytes proof;
    }

    /// The sgx/tdx-GethVerifier is the core verifier required in every proof.
    /// All other proofs share its status root, despite different public inputs
    /// due to different verification types.
    /// proofs come from geth client
    address public immutable sgxGethVerifier;
    address public immutable tdxGethVerifier;
    /// op for test purpose
    address public immutable opVerifier;
    /// proofs come from reth client
    address public immutable sgxRethVerifier;
    address public immutable risc0RethVerifier;
    address public immutable sp1RethVerifier;

    constructor(
        address _sgxGethVerifier,
        address _tdxGethVerifier,
        address _opVerifier,
        address _sgxRethVerifier,
        address _risc0RethVerifier,
        address _sp1RethVerifier
    ) {
        sgxGethVerifier = _sgxGethVerifier;
        tdxGethVerifier = _tdxGethVerifier;
        opVerifier = _opVerifier;
        sgxRethVerifier = _sgxRethVerifier;
        risc0RethVerifier = _risc0RethVerifier;
        sp1RethVerifier = _sp1RethVerifier;
    }

    error CV_INVALID_SUB_VERIFIER();
    error CV_INVALID_SUB_VERIFIER_ORDER();
    error CV_VERIFIERS_INSUFFICIENT();

    /// @inheritdoc IProofVerifier
    function verifyProof(bytes32 _transitionsHash, bytes calldata _proof) external view {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        uint256 size = subProofs.length;
        address[] memory verifiers = new address[](size);

        address verifier;

        for (uint256 i; i < size; ++i) {
            require(subProofs[i].verifier != address(0), CV_INVALID_SUB_VERIFIER());
            require(subProofs[i].verifier > verifier, CV_INVALID_SUB_VERIFIER_ORDER());

            verifier = subProofs[i].verifier;
            IProofVerifier(verifier).verifyProof(_transitionsHash, subProofs[i].proof);

            verifiers[i] = verifier;
        }

        require(areVerifiersSufficient(verifiers), CV_VERIFIERS_INSUFFICIENT());
    }

    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        virtual
        returns (bool);
}
