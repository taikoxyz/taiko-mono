// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../L1/TaikoData.sol";

/// @title IVerifier
/// @notice Defines the function that handles proof verification.
/// @custom:security-contact security@taiko.xyz
interface IVerifier {
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
        bool blobUsed;
        address msgSender;
        TaikoData.Transition tran;
    }

    /// @notice Verifies a proof.
    /// @param _ctx The context of the proof verification.
    /// @param _tran The transition to verify.
    /// @param _proof The proof to verify.
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external;

    /// @notice Verifies multiple proofs.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external;
}
