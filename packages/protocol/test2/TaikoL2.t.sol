// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/L2/TaikoL2.sol";

contract ReadBlockhashVsCalldata is Test {
    TaikoL2 public L2;

    function setUp() public {
        L2 = new TaikoL2();
        L2.init(address(1)); // Dummy address manager address.
        vm.roll(block.number + 1);
    }

    function testAnchorTx() external {
        for (uint256 i = 0; i < 1000; i++) {
            L2.anchor(12345, keccak256("a"), keccak256("b"));
            vm.roll(block.number + 1);
        }
    }
}
