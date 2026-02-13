// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { LibAnchorSigner } from "test/layer2/LibAnchorSigner.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { GoldenTouchVerifier } from "src/layer1/verifiers/GoldenTouchVerifier.sol";

contract GoldenTouchVerifierTest is Test {
    uint64 private constant CHAIN_ID = 167;
    uint32 private constant INSTANCE_ID = 0xDEADC0DE;

    GoldenTouchVerifier internal verifier;

    function setUp() external {
        verifier = new GoldenTouchVerifier(CHAIN_ID);
    }

    function test_verifyProof_SucceedsWithValidSignature() external {
        (bytes memory proof, bytes32 aggregatedHash) = _prepareValidProof();

        verifier.verifyProof(0, aggregatedHash, proof);
    }

    function test_verifyProof_RevertWhen_ProofLengthInvalid() external {
        vm.expectRevert(GoldenTouchVerifier.GOLDEN_TOUCH_INVALID_PROOF.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), hex"1234");
    }

    function test_verifyProof_RevertWhen_InstanceIdInvalid() external {
        (bytes memory proof, bytes32 aggregatedHash) = _prepareValidProof();

        bytes memory badIdProof = new bytes(proof.length);
        bytes memory newId = abi.encodePacked(uint32(INSTANCE_ID + 1));
        for (uint256 i; i < 4; ++i) {
            badIdProof[i] = newId[i];
        }
        for (uint256 i; i < proof.length - 4; ++i) {
            badIdProof[i + 4] = proof[i + 4];
        }

        vm.expectRevert(GoldenTouchVerifier.GOLDEN_TOUCH_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggregatedHash, badIdProof);
    }

    function test_verifyProof_RevertWhen_SignatureInvalid() external {
        bytes32 aggregatedHash = bytes32(uint256(0x1234));
        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            aggregatedHash, address(verifier), LibAnchorSigner.GOLDEN_TOUCH_ADDRESS, CHAIN_ID
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xA11CE, signatureHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory proof = abi.encodePacked(
            uint32(INSTANCE_ID), bytes20(LibAnchorSigner.GOLDEN_TOUCH_ADDRESS), signature
        );

        vm.expectRevert(GoldenTouchVerifier.GOLDEN_TOUCH_INVALID_PROOF.selector);
        verifier.verifyProof(0, aggregatedHash, proof);
    }

    function _prepareValidProof()
        private
        returns (bytes memory proof, bytes32 aggregatedHash)
    {
        aggregatedHash = bytes32(uint256(0x1234));
        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            aggregatedHash, address(verifier), LibAnchorSigner.GOLDEN_TOUCH_ADDRESS, CHAIN_ID
        );

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(LibAnchorSigner.GOLDEN_TOUCH_PRIVATEKEY, signatureHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        proof = abi.encodePacked(
            uint32(INSTANCE_ID), bytes20(LibAnchorSigner.GOLDEN_TOUCH_ADDRESS), signature
        );
    }
}
