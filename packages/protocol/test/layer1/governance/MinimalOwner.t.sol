// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/governance/MinimalOwner.sol";

contract DummyContract {
    function someFunction() public pure returns (string memory) {
        return "someFunction";
    }
}

contract TestMinimalOwner is Test {
    MinimalOwner minimalOwner;
    address owner = address(0x123);
    address newOwner = address(0x456);
    address target = address(new DummyContract());
    bytes data = abi.encodeWithSignature("someFunction()");

    function setUp() public {
        minimalOwner = new MinimalOwner(owner);
    }

    function test_minimalOwner_InitialOwner() public view {
        assertEq(minimalOwner.owner(), owner, "Owner should be set correctly");
    }

    function test_minimalOwner_TransferOwnership() public {
        vm.startPrank(owner);
        minimalOwner.transferOwnership(newOwner);
        assertEq(minimalOwner.owner(), newOwner, "Ownership should be transferred");
        vm.stopPrank();
    }

    function test_minimalOwner_TransferOwnershipToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(MinimalOwner.ZeroAddress.selector);
        minimalOwner.transferOwnership(address(0));
        vm.stopPrank();
    }

    function test_minimalOwner_TransferOwnershipToSameAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(MinimalOwner.SameAddress.selector);
        minimalOwner.transferOwnership(owner);
        vm.stopPrank();
    }

    function test_minimalOwner_ForwardCall() public {
        vm.startPrank(owner);
        (bool success,) = target.call(data);
        require(success);
        bytes memory result = minimalOwner.forwardCall(target, data);
        assertEq(result, abi.encode("someFunction"), "Forwarded call should return correct data");
        vm.stopPrank();
    }

    function test_minimalOwner_ForwardCallNotOwner() public {
        vm.startPrank(newOwner);
        vm.expectRevert(MinimalOwner.NotOwner.selector);
        minimalOwner.forwardCall(target, data);
        vm.stopPrank();
    }

    function test_minimalOwner_ForwardCallToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(MinimalOwner.InvalidTarget.selector);
        minimalOwner.forwardCall(address(0), data);
    }

    function test_minimalOwner_ForwardCallToSameAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(MinimalOwner.InvalidTarget.selector);
        minimalOwner.forwardCall(address(minimalOwner), data);
    }

    function test_minimalOwner_ForwardCallToOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(MinimalOwner.InvalidTarget.selector);
        minimalOwner.forwardCall(owner, data);
    }

    function test_minimalOwner_ForwardCallToContractWithoutCode() public {
        vm.startPrank(owner);
        vm.expectRevert(MinimalOwner.InvalidTarget.selector);
        minimalOwner.forwardCall(address(0x999), data);
    }
}
