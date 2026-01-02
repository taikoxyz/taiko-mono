// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../IProofVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is IProofVerifier {
    enum VerifierType {
        NONE,
        SGX_GETH,
        TDX_GETH,
        OP,
        SGX_RETH,
        RISC0_RETH,
        SP1_RETH
    }

    struct SubProof {
        VerifierType verifierId;
        bytes proof;
    }

    /// @notice Immutable verifier addresses
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

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256 _proposalAge,
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        view
        virtual
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        uint256 size = subProofs.length;
        address[] memory verifiers = new address[](size);

        VerifierType lastVerifierId;

        for (uint256 i; i < size; ++i) {
            VerifierType verifierId = subProofs[i].verifierId;

            require(verifierId != VerifierType.NONE, CV_INVALID_SUB_VERIFIER());
            require(verifierId > lastVerifierId, CV_INVALID_SUB_VERIFIER_ORDER());

            address verifier = getVerifierAddress(verifierId);
            require(verifier != address(0), CV_INVALID_SUB_VERIFIER());

            IProofVerifier(verifier).verifyProof(_proposalAge, _commitmentHash, subProofs[i].proof);

            verifiers[i] = verifier;
            lastVerifierId = verifierId;
        }

        require(areVerifiersSufficient(verifiers), CV_VERIFIERS_INSUFFICIENT());
    }

    /// @notice Returns the verifier address for a given verifier ID
    /// @param _verifierId The verifier ID to query
    /// @return The address of the verifier (or address(0) if invalid)
    function getVerifierAddress(VerifierType _verifierId) public view returns (address) {
        if (_verifierId == VerifierType.SGX_GETH) return sgxGethVerifier;
        if (_verifierId == VerifierType.TDX_GETH) return tdxGethVerifier;
        if (_verifierId == VerifierType.OP) return opVerifier;
        if (_verifierId == VerifierType.SGX_RETH) return sgxRethVerifier;
        if (_verifierId == VerifierType.RISC0_RETH) return risc0RethVerifier;
        if (_verifierId == VerifierType.SP1_RETH) return sp1RethVerifier;
        return address(0);
    }

    /// @dev Checks if the provided verifiers are sufficient
    /// NOTE: Verifier addresses are provided in ascending order of their IDs
    function areVerifiersSufficient(address[] memory _verifiers)
        internal
        view
        virtual
        returns (bool);

    error CV_INVALID_SUB_VERIFIER();
    error CV_INVALID_SUB_VERIFIER_ORDER();
    error CV_VERIFIERS_INSUFFICIENT();
}
