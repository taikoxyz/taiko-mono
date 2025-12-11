// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputCodec } from "src/layer1/core/libs/LibProveInputCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibProveInputCodecTest is Test {
    function test_encode_decode_roundtrip() public pure {
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

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 5,
            firstProposalParentCheckpointHash: bytes32(uint256(99)),
            actualProver: address(0xAAAA),
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 1000,
                blockHash: transitions[1].checkpointHash,
                stateRoot: bytes32(uint256(88))
            }),
            forceCheckpointSync: true
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.firstProposalId, input.firstProposalId, "firstProposalId");
        assertEq(
            decoded.firstProposalParentCheckpointHash,
            input.firstProposalParentCheckpointHash,
            "firstProposalParentCheckpointHash"
        );
        assertEq(decoded.transitions.length, 2, "transitions length");
        assertEq(
            decoded.transitions[0].proposer, transitions[0].proposer, "transitions[0] proposer"
        );
        assertEq(
            decoded.transitions[0].designatedProver,
            transitions[0].designatedProver,
            "transitions[0] designatedProver"
        );
        assertEq(
            decoded.transitions[0].timestamp, transitions[0].timestamp, "transitions[0] timestamp"
        );
        assertEq(
            decoded.transitions[0].checkpointHash,
            transitions[0].checkpointHash,
            "transitions[0] checkpointHash"
        );
        assertEq(
            decoded.transitions[1].proposer, transitions[1].proposer, "transitions[1] proposer"
        );
        assertEq(
            decoded.transitions[1].checkpointHash,
            transitions[1].checkpointHash,
            "transitions[1] checkpointHash"
        );
        assertEq(
            decoded.lastCheckpoint.blockNumber,
            input.lastCheckpoint.blockNumber,
            "lastCheckpoint blockNumber"
        );
        assertEq(
            decoded.lastCheckpoint.blockHash,
            input.lastCheckpoint.blockHash,
            "lastCheckpoint blockHash"
        );
        assertEq(
            decoded.lastCheckpoint.stateRoot,
            input.lastCheckpoint.stateRoot,
            "lastCheckpoint stateRoot"
        );
        assertEq(decoded.actualProver, input.actualProver, "actualProver");
        assertEq(decoded.forceCheckpointSync, input.forceCheckpointSync, "forceCheckpointSync");
    }

    function test_encode_decode_singleProposal() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x5555),
            designatedProver: address(0x6666),
            timestamp: 500,
            checkpointHash: bytes32(uint256(55))
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentCheckpointHash: bytes32(0),
            actualProver: address(0xBBBB),
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 50,
                blockHash: transitions[0].checkpointHash,
                stateRoot: bytes32(uint256(66))
            }),
            forceCheckpointSync: false
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.firstProposalId, 1, "firstProposalId");
        assertEq(decoded.transitions.length, 1, "transitions length");
        assertEq(decoded.transitions[0].proposer, address(0x5555), "proposer");
        assertEq(decoded.actualProver, address(0xBBBB), "actualProver");
        assertEq(decoded.forceCheckpointSync, false, "forceCheckpointSync");
    }

    function test_encode_decode_emptyProposals() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](0);

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 0,
            firstProposalParentCheckpointHash: bytes32(0),
            actualProver: address(0),
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 0, blockHash: bytes32(0), stateRoot: bytes32(0)
            }),
            forceCheckpointSync: false
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.transitions.length, 0, "empty transitions");
    }

    function test_encode_deterministic() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1234),
            designatedProver: address(0x5678),
            timestamp: 12_345,
            checkpointHash: bytes32(uint256(9999))
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 42,
            firstProposalParentCheckpointHash: bytes32(uint256(1111)),
            actualProver: address(0xCCCC),
            transitions: transitions,
            lastCheckpoint: ICheckpointStore.Checkpoint({
                blockNumber: 888,
                blockHash: transitions[0].checkpointHash,
                stateRoot: bytes32(uint256(7777))
            }),
            forceCheckpointSync: true
        });

        bytes memory encoded1 = LibProveInputCodec.encode(input);
        bytes memory encoded2 = LibProveInputCodec.encode(input);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }
}
