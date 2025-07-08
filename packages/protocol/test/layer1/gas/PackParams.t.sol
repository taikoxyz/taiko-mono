// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CompareGasTest.sol";
import { IInbox as I } from "src/layer1/based2/IInbox.sol";
import "src/layer1/based2/libs/LibCodec.sol";

contract Target {
    event Evt(I.TransitionMeta[] a);

    function foo(I.TransitionMeta[] memory trans) external {
        emit Evt(trans);
    }

    function bar(bytes calldata trans) external {
        I.TransitionMeta[] memory t = LibCodec.unpackTransitionMetas(trans);
        emit Evt(t);
    }
}

contract PackParamsGas is CompareGasTest {
    Target target = new Target();

    function test_PackParamsGas() external {
        I.TransitionMeta[] memory trans = _generateInput();

        // Measure gas for case 1
        vm.startSnapshotGas("no packing");
        target.foo(trans);
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
        transitions = new I.TransitionMeta[](3);

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

        transitions[1] = I.TransitionMeta({
            blockHash: keccak256(abi.encodePacked("blockHash2")),   
            stateRoot: 0x1234561234561234561234561234561234561234561234561234561234561234,
            prover: address(123),
            proofTiming: I.ProofTiming.OutOfExtendedProvingWindow,
            createdAt: uint48(block.timestamp),
            byAssignedProver: false,
            lastBlockId: 1002,
            provabilityBond: 2_000_000_000_000_000_000,
            livenessBond: 1_000_000_000_000_000_000
        });

        transitions[2] = I.TransitionMeta({
            blockHash: 0x1111111111111111111111111111111111111111111111111111111111111111,
            stateRoot: 0x2222222222222222222222222222222222222222222222222222222222222222,
            prover: 0x1111111111111111111111111111111111111111,
            proofTiming: I.ProofTiming.InProvingWindow,
            createdAt: uint48(block.timestamp),
            byAssignedProver: true,
            lastBlockId: 1003,
            provabilityBond: 3_000_000_000_000_000_000,
            livenessBond: 1_500_000_000_000_000_000
        });
    }
}
