// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibCanonicalRLP } from "../../../../contracts/shared/slotchain/libs/LibCanonicalRLP.sol";
import { Test } from "forge-std/src/Test.sol";

contract CanonicalRlpHarness {
    function decode(
        bytes calldata _input,
        uint256 _maximumNestingDepth
    )
        external
        pure
        returns (
            bool isList_,
            uint256 rawOffset_,
            uint256 rawLength_,
            uint256 payloadOffset_,
            uint256 payloadLength_
        )
    {
        LibCanonicalRLP.Item memory item =
            LibCanonicalRLP.decodeSingleBounded(_input, 0, _input.length, _maximumNestingDepth);
        return (item.isList, item.rawOffset, item.rawLength, item.payloadOffset, item.payloadLength);
    }

    function readUint(bytes calldata _input) external pure returns (uint256 value_) {
        LibCanonicalRLP.Item memory item = LibCanonicalRLP.decodeSingle(_input, 0, _input.length);
        return LibCanonicalRLP.readUint(_input, item);
    }

    function readUint64(bytes calldata _input) external pure returns (uint64 value_) {
        LibCanonicalRLP.Item memory item = LibCanonicalRLP.decodeSingle(_input, 0, _input.length);
        return LibCanonicalRLP.readUint64(_input, item);
    }

    function readBytes32(bytes calldata _input) external pure returns (bytes32 value_) {
        LibCanonicalRLP.Item memory item = LibCanonicalRLP.decodeSingle(_input, 0, _input.length);
        return LibCanonicalRLP.readBytes32(_input, item);
    }
}

contract LibCanonicalRLPTest is Test {
    CanonicalRlpHarness private harness;

    function setUp() external {
        harness = new CanonicalRlpHarness();
    }

    function test_decodeSingle_AcceptsCanonicalBoundaryForms() external view {
        (bool isList,,, uint256 payloadOffset, uint256 payloadLength) = harness.decode(hex"00", 1);
        assertFalse(isList);
        assertEq(payloadOffset, 0);
        assertEq(payloadLength, 1);

        (isList,,,, payloadLength) = harness.decode(hex"80", 1);
        assertFalse(isList);
        assertEq(payloadLength, 0);

        bytes memory payload55 = new bytes(55);
        bytes memory short55 = bytes.concat(hex"b7", payload55);
        (isList,,,, payloadLength) = harness.decode(short55, 1);
        assertFalse(isList);
        assertEq(payloadLength, 55);

        bytes memory payload56 = new bytes(56);
        bytes memory long56 = bytes.concat(hex"b838", payload56);
        (isList,,,, payloadLength) = harness.decode(long56, 1);
        assertFalse(isList);
        assertEq(payloadLength, 56);

        (isList,,,, payloadLength) = harness.decode(hex"c0", 1);
        assertTrue(isList);
        assertEq(payloadLength, 0);

        bytes memory list56 = bytes.concat(hex"f838", payload56);
        (isList,,,, payloadLength) = harness.decode(list56, 1);
        assertTrue(isList);
        assertEq(payloadLength, 56);
    }

    function test_decodeSingle_RejectsAlternativeLengthFormsAndTrailingBytes() external {
        vm.expectRevert(LibCanonicalRLP.NonCanonicalRlp.selector);
        harness.decode(hex"8100", 1);

        vm.expectRevert(LibCanonicalRLP.NonCanonicalRlp.selector);
        harness.decode(hex"b80100", 1);

        vm.expectRevert(LibCanonicalRLP.NonCanonicalRlp.selector);
        harness.decode(
            hex"b900380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            1
        );

        vm.expectRevert(LibCanonicalRLP.NonCanonicalRlp.selector);
        harness.decode(hex"f80180", 1);

        vm.expectRevert(LibCanonicalRLP.TrailingRlpBytes.selector);
        harness.decode(hex"8080", 1);

        vm.expectRevert(LibCanonicalRLP.RlpOutOfBounds.selector);
        harness.decode(hex"b83800", 1);
    }

    function test_decodeSingle_RecursivelyChecksNestedContainersAndDepth() external {
        (bool isList,,,, uint256 payloadLength) = harness.decode(hex"c2c180", 2);
        assertTrue(isList);
        assertEq(payloadLength, 2);

        vm.expectRevert(LibCanonicalRLP.RlpNestingTooDeep.selector);
        harness.decode(hex"c2c180", 1);

        vm.expectRevert(LibCanonicalRLP.InvalidRlpNestingBound.selector);
        harness.decode(hex"c0", 0);

        (isList,,,, payloadLength) = harness.decode(hex"c0", 2048);
        assertTrue(isList);
        assertEq(payloadLength, 0);
        vm.expectRevert(LibCanonicalRLP.InvalidRlpNestingBound.selector);
        harness.decode(hex"c0", 2049);
    }

    function test_decodeSingle_RejectsItemAboveFrozen2048ByteBound() external {
        bytes memory oversized = new bytes(2049);
        vm.expectRevert(LibCanonicalRLP.RlpItemTooLarge.selector);
        harness.decode(oversized, 1);
    }

    function test_readUint_EnforcesMinimalUnsignedEncodingAndWidths() external {
        assertEq(harness.readUint(hex"80"), 0);
        assertEq(harness.readUint(hex"01"), 1);
        assertEq(harness.readUint(hex"820100"), 256);

        vm.expectRevert(LibCanonicalRLP.InvalidRlpInteger.selector);
        harness.readUint(hex"00");

        vm.expectRevert(LibCanonicalRLP.InvalidRlpInteger.selector);
        harness.readUint(bytes.concat(hex"a1", new bytes(33)));

        vm.expectRevert(LibCanonicalRLP.InvalidRlpUint64.selector);
        harness.readUint64(hex"89010000000000000000");
    }

    function test_readBytes32_RequiresExactByteString() external {
        bytes32 expected = keccak256("rlp-bytes32");
        assertEq(harness.readBytes32(bytes.concat(hex"a0", expected)), expected);

        vm.expectRevert(LibCanonicalRLP.InvalidRlpBytes32.selector);
        harness.readBytes32(bytes.concat(hex"9f", bytes31(expected)));

        vm.expectRevert(LibCanonicalRLP.InvalidRlpBytes32.selector);
        harness.readBytes32(hex"c0");
    }
}
