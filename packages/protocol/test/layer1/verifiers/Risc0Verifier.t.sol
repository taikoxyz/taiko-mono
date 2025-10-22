// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IRiscZeroVerifier } from "@risc0/contracts/IRiscZeroVerifier.sol";
import "forge-std/src/Test.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { Risc0Verifier } from "src/layer1/verifiers/Risc0Verifier.sol";

contract Risc0VerifierTest is Test {
    uint64 private constant CHAIN_ID = 167;
    address private constant REMOTE = address(0xBEEF);

    Risc0Verifier internal verifier;

    bytes32 internal constant BLOCK_IMAGE_ID = bytes32("block-image");
    bytes32 internal constant AGGREGATION_IMAGE_ID = bytes32("aggregation-image");

    function setUp() external {
        verifier = new Risc0Verifier(CHAIN_ID, REMOTE, address(this));
    }

    function test_setImageIdTrusted_EmitsAndUpdates() external {
        bytes32 newImage = bytes32("new");

        vm.expectEmit();
        emit Risc0Verifier.ImageTrusted(newImage, true);
        verifier.setImageIdTrusted(newImage, true);

        assertTrue(verifier.isImageTrusted(newImage));
    }

    function test_verifyProof_RevertWhen_AggregationImageUntrusted() external {
        bytes memory proof = abi.encode(bytes("seal"), BLOCK_IMAGE_ID, AGGREGATION_IMAGE_ID);

        vm.expectRevert(Risc0Verifier.RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_RevertWhen_BlockImageUntrusted() external {
        verifier.setImageIdTrusted(AGGREGATION_IMAGE_ID, true);
        bytes memory proof = abi.encode(bytes("seal"), BLOCK_IMAGE_ID, AGGREGATION_IMAGE_ID);

        vm.expectRevert(Risc0Verifier.RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_RevertWhen_AggregatedHashZero() external {
        verifier.setImageIdTrusted(BLOCK_IMAGE_ID, true);
        verifier.setImageIdTrusted(AGGREGATION_IMAGE_ID, true);
        bytes memory proof = abi.encode(bytes("seal"), BLOCK_IMAGE_ID, AGGREGATION_IMAGE_ID);

        vm.expectRevert(LibPublicInput.InvalidAggregatedProvingHash.selector);
        verifier.verifyProof(0, bytes32(0), proof);
    }

    function test_verifyProof_RevertWhen_RemoteVerifierFails() external {
        verifier.setImageIdTrusted(BLOCK_IMAGE_ID, true);
        verifier.setImageIdTrusted(AGGREGATION_IMAGE_ID, true);
        bytes memory seal = bytes("seal");
        bytes memory proof = abi.encode(seal, BLOCK_IMAGE_ID, AGGREGATION_IMAGE_ID);
        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            bytes32(uint256(1)), address(verifier), address(0), CHAIN_ID
        );
        bytes32 journalDigest = sha256(abi.encodePacked(publicInput));

        vm.mockCallRevert(
            REMOTE,
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, AGGREGATION_IMAGE_ID, journalDigest)),
            "fail"
        );

        vm.expectRevert(Risc0Verifier.RISC_ZERO_INVALID_PROOF.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_SucceedsAndCallsRemoteVerifier() external {
        verifier.setImageIdTrusted(BLOCK_IMAGE_ID, true);
        verifier.setImageIdTrusted(AGGREGATION_IMAGE_ID, true);
        bytes memory seal = bytes("seal");
        bytes memory proof = abi.encode(seal, BLOCK_IMAGE_ID, AGGREGATION_IMAGE_ID);
        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            bytes32(uint256(1)), address(verifier), address(0), CHAIN_ID
        );
        bytes32 journalDigest = sha256(abi.encodePacked(publicInput));

        vm.expectCall(
            REMOTE,
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, AGGREGATION_IMAGE_ID, journalDigest))
        );
        vm.mockCall(
            REMOTE,
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, AGGREGATION_IMAGE_ID, journalDigest)),
            ""
        );

        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }
}
