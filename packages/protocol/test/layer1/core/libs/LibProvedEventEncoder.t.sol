// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventEncoder } from "src/layer1/core/libs/LibProvedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProvedEventEncoderTest
/// @notice Tests for LibProvedEventEncoder
contract LibProvedEventEncoderTest is Test {
    function test_encode_decode_simple() public pure {
        // Create transition
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: bytes32(uint256(123)),
            parentTransitionHash: bytes32(uint256(456)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 1000,
                blockHash: bytes32(uint256(789)),
                stateRoot: bytes32(uint256(101_112))
            })
        });

        // Create transition metadata
        IInbox.TransitionMetadata memory metadata = IInbox.TransitionMetadata({
            designatedProver: address(0x1234), actualProver: address(0x5678)
        });

        // Create transition record with bond instructions
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](1);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 5,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x9ABC),
            payee: address(0xDEF0)
        });

        IInbox.TransitionRecord memory transitionRecord = IInbox.TransitionRecord({
            span: 1,
            bondInstructions: bondInstructions,
            transitionHash: bytes32(uint256(131_415)),
            checkpointHash: bytes32(uint256(161_718))
        });

        // Create proved event payload
        IInbox.ProvedEventPayload memory original = IInbox.ProvedEventPayload({
            proposalId: 10,
            transition: transition,
            transitionRecord: transitionRecord,
            metadata: metadata
        });

        // Test encoding
        bytes memory encoded = LibProvedEventEncoder.encode(original);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        // Test decoding
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify all fields
        assertEq(decoded.proposalId, original.proposalId, "Proposal ID mismatch");

        // Verify transition
        assertEq(
            decoded.transition.proposalHash,
            original.transition.proposalHash,
            "Transition proposal hash mismatch"
        );
        assertEq(
            decoded.transition.parentTransitionHash,
            original.transition.parentTransitionHash,
            "Parent transition hash mismatch"
        );
        assertEq(
            decoded.transition.checkpoint.blockNumber,
            original.transition.checkpoint.blockNumber,
            "Checkpoint block number mismatch"
        );
        assertEq(
            decoded.transition.checkpoint.blockHash,
            original.transition.checkpoint.blockHash,
            "Checkpoint block hash mismatch"
        );
        assertEq(
            decoded.transition.checkpoint.stateRoot,
            original.transition.checkpoint.stateRoot,
            "Checkpoint state root mismatch"
        );

        // Verify transition record
        assertEq(
            decoded.transitionRecord.span,
            original.transitionRecord.span,
            "Transition record span mismatch"
        );
        assertEq(
            decoded.transitionRecord.bondInstructions.length, 1, "Bond instructions length mismatch"
        );
        assertEq(
            decoded.transitionRecord.bondInstructions[0].proposalId,
            5,
            "Bond instruction proposal ID mismatch"
        );
        assertEq(
            uint8(decoded.transitionRecord.bondInstructions[0].bondType),
            uint8(LibBonds.BondType.PROVABILITY),
            "Bond instruction type mismatch"
        );
        assertEq(
            decoded.transitionRecord.transitionHash,
            original.transitionRecord.transitionHash,
            "Transition record transition hash mismatch"
        );
        assertEq(
            decoded.transitionRecord.checkpointHash,
            original.transitionRecord.checkpointHash,
            "Transition record checkpoint hash mismatch"
        );

        // Verify metadata
        assertEq(
            decoded.metadata.designatedProver,
            original.metadata.designatedProver,
            "Designated prover mismatch"
        );
        assertEq(
            decoded.metadata.actualProver, original.metadata.actualProver, "Actual prover mismatch"
        );
    }

    function test_encode_decode_multiple_bond_instructions() public pure {
        // Create multiple bond instructions
        LibBonds.BondInstruction[] memory bondInstructions = new LibBonds.BondInstruction[](3);
        bondInstructions[0] = LibBonds.BondInstruction({
            proposalId: 1,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0x1111),
            payee: address(0x2222)
        });
        bondInstructions[1] = LibBonds.BondInstruction({
            proposalId: 2,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0x3333),
            payee: address(0x4444)
        });
        bondInstructions[2] = LibBonds.BondInstruction({
            proposalId: 3,
            bondType: LibBonds.BondType.NONE,
            payer: address(0x5555),
            payee: address(0x6666)
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 20,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(2000)),
                parentTransitionHash: bytes32(uint256(2001)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 2000,
                    blockHash: bytes32(uint256(2002)),
                    stateRoot: bytes32(uint256(2003))
                })
            }),
            transitionRecord: IInbox.TransitionRecord({
                span: 5,
                bondInstructions: bondInstructions,
                transitionHash: bytes32(uint256(2004)),
                checkpointHash: bytes32(uint256(2005))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0x7777), actualProver: address(0x8888)
            })
        });

        bytes memory encoded = LibProvedEventEncoder.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        // Verify multiple bond instructions
        assertEq(
            decoded.transitionRecord.bondInstructions.length, 3, "Should have 3 bond instructions"
        );
        assertEq(
            decoded.transitionRecord.bondInstructions[0].proposalId,
            1,
            "Bond instruction 0 proposal ID mismatch"
        );
        assertEq(
            uint8(decoded.transitionRecord.bondInstructions[0].bondType),
            uint8(LibBonds.BondType.PROVABILITY),
            "Bond instruction 0 type mismatch"
        );
        assertEq(
            decoded.transitionRecord.bondInstructions[1].proposalId,
            2,
            "Bond instruction 1 proposal ID mismatch"
        );
        assertEq(
            uint8(decoded.transitionRecord.bondInstructions[1].bondType),
            uint8(LibBonds.BondType.LIVENESS),
            "Bond instruction 1 type mismatch"
        );
        assertEq(
            decoded.transitionRecord.bondInstructions[2].proposalId,
            3,
            "Bond instruction 2 proposal ID mismatch"
        );
        assertEq(
            uint8(decoded.transitionRecord.bondInstructions[2].bondType),
            uint8(LibBonds.BondType.NONE),
            "Bond instruction 2 type mismatch"
        );
    }

    function test_encode_decode_empty_bond_instructions() public pure {
        // Test with empty bond instructions array
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 30,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(3000)),
                parentTransitionHash: bytes32(uint256(3001)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 3000,
                    blockHash: bytes32(uint256(3002)),
                    stateRoot: bytes32(uint256(3003))
                })
            }),
            transitionRecord: IInbox.TransitionRecord({
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0),
                transitionHash: bytes32(uint256(3004)),
                checkpointHash: bytes32(uint256(3005))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0x9999), actualProver: address(0xAAAA)
            })
        });

        bytes memory encoded = LibProvedEventEncoder.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(
            decoded.transitionRecord.bondInstructions.length,
            0,
            "Should have empty bond instructions array"
        );
        assertEq(decoded.proposalId, 30, "Proposal ID should match");
        assertEq(decoded.transitionRecord.span, 1, "Span should match");
    }

    function test_encode_decode_large_span() public pure {
        // Test with larger span value
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 100,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(10_000)),
                parentTransitionHash: bytes32(uint256(10_001)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 10_000,
                    blockHash: bytes32(uint256(10_002)),
                    stateRoot: bytes32(uint256(10_003))
                })
            }),
            transitionRecord: IInbox.TransitionRecord({
                span: 255, // Maximum uint8 value
                bondInstructions: new LibBonds.BondInstruction[](0),
                transitionHash: bytes32(uint256(10_004)),
                checkpointHash: bytes32(uint256(10_005))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xBBBB), actualProver: address(0xCCCC)
            })
        });

        bytes memory encoded = LibProvedEventEncoder.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded);

        assertEq(
            decoded.transitionRecord.span, 255, "Large span should be encoded/decoded correctly"
        );
        assertEq(decoded.proposalId, 100, "Proposal ID should match");
    }

    function test_encoding_determinism() public pure {
        // Test that encoding is deterministic
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 42,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(4200)),
                parentTransitionHash: bytes32(uint256(4201)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 4200,
                    blockHash: bytes32(uint256(4202)),
                    stateRoot: bytes32(uint256(4203))
                })
            }),
            transitionRecord: IInbox.TransitionRecord({
                span: 3,
                bondInstructions: new LibBonds.BondInstruction[](0),
                transitionHash: bytes32(uint256(4204)),
                checkpointHash: bytes32(uint256(4205))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xDDDD), actualProver: address(0xEEEE)
            })
        });

        bytes memory encoded1 = LibProvedEventEncoder.encode(payload);
        bytes memory encoded2 = LibProvedEventEncoder.encode(payload);

        assertEq(keccak256(encoded1), keccak256(encoded2), "Encoding should be deterministic");
    }
}
