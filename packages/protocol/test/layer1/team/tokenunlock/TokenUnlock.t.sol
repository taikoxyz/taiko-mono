// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "src/layer1/team/TokenUnlock.sol";
import "test/shared/CommonTest.sol";

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

contract MockProverSet is IProverSetInitializer {
    address public owner;
    address public admin;

    function init(address _owner, address _admin) external override {
        owner = _owner;
        admin = _admin;
    }
}

contract TestTokenUnlock is CommonTest {
    uint64 private constant TGE = 1_000_000;

    address private taikoL1 = randAddress();

    TokenUnlock private target;
    MyERC20 private taikoToken;

    function setUpOnEthereum() internal override {
        taikoToken = new MyERC20(Alice);

        address proverSetImpl = address(new MockProverSet());

        target = TokenUnlock(
            deploy({
                name: "token_unlock",
                impl: address(new TokenUnlock(address(taikoToken), proverSetImpl)),
                data: abi.encodeCall(TokenUnlock.init, (Alice, Bob, TGE))
            })
        );
    }

    function setUp() public override {
        super.setUp();

        vm.warp(TGE);
        vm.prank(Alice);
        taikoToken.approve(address(target), 1_000_000_000 ether);
    }

    function test_tokenunlock_single_vest_withdrawal() public {
        vm.prank(Carol);
        vm.expectRevert(); //"revert: Ownable: caller is not the owner"
        target.vest(10 ether);

        vm.startPrank(Alice);
        target.vest(100 ether);
        require(taikoToken.transfer(address(target), 0.5 ether), "Transfer failed");
        vm.stopPrank();

        assertEq(taikoToken.balanceOf(address(target)), 100.5 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0.5 ether);

        vm.warp(TGE + target.ONE_YEAR() - 1);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0.5 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 25.5 ether);

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 50.5 ether);

        vm.warp(TGE + target.ONE_YEAR() * 3);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 75.5 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 100.5 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4 + 1);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 100.5 ether);

        vm.prank(Alice);
        require(taikoToken.transfer(address(target), 0.5 ether), "Transfer failed");
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 101 ether);
    }

    function test_tokenunlock_multiple_vest_withdrawal() public {
        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);

        vm.prank(Alice);
        target.vest(200 ether);
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 75 ether);

        vm.prank(Alice);
        target.vest(300 ether);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 150 ether);

        vm.prank(Alice);
        require(taikoToken.transfer(address(target), 1000 ether), "Transfer failed");

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 1300 ether);

        vm.prank(Alice);
        target.vest(400 ether);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 1500 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 2000 ether);
    }

    function test_tokenunlock_multiple_vest_withdrawing() public {
        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
        target.withdraw(Bob, 1 ether);

        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(taikoToken.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
        target.withdraw(Bob, 1 ether);

        vm.prank(Alice);
        target.vest(200 ether);
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(taikoToken.balanceOf(address(target)), 300 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 75 ether);

        vm.prank(Bob);
        target.withdraw(Bob, 75 ether);
        assertEq(taikoToken.balanceOf(address(target)), 225 ether);
        assertEq(taikoToken.balanceOf(Bob), 75 ether);

        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(taikoToken.balanceOf(address(target)), 225 ether);

        vm.prank(Alice);
        target.vest(300 ether);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 75 ether);
        assertEq(taikoToken.balanceOf(address(target)), 525 ether);

        vm.prank(Alice);
        require(taikoToken.transfer(address(target), 1000 ether), "Transfer failed");

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 1225 ether);
        assertEq(taikoToken.balanceOf(address(target)), 1525 ether);

        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
        target.withdraw(Carol, 1226 ether);

        vm.prank(Bob);
        target.withdraw(Carol, 225 ether);
        assertEq(taikoToken.balanceOf(Carol), 225 ether);

        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 1000 ether);
        assertEq(taikoToken.balanceOf(address(target)), 1300 ether);

        vm.prank(Alice);
        target.vest(400 ether);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 1200 ether);
        assertEq(taikoToken.balanceOf(address(target)), 1700 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 1700 ether);
        assertEq(taikoToken.balanceOf(address(target)), 1700 ether);

        vm.prank(Bob);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        target.withdraw(address(0), 1 ether);

        vm.prank(Alice);
        require(taikoToken.transfer(address(target), 300 ether), "Transfer failed");

        vm.warp(TGE + target.ONE_YEAR() * 5);

        vm.prank(Bob);
        target.withdraw(David, 2000 ether);
        assertEq(taikoToken.balanceOf(David), 2000 ether);
        assertEq(taikoToken.balanceOf(address(target)), 0 ether);

        vm.prank(Alice);
        require(taikoToken.transfer(address(target), 1000 ether), "Transfer failed");
        assertEq(target.amountWithdrawable(), 1000 ether);

        vm.prank(Bob);
        target.withdraw(Emma, 1000 ether);
        assertEq(taikoToken.balanceOf(Emma), 1000 ether);
        assertEq(taikoToken.balanceOf(address(target)), 0 ether);
    }

    function test_tokenunlock_delegate() public {
        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(taikoToken.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        target.delegate(Carol);

        assertEq(taikoToken.delegates(address(target)), Carol);
    }
}
