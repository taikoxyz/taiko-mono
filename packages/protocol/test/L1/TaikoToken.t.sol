// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../TestBase.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { AddressResolver } from "../../contracts/common/AddressResolver.sol";
import { TaikoToken } from "../../contracts/L1/TaikoToken.sol";
import { UUPSUpgradeable } from
    "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from
    "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TaikoTokenTest is TestBase {
    bytes32 GENESIS_BLOCK_HASH;

    address public tokenOwner;

    AddressManager public addressManager;
    ERC1967Proxy public tokenProxy;
    TaikoToken public tko;
    TaikoToken public tkoUpgradedImpl;

    function setUp() public {
        GENESIS_BLOCK_HASH = getRandomBytes32();

        tokenOwner = getRandomAddress();

        addressManager = new AddressManager();
        addressManager.init(msg.sender);
        tko = new TaikoToken();

        tokenProxy = new ERC1967Proxy(
            address(tko),
            bytes.concat(
                tko.init.selector,
                abi.encode(
                    tokenOwner,
                    address(addressManager), "Taiko Token", "TKO", address(this)
                )
            )
        );

        tko = TaikoToken(address(tokenProxy));
        tko.transfer(Yasmine, 5 ether);
        tko.transfer(Zachary, 5 ether);
    }

    function test_TaikoToken_upgrade() public {
        tkoUpgradedImpl = new TaikoToken();

        vm.prank(tokenOwner);
        UUPSUpgradeable(address(tokenProxy)).upgradeToAndCall(
            address(tkoUpgradedImpl), ""
        );

        // Check if balance is still same
        assertEq(tko.balanceOf(Yasmine), 5 ether);
        assertEq(tko.balanceOf(Zachary), 5 ether);
    }

    function test_TaikoToken_upgrade_without_admin_rights() public {
        tkoUpgradedImpl = new TaikoToken();

        vm.expectRevert();
        UUPSUpgradeable(address(tokenProxy)).upgradeToAndCall(
            address(tkoUpgradedImpl), ""
        );
    }

    function _registerAddress(bytes32 nameHash, address addr) private {
        addressManager.setAddress(uint64(block.chainid), nameHash, addr);
    }
}
