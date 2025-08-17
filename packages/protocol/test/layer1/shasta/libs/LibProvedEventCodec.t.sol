// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibProvedEventCodec } from "contracts/layer1/shasta/libs/LibProvedEventCodec.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";

/// @title LibProvedEventCodecTest
/// @notice End-to-end tests for LibProvedEventCodec encoding/decoding
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventCodecTest is Test {
    function test_encodeDecodeClaimRecord_empty() public pure {
        // Create empty claim record (no bond instructions)
        IInbox.ClaimRecord memory original;
        original.proposalId = 12_345;
        original.claim.proposalHash = keccak256("proposal");
        original.claim.parentClaimHash = keccak256("parent");
        original.claim.endBlockNumber = 999_999;
        original.claim.endBlockHash = keccak256("block");
        original.claim.endStateRoot = keccak256("state");
        original.claim.designatedProver = address(0x1234567890123456789012345678901234567890);
        original.claim.actualProver = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        original.span = 42;
        original.bondInstructions = new LibBonds.BondInstruction[](0);

        // Encode
        bytes memory encoded = LibProvedEventCodec.encode(original);

        // Verify size (183 bytes for empty bond instructions)
        assertEq(encoded.length, 183);

        // Decode
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

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
        original.proposalId = 67_890;
        original.claim.proposalHash = keccak256("proposal2");
        original.claim.parentClaimHash = keccak256("parent2");
        original.claim.endBlockNumber = 555_555;
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
        bytes memory encoded = LibProvedEventCodec.encode(original);

        // Verify size (183 + 3*47 = 324 bytes)
        assertEq(encoded.length, 324);

        // Decode
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

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
            assertEq(
                decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(original.bondInstructions[i].bondType)
            );
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
        bytes memory encoded = LibProvedEventCodec.encode(original);

        // Decode
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

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
        assertEq(
            uint8(decoded.bondInstructions[0].bondType),
            uint8(original.bondInstructions[0].bondType)
        );
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
        bytes memory encoded = LibProvedEventCodec.encode(original);

        // Decode
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

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
    )
        public
        pure
    {
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
        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

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
            assertEq(
                decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(original.bondInstructions[i].bondType)
            );
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }

    // ---------------------------------------------------------------
    // Additional Fuzz Tests
    // ---------------------------------------------------------------

    /// @notice Fuzz test with large bond instructions arrays
    function testFuzz_largeBondInstructionsArray(
        uint48 proposalId,
        bytes32[5] memory hashes,
        uint48 endBlockNumber,
        address[2] memory provers,
        uint8 span
    )
        public
        pure
    {
        // Test with maximum allowed bond instructions (up to uint16.max)
        uint16 numInstructions = 100; // Test with 100 instructions

        IInbox.ClaimRecord memory original;
        original.proposalId = proposalId;
        original.claim.proposalHash = hashes[0];
        original.claim.parentClaimHash = hashes[1];
        original.claim.endBlockNumber = endBlockNumber;
        original.claim.endBlockHash = hashes[2];
        original.claim.endStateRoot = hashes[3];
        original.claim.designatedProver = provers[0];
        original.claim.actualProver = provers[1];
        original.span = span;

        // Create large array of bond instructions
        original.bondInstructions = new LibBonds.BondInstruction[](numInstructions);
        for (uint256 i = 0; i < numInstructions; i++) {
            original.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType(uint8(i % 3)),
                payer: address(uint160(uint256(keccak256(abi.encode(i, "payer", hashes[4]))))),
                receiver: address(uint160(uint256(keccak256(abi.encode(i, "receiver", proposalId)))))
            });
        }

        bytes memory encoded = LibProvedEventCodec.encode(original);
        assertEq(encoded.length, 183 + numInstructions * 47);

        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        assertEq(decoded.bondInstructions.length, numInstructions);
        assertEq(decoded.proposalId, original.proposalId);
    }

    /// @notice Fuzz test for boundary values
    function testFuzz_boundaryValues(
        bool useMaxProposalId,
        bool useMaxBlockNumber,
        bool useZeroAddresses,
        bool useMaxSpan,
        uint8 bondInstructionCount
    )
        public
        pure
    {
        bondInstructionCount = uint8(bound(bondInstructionCount, 0, 20));

        IInbox.ClaimRecord memory original;
        original.proposalId = useMaxProposalId ? type(uint48).max : 1;
        original.claim.proposalHash = keccak256(abi.encode("hash", useMaxProposalId));
        original.claim.parentClaimHash = keccak256(abi.encode("parent", useMaxBlockNumber));
        original.claim.endBlockNumber = useMaxBlockNumber ? type(uint48).max : 1;
        original.claim.endBlockHash = keccak256(abi.encode("block", useZeroAddresses));
        original.claim.endStateRoot = keccak256(abi.encode("state", useMaxSpan));
        original.claim.designatedProver = useZeroAddresses ? address(0) : address(0xdead);
        original.claim.actualProver = useZeroAddresses ? address(0) : address(0xbeef);
        original.span = useMaxSpan ? type(uint8).max : 0;

        original.bondInstructions = new LibBonds.BondInstruction[](bondInstructionCount);
        for (uint256 i = 0; i < bondInstructionCount; i++) {
            original.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: useMaxProposalId ? type(uint48).max - uint48(i) : uint48(i),
                bondType: LibBonds.BondType(uint8(i % 3)),
                payer: useZeroAddresses ? address(0) : address(uint160(i + 1)),
                receiver: useZeroAddresses ? address(0) : address(uint160(i + 2))
            });
        }

        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.proposalId, original.proposalId);
        assertEq(decoded.claim.endBlockNumber, original.claim.endBlockNumber);
        assertEq(decoded.span, original.span);
        assertEq(decoded.bondInstructions.length, bondInstructionCount);
    }

    function test_calculateClaimRecordSize_zero() public pure {
        uint256 size = LibProvedEventCodec.calculateClaimRecordSize(0);
        assertEq(size, 183); // Fixed size with no bond instructions
    }

    function test_calculateClaimRecordSize_withBondInstructions() public pure {
        uint256 size1 = LibProvedEventCodec.calculateClaimRecordSize(1);
        assertEq(size1, 183 + 47); // Fixed + 1 bond instruction

        uint256 size10 = LibProvedEventCodec.calculateClaimRecordSize(10);
        assertEq(size10, 183 + 470); // Fixed + 10 bond instructions

        uint256 size100 = LibProvedEventCodec.calculateClaimRecordSize(100);
        assertEq(size100, 183 + 4700); // Fixed + 100 bond instructions
    }

    /// @notice Fuzz test for encoding size calculations
    function testFuzz_encodingSizeCalculation(uint16 numBondInstructions) public pure {
        numBondInstructions = uint16(bound(numBondInstructions, 0, 1000));

        IInbox.ClaimRecord memory record;
        record.proposalId = 12_345;
        record.claim.proposalHash = keccak256("test");
        record.claim.parentClaimHash = keccak256("parent");
        record.claim.endBlockNumber = 999_999;
        record.claim.endBlockHash = keccak256("block");
        record.claim.endStateRoot = keccak256("state");
        record.claim.designatedProver = address(0x1);
        record.claim.actualProver = address(0x2);
        record.span = 42;

        record.bondInstructions = new LibBonds.BondInstruction[](numBondInstructions);
        for (uint256 i = 0; i < numBondInstructions; i++) {
            record.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(i),
                bondType: LibBonds.BondType.NONE,
                payer: address(uint160(i + 100)),
                receiver: address(uint160(i + 200))
            });
        }

        bytes memory encoded = LibProvedEventCodec.encode(record);

        // Verify size: base (183) + bond instructions (47 each)
        uint256 expectedSize = 183 + uint256(numBondInstructions) * 47;
        assertEq(encoded.length, expectedSize);

        // Verify decode works correctly
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);
        assertEq(decoded.bondInstructions.length, numBondInstructions);
    }

    /// @notice Fuzz test for different bond type patterns
    function testFuzz_bondTypePatterns(
        uint8 pattern,
        uint8 numInstructions,
        uint48 baseProposalId
    )
        public
        pure
    {
        numInstructions = uint8(bound(numInstructions, 1, 50));
        pattern = uint8(bound(pattern, 0, 7));

        IInbox.ClaimRecord memory original;
        original.proposalId = baseProposalId;
        original.claim.proposalHash = keccak256(abi.encode("hash", pattern));
        original.claim.parentClaimHash = keccak256(abi.encode("parent", baseProposalId));
        original.claim.endBlockNumber = 100_000;
        original.claim.endBlockHash = keccak256(abi.encode("block", pattern));
        original.claim.endStateRoot = keccak256(abi.encode("state", numInstructions));
        original.claim.designatedProver = address(0xaa);
        original.claim.actualProver = address(0xbb);
        original.span = 10;

        original.bondInstructions = new LibBonds.BondInstruction[](numInstructions);
        for (uint256 i = 0; i < numInstructions; i++) {
            LibBonds.BondType bondType;
            if (pattern == 0) {
                // All NONE
                bondType = LibBonds.BondType.NONE;
            } else if (pattern == 1) {
                // All PROVABILITY
                bondType = LibBonds.BondType.PROVABILITY;
            } else if (pattern == 2) {
                // All LIVENESS
                bondType = LibBonds.BondType.LIVENESS;
            } else if (pattern == 3) {
                // Alternating NONE/PROVABILITY
                bondType = i % 2 == 0 ? LibBonds.BondType.NONE : LibBonds.BondType.PROVABILITY;
            } else if (pattern == 4) {
                // Alternating PROVABILITY/LIVENESS
                bondType = i % 2 == 0 ? LibBonds.BondType.PROVABILITY : LibBonds.BondType.LIVENESS;
            } else if (pattern == 5) {
                // Rotating through all three
                bondType = LibBonds.BondType(uint8(i % 3));
            } else if (pattern == 6) {
                // Random based on hash
                bondType = LibBonds.BondType(uint8(uint256(keccak256(abi.encode(i, pattern))) % 3));
            } else {
                // Pattern 7: mostly LIVENESS with occasional others
                bondType = i % 5 == 0 ? LibBonds.BondType.NONE : LibBonds.BondType.LIVENESS;
            }

            original.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(baseProposalId + i),
                bondType: bondType,
                payer: address(uint160(uint256(keccak256(abi.encode(i, "payer", pattern))))),
                receiver: address(uint160(uint256(keccak256(abi.encode(i, "receiver", pattern)))))
            });
        }

        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.bondInstructions.length, numInstructions);
        for (uint256 i = 0; i < numInstructions; i++) {
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(original.bondInstructions[i].bondType)
            );
            assertEq(
                decoded.bondInstructions[i].proposalId, original.bondInstructions[i].proposalId
            );
        }
    }

    /// @notice Fuzz test for various address combinations
    function testFuzz_addressCombinations(
        address[4] memory addresses,
        bool[4] memory useZero,
        uint8 numInstructions
    )
        public
        pure
    {
        numInstructions = uint8(bound(numInstructions, 0, 30));

        IInbox.ClaimRecord memory original;
        original.proposalId = 54_321;
        original.claim.proposalHash = keccak256(abi.encode(addresses[0]));
        original.claim.parentClaimHash = keccak256(abi.encode(addresses[1]));
        original.claim.endBlockNumber = 200_000;
        original.claim.endBlockHash = keccak256(abi.encode(addresses[2]));
        original.claim.endStateRoot = keccak256(abi.encode(addresses[3]));
        original.claim.designatedProver = useZero[0] ? address(0) : addresses[0];
        original.claim.actualProver = useZero[1] ? address(0) : addresses[1];
        original.span = 25;

        original.bondInstructions = new LibBonds.BondInstruction[](numInstructions);
        for (uint256 i = 0; i < numInstructions; i++) {
            // Mix and match addresses
            address payer = useZero[2] && (i % 3 == 0) ? address(0) : addresses[i % 4];
            address receiver = useZero[3] && (i % 5 == 0) ? address(0) : addresses[(i + 1) % 4];

            // Special cases
            if (i % 7 == 0) {
                // Same payer and receiver
                receiver = payer;
            } else if (i % 11 == 0) {
                // Use designated prover as payer
                payer = original.claim.designatedProver;
            } else if (i % 13 == 0) {
                // Use actual prover as receiver
                receiver = original.claim.actualProver;
            }

            original.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(1000 + i),
                bondType: LibBonds.BondType(uint8(i % 3)),
                payer: payer,
                receiver: receiver
            });
        }

        bytes memory encoded = LibProvedEventCodec.encode(original);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.claim.designatedProver, original.claim.designatedProver);
        assertEq(decoded.claim.actualProver, original.claim.actualProver);
        assertEq(decoded.bondInstructions.length, numInstructions);

        for (uint256 i = 0; i < numInstructions; i++) {
            assertEq(decoded.bondInstructions[i].payer, original.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, original.bondInstructions[i].receiver);
        }
    }

    /// @notice Comprehensive fuzz test with all parameters
    function testFuzz_comprehensive(
        uint48 proposalId,
        bytes32[5] memory hashes,
        uint48 endBlockNumber,
        address[2] memory addresses,
        uint8 span,
        uint16 numBondInstructions
    )
        public
        pure
    {
        // Bound the number of bond instructions
        numBondInstructions = uint16(bound(numBondInstructions, 0, 100));

        // Create the input record
        IInbox.ClaimRecord memory inputRecord;
        inputRecord.proposalId = proposalId;
        inputRecord.claim.proposalHash = hashes[0];
        inputRecord.claim.parentClaimHash = hashes[1];
        inputRecord.claim.endBlockNumber = endBlockNumber;
        inputRecord.claim.endBlockHash = hashes[2];
        inputRecord.claim.endStateRoot = hashes[3];
        inputRecord.claim.designatedProver = addresses[0];
        inputRecord.claim.actualProver = addresses[1];
        inputRecord.span = span;

        // Create bond instructions array
        inputRecord.bondInstructions = new LibBonds.BondInstruction[](numBondInstructions);
        for (uint256 i = 0; i < numBondInstructions; i++) {
            inputRecord.bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(uint256(keccak256(abi.encode(i, proposalId)))),
                bondType: LibBonds.BondType(uint8(uint256(keccak256(abi.encode(i, "type"))) % 3)),
                payer: address(uint160(uint256(keccak256(abi.encode(i, "payer", hashes[4]))))),
                receiver: address(uint160(uint256(keccak256(abi.encode(i, "receiver", hashes[0])))))
            });
        }

        // Encode and decode
        bytes memory encoded = LibProvedEventCodec.encode(inputRecord);
        IInbox.ClaimRecord memory decoded = LibProvedEventCodec.decode(encoded);

        // Verify all fields
        assertEq(decoded.proposalId, inputRecord.proposalId);
        assertEq(decoded.claim.proposalHash, inputRecord.claim.proposalHash);
        assertEq(decoded.claim.parentClaimHash, inputRecord.claim.parentClaimHash);
        assertEq(decoded.claim.endBlockNumber, inputRecord.claim.endBlockNumber);
        assertEq(decoded.claim.endBlockHash, inputRecord.claim.endBlockHash);
        assertEq(decoded.claim.endStateRoot, inputRecord.claim.endStateRoot);
        assertEq(decoded.claim.designatedProver, inputRecord.claim.designatedProver);
        assertEq(decoded.claim.actualProver, inputRecord.claim.actualProver);
        assertEq(decoded.span, inputRecord.span);
        assertEq(decoded.bondInstructions.length, inputRecord.bondInstructions.length);

        for (uint256 i = 0; i < inputRecord.bondInstructions.length; i++) {
            assertEq(
                decoded.bondInstructions[i].proposalId, inputRecord.bondInstructions[i].proposalId
            );
            assertEq(
                uint8(decoded.bondInstructions[i].bondType),
                uint8(inputRecord.bondInstructions[i].bondType)
            );
            assertEq(decoded.bondInstructions[i].payer, inputRecord.bondInstructions[i].payer);
            assertEq(decoded.bondInstructions[i].receiver, inputRecord.bondInstructions[i].receiver);
        }
    }
}
