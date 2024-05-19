// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "../../TaikoTest.sol";
import "../../../contracts/team/tokenunlock/TokenUnlock.sol";

contract MyERC20 is ERC20, ERC20Votes {
    constructor(address owner) ERC20("Taiko Token", "TKO") ERC20Permit("Taiko Token") {
        _mint(owner, 1_000_000_000 ether);
    }

    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }
}

contract TestTokenUnlock is TaikoTest {
    AddressManager private addressManager;
    uint64 private TGE = 1_000_000;

    TokenUnlock private target;
    MyERC20 tko = new MyERC20(Alice);

    function setUp() public {
        addressManager = AddressManager(
            deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: abi.encodeCall(AddressManager.init, (address(0)))
            })
        );

        addressManager.setAddress(uint64(block.chainid), "taiko_token", address(tko));

        vm.warp(TGE);

        target = TokenUnlock(
            deployProxy({
                name: "target",
                impl: address(new TokenUnlock()),
                data: abi.encodeCall(TokenUnlock.init, (Alice, address(addressManager), Bob, TGE))
            })
        );

        vm.prank(Alice);
        tko.approve(address(target), 1_000_000_000 ether);
    }

    function test_tokenunlock_single_vest_withdrawal() public {
        vm.prank(Carol);
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

    function test_tokenunlock_multiple_vest_withdrawal() public {
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

    function test_tokenunlock_multiple_vest_withdrawing() public {
        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
        target.withdraw(Bob);

        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
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
        target.withdraw(Carol);
        assertEq(tko.balanceOf(Carol), 225 ether);

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

    function test_tokenunlock_delegate() public {
        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountWithdrawn(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        target.delegate(Carol);

        assertEq(tko.delegates(address(target)), Carol);
    }
}
