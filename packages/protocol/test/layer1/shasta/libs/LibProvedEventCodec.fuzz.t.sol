// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProvedEventCodec } from "src/layer1/shasta/libs/LibProvedEventCodec.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventCodecFuzzTest
/// @notice Comprehensive fuzz tests for LibProvedEventCodec
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventCodecFuzzTest is Test {
    uint256 constant MAX_BOND_INSTRUCTIONS = 100;
    uint48 constant MAX_UINT48 = type(uint48).max;
    uint16 constant MAX_UINT16 = type(uint16).max;
    uint8 constant MAX_UINT8 = type(uint8).max;

    function testFuzz_encodeDecodeClaimRecord_basicFields(
        uint48 _proposalId,
        uint8 _span
    )
        public
        pure
    {
        IInbox.ClaimRecord memory original;
        original.proposalId = _proposalId;
        original.span = _span;
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.span, original.span);
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
        IInbox.ClaimRecord memory original;
        original.claim.proposalHash = _proposalHash;
        original.claim.parentClaimHash = _parentClaimHash;
        original.claim.endBlockNumber = _endBlockNumber;
        original.claim.endBlockHash = _endBlockHash;
        original.claim.endStateRoot = _endStateRoot;
        original.claim.designatedProver = _designatedProver;
        original.claim.actualProver = _actualProver;
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
    }

    function testFuzz_encodeBondInstructions(
        uint8 _instructionCount
    )
        public
        pure
    {
        vm.assume(_instructionCount <= MAX_BOND_INSTRUCTIONS);
        
        IInbox.ClaimRecord memory original;
        original.bondInstructions = new LibBonds.BondInstruction[](_instructionCount);
        
        for (uint256 i = 0; i < _instructionCount; i++) {
            original.bondInstructions[i].proposalId = uint48(i + 1000);
            original.bondInstructions[i].bondType = LibBonds.BondType(i % 3);
            original.bondInstructions[i].payer = address(uint160(i * 1000));
            original.bondInstructions[i].receiver = address(uint160(i * 2000));
        }
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(decoded.bondInstructions.length, _instructionCount);
        
        for (uint256 i = 0; i < _instructionCount; i++) {
            assertEq(decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId);
            assertEq(uint8(decoded.bondInstructions[i].bondType), uint8(original.bondInstructions[i].bondType));
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }

    function testFuzz_completeEncodeDecode(
        uint48 _proposalId,
        bytes32 _proposalHash,
        bytes32 _parentClaimHash,
        uint48 _endBlockNumber,
        bytes32 _endBlockHash,
        bytes32 _endStateRoot,
        address _designatedProver,
        address _actualProver,
        uint8 _span,
        uint8 _instructionCount
    )
        public
        pure
    {
        vm.assume(_instructionCount <= 20);
        
        IInbox.ClaimRecord memory original;
        original.proposalId = _proposalId;
        original.claim.proposalHash = _proposalHash;
        original.claim.parentClaimHash = _parentClaimHash;
        original.claim.endBlockNumber = _endBlockNumber;
        original.claim.endBlockHash = _endBlockHash;
        original.claim.endStateRoot = _endStateRoot;
        original.claim.designatedProver = _designatedProver;
        original.claim.actualProver = _actualProver;
        original.span = _span;
        
        original.bondInstructions = new LibBonds.BondInstruction[](_instructionCount);
        for (uint256 i = 0; i < _instructionCount; i++) {
            original.bondInstructions[i].proposalId = uint48(i);
            original.bondInstructions[i].bondType = LibBonds.BondType(i % 3);
            original.bondInstructions[i].payer = address(uint160(uint256(keccak256(abi.encode(_proposalHash, i, "payer")))));
            original.bondInstructions[i].receiver = address(uint160(uint256(keccak256(abi.encode(_proposalHash, i, "receiver")))));
        }
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        
        uint256 expectedSize = LibProvedEventCodec.calculateClaimRecordSize(_instructionCount);
        assertEq(encoded.length, expectedSize);
        
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, _instructionCount);
        
        for (uint256 i = 0; i < _instructionCount; i++) {
            assertEq(decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId);
            assertEq(uint8(decoded.bondInstructions[i].bondType), uint8(original.bondInstructions[i].bondType));
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }

    function testFuzz_calculateSize(uint256 _bondInstructionCount) public pure {
        vm.assume(_bondInstructionCount <= MAX_UINT16);
        
        uint256 expectedSize = 183 + (_bondInstructionCount * 47);
        uint256 calculatedSize = LibProvedEventCodec.calculateClaimRecordSize(_bondInstructionCount);
        assertEq(calculatedSize, expectedSize);
    }

    function testFuzz_bondTypes(uint8 _bondType) public pure {
        vm.assume(_bondType <= uint8(LibBonds.BondType.LIVENESS));
        
        IInbox.ClaimRecord memory original;
        original.bondInstructions = new LibBonds.BondInstruction[](1);
        original.bondInstructions[0].bondType = LibBonds.BondType(_bondType);
        original.bondInstructions[0].payer = address(1);
        original.bondInstructions[0].receiver = address(2);
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(uint8(decoded.bondInstructions[0].bondType), _bondType);
    }

    function testFuzz_edgeCases_maxValues() public pure {
        IInbox.ClaimRecord memory original;
        original.proposalId = MAX_UINT48;
        original.claim.proposalHash = bytes32(type(uint256).max);
        original.claim.parentClaimHash = bytes32(type(uint256).max);
        original.claim.endBlockNumber = MAX_UINT48;
        original.claim.endBlockHash = bytes32(type(uint256).max);
        original.claim.endStateRoot = bytes32(type(uint256).max);
        original.claim.designatedProver = address(type(uint160).max);
        original.claim.actualProver = address(type(uint160).max);
        original.span = MAX_UINT8;
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(decoded.proposalId, MAX_UINT48);
        assertEq(decoded.claim.proposalHash, bytes32(type(uint256).max));
        assertEq(decoded.claim.parentClaimHash, bytes32(type(uint256).max));
        assertEq(decoded.claim.endBlockNumber, MAX_UINT48);
        assertEq(decoded.claim.endBlockHash, bytes32(type(uint256).max));
        assertEq(decoded.claim.endStateRoot, bytes32(type(uint256).max));
        assertEq(decoded.claim.designatedProver, address(type(uint160).max));
        assertEq(decoded.claim.actualProver, address(type(uint160).max));
        assertEq(decoded.span, MAX_UINT8);
    }

    function testFuzz_edgeCases_zeroValues() public pure {
        IInbox.ClaimRecord memory original;
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        
        assertEq(decoded.proposalId, 0);
        assertEq(decoded.claim.proposalHash, bytes32(0));
        assertEq(decoded.claim.parentClaimHash, bytes32(0));
        assertEq(decoded.claim.endBlockNumber, 0);
        assertEq(decoded.claim.endBlockHash, bytes32(0));
        assertEq(decoded.claim.endStateRoot, bytes32(0));
        assertEq(decoded.claim.designatedProver, address(0));
        assertEq(decoded.claim.actualProver, address(0));
        assertEq(decoded.span, 0);
        assertEq(decoded.bondInstructions.length, 0);
    }



    function testFuzz_consistency_multipleEncodings(
        uint48 _proposalId,
        address _designatedProver,
        uint8 _instructionCount
    )
        public
        pure
    {
        vm.assume(_instructionCount <= 10);
        
        IInbox.ClaimRecord memory record;
        record.proposalId = _proposalId;
        record.claim.designatedProver = _designatedProver;
        record.bondInstructions = new LibBonds.BondInstruction[](_instructionCount);
        
        for (uint256 i = 0; i < _instructionCount; i++) {
            record.bondInstructions[i].proposalId = uint48(i);
            record.bondInstructions[i].bondType = LibBonds.BondType(i % 3);
            record.bondInstructions[i].payer = address(uint160(i));
            record.bondInstructions[i].receiver = address(uint160(i + 1000));
        }
        
        bytes memory encoded1 = LibProvedEventCodec.encode(record);
        bytes memory encoded2 = LibProvedEventCodec.encode(record);
        
        assertEq(keccak256(encoded1), keccak256(encoded2));
        
        IInbox.ClaimRecord memory decoded1 = LibProvedEventCodec.decode(encoded1);
        IInbox.ClaimRecord memory decoded2 = LibProvedEventCodec.decode(encoded2);
        
        assertEq(decoded1.proposalId, decoded2.proposalId);
        assertEq(decoded1.claim.designatedProver, decoded2.claim.designatedProver);
        assertEq(decoded1.bondInstructions.length, decoded2.bondInstructions.length);
    }

    function testFuzz_manyBondInstructions(uint16 _count) public pure {
        vm.assume(_count <= 1000);
        
        IInbox.ClaimRecord memory original;
        original.bondInstructions = new LibBonds.BondInstruction[](_count);
        
        for (uint256 i = 0; i < _count; i++) {
            original.bondInstructions[i].proposalId = uint48((i * 7) % type(uint48).max);
            original.bondInstructions[i].bondType = LibBonds.BondType(i % 3);
            original.bondInstructions[i].payer = address(uint160(uint256(keccak256(abi.encode(i, "payer")))));
            original.bondInstructions[i].receiver = address(uint160(uint256(keccak256(abi.encode(i, "receiver")))));
        }
        
        bytes memory encoded = LibProvedEventCodec.encode(original);
        uint256 expectedSize = LibProvedEventCodec.calculateClaimRecordSize(_count);
        assertEq(encoded.length, expectedSize);
        
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        assertEq(decoded.bondInstructions.length, _count);
        
        for (uint256 i = 0; i < _count; i++) {
            assertEq(decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId);
            assertEq(uint8(decoded.bondInstructions[i].bondType), uint8(original.bondInstructions[i].bondType));
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }
}