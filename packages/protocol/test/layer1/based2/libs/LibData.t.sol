// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { LibData } from "../../../../contracts/layer1/based2/libs/LibData.sol";
import { IInbox } from "../../../../contracts/layer1/based2/IInbox.sol";

contract LibDataTest is Test {
    using LibData for IInbox.TransitionMeta;

    function test_packUnpackTransitionMeta_basic() public pure {
        // Create a basic TransitionMeta struct
        IInbox.TransitionMeta memory original = IInbox.TransitionMeta({
            blockHash: bytes32(uint256(1)),
            stateRoot: bytes32(uint256(2)),
            prover: address(0x1234567890123456789012345678901234567890),
            proofTiming: IInbox.ProofTiming.InProvingWindow,
            createdAt: 12_345,
            byAssignedProver: true,
            lastBlockId: 67_890,
            provabilityBond: 1_000_000_000_000_000_000,
            livenessBond: 2_000_000_000_000_000_000
        });

        bytes[122] memory packed = LibData.packTransitionMeta(original);
        IInbox.TransitionMeta memory unpacked = LibData.unpackTransitionMeta(packed);
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked)));
    }

    function test_packUnpackTransitionMeta_maxValues() public pure {
        // Test with maximum values
        IInbox.TransitionMeta memory original = IInbox.TransitionMeta({
            blockHash: bytes32(type(uint256).max),
            stateRoot: bytes32(type(uint256).max),
            prover: address(type(uint160).max),
            proofTiming: IInbox.ProofTiming.InExtendedProvingWindow,
            createdAt: type(uint48).max,
            byAssignedProver: true,
            lastBlockId: type(uint48).max,
            provabilityBond: type(uint96).max,
            livenessBond: type(uint96).max
        });

        // Pack and unpack
        bytes[122] memory packed = LibData.packTransitionMeta(original);
        IInbox.TransitionMeta memory unpacked = LibData.unpackTransitionMeta(packed);
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked)));
    }

    function test_packUnpackTransitionMeta_minValues() public pure {
        // Test with minimum values
        IInbox.TransitionMeta memory original = IInbox.TransitionMeta({
            blockHash: bytes32(0),
            stateRoot: bytes32(0),
            prover: address(0),
            proofTiming: IInbox.ProofTiming.OutOfExtendedProvingWindow,
            createdAt: 0,
            byAssignedProver: false,
            lastBlockId: 0,
            provabilityBond: 0,
            livenessBond: 0
        });

        // Pack and unpack
        bytes[122] memory packed = LibData.packTransitionMeta(original);
        IInbox.TransitionMeta memory unpacked = LibData.unpackTransitionMeta(packed);
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked)));
    }

    function test_packUnpackTransitionMeta_allProofTimings() public pure {
        // Test all ProofTiming enum values
        IInbox.ProofTiming[3] memory timings = [
            IInbox.ProofTiming.OutOfExtendedProvingWindow,
            IInbox.ProofTiming.InProvingWindow,
            IInbox.ProofTiming.InExtendedProvingWindow
        ];

        for (uint256 i = 0; i < timings.length; i++) {
            IInbox.TransitionMeta memory original = IInbox.TransitionMeta({
                blockHash: keccak256(abi.encode("block", i)),
                stateRoot: keccak256(abi.encode("state", i)),
                prover: address(uint160(i + 1)),
                proofTiming: timings[i],
                createdAt: uint48(i * 1000),
                byAssignedProver: i % 2 == 0,
                lastBlockId: uint48(i * 10_000),
                provabilityBond: uint96(i * 1e18),
                livenessBond: uint96(i * 2e18)
            });

            bytes[122] memory packed = LibData.packTransitionMeta(original);
            IInbox.TransitionMeta memory unpacked = LibData.unpackTransitionMeta(packed);
            assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked)));
        }
    }

    function test_packUnpackTransitionMeta_fuzz(
        bytes32 blockHash,
        bytes32 stateRoot,
        address prover,
        uint8 proofTimingRaw,
        uint48 createdAt,
        bool byAssignedProver,
        uint48 lastBlockId,
        uint96 provabilityBond,
        uint96 livenessBond
    )
        public
        pure
    {
        // Bound proofTiming to valid enum values
        proofTimingRaw = proofTimingRaw % 3;
        IInbox.ProofTiming proofTiming = IInbox.ProofTiming(proofTimingRaw);

        // Create TransitionMeta with fuzzed values
        IInbox.TransitionMeta memory original = IInbox.TransitionMeta({
            blockHash: blockHash,
            stateRoot: stateRoot,
            prover: prover,
            proofTiming: proofTiming,
            createdAt: createdAt,
            byAssignedProver: byAssignedProver,
            lastBlockId: lastBlockId,
            provabilityBond: provabilityBond,
            livenessBond: livenessBond
        });

        bytes[122] memory packed = LibData.packTransitionMeta(original);
        IInbox.TransitionMeta memory unpacked = LibData.unpackTransitionMeta(packed);
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked)));
    }

    function test_packUnpackTransitionMeta_edgeCases() public pure {
        // Test edge case values
        IInbox.TransitionMeta memory original = IInbox.TransitionMeta({
            blockHash: 0x0000000000000000000000000000000000000000000000000000000000000001,
            stateRoot: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            prover: address(1),
            proofTiming: IInbox.ProofTiming.OutOfExtendedProvingWindow,
            createdAt: 1,
            byAssignedProver: false,
            lastBlockId: type(uint48).max - 1,
            provabilityBond: 1,
            livenessBond: type(uint96).max - 1
        });

        bytes[122] memory packed = LibData.packTransitionMeta(original);
        IInbox.TransitionMeta memory unpacked = LibData.unpackTransitionMeta(packed);
        assertEq(keccak256(abi.encode(original)), keccak256(abi.encode(unpacked)));
    }
}
