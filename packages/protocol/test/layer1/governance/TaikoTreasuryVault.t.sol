// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";
import "src/layer1/governance/TaikoTreasuryVault.sol";
import "test/mocks/TestERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AlwaysRevert {
    fallback() external payable {
        revert("Always fails");
    }
}

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
        vm.startPrank(owner);

        // First transfer tokens to the vault
        token.transfer(address(vault), initialBalance);
        assertEq(token.balanceOf(address(vault)), initialBalance, "Vault should have tokens");
        assertEq(token.balanceOf(owner), 0, "Owner should have no tokens left");

        // Now use vault to transfer tokens to recipient
        bytes memory data =
            abi.encodeWithSelector(token.transfer.selector, recipient, initialBalance);
        vault.forwardCall(address(token), 0, data);

        // Verify final balances
        assertEq(token.balanceOf(recipient), initialBalance, "Recipient should have all tokens");
        assertEq(token.balanceOf(address(vault)), 0, "Vault should have no tokens left");

        vm.stopPrank();
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

    function testNonOwnerCannotForwardCall() public {
        vm.startPrank(address(0x789)); // Not the owner

        bytes memory data = abi.encodeWithSelector(token.transfer.selector, recipient, 100);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.forwardCall(address(token), 0, data);

        vm.stopPrank();
    }

    function testForwardCallToSelfShouldRevert() public {
        vm.startPrank(owner);

        bytes memory dummyData = hex"00";
        vm.expectRevert(TaikoTreasuryVault.InvalidTarget.selector);
        vault.forwardCall(address(vault), 0, dummyData);

        vm.stopPrank();
    }

    function testForwardCallFailsOnError() public {
        AlwaysRevert target = new AlwaysRevert();

        vm.startPrank(owner);
        vm.expectRevert(TaikoTreasuryVault.CallFailed.selector);
        vault.forwardCall(address(target), 0, hex"");
        vm.stopPrank();
    }
}
