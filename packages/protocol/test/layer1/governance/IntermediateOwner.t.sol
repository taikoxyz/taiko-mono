// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "src/layer1/governance/IntermediateOwner.sol";

contract DummyContract {
    function someFunction() public pure returns (string memory) {
        return "someFunction";
    }
}

contract TestIntermediateOwner is Test {
    IntermediateOwner internal intermediateOwner;
    address owner = address(0x123);
    address newOwner = address(0x456);
    address target = address(new DummyContract());
    bytes data = abi.encodeWithSignature("someFunction()");

    function setUp() public {
        intermediateOwner = new IntermediateOwner(owner);
    }

    function test_IntermediateOwner_InitialOwner() public view {
        assertEq(intermediateOwner.owner(), owner, "Owner should be set correctly");
    }

    function test_IntermediateOwner_TransferOwnership() public {
        vm.startPrank(owner);
        intermediateOwner.transferOwnership(newOwner);
        assertEq(intermediateOwner.owner(), newOwner, "Ownership should be transferred");
        vm.stopPrank();
    }

    function test_IntermediateOwner_TransferOwnershipToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IntermediateOwner.ZeroAddress.selector);
        intermediateOwner.transferOwnership(address(0));
        vm.stopPrank();
    }

    function test_IntermediateOwner_TransferOwnershipToSameAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IntermediateOwner.SameAddress.selector);
        intermediateOwner.transferOwnership(owner);
        vm.stopPrank();
    }

    function test_IntermediateOwner_ForwardCall() public {
        vm.startPrank(owner);
        (bool success,) = target.call(data);
        require(success);
        bytes memory result = intermediateOwner.forwardCall(target, data);
        assertEq(result, abi.encode("someFunction"), "Forwarded call should return correct data");
        vm.stopPrank();
    }

    function test_IntermediateOwner_ForwardCallNotOwner() public {
        vm.startPrank(newOwner);
        vm.expectRevert(IntermediateOwner.NotOwner.selector);
        intermediateOwner.forwardCall(target, data);
        vm.stopPrank();
    }

    function test_IntermediateOwner_ForwardCallToZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IntermediateOwner.InvalidTarget.selector);
        intermediateOwner.forwardCall(address(0), data);
    }

    function test_IntermediateOwner_ForwardCallToSameAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IntermediateOwner.InvalidTarget.selector);
        intermediateOwner.forwardCall(address(intermediateOwner), data);
    }

    function test_IntermediateOwner_ForwardCallToOwner() public {
        vm.startPrank(owner);
        vm.expectRevert(IntermediateOwner.InvalidTarget.selector);
        intermediateOwner.forwardCall(owner, data);
    }

    function test_IntermediateOwner_ForwardCallToContractWithoutCode() public {
        vm.startPrank(owner);
        vm.expectRevert(IntermediateOwner.InvalidTarget.selector);
        intermediateOwner.forwardCall(address(0x999), data);
    }
}
