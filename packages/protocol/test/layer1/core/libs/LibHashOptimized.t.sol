// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

contract LibHashOptimizedTest is Test {
    // ---------------------------------------------------------------
    // Unit Tests for hashBondInstruction
    // ---------------------------------------------------------------

    function test_hashBondInstruction_basic() public pure {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        bytes32 hash = LibHashOptimized.hashBondInstruction(instruction);

        // Verify the hash is not zero
        assertTrue(hash != bytes32(0), "hash should not be zero");

        // Verify determinism - same input should produce same output
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction);
        assertEq(hash, hash2, "hash should be deterministic");
    }

    function test_hashBondInstruction_matchesAbiEncode() public pure {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: 42,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0xAAAA),
            payee: address(0xBBBB)
        });

        bytes32 optimizedHash = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 expectedHash = keccak256(abi.encode(instruction));

        assertEq(optimizedHash, expectedHash, "hash should match abi.encode");
    }

    function test_hashBondInstruction_differentProposalIds() public pure {
        LibBonds.BondInstruction memory instruction1 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        LibBonds.BondInstruction memory instruction2 = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction1);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction2);

        assertTrue(hash1 != hash2, "different proposalIds should produce different hashes");
    }

    function test_hashBondInstruction_differentBondTypes() public pure {
        LibBonds.BondInstruction memory instruction1 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        LibBonds.BondInstruction memory instruction2 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        LibBonds.BondInstruction memory instruction3 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction1);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction2);
        bytes32 hash3 = LibHashOptimized.hashBondInstruction(instruction3);

        assertTrue(hash1 != hash2, "NONE vs LIVENESS should produce different hashes");
        assertTrue(hash2 != hash3, "LIVENESS vs PROVABILITY should produce different hashes");
        assertTrue(hash1 != hash3, "NONE vs PROVABILITY should produce different hashes");
    }

    function test_hashBondInstruction_differentPayers() public pure {
        LibBonds.BondInstruction memory instruction1 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x3333)
        });

        LibBonds.BondInstruction memory instruction2 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x2222),
            payee: address(0x3333)
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction1);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction2);

        assertTrue(hash1 != hash2, "different payers should produce different hashes");
    }

    function test_hashBondInstruction_differentPayees() public pure {
        LibBonds.BondInstruction memory instruction1 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x2222)
        });

        LibBonds.BondInstruction memory instruction2 = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x3333)
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction1);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction2);

        assertTrue(hash1 != hash2, "different payees should produce different hashes");
    }

    function test_hashBondInstruction_zeroValues() public pure {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: 0, bondType: LibBonds.BondType.NONE, payer: address(0), payee: address(0)
        });

        bytes32 hash = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 expectedHash = keccak256(abi.encode(instruction));

        assertEq(hash, expectedHash, "zero values should hash correctly");
        assertTrue(hash != bytes32(0), "hash of zero values should not be zero");
    }

    function test_hashBondInstruction_maxValues() public pure {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: type(uint48).max,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(type(uint160).max),
            payee: address(type(uint160).max)
        });

        bytes32 hash = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 expectedHash = keccak256(abi.encode(instruction));

        assertEq(hash, expectedHash, "max values should hash correctly");
    }

    function test_hashBondInstruction_samePayer_andPayee() public pure {
        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x1111),
            payee: address(0x1111)
        });

        bytes32 hash = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 expectedHash = keccak256(abi.encode(instruction));

        assertEq(hash, expectedHash, "same payer and payee should hash correctly");
    }

    // ---------------------------------------------------------------
    // Fuzz Tests for hashBondInstruction
    // ---------------------------------------------------------------

    function testFuzz_hashBondInstruction_matchesAbiEncode(
        uint48 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address payee
    )
        public
        pure
    {
        // Bound bondType to valid enum values (0, 1, 2)
        LibBonds.BondType bondType = LibBonds.BondType(bondTypeRaw % 3);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposalId, bondType: bondType, payer: payer, payee: payee
        });

        bytes32 optimizedHash = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 expectedHash = keccak256(abi.encode(instruction));

        assertEq(optimizedHash, expectedHash, "fuzz: hash should match abi.encode");
    }

    function testFuzz_hashBondInstruction_deterministic(
        uint48 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address payee
    )
        public
        pure
    {
        LibBonds.BondType bondType = LibBonds.BondType(bondTypeRaw % 3);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposalId, bondType: bondType, payer: payer, payee: payee
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction);

        assertEq(hash1, hash2, "fuzz: hash should be deterministic");
    }

    function testFuzz_hashBondInstruction_uniqueness(
        uint48 proposalId1,
        uint48 proposalId2,
        uint8 bondTypeRaw1,
        uint8 bondTypeRaw2,
        address payer1,
        address payer2,
        address payee1,
        address payee2
    )
        public
        pure
    {
        LibBonds.BondType bondType1 = LibBonds.BondType(bondTypeRaw1 % 3);
        LibBonds.BondType bondType2 = LibBonds.BondType(bondTypeRaw2 % 3);

        LibBonds.BondInstruction memory instruction1 = LibBonds.BondInstruction({
            proposalId: proposalId1, bondType: bondType1, payer: payer1, payee: payee1
        });

        LibBonds.BondInstruction memory instruction2 = LibBonds.BondInstruction({
            proposalId: proposalId2, bondType: bondType2, payer: payer2, payee: payee2
        });

        bytes32 hash1 = LibHashOptimized.hashBondInstruction(instruction1);
        bytes32 hash2 = LibHashOptimized.hashBondInstruction(instruction2);

        // If any field differs, hashes should differ (with high probability)
        bool allFieldsEqual = proposalId1 == proposalId2 && bondType1 == bondType2
            && payer1 == payer2 && payee1 == payee2;

        if (allFieldsEqual) {
            assertEq(hash1, hash2, "fuzz: identical inputs should produce identical hashes");
        } else {
            // Note: In theory, different inputs could produce the same hash (collision),
            // but this is astronomically unlikely with keccak256
            assertTrue(hash1 != hash2, "fuzz: different inputs should produce different hashes");
        }
    }

    function testFuzz_hashBondInstruction_nonZeroOutput(
        uint48 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address payee
    )
        public
        pure
    {
        LibBonds.BondType bondType = LibBonds.BondType(bondTypeRaw % 3);

        LibBonds.BondInstruction memory instruction = LibBonds.BondInstruction({
            proposalId: proposalId, bondType: bondType, payer: payer, payee: payee
        });

        bytes32 hash = LibHashOptimized.hashBondInstruction(instruction);

        // keccak256 should never return zero for any input
        assertTrue(hash != bytes32(0), "fuzz: hash should never be zero");
    }
}
