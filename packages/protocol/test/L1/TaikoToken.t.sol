// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TestBase } from "../TestBase.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { AddressResolver } from "../../contracts/common/AddressResolver.sol";
import { TaikoToken } from "../../contracts/L1/TaikoToken.sol";
import { TransparentUpgradeableProxy } from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TaikoTokenTest is TestBase {
    bytes32 GENESIS_BLOCK_HASH;

    address public tokenOwner;
    address public taikoL1;

    AddressManager public addressManager;
    TransparentUpgradeableProxy public tokenProxy;
    TaikoToken public tko;
    TaikoToken public tkoUpgradedImpl;

    function setUp() public {
        GENESIS_BLOCK_HASH = getRandomBytes32();

        tokenOwner = getRandomAddress();
        taikoL1 = getRandomAddress();

        addressManager = new AddressManager();
        addressManager.init();
        _registerAddress("taiko", taikoL1);

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

    function test_TaikoToken_mint() public {
        assertEq(tko.balanceOf(Emma), 0 ether);

        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);
    }

    function test_TaikoToken_mint_invalid_address() public {
        vm.prank(taikoL1);
        vm.expectRevert("ERC20: mint to the zero address");
        tko.mint(address(0), 1 ether);
    }

    function test_TaikoToken_mint_not_taiko_l1() public {
        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        tko.mint(Emma, 1 ether);
    }

    function test_TaikoToken_burn() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(taikoL1);
        tko.burn(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), 0);
    }

    function test_TaikoToken_burn_not_taiko_l1() public {
        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        tko.burn(address(0), 1 ether);
    }

    function test_TaikoToken_burn_amount_exceeded() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);
    }

    function test_TaikoToken_transfer() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        tko.transfer(David, amountToMint);

        assertEq(tko.balanceOf(Emma), 0);
        assertEq(tko.balanceOf(David), amountToMint);
    }

    function test_TaikoToken_transfer_invalid_address() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        vm.expectRevert("ERC20: transfer to the zero address");
        tko.transfer(address(0), amountToMint);
    }

    function test_TaikoToken_transfer_to_contract_address() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        vm.expectRevert(TaikoToken.TKO_INVALID_ADDR.selector);
        tko.transfer(address(tko), amountToMint);
    }

    function test_TaikoToken_transfer_amount_exceeded() public {
        uint256 amountToMint = 1 ether;
        uint256 amountToTransfer = 2 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        vm.expectRevert();
        tko.transfer(address(tko), amountToTransfer);
        assertEq(tko.balanceOf(Emma), amountToMint);
    }

    function test_TaikoToken_transferFrom() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        tko.approve(David, 1 ether);

        vm.prank(David);
        tko.transferFrom(Emma, David, amountToMint);

        assertEq(tko.balanceOf(Emma), 0);
        assertEq(tko.balanceOf(David), amountToMint);
    }

    function test_TaikoToken_transferFrom_to_is_invalid() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        tko.approve(David, 1 ether);

        vm.prank(David);
        vm.expectRevert("ERC20: transfer to the zero address");
        tko.transferFrom(Emma, address(0), amountToMint);
    }

    function test_TaikoToken_transferFrom_to_is_the_contract() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        tko.approve(David, 1 ether);

        vm.prank(David);
        vm.expectRevert(TaikoToken.TKO_INVALID_ADDR.selector);
        tko.transferFrom(Emma, address(tko), amountToMint);
    }

    function test_TaikoToken_transferFrom_from_is_invalid() public {
        uint256 amountToMint = 1 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        tko.approve(David, 1 ether);

        vm.prank(David);
        // transferFrom(address(0)) will always throw has no allowance
        vm.expectRevert("ERC20: insufficient allowance");
        tko.transferFrom(address(0), David, amountToMint);
    }

    function test_TaikoToken_transferFrom_amount_exceeded() public {
        uint256 amountToMint = 1 ether;
        uint256 amountToTransfer = 2 ether;
        vm.prank(taikoL1);
        tko.mint(Emma, amountToMint);
        assertEq(tko.balanceOf(Emma), amountToMint);

        vm.prank(Emma);
        vm.expectRevert();
        tko.transfer(address(tko), amountToTransfer);
        assertEq(tko.balanceOf(Emma), amountToMint);
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
