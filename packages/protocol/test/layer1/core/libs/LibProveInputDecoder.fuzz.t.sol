// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputDecoder } from "src/layer1/core/libs/LibProveInputDecoder.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title LibProveInputDecoderFuzzTest
/// @notice Fuzzy tests for LibProveInputDecoder to ensure encode/decode correctness
/// @custom:security-contact security@taiko.xyz
contract LibProveInputDecoderFuzzTest is Test {
    // Wrapper contract to test reverts properly
    TestWrapperFuzz wrapper;

    function setUp() public {
        wrapper = new TestWrapperFuzz();
    }

    /// @notice Fuzz test for single proposal and transition
    function testFuzz_encodeDecodeSingleProposal(
        uint48 proposalId,
        address proposer,
        uint48 timestamp,
        uint48 endBlockNumber,
        address designatedProver
    )
        public
        pure
    {
        // Derive other values to avoid stack too deep
        bytes32 coreStateHash = keccak256(abi.encode("core", proposalId));
        bytes32 derivationHash = keccak256(abi.encode("deriv", proposalId));
        bytes32 proposalHash = keccak256(abi.encode("proposal", proposalId));
        bytes32 parentTransitionHash = keccak256(abi.encode("parent", proposalId));
        bytes32 endBlockHash = keccak256(abi.encode("block", endBlockNumber));
        bytes32 endStateRoot = keccak256(abi.encode("state", endBlockNumber));
        uint160 designated = uint160(designatedProver);
        // avoid overflow
        address actualProver =
            designated == type(uint160).max ? address(designated - 1) : address(designated + 1);

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: proposalId,
            proposer: proposer,
            timestamp: timestamp,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: coreStateHash,
            derivationHash: derivationHash
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: proposalHash,
            parentTransitionHash: parentTransitionHash,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: endBlockNumber, blockHash: endBlockHash, stateRoot: endStateRoot
            })
        });

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: designatedProver, actualProver: actualProver
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        // Encode
        bytes memory encoded = LibProveInputDecoder.encode(proveInput);

        // Decode
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        // Verify lengths
        assertEq(decoded.proposals.length, 1);
        assertEq(decoded.transitions.length, 1);

        // Verify proposal fields
        assertEq(decoded.proposals[0].id, proposals[0].id);
        assertEq(decoded.proposals[0].proposer, proposals[0].proposer);
        assertEq(decoded.proposals[0].timestamp, proposals[0].timestamp);
        assertEq(decoded.proposals[0].coreStateHash, proposals[0].coreStateHash);
        assertEq(decoded.proposals[0].derivationHash, proposals[0].derivationHash);

        // Verify transition fields
        assertEq(decoded.transitions[0].proposalHash, transitions[0].proposalHash);
        assertEq(decoded.transitions[0].parentTransitionHash, transitions[0].parentTransitionHash);
        assertEq(
            decoded.transitions[0].checkpoint.blockNumber, transitions[0].checkpoint.blockNumber
        );
        assertEq(decoded.transitions[0].checkpoint.blockHash, transitions[0].checkpoint.blockHash);
        assertEq(decoded.transitions[0].checkpoint.stateRoot, transitions[0].checkpoint.stateRoot);

        // Verify metadata
        assertEq(decoded.metadata.length, 1);
        assertEq(decoded.metadata[0].designatedProver, metadata[0].designatedProver);
        assertEq(decoded.metadata[0].actualProver, metadata[0].actualProver);
    }

    /// @notice Fuzz test for multiple proposals and transitions
    function testFuzz_encodeDecodeMultiple(uint8 count) public pure {
        // Bound count to reasonable values
        count = uint8(bound(count, 1, 20));

        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](count);
        IInbox.Transition[] memory transitions = new IInbox.Transition[](count);

        for (uint256 i = 0; i < count; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i + 1),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i),
                endOfSubmissionWindowTimestamp: uint48(1_000_000 + i + 12),
                coreStateHash: keccak256(abi.encodePacked("state", i)),
                derivationHash: keccak256(abi.encodePacked("derivation", i))
            });

            transitions[i] = IInbox.Transition({
                proposalHash: keccak256(abi.encodePacked("proposal", i)),
                parentTransitionHash: keccak256(abi.encodePacked("parent", i)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(2_000_000 + i),
                    blockHash: keccak256(abi.encodePacked("block", i)),
                    stateRoot: keccak256(abi.encodePacked("state", i))
                })
            });
        }

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](count);
        for (uint256 i = 0; i < count; i++) {
            metadata[i] = IInbox.TransitionMetadata({
                designatedProver: address(uint160(0x2000 + i)),
                actualProver: address(uint160(0x3000 + i))
            });
        }

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        // Encode
        bytes memory encoded = LibProveInputDecoder.encode(proveInput);

        // Decode
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        // Verify lengths
        assertEq(decoded.proposals.length, count);
        assertEq(decoded.transitions.length, count);

        // Verify all data
        for (uint256 i = 0; i < count; i++) {
            assertEq(decoded.proposals[i].id, proposals[i].id);
            assertEq(decoded.proposals[i].proposer, proposals[i].proposer);
            assertEq(decoded.transitions[i].proposalHash, transitions[i].proposalHash);
            assertEq(
                decoded.transitions[i].checkpoint.blockNumber, transitions[i].checkpoint.blockNumber
            );
        }
    }

    /// @notice Fuzz test for size efficiency
    function testFuzz_sizeEfficiency(
        uint8 proposalCount,
        uint8 transitionCount
    )
        public
        pure
    {
        // Bound counts - proposals and transitions must be equal per the library requirement
        proposalCount = uint8(bound(proposalCount, 1, 10));
        transitionCount = proposalCount; // Ensure equal counts

        (IInbox.ProveInput memory proveInput) = _createTestData(proposalCount, transitionCount);

        // Compare sizes
        bytes memory abiEncoded = abi.encode(proveInput);
        bytes memory compactEncoded = LibProveInputDecoder.encode(proveInput);

        // Compact encoding should be smaller
        assertLt(compactEncoded.length, abiEncoded.length);
    }

    /// @notice Fuzz test for round-trip correctness
    function testFuzz_roundTripCorrectness(
        uint48 id1,
        uint48 id2,
        address proposer1,
        address proposer2,
        uint48 timestamp1,
        uint48 timestamp2
    )
        public
        pure
    {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = IInbox.Proposal({
            id: id1,
            proposer: proposer1,
            timestamp: timestamp1,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256(abi.encode("core1")),
            derivationHash: keccak256(abi.encode("deriv1"))
        });
        proposals[1] = IInbox.Proposal({
            id: id2,
            proposer: proposer2,
            timestamp: timestamp2,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256(abi.encode("core2")),
            derivationHash: keccak256(abi.encode("deriv2"))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposalHash: keccak256(abi.encode(id1)),
            parentTransitionHash: keccak256(abi.encode("parent1")),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: timestamp1,
                blockHash: keccak256(abi.encode("block1")),
                stateRoot: keccak256(abi.encode("state1"))
            })
        });
        transitions[1] = IInbox.Transition({
            proposalHash: keccak256(abi.encode(id2)),
            parentTransitionHash: keccak256(abi.encode("parent2")),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: timestamp2,
                blockHash: keccak256(abi.encode("block2")),
                stateRoot: keccak256(abi.encode("state2"))
            })
        });

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](2);
        metadata[0] =
            IInbox.TransitionMetadata({ designatedProver: proposer1, actualProver: proposer2 });
        metadata[1] =
            IInbox.TransitionMetadata({ designatedProver: proposer2, actualProver: proposer1 });

        IInbox.ProveInput memory original = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        // First round trip
        bytes memory encoded1 = LibProveInputDecoder.encode(original);
        IInbox.ProveInput memory decoded1 = LibProveInputDecoder.decode(encoded1);

        // Second round trip
        bytes memory encoded2 = LibProveInputDecoder.encode(decoded1);
        IInbox.ProveInput memory decoded2 = LibProveInputDecoder.decode(encoded2);

        // Encodings should be identical
        assertEq(encoded1, encoded2);

        // Data should be preserved
        assertEq(decoded1.proposals[0].id, decoded2.proposals[0].id);
        assertEq(decoded1.transitions[0].proposalHash, decoded2.transitions[0].proposalHash);
    }

    /// @notice Fuzz test with maximum values
    function testFuzz_maxValues() public pure {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: type(uint48).max,
            proposer: address(type(uint160).max),
            timestamp: type(uint48).max,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: bytes32(type(uint256).max),
            derivationHash: bytes32(type(uint256).max)
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(type(uint256).max),
            parentTransitionHash: bytes32(type(uint256).max),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: type(uint48).max,
                blockHash: bytes32(type(uint256).max),
                stateRoot: bytes32(type(uint256).max)
            })
        });

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(type(uint160).max), actualProver: address(type(uint160).max)
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, metadata: metadata
        });

        bytes memory encoded = LibProveInputDecoder.encode(proveInput);
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        assertEq(decoded.proposals[0].id, type(uint48).max);
        assertEq(decoded.transitions[0].checkpoint.blockNumber, type(uint48).max);
    }

    /// @notice Helper function to create test data
    function _createTestData(
        uint256 proposalCount,
        uint256 transitionCount
    )
        private
        pure
        returns (IInbox.ProveInput memory proveInput)
    {
        proveInput.proposals = new IInbox.Proposal[](proposalCount);
        for (uint256 i = 0; i < proposalCount; i++) {
            proveInput.proposals[i] = IInbox.Proposal({
                id: uint48(100 + i),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(1_000_000 + i * 100),
                endOfSubmissionWindowTimestamp: uint48(1_000_000 + i * 100 + 12),
                coreStateHash: keccak256(abi.encodePacked("core", i)),
                derivationHash: keccak256(abi.encodePacked("deriv", i))
            });
        }

        proveInput.transitions = new IInbox.Transition[](transitionCount);
        for (uint256 i = 0; i < transitionCount; i++) {
            proveInput.transitions[i] = IInbox.Transition({
                proposalHash: keccak256(abi.encodePacked("proposal", i)),
                parentTransitionHash: keccak256(abi.encodePacked("parent", i)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(2_000_000 + i * 100),
                    blockHash: keccak256(abi.encodePacked("block", i)),
                    stateRoot: keccak256(abi.encodePacked("state", i))
                })
            });
        }

        // Create metadata array
        proveInput.metadata = new IInbox.TransitionMetadata[](transitionCount);
        for (uint256 i = 0; i < transitionCount; i++) {
            proveInput.metadata[i] = IInbox.TransitionMetadata({
                designatedProver: address(uint160(0x2000 + i)),
                actualProver: address(uint160(0x3000 + i))
            });
        }
    }

    /// @notice Test invalid data handling
    function testFuzz_invalidData(bytes memory randomData) public view {
        // Bound data size to avoid excessive gas usage
        vm.assume(randomData.length < 1000);
        vm.assume(randomData.length > 0);

        // Most random data should fail to decode properly
        // We expect a revert in most cases
        try wrapper.decode(randomData) returns (
            IInbox.ProveInput memory
        ) {
        // If it doesn't revert, that's okay - some random data might be valid
        }
            catch {
            // Expected behavior for most random data
        }
    }
}

// Wrapper contract to test reverts properly
contract TestWrapperFuzz {
    function decode(bytes memory data) public pure returns (IInbox.ProveInput memory) {
        return LibProveInputDecoder.decode(data);
    }
}
