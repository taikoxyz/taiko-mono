// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../IProofVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is IProofVerifier {
    struct SubProof {
        uint8 verifierId;
        bytes proof;
    }

    /// @notice Enum for verifier identification using stable IDs
    uint8 public constant NONE = 0;
    uint8 public constant SGX_GETH = 1;
    uint8 public constant TDX_GETH = 2;
    uint8 public constant OP = 3;
    uint8 public constant SGX_RETH = 4;
    uint8 public constant RISC0_RETH = 5;
    uint8 public constant SP1_RETH = 6;

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
        bytes32 _transitionsHash,
        bytes calldata _proof
    )
        external
        view
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        uint256 size = subProofs.length;
        address[] memory verifiers = new address[](size);

        uint8 lastVerifierId;

        for (uint256 i; i < size; ++i) {
            uint8 verifierId = subProofs[i].verifierId;

            require(verifierId != NONE, CV_INVALID_SUB_VERIFIER());
            require(verifierId > lastVerifierId, CV_INVALID_SUB_VERIFIER_ORDER());

            address verifier = getVerifierAddress(verifierId);
            require(verifier != address(0), CV_INVALID_SUB_VERIFIER());

            IProofVerifier(verifier).verifyProof(_proposalAge, _transitionsHash, subProofs[i].proof);

            verifiers[i] = verifier;
            lastVerifierId = verifierId;
        }

        require(areVerifiersSufficient(verifiers), CV_VERIFIERS_INSUFFICIENT());
    }

    /// @notice Returns the verifier address for a given verifier ID
    /// @param _verifierId The verifier ID to query
    /// @return The address of the verifier (or address(0) if invalid)
    function getVerifierAddress(uint8 _verifierId) public view returns (address) {
        if (_verifierId == SGX_GETH) return sgxGethVerifier;
        if (_verifierId == TDX_GETH) return tdxGethVerifier;
        if (_verifierId == OP) return opVerifier;
        if (_verifierId == SGX_RETH) return sgxRethVerifier;
        if (_verifierId == RISC0_RETH) return risc0RethVerifier;
        if (_verifierId == SP1_RETH) return sp1RethVerifier;
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
