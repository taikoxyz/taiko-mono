// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "src/layer1/surge/verifiers/LibProofType.sol";

/// @title ISurgeVerifier
/// @notice Defines the function that handles proof verification.
/// @custom:security-contact security@nethermind.io

interface ISurgeVerifier {
    struct SubProof {
        // This is a single proof type i.e SGX_RETH / SP1_RETH / RISC0_RETH / TDX_RETH
        LibProofType.ProofType proofType;
        bytes proof;
    }

    // This represents an internal verifier for a specific proof type
    // The internal verifiers will continue to use the default `IVerifier` interface of Taiko
    struct InternalVerifier {
        bool upgradeable;
        address addr;
    }

    error INVALID_PROOF_TYPE();
    error VERIFIER_NOT_MARKED_UPGRADEABLE();

    /// @notice Verifies multiple proofs. This function must throw if the proof cannot be verified.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    /// @return proofType The type of proof.
    function verifyProof(
        IVerifier.Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        returns (LibProofType.ProofType);

    /// @notice Marks the verifier for a proof type as upgradeable.
    /// @dev Should be called by the inbox contract.
    /// @param _proofType The proof type to mark as upgradeable.
    function markUpgradeable(LibProofType.ProofType _proofType) external;

    /// @notice Upgrades the verifier for a proof type.
    /// @dev Called by the owner of the parent compose verifier
    /// @param _proofType The proof type to upgrade.
    /// @param _newVerifier The address of the new verifier.
    function upgradeVerifier(LibProofType.ProofType _proofType, address _newVerifier) external;
}
