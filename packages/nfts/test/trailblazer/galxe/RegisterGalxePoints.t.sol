// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { RegisterGalxePoints } from "../../../contracts/trailblazer/galxe/RegisterGalxePoints.sol";

contract RegisterGalxePointsTest is Test {
    RegisterGalxePoints public registerGalxePoints;

    address public owner = vm.addr(0x1);

    function setUp() public {
        // create whitelist merkle tree
        vm.startBroadcast(owner);

        registerGalxePoints = new RegisterGalxePoints();

        vm.stopBroadcast();
    }
    // Test register function on RegisterGalxePoints also test for Registered event emitted

    function testRegister() public {
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit RegisterGalxePoints.Registered(owner);
        registerGalxePoints.register();

        vm.stopPrank();
    }

    // Test case to check if already registered user is not allowed to register again
    function testCannotRegisterTwice() public {
        vm.startPrank(owner);
        registerGalxePoints.register();
        vm.expectRevert("Address already registered");
        registerGalxePoints.register();
        vm.stopPrank();
    }
}
