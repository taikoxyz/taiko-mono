// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TestBridge2Base.sol";
import "src/shared/bridge/IEthMinter.sol";

contract TestBridge2_ethMinter is TestBridge2Base {
    function test_bridge2_setEthMinter_reverts_when_not_owner() public {
        vm.prank(Alice);
        vm.expectRevert("Ownable: caller is not the owner");
        eBridge.setEthMinter(Alice, true);
    }

    function test_bridge2_setEthMinter_reverts_on_zero_address() public {
        vm.prank(deployer);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        eBridge.setEthMinter(address(0), true);
    }

    function test_bridge2_setEthMinter_updates_state_and_emits() public {
        assertEq(eBridge.isEthMinter(Alice), false);

        vm.expectEmit(address(eBridge));
        emit Bridge.EthMinterSet(Alice, true);
        vm.prank(deployer);
        eBridge.setEthMinter(Alice, true);

        assertEq(eBridge.isEthMinter(Alice), true);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(deployer);
        eBridge.setEthMinter(Alice, true);

        vm.expectEmit(address(eBridge));
        emit Bridge.EthMinterSet(Alice, false);
        vm.prank(deployer);
        eBridge.setEthMinter(Alice, false);

        assertEq(eBridge.isEthMinter(Alice), false);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        vm.prank(deployer);
        eBridge.setEthMinter(Alice, false);
    }

    function test_bridge2_mintEth_reverts_for_invalid_recipient() public {
        vm.prank(deployer);
        eBridge.setEthMinter(Alice, true);

        vm.startPrank(Alice);

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        eBridge.mintEth(address(0), 1 ether);

        vm.expectRevert(Bridge.INVALID_MINT_RECIPIENT.selector);
        eBridge.mintEth(address(eBridge), 1 ether);

        vm.stopPrank();
    }

    function test_bridge2_mintEth_reverts_for_non_minter() public {
        vm.prank(Bob);
        vm.expectRevert(Bridge.B_INVALID_ETH_MINTER.selector);
        eBridge.mintEth(Alice, 1 ether);
    }

    function test_bridge2_mintEth_transfers_and_emits() public assertSameTotalBalance {
        uint256 amount = 2 ether;
        vm.prank(deployer);
        eBridge.setEthMinter(Alice, true);

        uint256 bridgeBalance = address(eBridge).balance;
        uint256 bobBalance = Bob.balance;

        vm.expectEmit(address(eBridge));
        emit IEthMinter.EthMinted(Bob, amount);

        vm.prank(Alice);
        eBridge.mintEth(Bob, amount);

        assertEq(address(eBridge).balance, bridgeBalance - amount);
        assertEq(Bob.balance, bobBalance + amount);
    }
}
