// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LibAddress.h.sol";

contract TestLibAddress is CommonTest {
    EtherSenderContract bridge;
    CalldataReceiver calledContract;

    function setUpOnEthereum() internal override {
        bridge = new EtherSenderContract();
        vm.deal(address(bridge), 1 ether);

        calledContract = new CalldataReceiver();
    }

    function test_sendEther() public {
        uint256 balanceBefore = deployer.balance;
        bridge.sendEther((deployer), 0.5 ether, 2300, "");
        assertEq(deployer.balance, balanceBefore + 0.5 ether);

        // Cannot send to address(0)
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.sendEther(address(0), 0.5 ether, 2300, "");
    }

    function test_sendEther_with_calldata() public {
        bytes memory functionCalldata = abi.encodeCall(CalldataReceiver.returnSuccess, ());

        bool success = bridge.sendEther(address(calledContract), 0, 230_000, functionCalldata);

        assertEq(success, true);

        // No input argument so it will fall to the fallback.
        bytes memory wrongfunctionCalldata =
            abi.encodeWithSelector(IERC165Upgradeable.supportsInterface.selector, 10);
        success = bridge.sendEther(address(calledContract), 0, 230_000, wrongfunctionCalldata);

        assertEq(success, false);
    }

    function test_sendEtherAndVerify() public {
        uint256 balanceBefore = deployer.balance;
        bridge.sendEtherAndVerify(deployer, 0.5 ether, 2300);
        assertEq(deployer.balance, balanceBefore + 0.5 ether);

        // Send 0 ether is also possible
        bridge.sendEtherAndVerify(deployer, 0, 2300);

        // If sending fails, call reverts
        vm.expectRevert(LibAddress.ETH_TRANSFER_FAILED.selector);
        bridge.sendEtherAndVerify(address(calledContract), 0.1 ether, 2300);

        //Call sendEtherAndVerify without the gasLimit
        bridge.sendEtherAndVerify(deployer, 0.5 ether);
        assertEq(deployer.balance, balanceBefore + 1 ether);
    }

    function test_supportsInterface() public {
        bool doesSupport = bridge.supportsInterface(deployer, 0x10101010);

        assertEq(doesSupport, false);

        doesSupport = bridge.supportsInterface(address(bridge), 0x10101010);

        assertEq(doesSupport, false);

        doesSupport = bridge.supportsInterface(address(calledContract), 0x10101010);

        assertEq(doesSupport, true);
    }
}
