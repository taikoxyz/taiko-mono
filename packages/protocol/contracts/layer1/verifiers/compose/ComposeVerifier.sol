// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/core/iface/IProofVerifier.sol";

/// @title ComposeVerifier
/// @notice This contract is an abstract verifier that composes multiple sub-verifiers to validate
/// proofs.
/// It ensures that a set of sub-proofs are verified by their respective verifiers before
/// considering the overall proof as valid.
/// @custom:security-contact security@taiko.xyz
abstract contract ComposeVerifier is IProofVerifier {
    // ---------------------------------------------------------------
    // Struct and Constants
    // ---------------------------------------------------------------

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

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice Immutable verifier addresses
    /// The sgx/tdx-GethVerifier is the core verifier required in every proof.
    /// All other proofs share its status root, despite different public inputs
    /// due to different verification types.
    /// proofs come from geth client
    address private immutable _sgxGethVerifier;
    address private immutable _tdxGethVerifier;
    /// op for test purpose
    address private immutable _opVerifier;
    /// proofs come from reth client
    address private immutable _sgxRethVerifier;
    address private immutable _risc0RethVerifier;
    address private immutable _sp1RethVerifier;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address __sgxGethVerifier,
        address __tdxGethVerifier,
        address __opVerifier,
        address __sgxRethVerifier,
        address __risc0RethVerifier,
        address __sp1RethVerifier
    ) {
        _sgxGethVerifier = __sgxGethVerifier;
        _tdxGethVerifier = __tdxGethVerifier;
        _opVerifier = __opVerifier;
        _sgxRethVerifier = __sgxRethVerifier;
        _risc0RethVerifier = __risc0RethVerifier;
        _sp1RethVerifier = __sp1RethVerifier;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256 _youngestProposalAge,
        bytes32 _transitionsHash,
        bytes calldata _proof
    )
        external
        view
    {
        SubProof[] memory subProofs = abi.decode(_proof, (SubProof[]));
        uint256 size = subProofs.length;
        uint8[] memory verifierIds = new uint8[](size);

        uint8 lastVerifierId;

        for (uint256 i; i < size; ++i) {
            uint8 verifierId = subProofs[i].verifierId;

            require(verifierId != NONE, InvalidSubVerifier());
            require(verifierId > lastVerifierId, InvalidSubVerifierOrder());

            address verifier = getVerifierAddress(verifierId);
            require(verifier != address(0), InvalidSubVerifier());

            IProofVerifier(verifier)
                .verifyProof(_youngestProposalAge, _transitionsHash, subProofs[i].proof);

            verifierIds[i] = verifierId;
            lastVerifierId = verifierId;
        }

        require(
            areVerifiersSufficient(_youngestProposalAge, verifierIds), InsufficientSubVerifiers()
        );
    }

    // ---------------------------------------------------------------
    // Public Functions
    // ---------------------------------------------------------------

    /// @notice Returns the verifier address for a given verifier ID
    /// @param _verifierId The verifier ID to query
    /// @return The address of the verifier (or address(0) if invalid)
    function getVerifierAddress(uint8 _verifierId) public view returns (address) {
        if (_verifierId == SGX_GETH) return _sgxGethVerifier;
        if (_verifierId == TDX_GETH) return _tdxGethVerifier;
        if (_verifierId == OP) return _opVerifier;
        if (_verifierId == SGX_RETH) return _sgxRethVerifier;
        if (_verifierId == RISC0_RETH) return _risc0RethVerifier;
        if (_verifierId == SP1_RETH) return _sp1RethVerifier;
        return address(0);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function isZKVerifier(uint8 _verifierId) internal pure returns (bool) {
        return _verifierId == RISC0_RETH || _verifierId == SP1_RETH;
    }

    function areVerifiersSufficient(
        uint256 _youngestProposalAge,
        uint8[] memory _verifierIds
    )
        internal
        view
        virtual
        returns (bool);
}

// ---------------------------------------------------------------
// Errors
// ---------------------------------------------------------------

error InvalidSubVerifier();
error InvalidSubVerifierOrder();
error InsufficientSubVerifiers();
