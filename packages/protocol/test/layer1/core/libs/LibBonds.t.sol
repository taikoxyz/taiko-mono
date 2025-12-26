// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
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

    function creditBonds(IInbox.Transition[] memory _transitions, uint256 _start) external {
        _bonds.creditBonds(_transitions, _start);
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

    function test_creditBonds_aggregatesNonConsecutive() public {
        IInbox.Transition[] memory transitions = new IInbox.Transition[](6);
        transitions[0] = _transition(_alice, 3);
        transitions[1] = _transition(_bob, 3);
        transitions[2] = _transition(_alice, 5);
        transitions[3] = _transition(_carol, 3);
        transitions[4] = _transition(_alice, 1);
        transitions[5] = _transition(_bob, 7);

        _harness.creditBonds(transitions, 0);

        assertEq(_harness.balanceOf(_alice), 9, "alice balance");
        assertEq(_harness.balanceOf(_bob), 10, "bob balance");
        assertEq(_harness.balanceOf(_carol), 3, "carol balance");
    }

    function test_creditBonds_noopOnEmptyList() public {
        _harness.credit(_alice, 5);
        IInbox.Transition[] memory transitions = new IInbox.Transition[](0);
        _harness.creditBonds(transitions, 0);
        assertEq(_harness.balanceOf(_alice), 5, "balance");
    }

    function test_creditBonds_noopOnZeroAmounts() public {
        _harness.credit(_alice, 5);
        IInbox.Transition[] memory transitions = new IInbox.Transition[](3);
        transitions[0] = _transition(_alice, 0);
        transitions[1] = _transition(_bob, 3);
        transitions[2] = _transition(_alice, 0);

        _harness.creditBonds(transitions, 0);
        assertEq(_harness.balanceOf(_alice), 5, "alice balance");
        assertEq(_harness.balanceOf(_bob), 3, "bob balance");
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
        uint256 debited = _harness.processLivenessBond(
            livenessBond, _alice, _bob, _carol
        );

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

    function _transition(address _proposer, uint256 _livenessBond)
        private
        pure
        returns (IInbox.Transition memory)
    {
        return IInbox.Transition({
            proposer: _proposer,
            designatedProver: address(0),
            timestamp: 0,
            livenessBond: _livenessBond,
            blockHash: bytes32(0)
        });
    }
}
