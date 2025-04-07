// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "src/layer1/governance/TaikoTreasuryVault.sol";
import "test/mocks/TestERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestTaikoTreasuryVault is Test {
    ERC1967Proxy proxy;
    TaikoTreasuryVault vault;
    TestERC20 token;
    address owner = address(0x123);
    address recipient = address(0x456);
    uint256 initialBalance = 1000 * 10 ** 18;

    function setUp() public {
        bytes memory initData = abi.encodeWithSelector(TaikoTreasuryVault.init.selector, owner);

        vault = TaikoTreasuryVault(
            payable(address(new ERC1967Proxy(address(new TaikoTreasuryVault()), initData)))
        );

        token = new TestERC20("TestERC20", "TestERC20");
        token.mint(owner, initialBalance);

        vm.deal(owner, 10 ether);
    }

    function testTreasuryVaultTransferERC20() public {
        uint256 transferAmount = initialBalance / 10;
        uint256 remainingBalance = initialBalance - transferAmount;

        // Forward call to transfer ERC20 tokens
        bytes memory data =
            abi.encodeWithSignature("transfer(address,uint256)", recipient, transferAmount);
        vm.prank(owner);
        vault.forwardCall(address(token), 0, data);

        // Check recipient balance
        assertEq(token.balanceOf(recipient), transferAmount);

        // Check vault balance
        assertEq(token.balanceOf(address(vault)), remainingBalance);
    }

    function testTreasuryVaultTransferEther() public {
        vm.startPrank(owner);

        // Send Ether to the vault
        (bool success,) = payable(address(vault)).call{ value: 1 ether }("");
        require(success, "Transfer failed");

        vault.forwardCall(recipient, 1 ether, "");

        assertEq(address(vault).balance, 0);
        assertEq(recipient.balance, 1 ether);
        vm.stopPrank();
    }
}
