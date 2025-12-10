// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventCodec } from "src/layer1/core/libs/LibProvedEventCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibProvedEventCodecTest is Test {
    function test_encode_decode_single_proposal() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            checkpointHash: bytes32(uint256(1))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 5,
                firstProposalParentCheckpointHash: bytes32(uint256(99)),
                actualProver: address(0xAAAA),
                transitions: transitions,
                lastCheckpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 1000,
                    blockHash: transitions[0].checkpointHash,
                    stateRoot: bytes32(uint256(88))
                })
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.input.firstProposalId, payload.input.firstProposalId, "firstProposalId");
        assertEq(
            decoded.input.firstProposalParentCheckpointHash,
            payload.input.firstProposalParentCheckpointHash,
            "firstProposalParentCheckpointHash"
        );
        assertEq(decoded.input.transitions.length, 1, "transitions length");
        assertEq(
            decoded.input.transitions[0].proposer,
            transitions[0].proposer,
            "transitions[0] proposer"
        );
        assertEq(
            decoded.input.transitions[0].designatedProver,
            transitions[0].designatedProver,
            "transitions[0] designatedProver"
        );
        assertEq(
            decoded.input.transitions[0].timestamp,
            transitions[0].timestamp,
            "transitions[0] timestamp"
        );
        assertEq(
            decoded.input.transitions[0].checkpointHash,
            transitions[0].checkpointHash,
            "transitions[0] checkpointHash"
        );
        assertEq(
            decoded.input.lastCheckpoint.blockNumber,
            payload.input.lastCheckpoint.blockNumber,
            "lastCheckpoint blockNumber"
        );
        assertEq(
            decoded.input.lastCheckpoint.blockHash,
            payload.input.lastCheckpoint.blockHash,
            "lastCheckpoint blockHash"
        );
        assertEq(
            decoded.input.lastCheckpoint.stateRoot,
            payload.input.lastCheckpoint.stateRoot,
            "lastCheckpoint stateRoot"
        );
        assertEq(decoded.input.actualProver, payload.input.actualProver, "actualProver");
    }

    function test_encode_decode_multiple_proposals() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            checkpointHash: bytes32(uint256(1))
        });
        transitions[1] = IInbox.Transition({
            proposer: address(0x3333),
            designatedProver: address(0x4444),
            timestamp: 200,
            checkpointHash: bytes32(uint256(2))
        });
        transitions[2] = IInbox.Transition({
            proposer: address(0x5555),
            designatedProver: address(0x6666),
            timestamp: 300,
            checkpointHash: bytes32(uint256(3))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 10,
                firstProposalParentCheckpointHash: bytes32(uint256(999)),
                actualProver: address(0xBBBB),
                transitions: transitions,
                lastCheckpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 5000,
                    blockHash: transitions[2].checkpointHash,
                    stateRoot: bytes32(uint256(888))
                })
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.input.firstProposalId, 10, "firstProposalId");
        assertEq(decoded.input.transitions.length, 3, "transitions length");

        for (uint256 i; i < 3; ++i) {
            assertEq(
                decoded.input.transitions[i].proposer,
                transitions[i].proposer,
                string.concat("transitions[", vm.toString(i), "] proposer")
            );
            assertEq(
                decoded.input.transitions[i].designatedProver,
                transitions[i].designatedProver,
                string.concat("transitions[", vm.toString(i), "] designatedProver")
            );
            assertEq(
                decoded.input.transitions[i].timestamp,
                transitions[i].timestamp,
                string.concat("transitions[", vm.toString(i), "] timestamp")
            );
            assertEq(
                decoded.input.transitions[i].checkpointHash,
                transitions[i].checkpointHash,
                string.concat("transitions[", vm.toString(i), "] checkpointHash")
            );
        }
    }

    function test_encode_deterministic() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1234),
            designatedProver: address(0x5678),
            timestamp: 12_345,
            checkpointHash: bytes32(uint256(9999))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 42,
                firstProposalParentCheckpointHash: bytes32(uint256(1111)),
                actualProver: address(0xDDDD),
                transitions: transitions,
                lastCheckpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 888,
                    blockHash: transitions[0].checkpointHash,
                    stateRoot: bytes32(uint256(7777))
                })
            })
        });

        bytes memory encoded1 = LibProvedEventCodec.encode(payload);
        bytes memory encoded2 = LibProvedEventCodec.encode(payload);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }

    function test_encoded_size() public pure {
        // Test that encoded size matches expected formula: 130 + (numTransitions * 78)
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            checkpointHash: bytes32(uint256(1))
        });
        transitions[1] = IInbox.Transition({
            proposer: address(0x3333),
            designatedProver: address(0x4444),
            timestamp: 200,
            checkpointHash: bytes32(uint256(2))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 1,
                firstProposalParentCheckpointHash: bytes32(0),
                actualProver: address(0xAAAA),
                transitions: transitions,
                lastCheckpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 10,
                    blockHash: transitions[1].checkpointHash,
                    stateRoot: bytes32(uint256(2))
                })
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);

        // Expected size: 130 + (2 * 78) = 130 + 156 = 286
        assertEq(encoded.length, 286, "encoded size for 2 transitions");
    }
}
