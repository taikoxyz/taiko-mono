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

    function _getAddress(uint64, bytes32 _name) internal view override returns (address) {
        if (_name == LibStrings.B_TAIKO) return msg.sender;
        else return address(0);
    }
}

contract MockVerifier is IVerifier {
    bool private shouldSucceed;

    constructor(bool _shouldSucceed) {
        shouldSucceed = _shouldSucceed;
    }

    function verifyProof(
        Context calldata,
        TaikoData.Transition calldata,
        TaikoData.TierProof calldata
    )
        external
        view
        override
    {
        if (!shouldSucceed) {
            revert("MockVerifier: Verification failed");
        }
    }
}

contract ComposeVerifierTest is TaikoTest {
    IVerifier.Context private ctx;
    TaikoData.Transition private tran;

    function test_composeVerifeir_invalid_subproof_length() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(true));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](2);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier1, "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(1);

        vm.expectRevert(ComposeVerifier.CV_INVALID_SUBPROOF_LENGTH.selector);
        composeVerifier.verifyProof(ctx, tran, proof);
    }

    function test_composeVerifeir_1_outof_3() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(true));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](1);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(1);
        composeVerifier.verifyProof(ctx, tran, proof);
    }

    function test_composeVerifeir_2_outof_3() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(true));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](2);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier2, "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(2);
        composeVerifier.verifyProof(ctx, tran, proof);
    }

    function test_composeVerifeir_3_outof_3() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(true));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](3);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier2, "");
        subProofs[2] = ComposeVerifier.SubProof(verifier3, "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(3);
        composeVerifier.verifyProof(ctx, tran, proof);
    }

    function test_composeVerifeir_subproof_failure() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(false));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](3);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier2, "");
        subProofs[2] = ComposeVerifier.SubProof(verifier3, "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(3);

        // Expect the verification to fail because one sub proof is invalid
        vm.expectRevert("MockVerifier: Verification failed");
        composeVerifier.verifyProof(ctx, tran, proof);
    }

    function test_composeVerifeir_2_outof_3_duplicate_subproof() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(true));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](2);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier1, "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(2);
        vm.expectRevert(ComposeVerifier.CV_SUB_VERIFIER_NOT_FOUND.selector);
        composeVerifier.verifyProof(ctx, tran, proof);
    }

    function test_composeVerifeir_subproof_verifier_not_found() public {
        ComposeVerifierForTest composeVerifier = new ComposeVerifierForTest();
        address verifier1 = address(new MockVerifier(true));
        address verifier2 = address(new MockVerifier(true));
        address verifier3 = address(new MockVerifier(true));

        composeVerifier.addSubVerifier(verifier1);
        composeVerifier.addSubVerifier(verifier2);
        composeVerifier.addSubVerifier(verifier3);

        ComposeVerifier.SubProof[] memory subProofs = new ComposeVerifier.SubProof[](3);
        subProofs[0] = ComposeVerifier.SubProof(verifier1, "");
        subProofs[1] = ComposeVerifier.SubProof(verifier2, "");
        subProofs[2] = ComposeVerifier.SubProof(address((123)), "");

        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 1, data: abi.encode(subProofs) });

        composeVerifier.setThreshold(3);

        // Expect the verification to fail because one sub proof is invalid
        vm.expectRevert(ComposeVerifier.CV_SUB_VERIFIER_NOT_FOUND.selector);
        composeVerifier.verifyProof(ctx, tran, proof);
    }
}
