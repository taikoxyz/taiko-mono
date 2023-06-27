// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { AddressResolver } from "../contracts/common/AddressResolver.sol";
import { TaikoErrors } from "../contracts/L1/TaikoErrors.sol";
import { TaikoToken } from "../contracts/L1/TaikoToken.sol";

import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TaikoTokenTest is Test {
    AddressManager public addressManager;
    TransparentUpgradeableProxy public tokenProxy;
    TaikoToken public tko;
    TaikoToken public tkoUpgradedImpl;

    bytes32 public constant GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");

    address public constant tokenAdmin =
        0x200C9b60e19634E12FC6D68B7FeA7Bfb26c2e418;
    address public constant protoBroker =
        0x300C9b60E19634e12FC6D68B7FEa7bFB26c2E419;
    address public constant TeamWallet =
        0x300C9b60E19634e12FC6D68B7FEa7bFB26c2E419;
    address public constant DaoTreasury =
        0x400147C0Eb43D8D71b2B03037bB7B31f8f78EF5F;
    address public constant Eve = 0x50081b12838240B1bA02b3177153Bca678a86078;
    address public constant Dave = 0x50081b12838240B1ba02b3177153bCA678a86079;

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();
        registerAddress("proto_broker", protoBroker);

        tko = new TaikoToken();

        address[] memory premintRecipients = new address[](2);
        premintRecipients[0] = TeamWallet;
        premintRecipients[1] = DaoTreasury;

        uint256[] memory premintAmounts = new uint256[](2);
        premintAmounts[0] = 5 ether;
        premintAmounts[1] = 5 ether;

        tokenProxy = deployViaProxy(
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

    function test_proper_premint() public {
        assertEq(tko.balanceOf(TeamWallet), 5 ether);

        assertEq(tko.balanceOf(DaoTreasury), 5 ether);
    }

    function test_upgrade() public {
        tkoUpgradedImpl = new TaikoToken();

        vm.prank(tokenAdmin);
        tokenProxy.upgradeTo(address(tkoUpgradedImpl));

        // Check if balance is still same
        assertEq(tko.balanceOf(TeamWallet), 5 ether);
        assertEq(tko.balanceOf(DaoTreasury), 5 ether);
    }

    function test_upgrade_without_admin_rights() public {
        tkoUpgradedImpl = new TaikoToken();

        vm.expectRevert();
        tokenProxy.upgradeTo(address(tkoUpgradedImpl));
    }

    function test_mint() public {
        assertEq(tko.balanceOf(Eve), 0 ether);

        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);
    }

    function test_mint_invalid_amount() public {
        vm.prank(protoBroker);
        vm.expectRevert(TaikoToken.TKO_MINT_DISALLOWED.selector);
        tko.mint(Eve, 1000 ether);
    }

    function test_mint_invalid_address() public {
        vm.prank(protoBroker);
        vm.expectRevert("ERC20: mint to the zero address");
        tko.mint(address(0), 1 ether);
    }

    function test_mint_not_proto_broker() public {
        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        tko.mint(Eve, 1 ether);
    }

    function test_burn() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(protoBroker);
        tko.burn(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), 0);
    }

    function test_burn_invalid_address() public {
        vm.prank(protoBroker);
        vm.expectRevert("ERC20: burn from the zero address");
        tko.burn(address(0), 1 ether);
    }

    function test_burn_not_proto_broker() public {
        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        tko.burn(address(0), 1 ether);
    }

    function test_burn_amount_exceeded() public {
        uint256 amountToMint = 1 ether;
        uint256 amountToBurn = 2 ether;

        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(protoBroker);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        tko.burn(Eve, amountToBurn);
        assertEq(tko.balanceOf(Eve), amountToMint);
    }

    function test_transfer() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        tko.transfer(Dave, amountToMint);

        assertEq(tko.balanceOf(Eve), 0);
        assertEq(tko.balanceOf(Dave), amountToMint);
    }

    function test_transfer_invalid_address() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        vm.expectRevert("ERC20: transfer to the zero address");
        tko.transfer(address(0), amountToMint);
    }

    function test_transfer_to_contract_address() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        vm.expectRevert(TaikoToken.TKO_INVALID_ADDR.selector);
        tko.transfer(address(tko), amountToMint);
    }

    function test_transfer_amount_exceeded() public {
        uint256 amountToMint = 1 ether;
        uint256 amountToTransfer = 2 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        vm.expectRevert();
        tko.transfer(address(tko), amountToTransfer);
        assertEq(tko.balanceOf(Eve), amountToMint);
    }

    function test_transferFrom() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        tko.approve(Dave, 1 ether);

        vm.prank(Dave);
        tko.transferFrom(Eve, Dave, amountToMint);

        assertEq(tko.balanceOf(Eve), 0);
        assertEq(tko.balanceOf(Dave), amountToMint);
    }

    function test_transferFrom_to_is_invalid() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        tko.approve(Dave, 1 ether);

        vm.prank(Dave);
        vm.expectRevert("ERC20: transfer to the zero address");
        tko.transferFrom(Eve, address(0), amountToMint);
    }

    function test_transferFrom_to_is_the_contract() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        tko.approve(Dave, 1 ether);

        vm.prank(Dave);
        vm.expectRevert(TaikoToken.TKO_INVALID_ADDR.selector);
        tko.transferFrom(Eve, address(tko), amountToMint);
    }

    function test_transferFrom_from_is_invalid() public {
        uint256 amountToMint = 1 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        tko.approve(Dave, 1 ether);

        vm.prank(Dave);
        // transferFrom(address(0)) will always throw has no allowance
        vm.expectRevert("ERC20: insufficient allowance");
        tko.transferFrom(address(0), Dave, amountToMint);
    }

    function test_transferFrom_amount_exceeded() public {
        uint256 amountToMint = 1 ether;
        uint256 amountToTransfer = 2 ether;
        vm.prank(protoBroker);
        tko.mint(Eve, amountToMint);
        assertEq(tko.balanceOf(Eve), amountToMint);

        vm.prank(Eve);
        vm.expectRevert();
        tko.transfer(address(tko), amountToTransfer);
        assertEq(tko.balanceOf(Eve), amountToMint);
    }

    function registerAddress(bytes32 nameHash, address addr) internal {
        addressManager.setAddress(block.chainid, nameHash, addr);
    }

    function deployViaProxy(
        address implementation,
        bytes memory data
    )
        internal
        returns (TransparentUpgradeableProxy proxy)
    {
        proxy = new TransparentUpgradeableProxy(
            implementation,
            tokenAdmin,
            data
        );
    }
}
