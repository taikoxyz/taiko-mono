// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";
import "../../../contracts/verifiers/compose/ComposeVerifier.sol";

contract ComposeVerifierForTest is ComposeVerifier {
    uint256 private threshold;
    address[] private verifiers;

    function setThreshold(uint256 _threshold) external {
        threshold = _threshold;
    }

    function getSubVerifiersAndThreshold()
        public
        view
        override
        returns (address[] memory, uint256)
    {
        return (verifiers, threshold);
    }

    function addSubVerifier(address _verifier) external {
        verifiers.push(_verifier);
    }
}

contract MockVerifier is IVerifier {
    bool private shouldSucceed;

    constructor(bool _shouldSucceed) {
        shouldSucceed = _shouldSucceed;
    }

    function verifyProof(Context[] calldata, TaikoData.TierProof calldata) external view override {
        if (!shouldSucceed) {
            revert("MockVerifier: Verification failed");
        }
    }
}

contract ComposeVerifierTest is TaikoTest {
    ComposeVerifierForTest private composeVerifier;

    IVerifier.Context private ctx;
    TaikoData.TierProof proof;
    address private verifier1;
    address private verifier2;
    address private verifier3;

    function setUp() public {
        verifier1 = address(new MockVerifier(true));
        verifier2 = address(new MockVerifier(false));
        verifier3 = address(new MockVerifier(true));

        composeVerifier = new ComposeVerifierForTest();
        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](3);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier2, "");
        subProofs[2] = ComposeVerifier.SubProof(verifier3, "");

        proof = TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });
    }

    function test_composeVerifeir_All() public {
        composeVerifier.setThreshold(3);

        // Expect the verification to fail because not all verifiers succeed
        vm.expectRevert(ComposeVerifier.INSUFFICIENT_PROOF.selector);
        composeVerifier.verifyProof(ctxToList(ctx), proof);
    }

    function test_composeVerifeir_Majority() public {
        composeVerifier.setThreshold(2);
        composeVerifier.verifyProof(ctxToList(ctx), proof);
    }

    function test_composeVerifeir_One() public {
        composeVerifier.setThreshold(1);
        composeVerifier.verifyProof(ctxToList(ctx), proof);
    }
}
