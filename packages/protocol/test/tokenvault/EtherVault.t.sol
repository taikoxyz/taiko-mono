// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../TestBase.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { EtherVault } from "../../contracts/bridge/EtherVault.sol";

contract TestEtherVault is TestBase {
    AddressManager addressManager;
    EtherVault etherVault;

    function setUp() public {
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
        addressManager = new AddressManager();
        addressManager.init();
        etherVault = new EtherVault();
        vm.prank(Alice);
        etherVault.init(address(addressManager));
        addressManager.setAddress(block.chainid, "bridge", Alice);
    }

    function test_EtherVault_releaseEther_reverts_when_zero_address() public {
        vm.startPrank(Alice);
        _seedEtherVault();

        vm.expectRevert(EtherVault.VAULT_INVALID_RECIPIENT.selector);
        etherVault.releaseEther(address(0), 1 ether);
    }

    function test_EtherVault_releaseEther_releases_to_authorized_sender()
        public
    {
        vm.startPrank(Alice);
        _seedEtherVault();

        uint256 aliceBalanceBefore = Alice.balance;
        etherVault.releaseEther(Alice, 1 ether);
        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 1 ether);
        vm.stopPrank();
    }

    function test_EtherVault_releaseEther_releases_to_receipient_via_authorized_sender(
    )
        public
    {
        vm.startPrank(Alice);
        _seedEtherVault();

        uint256 bobBalanceBefore = Bob.balance;
        etherVault.releaseEther(Bob, 1 ether);
        uint256 bobBalanceAfter = Bob.balance;
        assertEq(bobBalanceAfter - bobBalanceBefore, 1 ether);
        vm.stopPrank();
    }

    function _seedEtherVault() private {
        vm.deal(address(etherVault), 100 ether);
    }
}
