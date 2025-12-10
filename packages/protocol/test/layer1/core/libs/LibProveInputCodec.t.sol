// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputCodec } from "src/layer1/core/libs/LibProveInputCodec.sol";

contract LibProveInputCodecTest is Test {
    function test_encode_decode_roundtrip() public pure {
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

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 5,
            firstProposalParentBlockHash: bytes32(uint256(99)),
            lastProposalHash: bytes32(uint256(77)),
            lastBlockNumber: 1000,
            lastStateRoot: bytes32(uint256(88)),
            actualProver: address(0xAAAA),
            proposalStates: proposalStates
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.firstProposalId, input.firstProposalId, "firstProposalId");
        assertEq(
            decoded.firstProposalParentBlockHash,
            input.firstProposalParentBlockHash,
            "firstProposalParentBlockHash"
        );
        assertEq(decoded.proposalStates.length, 2, "proposalStates length");
        assertEq(
            decoded.proposalStates[0].proposer,
            proposalStates[0].proposer,
            "proposalStates[0] proposer"
        );
        assertEq(
            decoded.proposalStates[0].designatedProver,
            proposalStates[0].designatedProver,
            "proposalStates[0] designatedProver"
        );
        assertEq(
            decoded.proposalStates[0].timestamp,
            proposalStates[0].timestamp,
            "proposalStates[0] timestamp"
        );
        assertEq(
            decoded.proposalStates[0].blockHash,
            proposalStates[0].blockHash,
            "proposalStates[0] blockHash"
        );
        assertEq(
            decoded.proposalStates[1].proposer,
            proposalStates[1].proposer,
            "proposalStates[1] proposer"
        );
        assertEq(
            decoded.proposalStates[1].blockHash,
            proposalStates[1].blockHash,
            "proposalStates[1] blockHash"
        );
        assertEq(decoded.lastBlockNumber, input.lastBlockNumber, "lastBlockNumber");
        assertEq(decoded.lastStateRoot, input.lastStateRoot, "lastStateRoot");
        assertEq(decoded.actualProver, input.actualProver, "actualProver");
    }

    function test_encode_decode_singleProposal() public pure {
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: address(0x5555),
            designatedProver: address(0x6666),
            timestamp: 500,
            blockHash: bytes32(uint256(55))
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 1,
            firstProposalParentBlockHash: bytes32(0),
            lastProposalHash: bytes32(uint256(11)),
            lastBlockNumber: 50,
            lastStateRoot: bytes32(uint256(66)),
            actualProver: address(0xBBBB),
            proposalStates: proposalStates
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.firstProposalId, 1, "firstProposalId");
        assertEq(decoded.proposalStates.length, 1, "proposalStates length");
        assertEq(decoded.proposalStates[0].proposer, address(0x5555), "proposer");
        assertEq(decoded.actualProver, address(0xBBBB), "actualProver");
    }

    function test_encode_decode_emptyProposals() public pure {
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](0);

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 0,
            firstProposalParentBlockHash: bytes32(0),
            lastProposalHash: bytes32(0),
            lastBlockNumber: 0,
            lastStateRoot: bytes32(0),
            actualProver: address(0),
            proposalStates: proposalStates
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.proposalStates.length, 0, "empty proposalStates");
    }

    function test_encode_deterministic() public pure {
        IInbox.ProposalState[] memory proposalStates = new IInbox.ProposalState[](1);
        proposalStates[0] = IInbox.ProposalState({
            proposer: address(0x1234),
            designatedProver: address(0x5678),
            timestamp: 12_345,
            blockHash: bytes32(uint256(9999))
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            firstProposalId: 42,
            firstProposalParentBlockHash: bytes32(uint256(1111)),
            lastProposalHash: bytes32(uint256(2222)),
            lastBlockNumber: 888,
            lastStateRoot: bytes32(uint256(7777)),
            actualProver: address(0xCCCC),
            proposalStates: proposalStates
        });

        bytes memory encoded1 = LibProveInputCodec.encode(input);
        bytes memory encoded2 = LibProveInputCodec.encode(input);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }
}
