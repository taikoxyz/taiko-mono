// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventEncoder } from "src/layer1/core/libs/LibProvedEventEncoder.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibProvedEventEncoderTest is Test {
    function test_encode_decode_with_bonds() public {
        LibBonds.BondInstruction[] memory instructions = new LibBonds.BondInstruction[](2);
        instructions[0] = LibBonds.BondInstruction({
            proposalId: 10,
            bondType: LibBonds.BondType.PROVABILITY,
            payer: address(0xAAAA),
            payee: address(0xBBBB)
        });
        instructions[1] = LibBonds.BondInstruction({
            proposalId: 11,
            bondType: LibBonds.BondType.LIVENESS,
            payer: address(0xCCCC),
            payee: address(0xDDDD)
        });

        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 7,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(1)),
                parentTransitionHash: bytes32(uint256(2)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 50,
                    blockHash: bytes32(uint256(3)),
                    stateRoot: bytes32(uint256(4))
                }),
                designatedProver: address(0x1111),
                actualProver: address(0x2222)
            }),
            transitionRecord: IInbox.TransitionRecord({
                bondInstructions: instructions,
                transitionHash: bytes32(uint256(5)),
                checkpointHash: bytes32(uint256(6))
            })
        });

        IInbox.ProvedEventPayload memory decoded =
            LibProvedEventEncoder.decode(LibProvedEventEncoder.encode(payload));

        assertEq(decoded.proposalId, payload.proposalId, "proposal id");
        assertEq(decoded.transition.proposalHash, payload.transition.proposalHash, "proposal hash");
        assertEq(decoded.transitionRecord.bondInstructions.length, 2, "instructions length");
        assertEq(
            uint8(decoded.transitionRecord.bondInstructions[1].bondType),
            uint8(LibBonds.BondType.LIVENESS),
            "bond type"
        );
        assertEq(decoded.transition.designatedProver, payload.transition.designatedProver, "designated prover");
    }

    function test_encode_decode_empty_bonds_is_deterministic() public {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 99,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(100)),
            parentTransitionHash: bytes32(uint256(101)),
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: 500,
                blockHash: bytes32(uint256(102)),
                stateRoot: bytes32(uint256(103))
            }),
            designatedProver: address(0x3333),
            actualProver: address(0x4444)
        }),
            transitionRecord: IInbox.TransitionRecord({
                bondInstructions: new LibBonds.BondInstruction[](0),
                transitionHash: bytes32(uint256(104)),
                checkpointHash: bytes32(uint256(105))
            })
        });

        bytes memory encoded1 = LibProvedEventEncoder.encode(payload);
        bytes memory encoded2 = LibProvedEventEncoder.encode(payload);
        assertEq(encoded1.length, encoded2.length, "length");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");

        IInbox.ProvedEventPayload memory decoded = LibProvedEventEncoder.decode(encoded1);
        assertEq(decoded.transitionRecord.bondInstructions.length, 0, "empty bond instructions");
    }
}
