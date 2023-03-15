// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/L2/TaikoL2.sol";

contract ReadBlockhashVsCalldata is Test {
    TaikoL2 public L2;

    function setUp() public {
        L2 = new TaikoL2();
        console2.log("current block number in Setup", block.number);
        L2.init(address(1)); // Dummy address manager address.
    }

    function testAnchorTx() external {
        for (uint256 i = 0; i < 3; i++) {
            vm.roll(block.number + 1);
            L2.anchor(12345, keccak256("a"), keccak256("b"));
        }
    }
}
