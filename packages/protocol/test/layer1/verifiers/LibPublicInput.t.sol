// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";

import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";

contract LibPublicInputTest is Test {
    function test_hashPublicInputs_ComputesExpectedHash() external pure {
        bytes32 aggregatedHash = bytes32(uint256(0x1234));
        address verifier = address(0xBEEF);
        address newInstance = address(0xCAFE);
        uint64 chainId = 167;

        bytes32 actual =
            LibPublicInput.hashPublicInputs(aggregatedHash, verifier, newInstance, chainId);
        bytes32 expected = EfficientHashLib.hash(
            bytes32("VERIFY_PROOF"),
            bytes32(uint256(chainId)),
            bytes32(uint256(uint160(verifier))),
            aggregatedHash,
            bytes32(uint256(uint160(newInstance)))
        );

        assertEq(actual, expected);
    }

    function test_hashPublicInputs_RevertWhen_AggregatedHashZero() external {
        vm.expectRevert(LibPublicInput.InvalidAggregatedProvingHash.selector);
        this._callHashPublicInputs(bytes32(0), address(this), address(0x1234), 167);
    }

    function _callHashPublicInputs(
        bytes32 aggregatedHash,
        address verifier,
        address newInstance,
        uint64 chainId
    )
        external
        pure
        returns (bytes32)
    {
        return LibPublicInput.hashPublicInputs(aggregatedHash, verifier, newInstance, chainId);
    }
}
