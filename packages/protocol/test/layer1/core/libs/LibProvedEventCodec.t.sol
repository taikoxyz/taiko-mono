// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibProvedEventCodec } from "src/layer1/core/libs/LibProvedEventCodec.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

contract LibProvedEventCodecTest is Test {
    function test_encode_decode_with_bond() public pure {
        IInbox.ProvedEventPayload memory payload = IInbox.ProvedEventPayload({
            proposalId: 7,
            transition: IInbox.Transition({
                proposalHash: bytes32(uint256(1)),
                parentTransitionHash: bytes32(uint256(2)),
                checkpoint: ICheckpointStore.Checkpoint({
                    blockNumber: 50, blockHash: bytes32(uint256(3)), stateRoot: bytes32(uint256(4))
                }),
                designatedProver: address(0x1111),
                actualProver: address(0x2222)
            }),
            bondInstruction: LibBonds.BondInstruction({
                proposalId: 10,
                bondType: LibBonds.BondType.PROVABILITY,
                payer: address(0xAAAA),
                payee: address(0xBBBB)
            }),
            bondSignal: bytes32(uint256(5))
        });

        IInbox.ProvedEventPayload memory decoded =
            LibProvedEventCodec.decode(LibProvedEventCodec.encode(payload));

        assertEq(decoded.proposalId, payload.proposalId, "proposal id");
        assertEq(decoded.transition.proposalHash, payload.transition.proposalHash, "proposal hash");
        assertEq(decoded.bondSignal, payload.bondSignal, "bond signal");
        assertEq(
            uint8(decoded.bondInstruction.bondType),
            uint8(LibBonds.BondType.PROVABILITY),
            "bond type"
        );
        assertEq(
            decoded.transition.designatedProver,
            payload.transition.designatedProver,
            "designated prover"
        );
    }

    function test_encode_decode_empty_bond_is_deterministic() public pure {
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
            bondInstruction: LibBonds.BondInstruction({
                proposalId: 0,
                bondType: LibBonds.BondType.NONE,
                payer: address(0),
                payee: address(0)
            }),
            bondSignal: bytes32(uint256(104))
        });

        bytes memory encoded1 = LibProvedEventCodec.encode(payload);
        bytes memory encoded2 = LibProvedEventCodec.encode(payload);
        assertEq(encoded1.length, encoded2.length, "length");
        assertEq(keccak256(encoded1), keccak256(encoded2), "deterministic encoding");

        IInbox.ProvedEventPayload memory decoded = LibProvedEventCodec.decode(encoded1);
        assertEq(
            uint8(decoded.bondInstruction.bondType),
            uint8(LibBonds.BondType.NONE),
            "empty bond instruction"
        );
    }
}
