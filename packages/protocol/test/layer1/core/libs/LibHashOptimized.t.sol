// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";

contract LibHashOptimizedTest is Test {
    function testFuzz_hashCommitment_EqualsKeccakAbiEncode(
        bytes32 seed,
        uint8 transitionsLen
    )
        public
        pure
    {
        transitionsLen = uint8(bound(uint256(transitionsLen), 0, 32));

        IInbox.Transition[] memory transitions = new IInbox.Transition[](transitionsLen);
        for (uint256 i; i < transitionsLen; ++i) {
            transitions[i] = IInbox.Transition({
                designatedProver: _addr(seed, "designatedProver", i),
                timestamp: uint48(uint256(keccak256(abi.encode(seed, "timestamp", i)))),
                blockHash: keccak256(abi.encode(seed, "blockHash", i))
            });
        }

        IInbox.Commitment memory commitment = IInbox.Commitment({
            firstProposalId: uint48(uint256(keccak256(abi.encode(seed, "firstProposalId")))),
            firstProposalParentBlockHash: keccak256(abi.encode(seed, "parentBlockHash")),
            lastProposalHash: keccak256(abi.encode(seed, "lastProposalHash")),
            actualProver: _addr(seed, "actualProver", 0),
            endBlockNumber: uint48(uint256(keccak256(abi.encode(seed, "endBlockNumber")))),
            endStateRoot: keccak256(abi.encode(seed, "endStateRoot")),
            transitions: transitions
        });

        bytes32 expected = keccak256(abi.encode(commitment));
        bytes32 actual = LibHashOptimized.hashCommitment(commitment);
        assertEq(actual, expected, "hashCommitment mismatch");
    }

    function _addr(
        bytes32 seed,
        string memory label,
        uint256 index
    )
        private
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encode(seed, label, index)))));
    }
}
