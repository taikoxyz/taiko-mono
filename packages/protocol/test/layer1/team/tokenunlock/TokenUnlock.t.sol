// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "src/layer1/team/tokenunlock/TokenUnlock.sol";
import "test/shared/TaikoTest.sol";

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
    address public assignmentHook = vm.addr(0x1000);
    address public taikoL1 = vm.addr(0x2000);
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
        addressManager.setAddress(uint64(block.chainid), "assignment_hook", assignmentHook);
        addressManager.setAddress(uint64(block.chainid), "taiko", taikoL1);
        addressManager.setAddress(uint64(block.chainid), "prover_set", address(new ProverSet()));

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

        vm.startPrank(Alice);
        target.vest(100 ether);
        tko.transfer(address(target), 0.5 ether);
        vm.stopPrank();

        assertEq(tko.balanceOf(address(target)), 100.5 ether);
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
        tko.transfer(address(target), 0.5 ether);
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
        tko.transfer(address(target), 1000 ether);

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
        assertEq(tko.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
        target.withdraw(Bob, 1 ether);

        vm.prank(Alice);
        target.vest(200 ether);
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 300 ether);

        vm.warp(TGE + target.ONE_YEAR());
        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 75 ether);

        vm.prank(Bob);
        target.withdraw(Bob, 75 ether);
        assertEq(tko.balanceOf(address(target)), 225 ether);
        assertEq(tko.balanceOf(Bob), 75 ether);

        assertEq(target.amountVested(), 300 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 225 ether);

        vm.prank(Alice);
        target.vest(300 ether);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 75 ether);
        assertEq(tko.balanceOf(address(target)), 525 ether);

        vm.prank(Alice);
        tko.transfer(address(target), 1000 ether);

        vm.warp(TGE + target.ONE_YEAR() * 2);
        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 1225 ether);
        assertEq(tko.balanceOf(address(target)), 1525 ether);

        vm.prank(Bob);
        vm.expectRevert(TokenUnlock.NOT_WITHDRAWABLE.selector);
        target.withdraw(Carol, 1226 ether);

        vm.prank(Bob);
        target.withdraw(Carol, 225 ether);
        assertEq(tko.balanceOf(Carol), 225 ether);

        assertEq(target.amountVested(), 600 ether);
        assertEq(target.amountWithdrawable(), 1000 ether);
        assertEq(tko.balanceOf(address(target)), 1300 ether);

        vm.prank(Alice);
        target.vest(400 ether);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 1200 ether);
        assertEq(tko.balanceOf(address(target)), 1700 ether);

        vm.warp(TGE + target.ONE_YEAR() * 4);
        assertEq(target.amountVested(), 1000 ether);
        assertEq(target.amountWithdrawable(), 1700 ether);
        assertEq(tko.balanceOf(address(target)), 1700 ether);

        vm.prank(Bob);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        target.withdraw(address(0), 1 ether);

        vm.prank(Alice);
        tko.transfer(address(target), 300 ether);

        vm.warp(TGE + target.ONE_YEAR() * 5);

        vm.prank(Bob);
        target.withdraw(David, 2000 ether);
        assertEq(tko.balanceOf(David), 2000 ether);
        assertEq(tko.balanceOf(address(target)), 0 ether);

        vm.prank(Alice);
        tko.transfer(address(target), 1000 ether);
        assertEq(target.amountWithdrawable(), 1000 ether);

        vm.prank(Bob);
        target.withdraw(Emma, 1000 ether);
        assertEq(tko.balanceOf(Emma), 1000 ether);
        assertEq(tko.balanceOf(address(target)), 0 ether);
    }

    function test_tokenunlock_delegate() public {
        vm.prank(Alice);
        target.vest(100 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);
        assertEq(tko.balanceOf(address(target)), 100 ether);

        vm.prank(Bob);
        target.delegate(Carol);

        assertEq(tko.delegates(address(target)), Carol);
    }

    function test_tokenunlock_proverset() public {
        vm.startPrank(Alice);
        target.vest(100 ether);
        tko.transfer(address(target), 20 ether);
        vm.warp(TGE + target.ONE_YEAR() * 2);

        vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
        target.createProverSet();
        vm.stopPrank();

        vm.startPrank(Bob);
        vm.expectRevert(TokenUnlock.NOT_PROVER_SET.selector);
        target.depositToProverSet(vm.addr(0x1234), 1 ether);

        ProverSet set1 = ProverSet(payable(target.createProverSet()));
        assertEq(set1.owner(), target.owner());
        assertEq(set1.admin(), address(target));

        assertTrue(target.isProverSet(address(set1)));

        vm.expectRevert(); //  ERC20: transfer amount exceeds balance
        target.depositToProverSet(address(set1), 121 ether);

        target.depositToProverSet(address(set1), 120 ether);
        assertEq(tko.balanceOf(address(set1)), 120 ether);
        assertEq(tko.balanceOf(address(target)), 0 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 0 ether);

        vm.expectRevert(); //  ERC20: transfer amount exceeds balance
        set1.withdrawToAdmin(121 ether);

        set1.withdrawToAdmin(120 ether);
        assertEq(tko.balanceOf(address(set1)), 0 ether);
        assertEq(tko.balanceOf(address(target)), 120 ether);
        assertEq(target.amountVested(), 100 ether);
        assertEq(target.amountWithdrawable(), 70 ether);

        set1.enableProver(Carol, true);
        assertTrue(set1.isProver(Carol));

        // create another one
        target.createProverSet();

        vm.stopPrank();

        vm.prank(target.owner());
        vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
        set1.enableProver(David, true);

        vm.prank(David);
        vm.expectRevert(TokenUnlock.PERMISSION_DENIED.selector);
        set1.enableProver(Carol, true);
    }
}
