// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/IVerifier.sol";

contract Verifier_ToggleStub is IVerifier {
    bool private shouldFail;

    function makeVerifierToFail() external {
        shouldFail = true;
    }

    function makeVerifierToSucceed() external {
        shouldFail = false;
    }

    function verifyProof(
        Context calldata,
        TaikoData.TransitionV3 calldata,
        TaikoData.TypedProof calldata
    )
        external
        view
    {
        require(!shouldFail, "IVerifier failure");
    }

    function verifyBatchProof(ContextV2[] calldata, TaikoData.TypedProof calldata) external view {
        require(!shouldFail, "IVerifier failure");
    }
}
