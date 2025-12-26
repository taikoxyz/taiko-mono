// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/src/Test.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { LibBonds } from "src/layer1/core/libs/LibBonds.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

contract LibBondsHarness {
    using LibBonds for LibBonds.Storage;

    LibBonds.Storage private _bonds;
    IERC20 public immutable bondToken;

    constructor(IERC20 _bondToken) {
        bondToken = _bondToken;
    }

    function credit(address _account, uint256 _amount) external {
        _bonds.creditBond(_account, _amount);
    }

    function creditSameAmount(
        address[] memory _accounts,
        uint256 _amountPerOccurrence
    )
        external
    {
        _bonds.creditBondsSameAmount(_accounts, _amountPerOccurrence);
    }

    function debit(address _account, uint256 _amount) external {
        _bonds.debitBond(_account, _amount);
    }

    function deposit(address _depositor, address _recipient, uint256 _amount) external {
        LibBonds.deposit(_bonds, bondToken, _depositor, _recipient, _amount);
    }

    function withdraw(address _from, address _to, uint256 _amount) external {
        LibBonds.withdraw(_bonds, bondToken, _from, _to, _amount);
    }

    function processLivenessBond(
        uint256 _livenessBond,
        address _payer,
        address _payee,
        address _caller
    )
        external
        returns (uint256 debitedAmount_)
    {
        return LibBonds.processLivenessBond(_bonds, _livenessBond, _payer, _payee, _caller);
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _bonds.getBondBalance(_account);
    }
}

contract LibBondsTest is Test {
    TestERC20 private _token;
    LibBondsHarness private _harness;

    address private _alice = address(0xA11CE);
    address private _bob = address(0xB0B);
    address private _carol = address(0xCA11);

    function setUp() public {
        _token = new TestERC20("Bond Token", "BOND");
        _harness = new LibBondsHarness(IERC20(address(_token)));
    }

    function test_creditBond_increasesBalance() public {
        _harness.credit(_alice, 25);
        assertEq(_harness.balanceOf(_alice), 25, "balance");
    }

    function test_debitBond_revertsOnInsufficientBalance() public {
        vm.expectRevert(LibBonds.InsufficientBondBalance.selector);
        _harness.debit(_alice, 1);
    }

    function test_debitBond_decreasesBalance() public {
        _harness.credit(_alice, 20);
        _harness.debit(_alice, 7);
        assertEq(_harness.balanceOf(_alice), 13, "balance");
    }

    function test_creditBondsSameAmount_aggregatesNonConsecutive() public {
        address[] memory accounts = new address[](6);
        accounts[0] = _alice;
        accounts[1] = _bob;
        accounts[2] = _alice;
        accounts[3] = _carol;
        accounts[4] = _alice;
        accounts[5] = _bob;

        _harness.creditSameAmount(accounts, 3);

        assertEq(_harness.balanceOf(_alice), 9, "alice balance");
        assertEq(_harness.balanceOf(_bob), 6, "bob balance");
        assertEq(_harness.balanceOf(_carol), 3, "carol balance");
    }

    function test_creditBondsSameAmount_noopOnEmptyList() public {
        _harness.credit(_alice, 5);
        address[] memory accounts = new address[](0);
        _harness.creditSameAmount(accounts, 7);
        assertEq(_harness.balanceOf(_alice), 5, "balance");
    }

    function test_creditBondsSameAmount_noopOnZeroAmount() public {
        _harness.credit(_alice, 5);
        address[] memory accounts = new address[](2);
        accounts[0] = _alice;
        accounts[1] = _bob;
        _harness.creditSameAmount(accounts, 0);
        assertEq(_harness.balanceOf(_alice), 5, "alice balance");
        assertEq(_harness.balanceOf(_bob), 0, "bob balance");
    }

    function test_deposit_creditsAndTransfers() public {
        uint256 amount = 100;
        _mintAndApprove(_alice, amount);

        vm.expectEmit(true, true, false, true, address(_harness));
        emit IBondManager.BondDeposited(_alice, _bob, amount);
        _harness.deposit(_alice, _bob, amount);

        assertEq(_harness.balanceOf(_bob), amount, "bond balance");
        assertEq(_token.balanceOf(_alice), 0, "alice token");
        assertEq(_token.balanceOf(address(_harness)), amount, "harness token");
    }

    function test_deposit_revertsOnZeroRecipient() public {
        uint256 amount = 50;
        _mintAndApprove(_alice, amount);

        vm.expectRevert(LibBonds.InvalidRecipient.selector);
        _harness.deposit(_alice, address(0), amount);
    }

    function test_withdraw_debitsAndTransfers() public {
        uint256 amount = 80;
        _mintAndApprove(_alice, amount);
        _harness.deposit(_alice, _alice, amount);

        vm.expectEmit(true, false, false, true, address(_harness));
        emit IBondManager.BondWithdrawn(_alice, amount);
        _harness.withdraw(_alice, _bob, amount);

        assertEq(_harness.balanceOf(_alice), 0, "bond balance");
        assertEq(_token.balanceOf(_bob), amount, "bob token");
        assertEq(_token.balanceOf(address(_harness)), 0, "harness token");
    }

    function test_withdraw_revertsOnInsufficientBalance() public {
        vm.expectRevert(LibBonds.InsufficientBondBalance.selector);
        _harness.withdraw(_alice, _bob, 1);
    }

    function test_processLivenessBond_payerNotPayee() public {
        uint256 livenessBond = 100;
        _harness.credit(_alice, livenessBond);

        vm.expectEmit(true, true, true, true, address(_harness));
        emit IBondManager.LivenessBondProcessed(
            _alice, _bob, _carol, livenessBond, livenessBond / 2, 0
        );
        uint256 debited = _harness.processLivenessBond(livenessBond, _alice, _bob, _carol);

        assertEq(debited, livenessBond, "debited");
        assertEq(_harness.balanceOf(_alice), livenessBond, "payer balance");
        assertEq(_harness.balanceOf(_bob), livenessBond / 2, "payee balance");
        assertEq(_harness.balanceOf(_carol), 0, "caller balance");
    }

    function test_processLivenessBond_payerEqualsPayee() public {
        uint256 livenessBond = 100;
        _harness.credit(_alice, 5);

        vm.expectEmit(true, true, true, true, address(_harness));
        emit IBondManager.LivenessBondProcessed(_alice, _alice, _bob, livenessBond, 40, 10);
        _harness.processLivenessBond(livenessBond, _alice, _alice, _bob);

        assertEq(_harness.balanceOf(_alice), 45, "payer balance");
        assertEq(_harness.balanceOf(_bob), 10, "caller balance");
    }

    function _mintAndApprove(address _owner, uint256 _amount) private {
        _token.mint(_owner, _amount);
        vm.prank(_owner);
        _token.approve(address(_harness), _amount);
    }
}
