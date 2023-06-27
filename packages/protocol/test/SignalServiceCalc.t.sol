// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { LibRLPWriter } from "../contracts/thirdparty/LibRLPWriter.sol";

contract TestSignalServiceCalc is Test {
    function setUp() public { }

    function testLibRLPWriterOne() public {
        assertEq(LibRLPWriter.writeBytes32(bytes32(uint256(1))), hex"01");
    }

    function testAbiEncodeBytes32(bytes32 seed) public {
        for (uint256 i = 0; i < 100; ++i) {
            seed = keccak256(abi.encodePacked(seed));
            bytes memory _seed = bytes.concat(seed);

            bytes memory encoded = abi.encodePacked(seed);
            assertEq(encoded.length, _seed.length);
            for (uint256 j = 0; j < encoded.length; ++j) {
                assertEq(encoded[j], _seed[j]);
            }
        }

        for (uint256 i = 0; i < 100; ++i) {
            seed = bytes32(i);
            bytes memory _seed = bytes.concat(seed);

            bytes memory encoded = abi.encodePacked(seed);
            assertEq(encoded.length, _seed.length);
            for (uint256 j = 0; j < encoded.length; ++j) {
                assertEq(encoded[j], _seed[j]);
            }
        }
    }
}
