// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoData.sol";

/// @title IVerifier
/// @notice Defines the function that handles proof verification.
/// @custom:security-contact security@taiko.xyz
interface IVerifier {
      struct TypedProof {
        uint16 tier;
        bytes data;
    }

    struct Context {
        bytes32 metaHash;
        bytes32 blobHash;
        address prover;
        uint64 blockId;
        bool isContesting;
        bool blobUsed;
        address msgSender;
    }

    struct ContextV2 {
        bytes32 metaHash;
        bytes32 blobHash;
        address prover;
        uint64 blockId;
        bool isContesting;
        address msgSender;
        TaikoData.TransitionV3 tran;
    }

    struct ContextV3 {
        bytes32 metaHash;
        bytes32 difficulty;
        TaikoData.TransitionV3 tran;
    }

    /// @notice Verifies a proof.
    /// @param _ctx The context of the proof verification.
    /// @param _tran The transition to verify.
    /// @param _proof The proof to verify.
    function verifyProof(
        Context calldata _ctx,
        TaikoData.TransitionV3 calldata _tran,
        TypedProof calldata _proof
    )
        external;

    /// @notice Verifies multiple proofs.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TypedProof calldata _proof
    )
        external;

    /// @notice Verifies multiple proofs.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyProofV3(ContextV3[] calldata _ctxs, bytes calldata _proof) external;
}
