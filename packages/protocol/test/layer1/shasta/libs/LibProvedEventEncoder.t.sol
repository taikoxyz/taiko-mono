// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProvedEventEncoder } from "contracts/layer1/shasta/libs/LibProvedEventEncoder.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventEncoderTest
/// @notice End-to-end tests for LibProvedEventEncoder encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventEncoderTest is Test {
    function test_encodeDecodeProvedEvent_empty() public pure {
        // Create empty proved event (no bond instructions)
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 12_345;
        original.claim.proposalHash = keccak256("proposal");
        original.claim.parentClaimHash = keccak256("parent");
        original.claim.endBlockMiniHeader.number = 999_999;
        original.claim.endBlockMiniHeader.hash = keccak256("block");
        original.claim.endBlockMiniHeader.stateRoot = keccak256("state");
        original.claim.designatedProver = address(0x1234567890123456789012345678901234567890);
        original.claim.actualProver = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        original.claimRecord.span = 42;
        original.claimRecord.claimHash = keccak256("claimHash");
        original.claimRecord.endBlockMiniHeaderHash = keccak256("endBlockMiniHeaderHash");
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        // Encode
        bytes memory encoded = LibProvedEventEncoder.encode(original);

        // Verify size calculation is correct
        uint256 expectedSize = LibProvedEventEncoder.calculateProvedEventSize(0);
        assertEq(encoded.length, expectedSize);

        // Decode
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockMiniHeader.number, original.claim.endBlockMiniHeader.number);
        assertEq(decoded.claim.endBlockMiniHeader.hash, original.claim.endBlockMiniHeader.hash);
        assertEq(
            decoded.claim.endBlockMiniHeader.stateRoot, original.claim.endBlockMiniHeader.stateRoot
        );
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.claimRecord.span, original.claimRecord.span);
        assertEq(decoded.claimRecord.claimHash, original.claimRecord.claimHash);
        assertEq(
            decoded.claimRecord.endBlockMiniHeaderHash, original.claimRecord.endBlockMiniHeaderHash
        );
        assertEq(decoded.claimRecord.bondInstructions.length, 0);
    }

    function test_encodeDecodeProvedEvent_withBondInstructions() public pure {
        // Create proved event with bond instructions
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 67_890;
        original.claim.proposalHash = keccak256("proposal2");
        original.claim.parentClaimHash = keccak256("parent2");
        original.claim.endBlockMiniHeader.number = 555_555;
        original.claim.endBlockMiniHeader.hash = keccak256("block2");
        original.claim.endBlockMiniHeader.stateRoot = keccak256("state2");
        original.claim.designatedProver = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        original.claim.actualProver = address(0x1111111111111111111111111111111111111111);
        original.claimRecord.span = 100;
        original.claimRecord.claimHash = keccak256("claimHash2");
        original.claimRecord.endBlockMiniHeaderHash = keccak256("endBlockMiniHeaderHash2");

        // Add 3 bond instructions
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](3);
        original.claimRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 111,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x2222222222222222222222222222222222222222),
            receiver: address(0x3333333333333333333333333333333333333333)
        });
        original.claimRecord.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 222,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x4444444444444444444444444444444444444444),
            receiver: address(0x5555555555555555555555555555555555555555)
        });
        original.claimRecord.bondInstructions[2] = LibBonds.BondInstruction({
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
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockMiniHeader.number, original.claim.endBlockMiniHeader.number);
        assertEq(decoded.claim.endBlockMiniHeader.hash, original.claim.endBlockMiniHeader.hash);
        assertEq(
            decoded.claim.endBlockMiniHeader.stateRoot, original.claim.endBlockMiniHeader.stateRoot
        );
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.claimRecord.span, original.claimRecord.span);
        assertEq(decoded.claimRecord.claimHash, original.claimRecord.claimHash);
        assertEq(
            decoded.claimRecord.endBlockMiniHeaderHash, original.claimRecord.endBlockMiniHeaderHash
        );
        assertEq(decoded.claimRecord.bondInstructions.length, 3);

        // Verify bond instructions
        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                decoded.claimRecord.bondInstructions[i].proposalId,
                original.claimRecord.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.claimRecord.bondInstructions[i].bondType),
                uint8(original.claimRecord.bondInstructions[i].bondType)
            );
            assertEq(
                decoded.claimRecord.bondInstructions[i].payer,
                original.claimRecord.bondInstructions[i].payer
            );
            assertEq(
                decoded.claimRecord.bondInstructions[i].receiver,
                original.claimRecord.bondInstructions[i].receiver
            );
        }
    }

    function test_encodeDecodeProvedEvent_maxValues() public pure {
        // Test with maximum values
        IInbox.ProvedEventPayload memory original;
        original.proposalId = type(uint48).max;
        original.claim.proposalHash = bytes32(type(uint256).max);
        original.claim.parentClaimHash = bytes32(type(uint256).max);
        original.claim.endBlockMiniHeader.number = type(uint48).max;
        original.claim.endBlockMiniHeader.hash = bytes32(type(uint256).max);
        original.claim.endBlockMiniHeader.stateRoot = bytes32(type(uint256).max);
        original.claim.designatedProver = address(type(uint160).max);
        original.claim.actualProver = address(type(uint160).max);
        original.claimRecord.span = type(uint8).max;
        original.claimRecord.claimHash = bytes32(type(uint256).max);
        original.claimRecord.endBlockMiniHeaderHash = bytes32(type(uint256).max);

        // Add one bond instruction with max values
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](1);
        original.claimRecord.bondInstructions[0] = LibBonds.BondInstruction({
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
        assertEq(decoded.claim.endBlockMiniHeader.number, type(uint48).max);
        assertEq(decoded.claimRecord.span, type(uint8).max);
        assertEq(decoded.claimRecord.bondInstructions[0].proposalId, type(uint48).max);
    }

    function test_encodeDecodeProvedEvent_zeroValues() public pure {
        // Test with zero/minimum values
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 0;
        original.claim.proposalHash = bytes32(0);
        original.claim.parentClaimHash = bytes32(0);
        original.claim.endBlockMiniHeader.number = 0;
        original.claim.endBlockMiniHeader.hash = bytes32(0);
        original.claim.endBlockMiniHeader.stateRoot = bytes32(0);
        original.claim.designatedProver = address(0);
        original.claim.actualProver = address(0);
        original.claimRecord.span = 0;
        original.claimRecord.claimHash = bytes32(0);
        original.claimRecord.endBlockMiniHeaderHash = bytes32(0);
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        // Encode and decode
        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify zero values are preserved
        assertEq(decoded.proposalId, 0);
        assertEq(decoded.claim.proposalHash, bytes32(0));
        assertEq(decoded.claim.endBlockMiniHeader.number, 0);
        assertEq(decoded.claimRecord.span, 0);
        assertEq(decoded.claimRecord.bondInstructions.length, 0);
    }

    function test_encodeProvedEvent_gasEfficiency() public {
        // Compare gas usage with ABI encoding
        IInbox.ProvedEventPayload memory payload;
        payload.proposalId = 123;
        payload.claim.proposalHash = keccak256("proposal");
        payload.claim.parentClaimHash = keccak256("parent");
        payload.claim.endBlockMiniHeader.number = 1_000_000;
        payload.claim.endBlockMiniHeader.hash = keccak256("endBlock");
        payload.claim.endBlockMiniHeader.stateRoot = keccak256("endState");
        payload.claim.designatedProver = address(0x1234);
        payload.claim.actualProver = address(0x5678);
        payload.claimRecord.span = 5;
        payload.claimRecord.claimHash = keccak256("claimHash");
        payload.claimRecord.endBlockMiniHeaderHash = keccak256("endBlockMiniHeaderHash");

        // Add 2 bond instructions
        payload.claimRecord.bondInstructions = new LibBonds.BondInstruction[](2);
        payload.claimRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 123,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xaaaa),
            receiver: address(0xbbbb)
        });
        payload.claimRecord.bondInstructions[1] = LibBonds.BondInstruction({
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
