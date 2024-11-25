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

    function verifyProof(Context[] calldata, bytes calldata) external view {
        require(!shouldFail, "IVerifier failure");
    }
}
