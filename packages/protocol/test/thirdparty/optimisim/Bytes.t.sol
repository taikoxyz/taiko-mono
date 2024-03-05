// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";
import "../../../contracts/thirdparty/optimism/Bytes.sol";
/// @author Kirk Baird <kirk@sigmaprime.io>

contract TestBytes is TaikoTest {
    function test_toNibbles() external {
        // 20 Bytes input
        bytes memory someBytes = hex"0123456789012345678901234567890123456789";
        bytes memory nibbles = Bytes.toNibbles(someBytes);
        assertEq(
            hex"00010203040506070809000102030405060708090001020304050607080900010203040506070809",
            nibbles
        );

        // Empty bytes input
        bytes memory emptyBytes;
        nibbles = Bytes.toNibbles(emptyBytes);
        assertEq(nibbles, hex"");
    }

    // We test slice using case division based on different input sizes, starts and lengths
    function test_slice() external {
        // 1. 20 bytes input
        bytes memory someBytes = hex"0123456789012345678901234567890123456789";

        // 1.A. 0 length
        // 1.A.i. 0 start
        assertEq(Bytes.slice(someBytes, 0, 0), hex"");

        // 1.A.ii. partial start
        assertEq(Bytes.slice(someBytes, 7, 0), hex"");

        // 1.A.iii. end start
        assertEq(Bytes.slice(someBytes, someBytes.length, 0), hex"");

        // 1.B. full length
        // 1.B.i. 0 start
        assertEq(
            Bytes.slice(someBytes, 0, someBytes.length),
            hex"0123456789012345678901234567890123456789"
        );

        // 1.B.ii. partial start
        vm.expectRevert("slice_outOfBounds");
        Bytes.slice(someBytes, 7, someBytes.length);

        // 1.C. partial length
        // 1.C.i. 0 start
        assertEq(Bytes.slice(someBytes, 0, 9), hex"012345678901234567");

        // 1.C.ii. partial start
        assertEq(Bytes.slice(someBytes, 7, 9), hex"456789012345678901");

        // 1.C.iii. partial start, until exact end of input
        assertEq(Bytes.slice(someBytes, 11, 9), hex"234567890123456789");

        // 1.C.iv. end start
        vm.expectRevert("slice_outOfBounds");
        Bytes.slice(someBytes, someBytes.length, 9);

        // 2. 64 byte input
        someBytes =
            hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

        // 2.A. 0 length
        // 2.A.i. 0 start
        assertEq(Bytes.slice(someBytes, 0, 0), hex"");

        // 2.A.ii. partial start
        assertEq(Bytes.slice(someBytes, 7, 0), hex"");

        // 2.A.iii. end start
        assertEq(Bytes.slice(someBytes, someBytes.length, 0), hex"");

        // 2.B. full length
        // 2.B.i. 0 start
        assertEq(
            Bytes.slice(someBytes, 0, someBytes.length),
            hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        );

        // 2.B.ii. partial start
        vm.expectRevert("slice_outOfBounds");
        Bytes.slice(someBytes, 7, someBytes.length); // TODO Foundry bug

        // 2.C. partial length
        // 2.C.i. 0 start
        assertEq(Bytes.slice(someBytes, 0, 9), hex"0123456789abcdef01");

        // 2.C.ii. partial start
        assertEq(Bytes.slice(someBytes, 7, 9), hex"ef0123456789abcdef");

        // 2.C.iii. partial start, until exact end of input
        assertEq(Bytes.slice(someBytes, 55, 9), hex"ef0123456789abcdef");

        // 2.C.iv. end start
        vm.expectRevert("slice_outOfBounds");
        Bytes.slice(someBytes, someBytes.length, 9);

        // 3. 0 byte input
        someBytes = hex"";

        // 3.A. 0 start
        assertEq(Bytes.slice(someBytes, 0, 0), hex"");

        // 3.B. overflow start
        vm.expectRevert("slice_outOfBounds");
        Bytes.slice(someBytes, 1, 0);

        // 3.C. overflow length
        vm.expectRevert("slice_outOfBounds");
        Bytes.slice(someBytes, 0, 1);
    }

    function test_slice2() external {
        // 20 byte input
        bytes memory someBytes = hex"0123456789012345678901234567890123456789";

        assertEq(Bytes.slice(someBytes, 0), hex"0123456789012345678901234567890123456789");

        assertEq(Bytes.slice(someBytes, 10), hex"01234567890123456789");

        assertEq(Bytes.slice(someBytes, someBytes.length * 1000), hex""); //Doesnt revert if start
            // is out of bounds
    }
}
