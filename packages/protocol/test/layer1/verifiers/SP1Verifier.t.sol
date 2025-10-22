// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ISP1Verifier } from "@sp1-contracts/src/ISP1Verifier.sol";
import "forge-std/src/Test.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { SP1Verifier } from "src/layer1/verifiers/SP1Verifier.sol";

contract SP1VerifierTest is Test {
    uint64 private constant CHAIN_ID = 167;
    address private constant REMOTE = address(0xCAFE);

    SP1Verifier internal verifier;

    bytes32 internal constant AGGREGATION_VKEY = bytes32("agg");
    bytes32 internal constant PROGRAM_VKEY = bytes32("prog");

    function setUp() external {
        verifier = new SP1Verifier(CHAIN_ID, REMOTE, address(this));
    }

    function _makeProof(bytes memory tail) internal pure returns (bytes memory) {
        return abi.encodePacked(AGGREGATION_VKEY, PROGRAM_VKEY, tail);
    }

    function test_setProgramTrusted_UpdatesMapping() external {
        vm.expectEmit();
        emit SP1Verifier.ProgramTrusted(AGGREGATION_VKEY, true);
        verifier.setProgramTrusted(AGGREGATION_VKEY, true);

        assertTrue(verifier.isProgramTrusted(AGGREGATION_VKEY));
    }

    function test_verifyProof_RevertWhen_ProofTooShort() external {
        bytes memory proof = bytes.concat(bytes32(0));
        vm.expectRevert(SP1Verifier.SP1_INVALID_PARAMS.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_RevertWhen_AggregationNotTrusted() external {
        verifier.setProgramTrusted(PROGRAM_VKEY, true);
        bytes memory proof = _makeProof(hex"abcd");

        vm.expectRevert(SP1Verifier.SP1_INVALID_AGGREGATION_VKEY.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_RevertWhen_BlockProgramNotTrusted() external {
        verifier.setProgramTrusted(AGGREGATION_VKEY, true);
        bytes memory proof = _makeProof(hex"abcd");

        vm.expectRevert(SP1Verifier.SP1_INVALID_PROGRAM_VKEY.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_RevertWhen_RemoteVerifierFails() external {
        verifier.setProgramTrusted(AGGREGATION_VKEY, true);
        verifier.setProgramTrusted(PROGRAM_VKEY, true);
        bytes memory succinctProof = hex"abcd";
        bytes memory proof = _makeProof(succinctProof);

        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            bytes32(uint256(1)), address(verifier), address(0), CHAIN_ID
        );

        vm.mockCallRevert(
            REMOTE,
            abi.encodeCall(
                ISP1Verifier.verifyProof,
                (AGGREGATION_VKEY, abi.encodePacked(publicInput), succinctProof)
            ),
            "fail"
        );

        vm.expectRevert(SP1Verifier.SP1_INVALID_PROOF.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }

    function test_verifyProof_Succeeds() external {
        verifier.setProgramTrusted(AGGREGATION_VKEY, true);
        verifier.setProgramTrusted(PROGRAM_VKEY, true);
        bytes memory succinctProof = hex"abcd";
        bytes memory proof = _makeProof(succinctProof);

        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            bytes32(uint256(1)), address(verifier), address(0), CHAIN_ID
        );

        bytes memory expectedCall = abi.encodeCall(
            ISP1Verifier.verifyProof,
            (AGGREGATION_VKEY, abi.encodePacked(publicInput), succinctProof)
        );

        vm.expectCall(REMOTE, expectedCall);
        vm.mockCall(REMOTE, expectedCall, "");

        verifier.verifyProof(0, bytes32(uint256(1)), proof);
    }
}
