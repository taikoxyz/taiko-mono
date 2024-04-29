// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Test.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../contracts/TokenUnlocking.sol";

contract MyERC20 is ERC20 {
    constructor(address owner) ERC20("Taiko Token", "TKO") {
        _mint(owner, 1_000_000_000 ether);
    }
}

contract TestTokenUnlocking is Test {
    address private Alice = vm.addr(0x1);
    address private Bob = vm.addr(0x2);
    address private Cindy = vm.addr(0x3);
    uint64 private TGE = 1_000_000;

    TokenUnlocking private target;
    ERC20 tko = new MyERC20(Alice);

    function setUp() public {
        vm.warp(TGE);

        target = TokenUnlocking(
            _deployProxy({
                impl: address(new TokenUnlocking()),
                data: abi.encodeCall(TokenUnlocking.init, (Alice, address(tko), Bob, TGE))
            })
        );

        vm.prank(Alice);
        tko.approve(address(target), 1_000_000_000 ether);
    }

    function test_single_vest_withdrawal() public {
        vm.prank(Cindy);
        vm.expectRevert(); //"revert: Ownable: caller is not the owner"
        target.vest(10 ether);

        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() - 1);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 25 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 50 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() * 3);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 75 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 100 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4 + 1);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 100 ether);
        assertEq(target.amountWithdrawn(), 0 ether);
    }

    function test_multiple_vest_withdrawal() public {
        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.prank(Alice);
        target.vest(200 ether);
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 75 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.prank(Alice);
        target.vest(300 ether);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 150 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 300 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.prank(Alice);
        target.vest(400 ether);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 500 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 1000 ether);
        assertEq(target.amountWithdrawn(), 0 ether);
    }

    function test_multiple_vest_withdrawing() public {
        vm.prank(Bob);
        vm.expectRevert(TokenUnlocking.NOT_WITHDRAWABLE.selector);
        target.withdraw(Bob);

        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        vm.expectRevert(TokenUnlocking.NOT_WITHDRAWABLE.selector);
        target.withdraw(Bob);

        vm.prank(Alice);
        target.vest(200 ether);
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 300 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 75 ether);
        assertEq(target.amountWithdrawn(), 0 ether);

        vm.prank(Bob);
        target.withdraw(Bob);
        assertEq(tko.balanceOf(address(target)), 225 ether);
        assertEq(tko.balanceOf(Bob), 75 ether);

        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 75 ether);
        assertEq(tko.balanceOf(address(target)), 225 ether);

        vm.prank(Alice);
        target.vest(300 ether);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 75 ether);
        assertEq(target.amountWithdrawn(), 75 ether);
        assertEq(tko.balanceOf(address(target)), 525 ether);

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 225 ether);
        assertEq(target.amountWithdrawn(), 75 ether);
        assertEq(tko.balanceOf(address(target)), 525 ether);

        vm.prank(Bob);
        target.withdraw(Cindy);
        assertEq(tko.balanceOf(Cindy), 225 ether);

        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 300 ether);
        assertEq(tko.balanceOf(address(target)), 300 ether);

        vm.prank(Alice);
        target.vest(400 ether);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 200 ether);
        assertEq(target.amountWithdrawn(), 300 ether);
        assertEq(tko.balanceOf(address(target)), 700 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 700 ether);
        assertEq(target.amountWithdrawn(), 300 ether);
        assertEq(tko.balanceOf(address(target)), 700 ether);

        vm.prank(Bob);
        target.withdraw(address(0));
        assertEq(tko.balanceOf(Bob), 775 ether);

        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 1000 ether);
        assertEq(tko.balanceOf(address(target)), 0 ether);
    }

    function _deployProxy(address impl, bytes memory data) private returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
