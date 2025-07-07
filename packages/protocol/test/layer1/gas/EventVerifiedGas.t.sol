// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./CompareGasTest.sol";

contract EventVerifiedGas is CompareGasTest {
    event   Verified1(uint48 batchId, uint48 blockId, bytes32 blockHash);
    event   Verified2(uint256 uint48_batchId__uint48_blockId, bytes32 blockHash);

    function emitVerified1() public {
        uint48 a = 1234;
        uint48 b = 5678;
        bytes32 c= 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        emit Verified1(a, b, c);
    }

    function emitVerified2() public {
        uint48 a = 1234;
        uint48 b = 5678;
         bytes32 c= 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        emit Verified2(a << 48 | b,c);
    }

    function test_EmitEventGas() external {
        measureGas("emitVerified1", emitVerified1, "emitVerified2", emitVerified2);
    }
}
