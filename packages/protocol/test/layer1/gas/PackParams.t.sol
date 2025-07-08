// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CompareGasTest.sol";
import { IInbox as I } from "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibCodec.sol";

contract Target {
    event Evt(I.TransitionMeta a);

    function foo(I.TransitionMeta memory tran) external {
        emit Evt(tran);
    }

    function bar(bytes calldata tran) external {
        I.TransitionMeta[] memory t = LibCodec.unpackTransitionMetas(tran);
        emit Evt(t[0]);
    }
}

contract PackParamsGas is CompareGasTest {
    Target target = new Target();

    function test_PackParamsGas() external {
        I.TransitionMeta[] memory trans = _generateInput();

        // Measure gas for case 1
        vm.startSnapshotGas("no packing");
        target.foo(trans[0]);
        uint256 gasUsed1 = vm.stopSnapshotGas();

        // Test packing and unpacking
        bytes memory packed = LibCodec.packTransitionMetas(trans);

        // Measure gas for case 2
        vm.startSnapshotGas("packing");
        target.bar(packed);
        uint256 gasUsed2 = vm.stopSnapshotGas();

        // Log the gas used for comparison
        emit log_named_uint("Gas used for case 1 (no packing):", gasUsed1);
        emit log_named_uint("Gas used for case 2 (packing):", gasUsed2);
    }

    function _generateInput() private view returns (I.TransitionMeta[] memory transitions) {
        transitions = new I.TransitionMeta[](1);

        transitions[0] = I.TransitionMeta({
            blockHash: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef,
            stateRoot: 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890,
            prover: 0x1234567890AbcdEF1234567890aBcdef12345678,
            proofTiming: I.ProofTiming.InProvingWindow,
            createdAt: uint48(block.timestamp),
            byAssignedProver: true,
            lastBlockId: 1001,
            provabilityBond: 1_000_000_000_000_000_000,
            livenessBond: 500_000_000_000_000_000
        });
    }
}
