// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventCodec } from "src/layer1/core/libs/LibProvedEventCodec.sol";

contract LibProvedEventCodecTest is Test {
    function test_encode_decode_single_proposal() public pure {
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            blockHash: bytes32(uint256(1))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 5,
                firstProposalParentBlockHash: bytes32(uint256(99)),
                lastProposalHash: bytes32(uint256(77)),
                lastBlockNumber: 1000,
                lastStateRoot: bytes32(uint256(88)),
                actualProver: address(0xAAAA),
                proposalStates: proposalStates
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.input.firstProposalId, payload.input.firstProposalId, "firstProposalId");
        assertEq(
            decoded.input.firstProposalParentBlockHash,
            payload.input.firstProposalParentBlockHash,
            "firstProposalParentBlockHash"
        );
        assertEq(decoded.input.proposalStates.length, 1, "proposalStates length");
        assertEq(
            decoded.input.proposalStates[0].proposer,
            proposalStates[0].proposer,
            "proposalStates[0] proposer"
        );
        assertEq(
            decoded.input.proposalStates[0].designatedProver,
            proposalStates[0].designatedProver,
            "proposalStates[0] designatedProver"
        );
        assertEq(
            decoded.input.proposalStates[0].timestamp,
            proposalStates[0].timestamp,
            "proposalStates[0] timestamp"
        );
        assertEq(
            decoded.input.proposalStates[0].blockHash,
            proposalStates[0].blockHash,
            "proposalStates[0] blockHash"
        );
        assertEq(decoded.input.lastBlockNumber, payload.input.lastBlockNumber, "lastBlockNumber");
        assertEq(decoded.input.lastStateRoot, payload.input.lastStateRoot, "lastStateRoot");
        assertEq(decoded.input.actualProver, payload.input.actualProver, "actualProver");
    }

    function test_encode_decode_multiple_proposals() public pure {
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](3);
        proposalStates[0] = IInbox.ProposalState({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            blockHash: bytes32(uint256(1))
        });
        proposalStates[1] = IInbox.ProposalState({
            proposer: address(0x3333),
            designatedProver: address(0x4444),
            timestamp: 200,
            blockHash: bytes32(uint256(2))
        });
        proposalStates[2] = IInbox.ProposalState({
            proposer: address(0x5555),
            designatedProver: address(0x6666),
            timestamp: 300,
            blockHash: bytes32(uint256(3))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 10,
                firstProposalParentBlockHash: bytes32(uint256(999)),
                lastProposalHash: bytes32(uint256(777)),
                lastBlockNumber: 5000,
                lastStateRoot: bytes32(uint256(888)),
                actualProver: address(0xBBBB),
                proposalStates: proposalStates
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);
        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded);

        assertEq(decoded.input.firstProposalId, 10, "firstProposalId");
        assertEq(decoded.input.proposalStates.length, 3, "proposalStates length");

        for (uint256 i; i < 3; ++i) {
            assertEq(
                decoded.input.proposalStates[i].proposer,
                proposalStates[i].proposer,
                string.concat("proposalStates[", vm.toString(i), "] proposer")
            );
            assertEq(
                decoded.input.proposalStates[i].designatedProver,
                proposalStates[i].designatedProver,
                string.concat("proposalStates[", vm.toString(i), "] designatedProver")
            );
            assertEq(
                decoded.input.proposalStates[i].timestamp,
                proposalStates[i].timestamp,
                string.concat("proposalStates[", vm.toString(i), "] timestamp")
            );
            assertEq(
                decoded.input.proposalStates[i].blockHash,
                proposalStates[i].blockHash,
                string.concat("proposalStates[", vm.toString(i), "] blockHash")
            );
        }
    }

    function test_encode_deterministic() public pure {
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: address(0x1234),
            designatedProver: address(0x5678),
            timestamp: 12_345,
            blockHash: bytes32(uint256(9999))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 42,
                firstProposalParentBlockHash: bytes32(uint256(1111)),
                lastProposalHash: bytes32(uint256(2222)),
                lastBlockNumber: 888,
                lastStateRoot: bytes32(uint256(7777)),
                actualProver: address(0xDDDD),
                proposalStates: proposalStates
            })
        });

        bytes memory encoded1 = LibProvedEventCodec.encode(payload);
        bytes memory encoded2 = LibProvedEventCodec.encode(payload);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }

    function test_encoded_size() public pure {
        // Test that encoded size matches expected formula: 98 + (numProposalStates * 78)
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](2);
        proposalStates[0] = IInbox.ProposalState({
            proposer: address(0x1111),
            designatedProver: address(0x2222),
            timestamp: 100,
            blockHash: bytes32(uint256(1))
        });
        proposalStates[1] = IInbox.ProposalState({
            proposer: address(0x3333),
            designatedProver: address(0x4444),
            timestamp: 200,
            blockHash: bytes32(uint256(2))
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            input: IInbox.ProveInput({
                firstProposalId: 1,
                firstProposalParentBlockHash: bytes32(0),
                lastProposalHash: bytes32(uint256(3)),
                lastBlockNumber: 10,
                lastStateRoot: bytes32(uint256(2)),
                actualProver: address(0xAAAA),
                proposalStates: proposalStates
            })
        });

        bytes memory encoded = LibProvedEventCodec.encode(payload);

        // Expected size: 130 + (2 * 78) = 130 + 156 = 286
        assertEq(encoded.length, 286, "encoded size for 2 proposalStates");
    }
}
