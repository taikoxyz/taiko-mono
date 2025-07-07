// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CompareGasTest.sol";
import { IInbox as I } from "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibData.sol";

contract Target {
    event Evt(uint a);

    function foo(I.TransitionMeta[] calldata trans) external {
        emit Evt(trans.length);
    }

    function bar(bytes[122][] calldata trans) external {
        uint256 nTrans = trans.length;
        I.TransitionMeta[] memory _trans = new I.TransitionMeta[](nTrans);
        for (uint256 i; i < nTrans; ++i) {
            _trans[i] = LibData.unpackTransitionMeta(trans[i]);
        }
        emit Evt(_trans.length);
    }
}

contract PackParamsGas is CompareGasTest {
    Target target = new Target();

    function test_PackParamsGas() external {
        I.TransitionMeta[] memory trans = _generateInput();
        
        // Test basic functionality
        target.foo(trans);
        
        // Test packing and unpacking
        bytes[122][] memory packedTrans = new bytes[122][](1);
        packedTrans[0] = LibData.packTransitionMeta(trans[0]);
        target.bar(packedTrans);
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
