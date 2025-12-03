// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/alt/iface/IInbox.sol";
import { LibProveInputCodec } from "src/layer1/alt/libs/LibProveInputCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProveInputCodecFuzzTest
/// @notice Fuzz tests for LibProveInputCodec to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProveInputCodecFuzzTest is Test {
    /// @notice Fuzz test for proposal fields
    function testFuzz_encodeDecodeProposal(
        uint40 id,
        uint40 timestamp,
        uint40 endOfSubmissionWindowTimestamp,
        address proposer,
        bytes32 coreStateHash,
        bytes32 derivationHash,
        bytes32 parentProposalHash
    )
        public
        pure
    {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);

        inputs[0] = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: id,
                timestamp: timestamp,
                endOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
                proposer: proposer,
                coreStateHash: coreStateHash,
                derivationHash: derivationHash,
                parentProposalHash: parentProposalHash
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 5000,
                blockHash: bytes32(uint256(444)),
                stateRoot: bytes32(uint256(555))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xAAAA),
                actualProver: address(0xBBBB)
            }),
            parentTransitionHash: bytes27(uint216(666))
        });

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded[0].proposal.id, id);
        assertEq(decoded[0].proposal.timestamp, timestamp);
        assertEq(decoded[0].proposal.endOfSubmissionWindowTimestamp, endOfSubmissionWindowTimestamp);
        assertEq(decoded[0].proposal.proposer, proposer);
        assertEq(decoded[0].proposal.coreStateHash, coreStateHash);
        assertEq(decoded[0].proposal.derivationHash, derivationHash);
        assertEq(decoded[0].proposal.parentProposalHash, parentProposalHash);
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
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: stateRoot
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: address(0xAAAA),
                actualProver: address(0xBBBB)
            }),
            parentTransitionHash: bytes27(uint216(666))
        });

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded[0].checkpoint.blockNumber, blockNumber);
        assertEq(decoded[0].checkpoint.blockHash, blockHash);
        assertEq(decoded[0].checkpoint.stateRoot, stateRoot);
    }

    /// @notice Fuzz test for metadata fields
    function testFuzz_encodeDecodeMetadata(
        address designatedProver,
        address actualProver
    )
        public
        pure
    {
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
                designatedProver: designatedProver,
                actualProver: actualProver
            }),
            parentTransitionHash: bytes27(uint216(666))
        });

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded[0].metadata.designatedProver, designatedProver);
        assertEq(decoded[0].metadata.actualProver, actualProver);
    }

    /// @notice Fuzz test for parentTransitionHash field
    function testFuzz_encodeDecodeParentTransitionHash(bytes27 parentTransitionHash) public pure {
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
                designatedProver: address(0xAAAA),
                actualProver: address(0xBBBB)
            }),
            parentTransitionHash: parentTransitionHash
        });

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded[0].parentTransitionHash, parentTransitionHash);
    }

    /// @notice Fuzz test for variable array lengths
    function testFuzz_encodeDecodeVariableLengths(uint8 inputCount) public pure {
        // Bound the inputs to reasonable values
        inputCount = uint8(bound(inputCount, 0, 10));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](inputCount);

        for (uint256 i = 0; i < inputCount; i++) {
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

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.length, inputCount, "Array length mismatch");

        for (uint256 i = 0; i < inputCount; i++) {
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
        }
    }

    /// @notice Fuzz test for full input with all fields randomized
    function testFuzz_fullInput(
        uint40 proposalId,
        uint40 timestamp,
        address proposer,
        uint48 blockNumber,
        bytes32 blockHash,
        address designatedProver,
        bytes27 parentTransitionHash
    )
        public
        pure
    {
        // Bound timestamp to avoid overflow when adding 12
        timestamp = uint40(bound(timestamp, 0, type(uint40).max - 12));
        // Bound designatedProver to avoid overflow when adding 1
        designatedProver =
            address(uint160(bound(uint160(designatedProver), 0, type(uint160).max - 1)));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);

        inputs[0] = IInbox.ProveInput({
            proposal: IInbox.Proposal({
                id: proposalId,
                timestamp: timestamp,
                endOfSubmissionWindowTimestamp: timestamp + 12,
                proposer: proposer,
                coreStateHash: keccak256(abi.encodePacked("coreState", proposalId)),
                derivationHash: keccak256(abi.encodePacked("derivation", proposalId)),
                parentProposalHash: keccak256(abi.encodePacked("parentProposal", proposalId))
            }),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: blockNumber,
                blockHash: blockHash,
                stateRoot: keccak256(abi.encodePacked("stateRoot", blockNumber))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: designatedProver,
                actualProver: address(uint160(designatedProver) + 1)
            }),
            parentTransitionHash: parentTransitionHash
        });

        bytes memory encoded = LibProveInputCodec.encode(inputs);
        IInbox.ProveInput[] memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded[0].proposal.id, proposalId);
        assertEq(decoded[0].proposal.timestamp, timestamp);
        assertEq(decoded[0].proposal.proposer, proposer);
        assertEq(decoded[0].checkpoint.blockNumber, blockNumber);
        assertEq(decoded[0].checkpoint.blockHash, blockHash);
        assertEq(decoded[0].metadata.designatedProver, designatedProver);
        assertEq(decoded[0].parentTransitionHash, parentTransitionHash);
    }

    /// @notice Fuzz test for encoding size consistency
    function testFuzz_encodingSizeConsistency(uint8 inputCount) public pure {
        // Bound the inputs
        inputCount = uint8(bound(inputCount, 1, 10));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](inputCount);

        for (uint256 i = 0; i < inputCount; i++) {
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

        bytes memory encoded = LibProveInputCodec.encode(inputs);

        // Expected size: 2 bytes for array length + 293 bytes per input
        uint256 expectedSize = 2 + (inputCount * 293);
        assertEq(encoded.length, expectedSize, "Encoding size should match expected");
    }

    /// @notice Fuzz test to ensure encoded is smaller than ABI encoding
    function testFuzz_encodedSizeComparison(uint8 inputCount) public pure {
        // Bound the inputs
        inputCount = uint8(bound(inputCount, 1, 5));

        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](inputCount);

        for (uint256 i = 0; i < inputCount; i++) {
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
            "LibProveInputCodec should produce smaller output than ABI encoding"
        );
    }

}
