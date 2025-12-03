// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputCodec } from "src/layer1/core/libs/LibProveInputCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProveInputCodecTest
/// @notice Unit tests for LibProveInputCodec
/// @custom:security-contact security@taiko.xyz
contract LibProveInputCodecTest is Test {
    function test_encode_decode_empty() public pure {
        // Test with empty array
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](0);

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        assertGt(encoded.length, 0, "Encoded data should not be empty");

        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);
        assertEq(decoded.length, 0, "Decoded array should be empty");
    }

    function test_encode_decode_single() public pure {
        // Test with single input - all fields have unique values
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);

        inputs[0] = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: 12_345,
                timestamp: 1_699_500_000,
                endOfSubmissionWindowTimestamp: 1_699_500_012,
                proposer: address(0xaabBccDdEe11223344556677889900aaBBccDDEE),
                coreStateHash: bytes32(
                    uint256(0x1111111111111111111111111111111111111111111111111111111111111111)
                ),
                derivationHash: bytes32(
                    uint256(0x2222222222222222222222222222222222222222222222222222222222222222)
                ),
                parentProposalHash: bytes32(
                    uint256(0x3333333333333333333333333333333333333333333333333333333333333333)
                )
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 18_500_000,
                blockHash: bytes32(
                    uint256(0x4444444444444444444444444444444444444444444444444444444444444444)
                ),
                stateRoot: bytes32(
                    uint256(0x5555555555555555555555555555555555555555555555555555555555555555)
                )
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0x1234567890123456789012345678901234567890),
                actualProver: address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD)
            }),
            parentTransitionHash: bytes27(
                uint216(0x6666666666666666666666666666666666666666666666666666)
            )
        });

        // Encode and decode
        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        // Verify
        assertEq(decoded.length, 1, "Decoded array length mismatch");

        // Verify proposal
        assertEq(decoded[0].proposal.id, 12_345, "Proposal ID mismatch");
        assertEq(decoded[0].proposal.timestamp, 1_699_500_000, "Proposal timestamp mismatch");
        assertEq(
            decoded[0].proposal.endOfSubmissionWindowTimestamp,
            1_699_500_012,
            "End of submission window timestamp mismatch"
        );
        assertEq(
            decoded[0].proposal.proposer,
            address(0xaabBccDdEe11223344556677889900aaBBccDDEE),
            "Proposer mismatch"
        );
        assertEq(
            decoded[0].proposal.coreStateHash,
            bytes32(uint256(0x1111111111111111111111111111111111111111111111111111111111111111)),
            "Core state hash mismatch"
        );
        assertEq(
            decoded[0].proposal.derivationHash,
            bytes32(uint256(0x2222222222222222222222222222222222222222222222222222222222222222)),
            "Derivation hash mismatch"
        );
        assertEq(
            decoded[0].proposal.parentProposalHash,
            bytes32(uint256(0x3333333333333333333333333333333333333333333333333333333333333333)),
            "Parent proposal hash mismatch"
        );

        // Verify checkpoint
        assertEq(decoded[0].checkpoint.blockNumber, 18_500_000, "Checkpoint block number mismatch");
        assertEq(
            decoded[0].checkpoint.blockHash,
            bytes32(uint256(0x4444444444444444444444444444444444444444444444444444444444444444)),
            "Checkpoint block hash mismatch"
        );
        assertEq(
            decoded[0].checkpoint.stateRoot,
            bytes32(uint256(0x5555555555555555555555555555555555555555555555555555555555555555)),
            "Checkpoint state root mismatch"
        );

        // Verify metadata
        assertEq(
            decoded[0].metadata.designatedProver,
            address(0x1234567890123456789012345678901234567890),
            "Designated prover mismatch"
        );
        assertEq(
            decoded[0].metadata.actualProver,
            address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD),
            "Actual prover mismatch"
        );

        // Verify parentTransitionHash
        assertEq(
            decoded[0].parentTransitionHash,
            bytes27(uint216(0x6666666666666666666666666666666666666666666666666666)),
            "Parent transition hash mismatch"
        );
    }

    function test_encode_decode_multiple() public pure {
        // Test with multiple inputs
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](3);

        for (uint256 i = 0; i < 3; i++) {
            inputs[i] = IInbox.ProveInput({
                proposal: IInbox.Proposal({
                    id: uint40(100 + i),
                    timestamp: uint40(1_700_000_000 + i * 12),
                    endOfSubmissionWindowTimestamp: uint40(1_700_000_012 + i * 12),
                    proposer: address(uint160(0x1000 + i)),
                    coreStateHash: keccak256(abi.encodePacked("coreState", i)),
                    derivationHash: keccak256(abi.encodePacked("derivation", i)),
                    parentProposalHash: keccak256(abi.encodePacked("parentProposal", i))
                }),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(5000 + i * 100),
                    blockHash: keccak256(abi.encodePacked("blockHash", i)),
                    stateRoot: keccak256(abi.encodePacked("stateRoot", i))
                }),
                metadata: IInbox.TransitionMetadata({
                    designatedProver: address(uint160(0xAAAA + i)),
                    actualProver: address(uint160(0xBBBB + i))
                }),
                parentTransitionHash: bytes27(keccak256(abi.encodePacked("parentTransition", i)))
            });
        }

        // Encode and decode
        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        // Verify
        assertEq(decoded.length, 3, "Decoded array length mismatch");

        for (uint256 i = 0; i < 3; i++) {
            assertEq(decoded[i].proposal.id, uint40(100 + i), "Proposal ID mismatch");
            assertEq(
                decoded[i].proposal.timestamp,
                uint40(1_700_000_000 + i * 12),
                "Proposal timestamp mismatch"
            );
            assertEq(
                decoded[i].checkpoint.blockNumber,
                uint48(5000 + i * 100),
                "Checkpoint block number mismatch"
            );
            assertEq(
                decoded[i].metadata.designatedProver,
                address(uint160(0xAAAA + i)),
                "Designated prover mismatch"
            );
        }
    }

    function test_encode_decode_maxValues() public pure {
        // Test with maximum values
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);

        inputs[0] = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: type(uint40).max,
                timestamp: type(uint40).max,
                endOfSubmissionWindowTimestamp: type(uint40).max,
                proposer: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
                coreStateHash: bytes32(type(uint256).max),
                derivationHash: bytes32(type(uint256).max),
                parentProposalHash: bytes32(type(uint256).max)
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: type(uint48).max,
                blockHash: bytes32(type(uint256).max),
                stateRoot: bytes32(type(uint256).max)
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
                actualProver: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)
            }),
            parentTransitionHash: bytes27(type(uint216).max)
        });

        // Encode and decode
        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        // Verify max values are preserved
        assertEq(decoded[0].proposal.id, type(uint40).max, "Max proposal ID should be preserved");
        assertEq(
            decoded[0].proposal.timestamp, type(uint40).max, "Max timestamp should be preserved"
        );
        assertEq(
            decoded[0].checkpoint.blockNumber,
            type(uint48).max,
            "Max block number should be preserved"
        );
        assertEq(
            decoded[0].parentTransitionHash,
            bytes27(type(uint216).max),
            "Max parentTransitionHash should be preserved"
        );
    }

    function test_encoding_determinism() public pure {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);

        inputs[0] = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: 100,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(444)),
                stateRoot: bytes32(uint256(555))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xAAAA), actualProver: address(0xBBBB)
            }),
            parentTransitionHash: bytes27(uint216(666))
        });

        bytes memory encoded1 = LibProveInputCodec.encode(inputs);
        bytes memory encoded2 = LibProveInputCodec.encode(inputs);

        assertEq(keccak256(encoded1), keccak256(encoded2), "Encoding should be deterministic");
    }

    function test_encoding_size_optimization() public pure {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](2);

        for (uint256 i = 0; i < 2; i++) {
            inputs[i] = IInbox.ProveInput({
                proposal: IInbox.Proposal({
                    id: uint40(100 + i),
                    timestamp: uint40(1_700_000_000 + i),
                    endOfSubmissionWindowTimestamp: uint40(1_700_000_012 + i),
                    proposer: address(uint160(0x1000 + i)),
                    coreStateHash: keccak256(abi.encodePacked("coreState", i)),
                    derivationHash: keccak256(abi.encodePacked("derivation", i)),
                    parentProposalHash: keccak256(abi.encodePacked("parentProposal", i))
                }),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(5000 + i),
                    blockHash: keccak256(abi.encodePacked("blockHash", i)),
                    stateRoot: keccak256(abi.encodePacked("stateRoot", i))
                }),
                metadata: IInbox.TransitionMetadata({
                    designatedProver: address(uint160(0xAAAA + i)),
                    actualProver: address(uint160(0xBBBB + i))
                }),
                parentTransitionHash: bytes27(keccak256(abi.encodePacked("parentTransition", i)))
            });
        }

        bytes memory optimized = LibProveInputCodec.encode(inputs);
        bytes memory standard = abi.encode(inputs);

        assertLt(
            optimized.length,
            standard.length,
            "Optimized encoding should be smaller than ABI encoding"
        );
    }

    function test_encoding_size_per_input() public pure {
        // Test that encoding size grows linearly per ProveInput
        IInbox.ProveInput[] memory inputs1 = new IInbox.ProveInput[](1);
        IInbox.ProveInput[] memory inputs2 = new IInbox.ProveInput[](2);

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: 100,
                timestamp: 1_700_000_000,
                endOfSubmissionWindowTimestamp: 1_700_000_012,
                proposer: address(0x1234),
                coreStateHash: bytes32(uint256(111)),
                derivationHash: bytes32(uint256(222)),
                parentProposalHash: bytes32(uint256(333))
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(444)),
                stateRoot: bytes32(uint256(555))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xAAAA), actualProver: address(0xBBBB)
            }),
            parentTransitionHash: bytes27(uint216(666))
        });

        inputs1[0] = input;
        inputs2[0] = input;
        inputs2[1] = input;

        bytes memory encoded1 = LibProveInputCodec.encode(inputs1);
        bytes memory encoded2 = LibProveInputCodec.encode(inputs2);

        // Size should increase by exactly 293 bytes per input (as per documentation)
        uint256 perInputSize = encoded2.length - encoded1.length;
        assertEq(perInputSize, 293, "Per-input size should be 293 bytes");
    }
}
