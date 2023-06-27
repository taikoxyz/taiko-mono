// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import { BridgeErrors } from "../contracts/bridge/BridgeErrors.sol";

contract TestEtherVault is Test {
    AddressManager addressManager;
    EtherVault etherVault;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;

    function setUp() public {
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
        addressManager = new AddressManager();
        addressManager.init();
        etherVault = new EtherVault();
        vm.prank(Alice);
        etherVault.init(address(addressManager));
    }

    function test_authorize_reverts_when_not_owner_authorizing() public {
        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        etherVault.authorize(Bob, true);

        bool auth = etherVault.isAuthorized(Bob);
        assertEq(auth, false);
    }

    function test_authorize_authorizes_when_owner_authorizing() public {
        vm.prank(Alice);
        etherVault.authorize(Bob, true);

        bool auth = etherVault.isAuthorized(Bob);
        assertEq(auth, true);
    }

    function test_authorize_reverts_when_authorizing_zero_address() public {
        vm.prank(Alice);
        vm.expectRevert(BridgeErrors.B_EV_PARAM.selector);
        etherVault.authorize(address(0), true);
    }

    function test_authorize_reverts_when_authorizing_already_authorized_address(
    )
        public
    {
        vm.startPrank(Alice);
        etherVault.authorize(Bob, true);
        vm.expectRevert(BridgeErrors.B_EV_PARAM.selector);
        etherVault.authorize(Bob, true);
        bool auth = etherVault.isAuthorized(Bob);
        assertEq(auth, true);
        vm.stopPrank();
    }

    function test_receive_allows_sending_when_authorized_only() public {
        assertEq(address(etherVault).balance, 0);
        assertEq(Alice.balance > 0, true);
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
        (bool aliceSent,) = address(etherVault).call{ value: 1 }("");
        assertEq(aliceSent, true);
        assertEq(address(etherVault).balance, 1);

        vm.stopPrank();
        assertEq(Bob.balance > 0, true);
        vm.startPrank(Bob);

        (bool bobSent,) = address(etherVault).call{ value: 1 }("");
        assertEq(bobSent, false);
        vm.stopPrank();
    }

    function test_release_ether_reverts_when_zero_address() public {
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
        seedEtherVault();

        vm.expectRevert(BridgeErrors.B_EV_DO_NOT_BURN.selector);
        etherVault.releaseEther(address(0), 1 ether);
    }

    function test_release_ether_releases_to_authorized_sender() public {
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
        seedEtherVault();

        uint256 aliceBalanceBefore = Alice.balance;
        etherVault.releaseEther(1 ether);
        uint256 aliceBalanceAfter = Alice.balance;
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 1 ether);
        vm.stopPrank();
    }

    function test_release_ether_releases_to_receipient_via_authorized_sender()
        public
    {
        vm.startPrank(Alice);
        etherVault.authorize(Alice, true);
        seedEtherVault();

        uint256 bobBalanceBefore = Bob.balance;
        etherVault.releaseEther(Bob, 1 ether);
        uint256 bobBalanceAfter = Bob.balance;
        assertEq(bobBalanceAfter - bobBalanceBefore, 1 ether);
        vm.stopPrank();
    }

    function seedEtherVault() internal {
        vm.deal(address(etherVault), 100 ether);
    }
}
