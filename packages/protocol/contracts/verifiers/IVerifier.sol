// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
        TaikoData.Transition transition;
    }

    /// @notice Verifies a proof.
    /// @param _ctxs The context of the proof verification.
    /// @param _proof The proof to verify.
    function verifyProof(Context[] calldata _ctxs, TaikoData.TierProof calldata _proof) external;
}
