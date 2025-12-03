// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibProvedEventCodec } from "src/layer1/alt/libs/LibProvedEventCodec.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProvedEventCodecFuzzTest
/// @notice Fuzz tests for LibProvedEventCodec to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProvedEventCodecFuzzTest is Test {
    /// @notice Fuzz test for finalizationDeadline field
    function testFuzz_encodeDecodeFinalizationDeadline(uint40 finalizationDeadline) public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: finalizationDeadline,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(111)),
                stateRoot: bytes32(uint256(222))
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.finalizationDeadline, finalizationDeadline);
    }

    /// @notice Fuzz test for checkpoint fields
    function testFuzz_encodeDecodeCheckpoint(
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot
    )
        public
        pure
    {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: 1_700_000_100,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            }),
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.checkpoint.blockNumber, blockNumber);
        assertEq(decoded.checkpoint.blockHash, blockHash);
        assertEq(decoded.checkpoint.stateRoot, stateRoot);
    }

    /// @notice Fuzz test for single bond instruction
    function testFuzz_encodeDecodeSingleBondInstruction(
        uint40 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address payee
    )
        public
        pure
    {
        // Bound bondType to valid range (0-2)
        bondTypeRaw = uint8(bound(bondTypeRaw, 0, 2));
        LibBonds.BondType bondType = LibBonds.BondType(bondTypeRaw);

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](1);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: bondType,
            payer: payer,
            payee: payee
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: 1_700_000_100,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(111)),
                stateRoot: bytes32(uint256(222))
            }),
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.bondInstructions.length, 1);
        assertEq(decoded.bondInstructions[0].proposalId, proposalId);
        assertEq(uint8(decoded.bondInstructions[0].bondType), uint8(bondType));
        assertEq(decoded.bondInstructions[0].payer, payer);
        assertEq(decoded.bondInstructions[0].payee, payee);
    }

    /// @notice Fuzz test for variable bond instruction count
    function testFuzz_encodeDecodeVariableBonds(uint8 bondCount) public pure {
        // Bound to reasonable values
        bondCount = uint8(bound(bondCount, 0, 10));

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(100 + i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(0x1000 + i)),
                payee: address(uint160(0x2000 + i))
            });
        }

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: 1_700_000_100,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(111)),
                stateRoot: bytes32(uint256(222))
            }),
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.bondInstructions.length, bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            assertEq(decoded.bondInstructions[i].proposalId, uint48(100 + i));
            assertEq(uint8(decoded.bondInstructions[i].bondType), i % 3);
            assertEq(decoded.bondInstructions[i].payer, address(uint160(0x1000 + i)));
            assertEq(decoded.bondInstructions[i].payee, address(uint160(0x2000 + i)));
        }
    }

    /// @notice Fuzz test for size calculation accuracy
    function testFuzz_sizeCalculation(uint8 bondCount) public pure {
        // Bound to reasonable values
        bondCount = uint8(bound(bondCount, 0, 10));

        uint256 calculatedSize = LibProvedEventCodec.calculateProvedEventSize(bondCount);

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(100 + i),
                bondType: LibBonds.BondType.PROVABILITY,
                payer: address(uint160(0x1000 + i)),
                payee: address(uint160(0x2000 + i))
            });
        }

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: 1_700_000_100,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(111)),
                stateRoot: bytes32(uint256(222))
            }),
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);

        assertEq(encoded.length, calculatedSize, "Calculated size should match actual encoding");
    }

    /// @notice Fuzz test for full payload with all fields randomized
    function testFuzz_fullPayload(
        uint40 finalizationDeadline,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint8 bondCount
    )
        public
        pure
    {
        bondCount = uint8(bound(bondCount, 0, 5));

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(100 + i),
                bondType: LibBonds.BondType(i % 3),
                payer: address(uint160(0x1000 + i)),
                payee: address(uint160(0x2000 + i))
            });
        }

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: finalizationDeadline,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            }),
            bondInstructions: bondInstructions
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.finalizationDeadline, finalizationDeadline);
        assertEq(decoded.checkpoint.blockNumber, blockNumber);
        assertEq(decoded.checkpoint.blockHash, blockHash);
        assertEq(decoded.checkpoint.stateRoot, stateRoot);
        assertEq(decoded.bondInstructions.length, bondCount);
    }

    /// @notice Fuzz test to ensure encoded size is always smaller than ABI encoding
    function testFuzz_encodedSizeComparison(uint8 bondCount) public pure {
        // Bound to reasonable values
        bondCount = uint8(bound(bondCount, 1, 5));

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](bondCount);
        for (uint256 i = 0; i < bondCount; i++) {
            bondInstructions[i] = LibBonds.BondInstruction({
                proposalId: uint48(100 + i),
                bondType: LibBonds.BondType.PROVABILITY,
                payer: address(uint160(0x1000 + i)),
                payee: address(uint160(0x2000 + i))
            });
        }

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: 1_700_000_100,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(111)),
                stateRoot: bytes32(uint256(222))
            }),
            bondInstructions: bondInstructions
        });

        bytes memory optimized = LibProvedEventCodec.encode(payload);
        bytes memory standard = abi.encode(payload);

        assertLt(
            optimized.length,
            standard.length,
            "LibProvedEventCodec should produce smaller output than ABI encoding"
        );
    }

    /// @notice Fuzz test for encoding/decoding roundtrip consistency - all fields fuzzed
    function testFuzz_roundtripConsistency(
        uint40 finalizationDeadline,
        uint48 blockNumber,
        bytes32 blockHash,
        bytes32 stateRoot,
        uint40 proposalId,
        uint8 bondTypeRaw,
        address payer,
        address payee
    )
        public
        pure
    {
        // Bound bondType to valid range (0-2)
        bondTypeRaw = uint8(bound(bondTypeRaw, 0, 2));

        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](1);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: proposalId,
            bondType: LibBonds.BondType(bondTypeRaw),
            payer: payer,
            payee: payee
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            finalizationDeadline: finalizationDeadline,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            }),
            bondInstructions: bondInstructions
        });

        // Encode once
        bytes memory encoded1 = LibProvedEventCodec.encode(payload);

        // Decode and re-encode
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded1);
        bytes memory encoded2 = LibProvedEventCodec.encode(decoded);

        // Should produce identical encoding
        assertEq(keccak256(encoded1), keccak256(encoded2), "Roundtrip should be consistent");

        // Also verify all decoded fields match
        assertEq(decoded.finalizationDeadline, finalizationDeadline);
        assertEq(decoded.checkpoint.blockNumber, blockNumber);
        assertEq(decoded.checkpoint.blockHash, blockHash);
        assertEq(decoded.checkpoint.stateRoot, stateRoot);
        assertEq(decoded.bondInstructions[0].proposalId, proposalId);
        assertEq(uint8(decoded.bondInstructions[0].bondType), bondTypeRaw);
        assertEq(decoded.bondInstructions[0].payer, payer);
        assertEq(decoded.bondInstructions[0].payee, payee);
    }
}
