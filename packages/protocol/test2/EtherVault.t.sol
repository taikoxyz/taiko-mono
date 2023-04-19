// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {AddressManager} from "../contracts/thirdparty/AddressManager.sol";
import {EtherVault} from "../contracts/bridge/EtherVault.sol";
import {BridgeErrors} from "../contracts/bridge/BridgeErrors.sol";

contract TestEtherVault is Test {
    AddressManager addressManager;
    EtherVault etherVault;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;

    function setUp() public {
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

    function test_authorize_reverts_when_authorizing_already_authorized_address()
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
}
