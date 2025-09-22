// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { LibProveInputDecoder } from "src/layer1/shasta/libs/LibProveInputDecoder.sol";
import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";

/// @title LibProveInputDecoderTest
/// @notice Tests for LibProveInputDecoder
/// @custom:security-contact security@taiko.xyz
contract LibProveInputDecoderTest is Test {
    // Wrapper contract to test reverts properly
    TestWrapper wrapper;

    function setUp() public {
        wrapper = new TestWrapper();
    }

    function test_baseline_vs_optimized_simple() public {
        // Setup simple test case with 1 proposal and 1 transition
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 10,
            proposer: address(0x1),
            timestamp: 1000,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256("coreState"),
            derivationHash: keccak256("derivation")
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: keccak256("proposal_10"),
            parentTransitionHash: keccak256("parent_transition"),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 200,
                blockHash: keccak256("end_block"),
                stateRoot: keccak256("end_state")
            })
        });

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x2),
            actualProver: address(0x3)
        });

        // Create ProveInput struct
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        // Test with standard ABI encoding for baseline
        bytes memory abiEncodedData = abi.encode(proveInput);

        // Test with compact encoding
        bytes memory compactEncodedData = LibProveInputDecoder.encode(proveInput);

        // Measure baseline gas (ABI decoding)
        uint256 gasStart = gasleft();
        IInbox.ProveInput memory decoded1 = abi.decode(abiEncodedData, (IInbox.ProveInput));
        uint256 baselineGas = gasStart - gasleft();

        // Measure optimized gas (compact decoding)
        gasStart = gasleft();
        IInbox.ProveInput memory decoded2 = LibProveInputDecoder.decode(compactEncodedData);
        uint256 optimizedGas = gasStart - gasleft();

        // Verify data integrity
        assertEq(decoded1.proposals.length, decoded2.proposals.length);
        assertEq(decoded1.transitions.length, decoded2.transitions.length);
        assertEq(decoded1.proposals[0].id, decoded2.proposals[0].id);
        assertEq(decoded1.transitions[0].proposalHash, decoded2.transitions[0].proposalHash);

        // Log results
        emit log_named_uint("Baseline gas (ABI)", baselineGas);
        emit log_named_uint("Optimized gas", optimizedGas);
        emit log_named_uint("ABI encoded size", abiEncodedData.length);
        emit log_named_uint("Compact encoded size", compactEncodedData.length);

        // Verify compact encoding is smaller
        assertLt(compactEncodedData.length, abiEncodedData.length);
    }

    function test_encode_decode_single() public pure {
        // Create test data
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](1);
        proposals[0] = IInbox.Proposal({
            id: 123,
            proposer: address(0xabcd),
            timestamp: 999_999,
            endOfSubmissionWindowTimestamp: 1_700_000_012,
            coreStateHash: keccak256("core_state_hash"),
            derivationHash: keccak256("derivation_hash")
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposalHash: keccak256("proposal_hash"),
            parentTransitionHash: keccak256("parent_hash"),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 456_789,
                blockHash: keccak256("end_block_hash"),
                stateRoot: keccak256("end_state_root")
            })
        });

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](1);
        metadata[0] = IInbox.TransitionMetadata({
            designatedProver: address(0x1234),
            actualProver: address(0x5678)
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        // Encode
        bytes memory encoded = LibProveInputDecoder.encode(proveInput);

        // Decode
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        // Verify Proposals
        assertEq(decoded.proposals.length, 1);
        assertEq(decoded.proposals[0].id, 123);
        assertEq(decoded.proposals[0].proposer, address(0xabcd));
        assertEq(decoded.proposals[0].timestamp, 999_999);
        assertEq(decoded.proposals[0].coreStateHash, keccak256("core_state_hash"));
        assertEq(decoded.proposals[0].derivationHash, keccak256("derivation_hash"));

        // Verify Transitions
        assertEq(decoded.transitions.length, 1);
        assertEq(decoded.transitions[0].proposalHash, keccak256("proposal_hash"));
        assertEq(decoded.transitions[0].parentTransitionHash, keccak256("parent_hash"));
        assertEq(decoded.transitions[0].checkpoint.blockNumber, 456_789);
        assertEq(decoded.transitions[0].checkpoint.blockHash, keccak256("end_block_hash"));
        assertEq(decoded.transitions[0].checkpoint.stateRoot, keccak256("end_state_root"));
        // Verify metadata
        assertEq(decoded.metadata.length, 1);
        assertEq(decoded.metadata[0].designatedProver, address(0x1234));
        assertEq(decoded.metadata[0].actualProver, address(0x5678));
    }

    function test_encode_decode_multiple() public pure {
        // Create multiple proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);
        for (uint256 i = 0; i < 3; i++) {
            proposals[i] = IInbox.Proposal({
                id: uint48(i + 100),
                proposer: address(uint160(0x1000 + i)),
                timestamp: uint48(2000 + i * 100),
                endOfSubmissionWindowTimestamp: uint48(2000 + i * 100 + 12),
                coreStateHash: keccak256(abi.encodePacked("core", i)),
                derivationHash: keccak256(abi.encodePacked("deriv", i))
            });
        }

        // Create multiple transitions
        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        for (uint256 i = 0; i < 3; i++) {
            transitions[i] = IInbox.Transition({
                proposalHash: keccak256(abi.encodePacked("proposal", i)),
                parentTransitionHash: keccak256(abi.encodePacked("parent", i)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: uint48(3000 + i * 100),
                    blockHash: keccak256(abi.encodePacked("endBlock", i)),
                    stateRoot: keccak256(abi.encodePacked("endState", i))
                })
            });
        }

        // Create metadata array
        IInbox.TransitionMetadata[] memory metadata = new IInbox.TransitionMetadata[](3);
        for (uint256 i = 0; i < 3; i++) {
            metadata[i] = IInbox.TransitionMetadata({
                designatedProver: address(uint160(0x2000 + i)),
                actualProver: address(uint160(0x3000 + i))
            });
        }

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        // Encode and decode
        bytes memory encoded = LibProveInputDecoder.encode(proveInput);
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        // Verify all proposals
        assertEq(decoded.proposals.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(decoded.proposals[i].id, proposals[i].id);
            assertEq(decoded.proposals[i].proposer, proposals[i].proposer);
            assertEq(decoded.proposals[i].timestamp, proposals[i].timestamp);
            assertEq(decoded.proposals[i].coreStateHash, proposals[i].coreStateHash);
            assertEq(decoded.proposals[i].derivationHash, proposals[i].derivationHash);
        }

        // Verify all transitions
        assertEq(decoded.transitions.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(decoded.transitions[i].proposalHash, transitions[i].proposalHash);
            assertEq(
                decoded.transitions[i].parentTransitionHash, transitions[i].parentTransitionHash
            );
            assertEq(
                decoded.transitions[i].checkpoint.blockNumber, transitions[i].checkpoint.blockNumber
            );
            assertEq(
                decoded.transitions[i].checkpoint.blockHash, transitions[i].checkpoint.blockHash
            );
            assertEq(
                decoded.transitions[i].checkpoint.stateRoot, transitions[i].checkpoint.stateRoot
            );
        }

        // Verify all metadata
        assertEq(decoded.metadata.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(decoded.metadata[i].designatedProver, metadata[i].designatedProver);
            assertEq(decoded.metadata[i].actualProver, metadata[i].actualProver);
        }
    }

    function test_encode_decode_empty() public pure {
        // Test with empty arrays
        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: new IInbox.Proposal[](0),
            transitions: new IInbox.Transition[](0),
            metadata: new IInbox.TransitionMetadata[](0)
        });

        bytes memory encoded = LibProveInputDecoder.encode(proveInput);
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        assertEq(decoded.proposals.length, 0);
        assertEq(decoded.transitions.length, 0);
        assertEq(decoded.metadata.length, 0);
    }

    function test_encode_decode_maxValues() public pure {
        // Test with maximum values
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
            designatedProver: address(type(uint160).max),
            actualProver: address(type(uint160).max)
        });

        IInbox.ProveInput memory proveInput = IInbox.ProveInput({
            proposals: proposals,
            transitions: transitions,
            metadata: metadata
        });

        bytes memory encoded = LibProveInputDecoder.encode(proveInput);
        IInbox.ProveInput memory decoded = LibProveInputDecoder.decode(encoded);

        assertEq(decoded.proposals[0].id, type(uint48).max);
        assertEq(decoded.proposals[0].proposer, address(type(uint160).max));
        assertEq(decoded.transitions[0].checkpoint.blockNumber, type(uint48).max);
    }

    function test_revert_mismatchedLengths() public {
        // Test that mismatched array lengths revert properly
        // The decoder reads uint24 (3 bytes) for proposal count, then uint24 for transition count
        // We need at least 6 bytes, with different values for the two counts
        bytes memory badData = new bytes(6);

        // Set proposal count to 0 (3 bytes, all zeros already)
        // Set transition count to 1 at bytes 3-5 (non-zero to trigger mismatch)
        assembly {
            mstore8(add(badData, 35), 1) // Set byte at index 3 to 1
        }

        // Should revert with ProposalTransitionLengthMismatch
        vm.expectRevert(LibProveInputDecoder.ProposalTransitionLengthMismatch.selector);
        wrapper.decode(badData);
    }
}

// Wrapper contract to test reverts properly
contract TestWrapper {
    function decode(bytes memory data) public pure returns (IInbox.ProveInput memory) {
        return LibProveInputDecoder.decode(data);
    }
}
