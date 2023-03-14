// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoL1} from "../contracts/L2/TaikoL2.sol";

contract TaikoL2TestBase is Test {
    TaikoL2 public L2;

    function setUp() public {
        L2 = new TaikoL2();
        L2.init();
    }

    function testSAA() public {}
}
