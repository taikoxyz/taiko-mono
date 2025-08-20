// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProvedEventEncoder } from "src/layer1/shasta/libs/LibProvedEventEncoder.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventEncoderFuzzTest
/// @notice Comprehensive fuzz tests for LibProvedEventEncoder
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventEncoderFuzzTest is Test {
    uint256 constant MAX_BOND_INSTRUCTIONS = 100;
    uint48 constant MAX_UINT48 = type(uint48).max;
    uint16 constant MAX_UINT16 = type(uint16).max;
    uint8 constant MAX_UINT8 = type(uint8).max;

    function testFuzz_encodeDecodeBasicFields(
        uint48 _proposalId,
        uint8 _span,
        bytes32 _claimHash,
        bytes32 _endBlockMiniHeaderHash
    )
        public
        pure
    {
        IInbox.ProvedEventPayload memory original;
        original.proposalId = _proposalId;
        original.claimRecord.span = _span;
        original.claimRecord.claimHash = _claimHash;
        original.claimRecord.endBlockMiniHeaderHash = _endBlockMiniHeaderHash;
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claimRecord.span, original.claimRecord.span);
        assertEq(decoded.claimRecord.claimHash, original.claimRecord.claimHash);
        assertEq(
            decoded.claimRecord.endBlockMiniHeaderHash, original.claimRecord.endBlockMiniHeaderHash
        );
    }

    function testFuzz_encodeDecodeClaim(
        bytes32 _proposalHash,
        bytes32 _parentClaimHash,
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
        original.claim.proposalHash = _proposalHash;
        original.claim.parentClaimHash = _parentClaimHash;
        original.claim.endBlockMiniHeader.number = _endBlockNumber;
        original.claim.endBlockMiniHeader.hash = _endBlockHash;
        original.claim.endBlockMiniHeader.stateRoot = _endStateRoot;
        original.claim.designatedProver = _designatedProver;
        original.claim.actualProver = _actualProver;
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](0);

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockMiniHeader.number, original.claim.endBlockMiniHeader.number);
        assertEq(decoded.claim.endBlockMiniHeader.hash, original.claim.endBlockMiniHeader.hash);
        assertEq(
            decoded.claim.endBlockMiniHeader.stateRoot, original.claim.endBlockMiniHeader.stateRoot
        );
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
    }

    function testFuzz_encodeBondInstructions(uint8 _instructionCount) public pure {
        vm.assume(_instructionCount <= MAX_BOND_INSTRUCTIONS);

        IInbox.ProvedEventPayload memory original;
        original.proposalId = 100;
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](_instructionCount);

        for (uint256 i = 0; i < _instructionCount; i++) {
            original.claimRecord.bondInstructions[i].proposalId = uint48(i + 1000);
            original.claimRecord.bondInstructions[i].bondType = LibBonds.BondType(i % 3);
            original.claimRecord.bondInstructions[i].payer = address(uint160(i * 1000));
            original.claimRecord.bondInstructions[i].receiver = address(uint160(i * 2000));
        }

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.claimRecord.bondInstructions.length, _instructionCount);

        for (uint256 i = 0; i < _instructionCount; i++) {
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

        // Create Claim with derived values
        original.claim.proposalHash = keccak256(abi.encode("proposal", _proposalId));
        original.claim.parentClaimHash = keccak256(abi.encode("parent", _proposalId));
        original.claim.endBlockMiniHeader.number =
            uint48(uint256(keccak256(abi.encode(_proposalId))) % MAX_UINT48);
        original.claim.endBlockMiniHeader.hash = keccak256(abi.encode("endBlock", _proposalId));
        original.claim.endBlockMiniHeader.stateRoot = keccak256(abi.encode("endState", _proposalId));
        original.claim.designatedProver = _designatedProver;
        original.claim.actualProver = address(uint160(_designatedProver) + 1);

        // Create ClaimRecord with derived values
        original.claimRecord.span = uint8(uint256(keccak256(abi.encode(_proposalId))) % 10 + 1);
        original.claimRecord.claimHash = keccak256(abi.encode("claimHash", _proposalId));
        original.claimRecord.endBlockMiniHeaderHash =
            keccak256(abi.encode("endBlockMiniHeaderHash", _proposalId));

        // Create bond instructions
        original.claimRecord.bondInstructions =
            new LibBonds.BondInstruction[](_bondInstructionCount);
        for (uint256 i = 0; i < _bondInstructionCount; i++) {
            original.claimRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(_proposalId + i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(0xaaaa + i * 10)),
                receiver: address(uint160(0xbbbb + i * 10))
            });
        }

        // Encode and decode
        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify all fields
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
        assertEq(decoded.claimRecord.bondInstructions.length, _bondInstructionCount);
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
        original.claimRecord.span = _span;

        // First round trip
        bytes memory encoded1 = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded1 = LibProvedEventEncoder.decode(encoded1);

        // Second round trip
        bytes memory encoded2 = LibProvedEventEncoder.encode(decoded1);
        IInbox.ProvedEventPayload memory decoded2 = LibProvedEventEncoder.decode(encoded2);

        // Verify data is preserved through multiple round trips
        assertEq(decoded1.proposalId, decoded2.proposalId);
        assertEq(decoded1.claimRecord.span, decoded2.claimRecord.span);
        assertEq(decoded1.claim.proposalHash, decoded2.claim.proposalHash);
        assertEq(encoded1, encoded2);
    }

    function testFuzz_maxValues() public pure {
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
        original.claimRecord.bondInstructions = new LibBonds.BondInstruction[](1);
        original.claimRecord.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: type(uint48).max,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(type(uint160).max),
            receiver: address(type(uint160).max)
        });

        bytes memory encoded = LibProvedEventEncoder.encode(original);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(decoded.proposalId, type(uint48).max);
        assertEq(decoded.claim.endBlockMiniHeader.number, type(uint48).max);
        assertEq(decoded.claimRecord.span, type(uint8).max);
    }

    function _createPayload(uint8 _bondInstructionCount)
        private
        pure
        returns (IInbox.ProvedEventPayload memory payload)
    {
        payload.proposalId = 123;
        payload.claim.proposalHash = keccak256("proposal");
        payload.claim.parentClaimHash = keccak256("parent");
        payload.claim.endBlockMiniHeader.number = 1_000_000;
        payload.claim.endBlockMiniHeader.hash = keccak256("endBlock");
        payload.claim.endBlockMiniHeader.stateRoot = keccak256("endState");
        payload.claim.designatedProver = address(0x1234);
        payload.claim.actualProver = address(0x5678);
        payload.claimRecord.span = 3;
        payload.claimRecord.claimHash = keccak256("claimHash");
        payload.claimRecord.endBlockMiniHeaderHash = keccak256("endBlockMiniHeaderHash");

        payload.claimRecord.bondInstructions = new LibBonds.BondInstruction[](_bondInstructionCount);
        for (uint256 i = 0; i < _bondInstructionCount; i++) {
            payload.claimRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(123 + i),
                bondType: i % 2 == 0 ? LibBonds.BondType.LIVENESS : LibBonds.BondType.PROVABILITY,
                payer: address(uint160(0x1000 + i)),
                receiver: address(uint160(0x2000 + i))
            });
        }
    }
}
