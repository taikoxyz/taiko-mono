// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ShadowVerifier} from "../src/impl/ShadowVerifier.sol";
import {IShadow} from "../src/iface/IShadow.sol";
import {IShadowVerifier} from "../src/iface/IShadowVerifier.sol";
import {MockCircuitVerifier} from "./mocks/MockCircuitVerifier.sol";
import {MockCheckpointStore} from "./mocks/MockCheckpointStore.sol";

contract ShadowVerifierTest is Test {
    MockCheckpointStore internal checkpointStore;
    MockCircuitVerifier internal circuitVerifier;
    ShadowVerifier internal verifier;

    function setUp() public {
        checkpointStore = new MockCheckpointStore();
        circuitVerifier = new MockCircuitVerifier();
        verifier = new ShadowVerifier(address(checkpointStore), address(circuitVerifier));
    }

    function test_verifyProof_succeeds() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        bool ok = verifier.verifyProof("", input);
        assertTrue(ok);
    }

    function test_verifyProof_RevertWhen_StateRootMismatch() external {
        uint48 blockNumber = 100;
        bytes32 expectedRoot = keccak256("expected");
        bytes32 actualRoot = keccak256("actual");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), expectedRoot);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: actualRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        vm.expectRevert(abi.encodeWithSelector(IShadowVerifier.StateRootMismatch.selector, expectedRoot, actualRoot));
        verifier.verifyProof("", input);
    }

    function test_verifyProof_RevertWhen_ProofVerificationFails() external {
        uint48 blockNumber = 100;
        bytes32 stateRoot = keccak256("root");
        checkpointStore.setCheckpoint(blockNumber, bytes32(0), stateRoot);
        circuitVerifier.setShouldVerify(false);

        IShadow.PublicInput memory input = IShadow.PublicInput({
            blockNumber: blockNumber,
            stateRoot: stateRoot,
            chainId: block.chainid,
            noteIndex: 1,
            amount: 1 ether,
            recipient: address(0xBEEF),
            nullifier: keccak256("nullifier"),
            powDigest: bytes32(uint256(1) << 24)
        });

        vm.expectRevert(abi.encodeWithSelector(IShadowVerifier.ProofVerificationFailed.selector));
        verifier.verifyProof("", input);
    }
}
