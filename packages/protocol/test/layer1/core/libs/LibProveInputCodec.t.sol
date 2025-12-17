// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputCodec } from "src/layer1/core/libs/LibProveInputCodec.sol";

contract LibProveInputCodecTest is Test {
    function test_encode_decode_roundtrip() public pure {
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

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 5,
                firstProposalParentBlockHash: bytes32(uint256(99)),
                lastProposalHash: bytes32(uint256(100)),
                actualProver: address(0xAAAA),
                endBlockNumber: 1000,
                endStateRoot: bytes32(uint256(88)),
                transitions: transitions
            }),
            forceCheckpointSync: true
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(
            decoded.commitment.firstProposalId, input.commitment.firstProposalId, "firstProposalId"
        );
        assertEq(
            decoded.commitment.firstProposalParentBlockHash,
            input.commitment.firstProposalParentBlockHash,
            "firstProposalParentBlockHash"
        );
        assertEq(
            decoded.commitment.lastProposalHash,
            input.commitment.lastProposalHash,
            "lastProposalHash"
        );
        assertEq(decoded.commitment.transitions.length, 2, "transitions length");
        assertEq(
            decoded.commitment.transitions[0].proposer,
            transitions[0].proposer,
            "transitions[0] proposer"
        );
        assertEq(
            decoded.commitment.transitions[0].designatedProver,
            transitions[0].designatedProver,
            "transitions[0] designatedProver"
        );
        assertEq(
            decoded.commitment.transitions[0].timestamp,
            transitions[0].timestamp,
            "transitions[0] timestamp"
        );
        assertEq(
            decoded.commitment.transitions[0].blockHash,
            transitions[0].blockHash,
            "transitions[0] blockHash"
        );
        assertEq(
            decoded.commitment.transitions[1].proposer,
            transitions[1].proposer,
            "transitions[1] proposer"
        );
        assertEq(
            decoded.commitment.transitions[1].blockHash,
            transitions[1].blockHash,
            "transitions[1] blockHash"
        );
        assertEq(
            decoded.commitment.endBlockNumber, input.commitment.endBlockNumber, "endBlockNumber"
        );
        assertEq(decoded.commitment.endStateRoot, input.commitment.endStateRoot, "endStateRoot");
        assertEq(decoded.commitment.actualProver, input.commitment.actualProver, "actualProver");
        assertEq(decoded.forceCheckpointSync, input.forceCheckpointSync, "forceCheckpointSync");
    }

    function test_encode_decode_singleProposal() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x5555),
            designatedProver: address(0x6666),
            timestamp: 500,
            blockHash: bytes32(uint256(55))
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 1,
                firstProposalParentBlockHash: bytes32(0),
                lastProposalHash: bytes32(uint256(101)),
                actualProver: address(0xBBBB),
                endBlockNumber: 50,
                endStateRoot: bytes32(uint256(66)),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.commitment.firstProposalId, 1, "firstProposalId");
        assertEq(decoded.commitment.transitions.length, 1, "transitions length");
        assertEq(decoded.commitment.transitions[0].proposer, address(0x5555), "proposer");
        assertEq(decoded.commitment.actualProver, address(0xBBBB), "actualProver");
        assertEq(decoded.forceCheckpointSync, false, "forceCheckpointSync");
    }

    function test_encode_decode_emptyProposals() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](0);

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 0,
                firstProposalParentBlockHash: bytes32(0),
                lastProposalHash: bytes32(0),
                actualProver: address(0),
                endBlockNumber: 0,
                endStateRoot: bytes32(0),
                transitions: transitions
            }),
            forceCheckpointSync: false
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.commitment.transitions.length, 0, "empty transitions");
    }

    function test_encode_deterministic() public pure {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = IInbox.Transition({
            proposer: address(0x1234),
            designatedProver: address(0x5678),
            timestamp: 12_345,
            blockHash: bytes32(uint256(9999))
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: 42,
                firstProposalParentBlockHash: bytes32(uint256(1111)),
                lastProposalHash: bytes32(uint256(2222)),
                actualProver: address(0xCCCC),
                endBlockNumber: 888,
                endStateRoot: bytes32(uint256(7777)),
                transitions: transitions
            }),
            forceCheckpointSync: true
        });

        bytes memory encoded1 = LibProveInputCodec.encode(input);
        bytes memory encoded2 = LibProveInputCodec.encode(input);

        assertEq(encoded1.length, encoded2.length, "length match");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");
    }

    function testFuzz_encodeDecodeProveInput_PreservesFields(
        bytes32 seed,
        uint8 transitionsLen,
        bool forceCheckpointSync
    )
        public
        pure
    {
        transitionsLen = uint8(bound(uint256(transitionsLen), 0, 16));

        IInbox.Transition[] memory transitions = new IInbox.Transition[](transitionsLen);
        for (uint256 i; i < transitionsLen; ++i) {
            transitions[i] = IInbox.Transition({
                proposer: _addr(seed, "proposer", i),
                designatedProver: _addr(seed, "designatedProver", i),
                timestamp: uint48(uint256(keccak256(abi.encode(seed, "timestamp", i)))),
                blockHash: keccak256(abi.encode(seed, "blockHash", i))
            });
        }

        IInbox.ProveInput memory input;
        input.commitment = IInbox.Commitment({
            firstProposalId: uint48(uint256(keccak256(abi.encode(seed, "firstProposalId")))),
            firstProposalParentBlockHash: keccak256(abi.encode(seed, "parentBlockHash")),
            lastProposalHash: keccak256(abi.encode(seed, "lastProposalHash")),
            actualProver: _addr(seed, "actualProver", 0),
            endBlockNumber: uint48(uint256(keccak256(abi.encode(seed, "endBlockNumber")))),
            endStateRoot: keccak256(abi.encode(seed, "endStateRoot")),
            transitions: transitions
        });
        input.forceCheckpointSync = forceCheckpointSync;

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(
            decoded.commitment.firstProposalId, input.commitment.firstProposalId, "firstProposalId"
        );
        assertEq(
            decoded.commitment.firstProposalParentBlockHash,
            input.commitment.firstProposalParentBlockHash,
            "firstProposalParentBlockHash"
        );
        assertEq(
            decoded.commitment.lastProposalHash,
            input.commitment.lastProposalHash,
            "lastProposalHash"
        );
        assertEq(decoded.commitment.actualProver, input.commitment.actualProver, "actualProver");
        assertEq(
            decoded.commitment.endBlockNumber, input.commitment.endBlockNumber, "endBlockNumber"
        );
        assertEq(decoded.commitment.endStateRoot, input.commitment.endStateRoot, "endStateRoot");
        assertEq(
            decoded.commitment.transitions.length, input.commitment.transitions.length, "length"
        );

        for (uint256 i; i < input.commitment.transitions.length; ++i) {
            assertEq(
                decoded.commitment.transitions[i].proposer,
                input.commitment.transitions[i].proposer,
                "transition proposer"
            );
            assertEq(
                decoded.commitment.transitions[i].designatedProver,
                input.commitment.transitions[i].designatedProver,
                "transition designatedProver"
            );
            assertEq(
                decoded.commitment.transitions[i].timestamp,
                input.commitment.transitions[i].timestamp,
                "transition timestamp"
            );
            assertEq(
                decoded.commitment.transitions[i].blockHash,
                input.commitment.transitions[i].blockHash,
                "transition blockHash"
            );
        }

        assertEq(decoded.forceCheckpointSync, input.forceCheckpointSync, "forceCheckpointSync");
    }

    function _addr(bytes32 seed, string memory label, uint256 index) private pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(seed, label, index)))));
    }
}
