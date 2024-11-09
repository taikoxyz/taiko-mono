// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/IVerifier.sol";

contract TestVerifier is IVerifier {
    bool private shouldFail;

    function makeVerifierToFail() external {
        shouldFail = true;
    }

    function makeVerifierToSucceed() external {
        shouldFail = false;
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
        external
    {
        require(!shouldFail, "IVerifier failure");
    }

    /// @notice Verifies multiple proofs.
    /// @param _ctxs The array of contexts for the proof verifications.
    /// @param _proof The batch proof to verify.
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
    {
        require(!shouldFail, "IVerifier failure");
    }
}
