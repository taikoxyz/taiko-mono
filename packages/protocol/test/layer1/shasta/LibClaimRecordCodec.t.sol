// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibClaimRecordCodec } from "contracts/layer1/shasta/libs/LibClaimRecordCodec.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibClaimRecordCodecTest
/// @notice End-to-end tests for LibClaimRecordCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibClaimRecordCodecTest is Test {
    
    function test_encodeDecodeClaimRecord_empty() public pure {
        // Create empty claim record (no bond instructions)
        IInbox.ClaimRecord memory original;
        original.proposalId = 12345;
        original.claim.proposalHash = keccak256("proposal");
        original.claim.parentClaimHash = keccak256("parent");
        original.claim.endBlockNumber = 999999;
        original.claim.endBlockHash = keccak256("block");
        original.claim.endStateRoot = keccak256("state");
        original.claim.designatedProver = address(0x1234567890123456789012345678901234567890);
        original.claim.actualProver = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        original.span = 42;
        original.bondInstructions = new LibBonds.BondInstruction[](0);
        
        // Encode
        bytes memory encoded = LibClaimRecordCodec.encode(original);
        
        // Verify size (183 bytes for empty bond instructions)
        assertEq(encoded.length, 183);
        
        // Decode
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);
        
        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, 0);
    }
    
    function test_encodeDecodeClaimRecord_withBondInstructions() public pure {
        // Create claim record with bond instructions
        IInbox.ClaimRecord memory original;
        original.proposalId = 67890;
        original.claim.proposalHash = keccak256("proposal2");
        original.claim.parentClaimHash = keccak256("parent2");
        original.claim.endBlockNumber = 555555;
        original.claim.endBlockHash = keccak256("block2");
        original.claim.endStateRoot = keccak256("state2");
        original.claim.designatedProver = address(0xabCDEF1234567890ABcDEF1234567890aBCDeF12);
        original.claim.actualProver = address(0x1111111111111111111111111111111111111111);
        original.span = 100;
        
        // Add 3 bond instructions
        original.bondInstructions = new LibBonds.BondInstruction[](3);
        original.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 111,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x2222222222222222222222222222222222222222),
            receiver: address(0x3333333333333333333333333333333333333333)
        });
        original.bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 222,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x4444444444444444444444444444444444444444),
            receiver: address(0x5555555555555555555555555555555555555555)
        });
        original.bondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 333,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x6666666666666666666666666666666666666666),
            receiver: address(0x7777777777777777777777777777777777777777)
        });
        
        // Encode
        bytes memory encoded = LibClaimRecordCodec.encode(original);
        
        // Verify size (183 + 3*47 = 324 bytes)
        assertEq(encoded.length, 324);
        
        // Decode
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);
        
        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        
        // Verify bond instructions
        assertEq(decoded.bondInstructions.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId);
            assertEq(uint8(decoded.bondInstructions[i].bondType), uint8(original.bondInstructions[i].bondType));
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }
    
    function test_encodeDecodeClaimRecord_maxValues() public pure {
        // Test with maximum values
        IInbox.ClaimRecord memory original;
        original.proposalId = type(uint48).max;
        original.claim.proposalHash = bytes32(type(uint256).max);
        original.claim.parentClaimHash = bytes32(type(uint256).max);
        original.claim.endBlockNumber = type(uint48).max;
        original.claim.endBlockHash = bytes32(type(uint256).max);
        original.claim.endStateRoot = bytes32(type(uint256).max);
        original.claim.designatedProver = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        original.claim.actualProver = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        original.span = type(uint8).max;
        
        // Add one bond instruction with max values
        original.bondInstructions = new LibBonds.BondInstruction[](1);
        original.bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: type(uint48).max,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            receiver: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)
        });
        
        // Encode
        bytes memory encoded = LibClaimRecordCodec.encode(original);
        
        // Decode
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);
        
        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, 1);
        assertEq(decoded.bondInstructions[0].proposalId, original.bondInstructions[0].proposalId);
        assertEq(uint8(decoded.bondInstructions[0].bondType), uint8(original.bondInstructions[0].bondType));
        assertEq(decoded.bondInstructions[0].payer, original.bondInstructions[0].payer);
        assertEq(decoded.bondInstructions[0].receiver, original.bondInstructions[0].receiver);
    }
    
    function test_encodeDecodeClaimRecord_zeroValues() public pure {
        // Test with zero values
        IInbox.ClaimRecord memory original;
        original.proposalId = 0;
        original.claim.proposalHash = bytes32(0);
        original.claim.parentClaimHash = bytes32(0);
        original.claim.endBlockNumber = 0;
        original.claim.endBlockHash = bytes32(0);
        original.claim.endStateRoot = bytes32(0);
        original.claim.designatedProver = address(0);
        original.claim.actualProver = address(0);
        original.span = 0;
        original.bondInstructions = new LibBonds.BondInstruction[](0);
        
        // Encode
        bytes memory encoded = LibClaimRecordCodec.encode(original);
        
        // Decode
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);
        
        // Verify all fields match
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
    
    // Fuzz test for round-trip encoding/decoding
    function testFuzz_encodeDecodeClaimRecord(
        uint48 proposalId,
        bytes32 proposalHash,
        bytes32 parentClaimHash,
        uint48 endBlockNumber,
        bytes32 endBlockHash,
        bytes32 endStateRoot,
        address designatedProver,
        address actualProver,
        uint8 span,
        uint8 numBondInstructions
    ) public pure {
        // Limit bond instructions to reasonable number
        numBondInstructions = uint8(bound(numBondInstructions, 0, 10));
        
        // Create original record
        IInbox.ClaimRecord memory original;
        original.proposalId = proposalId;
        original.claim.proposalHash = proposalHash;
        original.claim.parentClaimHash = parentClaimHash;
        original.claim.endBlockNumber = endBlockNumber;
        original.claim.endBlockHash = endBlockHash;
        original.claim.endStateRoot = endStateRoot;
        original.claim.designatedProver = designatedProver;
        original.claim.actualProver = actualProver;
        original.span = span;
        
        // Add random bond instructions
        original.bondInstructions = new LibBonds.BondInstruction[](numBondInstructions);
        for (uint256 i = 0; i < numBondInstructions; i++) {
            original.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(uint256(keccak256(abi.encode(i, proposalId)))),
                bondType: LibBonds.BondType(uint8(i % 3)), // NONE, PROVABILITY, LIVENESS
                payer: address(uint160(uint256(keccak256(abi.encode(i, "payer"))))),
                receiver: address(uint160(uint256(keccak256(abi.encode(i, "receiver")))))
            });
        }
        
        // Encode and decode
        bytes memory encoded = LibClaimRecordCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibClaimRecordCodec.decode(encoded);
        
        // Verify all fields match
        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.proposalHash, original.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, original.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, original.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, original.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, original.bondInstructions.length);
        
        for (uint256 i = 0; i < original.bondInstructions.length; i++) {
            assertEq(decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId);
            assertEq(uint8(decoded.bondInstructions[i].bondType), uint8(original.bondInstructions[i].bondType));
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }
}