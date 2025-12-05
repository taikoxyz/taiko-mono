// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "src/layer1/team/SimpleTokenUnlock.sol";
import "../../Layer1Test.sol";

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

contract TestSimpleTokenUnlock is Layer1Test {
    address private constant TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address private taikoL1 = randAddress();
    uint64 private grantTimestamp;

    SimpleTokenUnlock private target;
    MyERC20 private taikoToken;

    function setUpOnEthereum() internal override {
        MyERC20 tokenImpl = new MyERC20(Alice);
        taikoToken = MyERC20(TAIKO_TOKEN);

        vm.etch(TAIKO_TOKEN, address(tokenImpl).code);
        _primeTaikoTokenStorage();

        register("taiko_token", address(taikoToken));
        register("taiko", taikoL1);

        target = SimpleTokenUnlock(
            deploy({
                name: "simple_token_unlock",
                impl: address(new SimpleTokenUnlock(address(resolver))),
                data: abi.encodeCall(SimpleTokenUnlock.init, (Alice, Bob))
            })
        );
    }

    function setUp() public override {
        super.setUp();

        grantTimestamp = target.GRANT_TIMESTAMP();
        vm.warp(grantTimestamp);
        vm.prank(Alice);
        taikoToken.approve(address(target), 1_000_000_000 ether);
    }

    function _primeTaikoTokenStorage() private {
        uint256 totalSupply = 1_000_000_000 ether;
        // _balances[Alice] at slot 0: keccak256(abi.encode(key, slot))
        bytes32 balanceSlot = keccak256(abi.encode(Alice, uint256(0)));
        vm.store(TAIKO_TOKEN, balanceSlot, bytes32(totalSupply));
        // _totalSupply at slot 2
        vm.store(TAIKO_TOKEN, bytes32(uint256(2)), bytes32(totalSupply));
    }

    function test_simpletokenunlock_single_vest_withdrawal() public {
        vm.prank(Carol);
        vm.expectRevert(); //"revert: Ownable: caller is not the owner"
        target.grant(10 ether);

        vm.startPrank(Alice);
        target.grant(100 ether);
        taikoToken.transfer(address(target), 0.5 ether);
        vm.stopPrank();

        assertEq(taikoToken.balanceOf(address(target)), 100.5 ether);
        assertEq(target.amountGranted(), 100 ether);
        assertEq(target.amountWithdrawable(), 0.5 ether);

        vm.warp(grantTimestamp + target.SIX_MONTHS() - 1);
        assertEq(target.amountGranted(), 100 ether);
        assertEq(target.amountWithdrawable(), 0.5 ether);

        vm.warp(grantTimestamp + target.SIX_MONTHS());
        assertEq(target.amountGranted(), 100 ether);
        assertEq(target.amountWithdrawable(), 100.5 ether);

        vm.prank(Alice);
        taikoToken.transfer(address(target), 0.5 ether);
        assertEq(target.amountGranted(), 100 ether);
        assertEq(target.amountWithdrawable(), 101 ether);
    }

    function test_simpletokenunlock_precliff_withdrawal_attack() public {
        vm.startPrank(Alice);
        target.grant(100 ether);
        taikoToken.transfer(address(target), 0.5 ether);
        vm.stopPrank();

        uint256 amt = target.amountWithdrawable();
        vm.prank(Bob);
        target.withdraw(Bob, amt);

        assertEq(target.amountGranted(), 100 ether);
        assertEq(taikoToken.balanceOf(address(target)), 100 ether);

        vm.warp(grantTimestamp + target.SIX_MONTHS());
        amt = target.amountWithdrawable();
        vm.prank(Bob);
        target.withdraw(Bob, amt);
        assertEq(taikoToken.balanceOf(address(target)), 0 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(target.amountGranted(), 0 ether);
    }

    function test_simpletokenunlock_delegate() public {
        vm.prank(Alice);
        target.grant(100 ether);
        assertEq(target.amountGranted(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(taikoToken.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        target.delegate(Carol);

        assertEq(taikoToken.delegates(address(target)), Carol);
    }

    function test_simpletokenunlock_delegate_change_recipient() public {
        vm.prank(Alice);
        target.grant(100 ether);
        assertEq(target.amountGranted(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(taikoToken.balanceOf(address(target)), 100 ether);

        vm.startPrank(Bob);
        target.delegate(Carol);
        target.changeRecipient(David);
        vm.stopPrank();
        assertEq(target.recipient(), David);

        assertEq(taikoToken.delegates(address(target)), David);
    }
}
