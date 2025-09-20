// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProvedEventEncoder } from "contracts/layer1/shasta/libs/LibProvedEventEncoder.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "contracts/shared/shasta/libs/LibBonds.sol";

/// @title LibProvedEventEncoderTest
/// @notice End-to-end tests for LibProvedEventEncoder encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventEncoderTest is Test {
    function test_encodeDecodeProvedEvent_empty() public pure {
        // Create empty proved event (no bond instructions)
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 12_345;
        original.transition.proposalHash = keccak256("proposal");
        original.transition.parentTransitionHash = keccak256("parent");
        original.transition.checkpoint.blockNumber = 999_999;
        original.transition.checkpoint.blockHash = keccak256("block");
        original.transition.checkpoint.stateRoot = keccak256("state");
        original.metadata.designatedProver = address(0x1234567890123456789012345678901234567890);
        original.metadata.actualProver = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        original.transitionRecord.span = 42;
        original.transitionRecord.transitionHash = keccak256("transitionHash");
        original.transitionRecord.checkpointHash = keccak256("checkpointHash");
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        // Encode
        bytes memory encoded = LibProvedEventEncoder.encode(original);

        // Verify size calculation is correct
        uint256 expectedSize = LibProvedEventEncoder.calculateProvedEventSize(0);
        assertEq(encoded.length, expectedSize);

        // Decode
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.transition.proposalHash, original.transition.proposalHash);
        assertEq(decoded.transition.parentTransitionHash, original.transition.parentTransitionHash);
        assertEq(
            decoded.transition.checkpoint.blockNumber, original.transition.checkpoint.blockNumber
        );
        assertEq(decoded.transition.checkpoint.blockHash, original.transition.checkpoint.blockHash);
        assertEq(decoded.transition.checkpoint.stateRoot, original.transition.checkpoint.stateRoot);
        assertEq(decoded.metadata.designatedProver, original.metadata.designatedProver);
        assertEq(decoded.metadata.actualProver, original.metadata.actualProver);
        assertEq(decoded.transitionRecord.span, original.transitionRecord.span);
        assertEq(decoded.transitionRecord.transitionHash, original.transitionRecord.transitionHash);
        assertEq(decoded.transitionRecord.checkpointHash, original.transitionRecord.checkpointHash);
        assertEq(decoded.transitionRecord.bondInstructions.length, 0);
    }

    function test_encodeDecodeProvedEvent_withBondInstructions() public pure {
        // Create proved event with bond instructions
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 67_890;
        original.transition.proposalHash = keccak256("proposal2");
        original.transition.parentTransitionHash = keccak256("parent2");
        original.transition.checkpoint.blockNumber = 555_555;
        original.transition.checkpoint.blockHash = keccak256("block2");
        original.transition.checkpoint.stateRoot = keccak256("state2");
        original.metadata.designatedProver = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        original.metadata.actualProver = address(0x1111111111111111111111111111111111111111);
        original.transitionRecord.span = 100;
        original.transitionRecord.transitionHash = keccak256("transitionHash2");
        original.transitionRecord.checkpointHash = keccak256("checkpointHash2");

        // Add 3 bond instructions
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](3);
        original.transitionRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 111,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x2222222222222222222222222222222222222222),
            receiver: address(0x3333333333333333333333333333333333333333)
        });
        original.transitionRecord.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 222,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x4444444444444444444444444444444444444444),
            receiver: address(0x5555555555555555555555555555555555555555)
        });
        original.transitionRecord.bondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 333,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x6666666666666666666666666666666666666666),
            receiver: address(0x7777777777777777777777777777777777777777)
        });

        // Encode
        bytes memory encoded = LibProvedEventEncoder.encode(original);

        // Verify size calculation is correct
        uint256 expectedSize = LibProvedEventEncoder.calculateProvedEventSize(3);
        assertEq(encoded.length, expectedSize);

        // Decode
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.transition.proposalHash, original.transition.proposalHash);
        assertEq(decoded.transition.parentTransitionHash, original.transition.parentTransitionHash);
        assertEq(
            decoded.transition.checkpoint.blockNumber, original.transition.checkpoint.blockNumber
        );
        assertEq(decoded.transition.checkpoint.blockHash, original.transition.checkpoint.blockHash);
        assertEq(decoded.transition.checkpoint.stateRoot, original.transition.checkpoint.stateRoot);
        assertEq(decoded.metadata.designatedProver, original.metadata.designatedProver);
        assertEq(decoded.metadata.actualProver, original.metadata.actualProver);
        assertEq(decoded.transitionRecord.span, original.transitionRecord.span);
        assertEq(decoded.transitionRecord.transitionHash, original.transitionRecord.transitionHash);
        assertEq(decoded.transitionRecord.checkpointHash, original.transitionRecord.checkpointHash);
        assertEq(decoded.transitionRecord.bondInstructions.length, 3);

        // Verify bond instructions
        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                decoded.transitionRecord.bondInstructions[i].proposalId,
                original.transitionRecord.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.transitionRecord.bondInstructions[i].bondType),
                uint8(original.transitionRecord.bondInstructions[i].bondType)
            );
            assertEq(
                decoded.transitionRecord.bondInstructions[i].payer,
                original.transitionRecord.bondInstructions[i].payer
            );
            assertEq(
                decoded.transitionRecord.bondInstructions[i].receiver,
                original.transitionRecord.bondInstructions[i].receiver
            );
        }
    }

    function test_encodeDecodeProvedEvent_maxValues() public pure {
        // Test with maximum values
        IInbox.ProvedEventPayload memory original;
        original.proposalId = type(uint48).max;
        original.transition.proposalHash = bytes32(type(uint256).max);
        original.transition.parentTransitionHash = bytes32(type(uint256).max);
        original.transition.checkpoint.blockNumber = type(uint48).max;
        original.transition.checkpoint.blockHash = bytes32(type(uint256).max);
        original.transition.checkpoint.stateRoot = bytes32(type(uint256).max);
        original.metadata.designatedProver = address(type(uint160).max);
        original.metadata.actualProver = address(type(uint160).max);
        original.transitionRecord.span = type(uint8).max;
        original.transitionRecord.transitionHash = bytes32(type(uint256).max);
        original.transitionRecord.checkpointHash = bytes32(type(uint256).max);

        // Add one bond instruction with max values
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](1);
        original.transitionRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: type(uint48).max,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(type(uint160).max),
            receiver: address(type(uint160).max)
        });

        // Encode and decode
        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify max values are preserved
        assertEq(decoded.proposalId, type(uint48).max);
        assertEq(decoded.transition.checkpoint.blockNumber, type(uint48).max);
        assertEq(decoded.transitionRecord.span, type(uint8).max);
        assertEq(decoded.transitionRecord.bondInstructions[0].proposalId, type(uint48).max);
    }

    function test_encodeDecodeProvedEvent_zeroValues() public pure {
        // Test with zero/minimum values
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 0;
        original.transition.proposalHash = bytes32(0);
        original.transition.parentTransitionHash = bytes32(0);
        original.transition.checkpoint.blockNumber = 0;
        original.transition.checkpoint.blockHash = bytes32(0);
        original.transition.checkpoint.stateRoot = bytes32(0);
        original.metadata.designatedProver = address(0);
        original.metadata.actualProver = address(0);
        original.transitionRecord.span = 0;
        original.transitionRecord.transitionHash = bytes32(0);
        original.transitionRecord.checkpointHash = bytes32(0);
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        // Encode and decode
        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify zero values are preserved
        assertEq(decoded.proposalId, 0);
        assertEq(decoded.transition.proposalHash, bytes32(0));
        assertEq(decoded.transition.checkpoint.blockNumber, 0);
        assertEq(decoded.transitionRecord.span, 0);
        assertEq(decoded.transitionRecord.bondInstructions.length, 0);
    }

    function test_encodeProvedEvent_gasEfficiency() public {
        // Compare gas usage with ABI encoding
        IInbox.ProvedEventPayload memory payload;
        payload.proposalId = 123;
        payload.transition.proposalHash = keccak256("proposal");
        payload.transition.parentTransitionHash = keccak256("parent");
        payload.transition.checkpoint.blockNumber = 1_000_000;
        payload.transition.checkpoint.blockHash = keccak256("endBlock");
        payload.transition.checkpoint.stateRoot = keccak256("endState");
        payload.metadata.designatedProver = address(0x1234);
        payload.metadata.actualProver = address(0x5678);
        payload.transitionRecord.span = 5;
        payload.transitionRecord.transitionHash = keccak256("transitionHash");
        payload.transitionRecord.checkpointHash = keccak256("checkpointHash");

        // Add 2 bond instructions
        payload.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](2);
        payload.transitionRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 123,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xaaaa),
            receiver: address(0xbbbb)
        });
        payload.transitionRecord.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 124,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0xcccc),
            receiver: address(0xdddd)
        });

        // Measure encoding gas
        uint256 gasStart = gasleft();
        bytes memory encoded = LibProvedEventEncoder.encode(payload);
        uint256 compactGas = gasStart - gasleft();

        // Measure ABI encoding gas
        gasStart = gasleft();
        bytes memory abiEncoded = abi.encode(payload);
        uint256 abiGas = gasStart - gasleft();

        // Log results
        emit log_named_uint("Compact encoding gas", compactGas);
        emit log_named_uint("ABI encoding gas", abiGas);
        emit log_named_uint("Compact encoded size", encoded.length);
        emit log_named_uint("ABI encoded size", abiEncoded.length);

        // Compact encoding should be more efficient in size
        assertLt(encoded.length, abiEncoded.length);
    }
}
