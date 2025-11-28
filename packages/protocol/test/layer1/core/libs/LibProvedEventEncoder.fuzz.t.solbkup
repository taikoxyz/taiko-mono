// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventEncoder } from "src/layer1/core/libs/LibProvedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title LibProvedEventEncoderFuzzTest
/// @notice Comprehensive fuzz tests for LibProvedEventEncoder
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventEncoderFuzzTest is Test {
    uint256 constant MAX_BOND_INSTRUCTIONS = 100;
    uint48 constant MAX_UINT48 = type(uint48).max;

    function testFuzz_encodeDecodeBasicFields(
        uint48 _proposalId,
        uint8 _span,
        bytes32 _transitionHash,
        bytes32 _checkpointHash
    )
        public
        pure
    {
        IInbox.ProvedEventPayload memory original;
        original.proposalId = _proposalId;
        original.transitionRecord.span = _span;
        original.transitionRecord.transitionHash = _transitionHash;
        original.transitionRecord.checkpointHash = _checkpointHash;
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.transitionRecord.span, original.transitionRecord.span);
        assertEq(decoded.transitionRecord.transitionHash, original.transitionRecord.transitionHash);
        assertEq(decoded.transitionRecord.checkpointHash, original.transitionRecord.checkpointHash);
    }

    function testFuzz_encodeDecodeTransition(
        bytes32 _proposalHash,
        bytes32 _parentTransitionHash,
        uint48 _endBlockNumber,
        bytes32 _endBlockHash,
        bytes32 _endStateRoot,
        address _designatedProver,
        address _actualProver
    )
        public
        pure
    {
        IInbox.ProvedEventPayload memory original;
        original.proposalId = 123;
        original.transition.proposalHash = _proposalHash;
        original.transition.parentTransitionHash = _parentTransitionHash;
        original.transition.checkpoint.blockNumber = _endBlockNumber;
        original.transition.checkpoint.blockHash = _endBlockHash;
        original.transition.checkpoint.stateRoot = _endStateRoot;
        original.metadata.designatedProver = _designatedProver;
        original.metadata.actualProver = _actualProver;
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.transition.proposalHash, original.transition.proposalHash);
        assertEq(decoded.transition.parentTransitionHash, original.transition.parentTransitionHash);
        assertEq(
            decoded.transition.checkpoint.blockNumber, original.transition.checkpoint.blockNumber
        );
        assertEq(decoded.transition.checkpoint.blockHash, original.transition.checkpoint.blockHash);
        assertEq(decoded.transition.checkpoint.stateRoot, original.transition.checkpoint.stateRoot);
        assertEq(decoded.metadata.designatedProver, original.metadata.designatedProver);
        assertEq(decoded.metadata.actualProver, original.metadata.actualProver);
    }

    function testFuzz_encodeBondInstructions(uint8 _instructionCount) public pure {
        vm.assume(_instructionCount <= MAX_BOND_INSTRUCTIONS);

        IInbox.ProvedEventPayload memory original;
        original.proposalId = 100;
        original.transitionRecord.bondInstructions =
            new LibBonds.BondInstruction[](_instructionCount);

        for (uint256 i = 0; i < _instructionCount; i++) {
            original.transitionRecord.bondInstructions[i].proposalId = uint48(i + 1000);
            original.transitionRecord.bondInstructions[i].bondType = LibBonds.BondType(i % 3);
            original.transitionRecord.bondInstructions[i].payer = address(uint160(i * 1000));
            original.transitionRecord.bondInstructions[i].payee = address(uint160(i * 2000));
        }

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.transitionRecord.bondInstructions.length, _instructionCount);

        for (uint256 i = 0; i < _instructionCount; i++) {
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
                decoded.transitionRecord.bondInstructions[i].payee,
                original.transitionRecord.bondInstructions[i].payee
            );
        }
    }

    function testFuzz_encodeDecodeComplete(
        uint48 _proposalId,
        address _designatedProver,
        uint8 _bondInstructionCount
    )
        public
        pure
    {
        vm.assume(_bondInstructionCount <= 10); // Keep small for efficiency

        IInbox.ProvedEventPayload memory original;

        // Set proposalId
        original.proposalId = _proposalId;

        // Create Transition with derived values
        original.transition.proposalHash = keccak256(abi.encode("proposal", _proposalId));
        original.transition.parentTransitionHash = keccak256(abi.encode("parent", _proposalId));
        original.transition.checkpoint.blockNumber =
            uint48(uint256(keccak256(abi.encode(_proposalId))) % MAX_UINT48);
        original.transition.checkpoint.blockHash = keccak256(abi.encode("endBlock", _proposalId));
        original.transition.checkpoint.stateRoot = keccak256(abi.encode("endState", _proposalId));
        original.metadata.designatedProver = _designatedProver;
        original.metadata.actualProver = address(uint160(_designatedProver) + 1);

        // Create TransitionRecord with derived values
        original.transitionRecord.span = uint8(uint256(keccak256(abi.encode(_proposalId))) % 10 + 1);
        original.transitionRecord.transitionHash =
            keccak256(abi.encode("transitionHash", _proposalId));
        original.transitionRecord.checkpointHash =
            keccak256(abi.encode("checkpointHash", _proposalId));

        // Create bond instructions
        original.transitionRecord.bondInstructions =
            new LibBonds.BondInstruction[](_bondInstructionCount);
        for (uint256 i = 0; i < _bondInstructionCount; i++) {
            original.transitionRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(_proposalId + i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(0xaaaa + i * 10)),
                payee: address(uint160(0xbbbb + i * 10))
            });
        }

        // Encode and decode
        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify all fields
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
        assertEq(decoded.transitionRecord.bondInstructions.length, _bondInstructionCount);
    }

    function testFuzz_encodedSizeIsOptimal(uint8 _bondInstructionCount) public pure {
        vm.assume(_bondInstructionCount <= MAX_BOND_INSTRUCTIONS);

        IInbox.ProvedEventPayload memory payload = _createPayload(_bondInstructionCount);

        bytes memory encoded = LibProvedEventEncoder.encode(payload);
        bytes memory abiEncoded = abi.encode(payload);

        // Compact encoding should be smaller than ABI encoding
        assertLt(encoded.length, abiEncoded.length);
    }

    function testFuzz_roundTripPreservesData(
        uint48 _proposalId,
        uint8 _span,
        uint8 _bondInstructionCount
    )
        public
        pure
    {
        vm.assume(_bondInstructionCount <= 5); // Keep small for efficiency

        IInbox.ProvedEventPayload memory original = _createPayload(_bondInstructionCount);
        original.proposalId = _proposalId;
        original.transitionRecord.span = _span;

        // First round trip
        bytes memory encoded1 = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded1 = LibProvedEventEncoder.decode(encoded1);

        // Second round trip
        bytes memory encoded2 = LibProvedEventEncoder.encode(decoded1);
        IInbox.ProvedEventPayload memory decoded2 = LibProvedEventEncoder.decode(encoded2);

        // Verify data is preserved through multiple round trips
        assertEq(decoded1.proposalId, decoded2.proposalId);
        assertEq(decoded1.transitionRecord.span, decoded2.transitionRecord.span);
        assertEq(decoded1.transition.proposalHash, decoded2.transition.proposalHash);
        assertEq(encoded1, encoded2);
    }

    function testFuzz_maxValues() public pure {
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
        original.transitionRecord.bondInstructions = new LibBonds.BondInstruction[](1);
        original.transitionRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: type(uint48).max,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(type(uint160).max),
            payee: address(type(uint160).max)
        });

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.proposalId, type(uint48).max);
        assertEq(decoded.transition.checkpoint.blockNumber, type(uint48).max);
        assertEq(decoded.transitionRecord.span, type(uint8).max);
    }

    function _createPayload(uint8 _bondInstructionCount)
        private
        pure
        returns (IInbox.ProvedEventPayload memory payload)
    {
        payload.proposalId = 123;
        payload.transition.proposalHash = keccak256("proposal");
        payload.transition.parentTransitionHash = keccak256("parent");
        payload.transition.checkpoint.blockNumber = 1_000_000;
        payload.transition.checkpoint.blockHash = keccak256("endBlock");
        payload.transition.checkpoint.stateRoot = keccak256("endState");
        payload.metadata.designatedProver = address(0x1234);
        payload.metadata.actualProver = address(0x5678);
        payload.transitionRecord.span = 3;
        payload.transitionRecord.transitionHash = keccak256("transitionHash");
        payload.transitionRecord.checkpointHash = keccak256("checkpointHash");

        payload.transitionRecord.bondInstructions =
            new LibBonds.BondInstruction[](_bondInstructionCount);
        for (uint256 i = 0; i < _bondInstructionCount; i++) {
            payload.transitionRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(123 + i),
                bondType: i % 2 == 0 ? LibBonds.BondType.LIVENESS : LibBonds.BondType.PROVABILITY,
                payer: address(uint160(0x1000 + i)),
                payee: address(uint160(0x2000 + i))
            });
        }
    }
}
