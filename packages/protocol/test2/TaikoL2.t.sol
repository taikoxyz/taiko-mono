// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoL2} from "../contracts/L2/TaikoL2.sol";

contract TaikoL2TestBase is Test {
    TaikoL2 public L2;

    function setUp() public {
        L2 = new TaikoL2();
        L2.init();
    }

    function testSAA() public {
        uint256 l1Height = 1000;
        bytes32 l1Hash = keccak256("l1Hash");
        bytes32 l1SignalRoot = keccak256("l1SignalRoot");

        for (uint i = 0; i < 5; i++) {
            vm.roll(block.number + 1);
            // L2.anchor(l1Height, l1Hash, l1SignalRoot);
        }
    }
}
