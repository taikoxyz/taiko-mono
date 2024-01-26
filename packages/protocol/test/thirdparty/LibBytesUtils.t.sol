// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../TaikoTest.sol";
import "../../contracts/thirdparty/LibBytesUtils.sol";

contract TestLibBytesUtils is TaikoTest {
    function testToBytes32() public {
        bytes memory byteArray = new bytes(32);
        for (uint256 i = 0; i < 32; i++) {
            byteArray[i] = bytes1(uint8(i + 1));
        }

        uint256 v = uint256(0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20);
        assertEq(LibBytesUtils.toBytes32(byteArray), bytes32(v));

        byteArray = new bytes(31);
        for (uint256 i = 0; i < 31; i++) {
            byteArray[i] = bytes1(uint8(i + 1));
        }

        v = uint256(0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20) >> 8;
        assertEq(LibBytesUtils.toBytes32(byteArray), bytes32(v));
    }
}
