// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventCodec } from "src/layer1/core/libs/LibProvedEventCodec.sol";

contract LibProvedEventCodecTest is Test {
    function test_encode_decode_single_proposal() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            blockHash: bytes32(uint256(1))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                commitment: IInbox.Commitment({
                    firstProposalId: 5,
                    firstProposalParentCheckpointHash: bytes32(uint256(99)),
                    lastProposalHash: bytes32(uint256(100)),
                    actualProver: address(0xAAAA),
                    endBlockNumber: 1000,
                    endStateRoot: bytes32(uint256(88)),
                    transitions: transitions
                }),
                forceCheckpointSync: false
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(
            decoded.input.commitment.firstProposalId,
            payload.input.commitment.firstProposalId,
            "firstProposalId"
        );
        assertEq(
            decoded.input.commitment.firstProposalParentCheckpointHash,
            payload.input.commitment.firstProposalParentCheckpointHash,
            "firstProposalParentCheckpointHash"
        );
        assertEq(
            decoded.input.commitment.lastProposalHash,
            payload.input.commitment.lastProposalHash,
            "lastProposalHash"
        );
        assertEq(decoded.input.commitment.transitions.length, 1, "transitions length");
        assertEq(
            decoded.input.commitment.transitions[0].proposer,
            transitions[0].proposer,
            "transitions[0] proposer"
        );
        assertEq(
            decoded.input.commitment.transitions[0].designatedProver,
            transitions[0].designatedProver,
            "transitions[0] designatedProver"
        );
        assertEq(
            decoded.input.commitment.transitions[0].timestamp,
            transitions[0].timestamp,
            "transitions[0] timestamp"
        );
        assertEq(
            decoded.input.commitment.transitions[0].blockHash,
            transitions[0].blockHash,
            "transitions[0] blockHash"
        );
        assertEq(
            decoded.input.commitment.endBlockNumber,
            payload.input.commitment.endBlockNumber,
            "endBlockNumber"
        );
        assertEq(
            decoded.input.commitment.endStateRoot,
            payload.input.commitment.endStateRoot,
            "endStateRoot"
        );
        assertEq(
            decoded.input.commitment.actualProver,
            payload.input.commitment.actualProver,
            "actualProver"
        );
    }

    function test_encode_decode_multiple_proposals() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            blockHash: bytes32(uint256(1))
        });
        transitions[1] = IInbox.Transition({
            proposer: address(0x3333),
            designatedProver: address(0x4444),
            timestamp: 200,
            blockHash: bytes32(uint256(2))
        });
        transitions[2] = IInbox.Transition({
            proposer: address(0x5555),
            designatedProver: address(0x6666),
            timestamp: 300,
            blockHash: bytes32(uint256(3))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                commitment: IInbox.Commitment({
                    firstProposalId: 10,
                    firstProposalParentCheckpointHash: bytes32(uint256(999)),
                    lastProposalHash: bytes32(uint256(1000)),
                    actualProver: address(0xBBBB),
                    endBlockNumber: 5000,
                    endStateRoot: bytes32(uint256(888)),
                    transitions: transitions
                }),
                forceCheckpointSync: true
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.input.commitment.firstProposalId, 10, "firstProposalId");
        assertEq(decoded.input.commitment.transitions.length, 3, "transitions length");

        for (uint256 i; i < 3; ++i) {
            assertEq(
                decoded.input.commitment.transitions[i].proposer,
                transitions[i].proposer,
                string.concat("transitions[", vm.toString(i), "] proposer")
            );
            assertEq(
                decoded.input.commitment.transitions[i].designatedProver,
                transitions[i].designatedProver,
                string.concat("transitions[", vm.toString(i), "] designatedProver")
            );
            assertEq(
                decoded.input.commitment.transitions[i].timestamp,
                transitions[i].timestamp,
                string.concat("transitions[", vm.toString(i), "] timestamp")
            );
            assertEq(
                decoded.input.commitment.transitions[i].blockHash,
                transitions[i].blockHash,
                string.concat("transitions[", vm.toString(i), "] blockHash")
            );
        }
    }

    function test_encode_deterministic() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1234),
            designatedProver: address(0x5678),
            timestamp: 12_345,
            blockHash: bytes32(uint256(9999))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                commitment: IInbox.Commitment({
                    firstProposalId: 42,
                    firstProposalParentCheckpointHash: bytes32(uint256(1111)),
                    lastProposalHash: bytes32(uint256(2222)),
                    actualProver: address(0xDDDD),
                    endBlockNumber: 888,
                    endStateRoot: bytes32(uint256(7777)),
                    transitions: transitions
                }),
                forceCheckpointSync: false
            })
        });

        bytes memory encoded1 = LibProvedEventCodec.encode(payload);
        bytes memory encoded2 = LibProvedEventCodec.encode(payload);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }

    function test_encoded_size() public pure {
        // Test that encoded size matches expected formula: 131 + (numTransitions * 78)
        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            blockHash: bytes32(uint256(1))
        });
        transitions[1] = IInbox.Transition({
            proposer: address(0x3333),
            designatedProver: address(0x4444),
            timestamp: 200,
            blockHash: bytes32(uint256(2))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                commitment: IInbox.Commitment({
                    firstProposalId: 1,
                    firstProposalParentCheckpointHash: bytes32(0),
                    lastProposalHash: bytes32(uint256(3)),
                    actualProver: address(0xAAAA),
                    endBlockNumber: 10,
                    endStateRoot: bytes32(uint256(2)),
                    transitions: transitions
                }),
                forceCheckpointSync: false
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);

        // Expected size: 131 + (2 * 78) = 131 + 156 = 287
        assertEq(encoded.length, 287, "encoded size for 2 transitions");
    }
}
