// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../TestBase.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { EtherVault } from "../../contracts/bridge/EtherVault.sol";
import { BridgeErrors } from "../../contracts/bridge/BridgeErrors.sol";

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
    }

    function test_EtherVault_authorize_revert() public {
        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        etherVault.authorize(Bob, true);

        vm.prank(Alice);
        vm.expectRevert(BridgeErrors.B_EV_PARAM.selector);
        etherVault.authorize(address(0), true);

        vm.startPrank(Alice);
        etherVault.authorize(Bob, true);
        vm.expectRevert(BridgeErrors.B_EV_PARAM.selector);
        etherVault.authorize(Bob, true);
        assertTrue(etherVault.isAuthorized(Bob));
    }

    function test_EtherVault_authorize_authorizes_when_owner_authorizing()
        public
    {
        vm.prank(Alice);
        etherVault.authorize(Bob, true);
        assertTrue(etherVault.isAuthorized(Bob));
    }

    function test_EtherVault_receive_allows_sending_when_authorized_only()
        public
    {
        assertEq(address(etherVault).balance, 0);
        assertEq(Alice.balance > 0, true);
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
        (bool aliceSent,) = address(etherVault).call{ value: 1 }("");
        assertTrue(aliceSent);
        assertEq(address(etherVault).balance, 1);

        vm.stopPrank();
        assertTrue(Bob.balance > 0);
        vm.startPrank(Bob);

        (bool bobSent,) = address(etherVault).call{ value: 1 }("");
        assertFalse(bobSent);
        vm.stopPrank();
    }

    function test_EtherVault_releaseEther_reverts_when_zero_address() public {
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
        _seedEtherVault();

        vm.expectRevert(BridgeErrors.B_EV_DO_NOT_BURN.selector);
        etherVault.releaseEther(address(0), 1 ether);
    }

    function test_EtherVault_releaseEther_releases_to_authorized_sender()
        public
    {
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
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
        etherVault.authorize(Alice, true);
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
