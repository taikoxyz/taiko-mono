// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../TestBase.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { AddressResolver } from "../../contracts/common/AddressResolver.sol";
import { TaikoToken } from "../../contracts/L1/TaikoToken.sol";
import { TransparentUpgradeableProxy } from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TaikoTokenTest is TestBase {
    bytes32 GENESIS_BLOCK_HASH;

    address public tokenOwner;

    AddressManager public addressManager;
    TransparentUpgradeableProxy public tokenProxy;
    TaikoToken public tko;
    TaikoToken public tkoUpgradedImpl;

    function setUp() public {
        GENESIS_BLOCK_HASH = getRandomBytes32();

        tokenOwner = getRandomAddress();

        addressManager = new AddressManager();
        addressManager.init();
        tko = new TaikoToken();

        address[] memory premintRecipients = new address[](2);
        premintRecipients[0] = Yasmine;
        premintRecipients[1] = Zachary;

        uint256[] memory premintAmounts = new uint256[](2);
        premintAmounts[0] = 5 ether;
        premintAmounts[1] = 5 ether;

        tokenProxy = _deployViaProxy(
            address(tko),
            bytes.concat(
                tko.init.selector,
                abi.encode(
                    address(addressManager),
                    "Taiko Token",
                    "TKO",
                    premintRecipients,
                    premintAmounts
                )
            )
        );

        tko = TaikoToken(address(tokenProxy));
    }

    function test_TaikoToken_proper_premint() public {
        assertEq(tko.balanceOf(Yasmine), 5 ether);

        assertEq(tko.balanceOf(Zachary), 5 ether);
    }

    function test_TaikoToken_upgrade() public {
        tkoUpgradedImpl = new TaikoToken();

        vm.prank(tokenOwner);
        tokenProxy.upgradeTo(address(tkoUpgradedImpl));

        // Check if balance is still same
        assertEq(tko.balanceOf(Yasmine), 5 ether);
        assertEq(tko.balanceOf(Zachary), 5 ether);
    }

    function test_TaikoToken_upgrade_without_admin_rights() public {
        tkoUpgradedImpl = new TaikoToken();

        vm.expectRevert();
        tokenProxy.upgradeTo(address(tkoUpgradedImpl));
    }

    function _registerAddress(bytes32 nameHash, address addr) private {
        addressManager.setAddress(block.chainid, nameHash, addr);
    }

    function _deployViaProxy(
        address implementation,
        bytes memory data
    )
        private
        returns (TransparentUpgradeableProxy)
    {
        return new TransparentUpgradeableProxy(
            implementation,
            tokenOwner,
            data
        );
    }
}
