// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CompareGasTest.sol";
import { IInbox as I } from "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibData.sol";

contract Target {
    event Evt(I.TransitionMeta a);

    function foo(I.TransitionMeta memory tran) external {
        emit Evt(tran);
    }

    function bar(bytes memory tran) external {
        // I.TransitionMeta memory t = LibData.unpackTransitionMeta(tran);
        // emit Evt(t);
    }
}

contract PackParamsGas is CompareGasTest {
    Target target = new Target();

    function test_PackParamsGas() external {
        I.TransitionMeta[] memory trans = _generateInput();

        // Test basic functionality
        target.foo(trans[0]);

        // Test packing and unpacking
        bytes memory packed;
        // The following line will cause the InvalidOperandOOG error
        packed = LibData.packTransitionMeta(trans);
        target.bar(packed);
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
