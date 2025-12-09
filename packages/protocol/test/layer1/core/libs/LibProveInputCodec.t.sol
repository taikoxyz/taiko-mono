// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProveInputCodec } from "src/layer1/core/libs/LibProveInputCodec.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibProveInputCodecTest is Test {
    function test_encode_decode_roundtrip() public pure {
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](2);
        proposals[0] = IInbox.Proposal({
            id: 1,
            timestamp: 10,
            endOfSubmissionWindowTimestamp: 11,
            proposer: address(0x1111),
            parentProposalHash: bytes32(uint256(1)),
            derivationHash: bytes32(uint256(2))
        });
        proposals[1] = IInbox.Proposal({
            id: 2,
            timestamp: 20,
            endOfSubmissionWindowTimestamp: 21,
            proposer: address(0x2222),
            parentProposalHash: bytes32(uint256(3)),
            derivationHash: bytes32(uint256(4))
        });

        IInbox.Transition[] memory transitions = new IInbox.Transition[](2);
        transitions[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(11)),
            parentTransitionHash: bytes32(uint256(12)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 99, blockHash: bytes32(uint256(13)), stateRoot: bytes32(uint256(14))
            }),
            designatedProver: address(0xAAAA),
            actualProver: address(0xBBBB)
        });
        transitions[1] = IInbox.Transition({
            proposalHash: bytes32(uint256(21)),
            parentTransitionHash: bytes32(uint256(22)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 199, blockHash: bytes32(uint256(23)), stateRoot: bytes32(uint256(24))
            }),
            designatedProver: address(0xCCCC),
            actualProver: address(0xDDDD)
        });

        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: proposals, transitions: transitions, syncCheckpoint: true
        });

        bytes memory encoded = LibProveInputCodec.encode(input);
        IInbox.ProveInput memory decoded = LibProveInputCodec.decode(encoded);

        assertEq(decoded.proposals.length, 2, "proposal length");
        assertEq(decoded.transitions.length, 2, "transition length");
        assertEq(decoded.proposals[1].proposer, proposals[1].proposer, "proposal proposer");
        assertEq(
            decoded.transitions[1].checkpoint.blockHash,
            transitions[1].checkpoint.blockHash,
            "checkpoint hash"
        );
        assertEq(
            decoded.transitions[0].designatedProver,
            transitions[0].designatedProver,
            "designated prover"
        );
        assertTrue(decoded.syncCheckpoint, "sync checkpoint");
    }

    function test_encode_RevertWhen_lengthsMismatch() public {
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: new IInbox.Proposal[](1),
            transitions: new IInbox.Transition[](0),
            syncCheckpoint: true
        });

        vm.expectRevert(LibProveInputCodec.ProposalTransitionLengthMismatch.selector);
        this._encodeExternal(input);
    }

    function test_decode_RevertWhen_lengthsMismatch() public {
        IInbox.ProveInput memory input = IInbox.ProveInput({
            proposals: _singleProposalArray(),
            transitions: _singleTransitionArray(),
            syncCheckpoint: true
        });

        bytes memory encoded = LibProveInputCodec.encode(input);

        uint256 transitionsLengthOffset = 2 + (input.proposals.length * 102);
        encoded[transitionsLengthOffset] = 0x00;
        encoded[transitionsLengthOffset + 1] = 0x00; // set transitions length to zero to trigger mismatch

        vm.expectRevert(LibProveInputCodec.ProposalTransitionLengthMismatch.selector);
        this._decodeExternal(encoded);
    }

    function _singleProposalArray() private pure returns (IInbox.Proposal[] memory arr_) {
        arr_ = new IInbox.Proposal[](1);
        arr_[0] = IInbox.Proposal({
            id: 7,
            timestamp: 70,
            endOfSubmissionWindowTimestamp: 75,
            proposer: address(0x1234),
            parentProposalHash: bytes32(uint256(77)),
            derivationHash: bytes32(uint256(78))
        });
    }

    function _singleTransitionArray() private pure returns (IInbox.Transition[] memory arr_) {
        arr_ = new IInbox.Transition[](1);
        arr_[0] = IInbox.Transition({
            proposalHash: bytes32(uint256(80)),
            parentTransitionHash: bytes32(uint256(81)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 90, blockHash: bytes32(uint256(82)), stateRoot: bytes32(uint256(83))
            }),
            designatedProver: address(0xAAAA),
            actualProver: address(0xBBBB)
        });
    }

    // External wrappers to ensure vm.expectRevert catches the revert (call depth increases).
    function _encodeExternal(IInbox.ProveInput memory _input) external pure returns (bytes memory) {
        return LibProveInputCodec.encode(_input);
    }

    function _decodeExternal(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory)
    {
        return LibProveInputCodec.decode(_data);
    }
}
