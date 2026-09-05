// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibCustodyAccounting
} from "../../../../contracts/shared/slotchain/libs/LibCustodyAccounting.sol";
import { stdError } from "forge-std/src/StdError.sol";
import { Test } from "forge-std/src/Test.sol";

contract LibCustodyAccountingTest is Test {
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    CustodyHarness private harness;

    function setUp() external {
        harness = new CustodyHarness();
        vm.deal(address(this), 100 ether);
    }

    function test_increaseReserve_AccountsOnlyExplicitValue() external {
        harness.increaseReserve{ value: 3 ether }(2 ether);
        assertEq(harness.reserves(), 2 ether);
        assertEq(harness.accounted(), 2 ether);
        assertEq(harness.surplus(), 1 ether);
    }

    function test_increaseReserve_RevertWhen_NewLiabilityIsUnderfunded() external {
        vm.expectRevert(abi.encodeWithSelector(LibCustodyAccounting.Insolvent.selector, 0, 1));
        harness.increaseReserve(1);
        assertEq(harness.reserves(), 0);
    }

    function test_reserveToPullCredit_ConservesAccountedValue() external {
        harness.increaseReserve{ value: 7 ether }(7 ether);
        harness.reserveToPullCredit(ALICE, 3 ether);
        assertEq(harness.reserves(), 4 ether);
        assertEq(harness.creditOf(ALICE), 3 ether);
        assertEq(harness.totalPullCredits(), 3 ether);
        assertEq(harness.accounted(), 7 ether);
        assertEq(harness.surplus(), 0);
    }

    function test_reserveToPullCredit_RevertWhen_BeneficiaryIsZero() external {
        harness.increaseReserve{ value: 1 }(1);
        vm.expectRevert(LibCustodyAccounting.InvalidBeneficiary.selector);
        harness.reserveToPullCredit(address(0), 1);
    }

    function test_reserveToPullCredit_RevertWhen_ReserveIsInsufficient() external {
        harness.increaseReserve{ value: 1 }(1);
        vm.expectRevert(
            abi.encodeWithSelector(LibCustodyAccounting.InsufficientReserve.selector, 1, 2)
        );
        harness.reserveToPullCredit(ALICE, 2);
    }

    function test_increasePullCredit_UsesOnlyAlreadyHeldSurplus() external {
        _forceEth(5 ether);
        harness.increasePullCredit(ALICE, 4 ether);
        assertEq(harness.creditOf(ALICE), 4 ether);
        assertEq(harness.accounted(), 4 ether);
        assertEq(harness.surplus(), 1 ether);
    }

    function test_releaseReserve_MakesValueSurplusWithoutCallingSink() external {
        harness.increaseReserve{ value: 5 }(5);
        harness.releaseReserve(2);
        assertEq(harness.reserves(), 3);
        assertEq(harness.surplus(), 2);
    }

    function test_claimPullCredit_DebitsLiabilityAndPaysSelectedRecipient() external {
        harness.increaseReserve{ value: 5 ether }(5 ether);
        harness.reserveToPullCredit(ALICE, 2 ether);

        vm.prank(ALICE);
        assertEq(harness.claimPullCredit(payable(BOB)), 2 ether);

        assertEq(BOB.balance, 2 ether);
        assertEq(harness.creditOf(ALICE), 0);
        assertEq(harness.totalPullCredits(), 0);
        assertEq(harness.accounted(), 3 ether);
        assertEq(address(harness).balance, 3 ether);
    }

    function test_claimPullCredit_MultipleOwnersPreserveAggregateAndIsolation() external {
        harness.increaseReserve{ value: 12 ether }(12 ether);
        harness.reserveToPullCredit(ALICE, 3 ether);
        harness.reserveToPullCredit(BOB, 5 ether);

        vm.prank(ALICE);
        assertEq(harness.claimPullCredit(payable(ALICE)), 3 ether);
        assertEq(harness.creditOf(ALICE), 0);
        assertEq(harness.creditOf(BOB), 5 ether);
        assertEq(harness.totalPullCredits(), 5 ether);
        assertEq(harness.accounted(), 9 ether);

        vm.prank(BOB);
        assertEq(harness.claimPullCredit(payable(BOB)), 5 ether);
        assertEq(harness.creditOf(BOB), 0);
        assertEq(harness.totalPullCredits(), 0);
        assertEq(harness.reserves(), 4 ether);
        assertEq(harness.accounted(), 4 ether);
        assertEq(address(harness).balance, 4 ether);
    }

    function test_claimPullCredit_RevertWhen_RecipientIsZero() external {
        vm.prank(ALICE);
        vm.expectRevert(LibCustodyAccounting.InvalidRecipient.selector);
        harness.claimPullCredit(payable(address(0)));
    }

    function test_claimPullCredit_RevertWhen_CallerHasNoCredit() external {
        vm.prank(ALICE);
        vm.expectRevert(LibCustodyAccounting.NoPullCredit.selector);
        harness.claimPullCredit(payable(BOB));
    }

    function test_claimPullCredit_RevertRestoresCreditAndAggregate() external {
        RevertingReceiver receiver = new RevertingReceiver();
        harness.increaseReserve{ value: 5 }(5);
        harness.reserveToPullCredit(ALICE, 3);

        vm.prank(ALICE);
        vm.expectRevert(LibCustodyAccounting.NativeTransferFailed.selector);
        harness.claimPullCredit(payable(address(receiver)));

        assertEq(harness.creditOf(ALICE), 3);
        assertEq(harness.totalPullCredits(), 3);
        assertEq(harness.reserves(), 2);
        assertEq(address(harness).balance, 5);
        assertFalse(harness.entered());
    }

    function test_claimPullCredit_ReentrantMutationCaughtByRecipient_OuterClaimSucceeds() external {
        ReentrantReceiver receiver = new ReentrantReceiver(harness, true);
        harness.increaseReserve{ value: 5 }(5);
        harness.reserveToPullCredit(address(receiver), 3);

        receiver.claim();

        assertTrue(receiver.sawReentrantRevert());
        assertEq(address(receiver).balance, 3);
        assertEq(harness.creditOf(address(receiver)), 0);
        assertEq(harness.totalPullCredits(), 0);
        assertEq(harness.reserves(), 2);
        assertFalse(harness.entered());
    }

    function test_claimPullCredit_UncaughtReentryRestoresCompleteState() external {
        ReentrantReceiver receiver = new ReentrantReceiver(harness, false);
        harness.increaseReserve{ value: 5 }(5);
        harness.reserveToPullCredit(address(receiver), 3);

        vm.expectRevert(LibCustodyAccounting.NativeTransferFailed.selector);
        receiver.claim();

        assertEq(harness.creditOf(address(receiver)), 3);
        assertEq(harness.totalPullCredits(), 3);
        assertEq(harness.reserves(), 2);
        assertEq(address(harness).balance, 5);
        assertFalse(harness.entered());
    }

    function test_payReserve_DebitsBeforeTransferAndHandlesZeroWithoutCall() external {
        CountingReceiver receiver = new CountingReceiver();
        harness.increaseReserve{ value: 5 }(5);

        harness.payReserve(payable(address(receiver)), 0);
        assertEq(receiver.calls(), 0);
        assertEq(harness.reserves(), 5);

        harness.payReserve(payable(address(receiver)), 2);
        assertEq(receiver.calls(), 1);
        assertEq(address(receiver).balance, 2);
        assertEq(harness.reserves(), 3);
    }

    function test_payReserve_RevertRestoresReserve() external {
        RevertingReceiver receiver = new RevertingReceiver();
        harness.increaseReserve{ value: 5 }(5);
        vm.expectRevert(LibCustodyAccounting.NativeTransferFailed.selector);
        harness.payReserve(payable(address(receiver)), 2);
        assertEq(harness.reserves(), 5);
        assertEq(address(harness).balance, 5);
    }

    function test_forceEth_IsAlwaysSurplusAndDoesNotCreateCredit() external {
        harness.increaseReserve{ value: 2 }(2);
        _forceEth(7);
        assertEq(harness.accounted(), 2);
        assertEq(harness.surplus(), 7);
        assertEq(harness.totalPullCredits(), 0);
    }

    function test_sweepSurplus_PreservesAllLiabilities() external {
        CountingReceiver sink = new CountingReceiver();
        harness.increaseReserve{ value: 5 }(3);
        harness.reserveToPullCredit(ALICE, 1);
        _forceEth(7);

        assertEq(harness.sweepSurplus(payable(address(sink))), 9);

        assertEq(address(sink).balance, 9);
        assertEq(harness.reserves(), 2);
        assertEq(harness.creditOf(ALICE), 1);
        assertEq(harness.accounted(), 3);
        assertEq(address(harness).balance, 3);
        assertEq(harness.surplus(), 0);
    }

    function test_sweepSurplus_RevertWhen_SinkIsZeroOrCustodyItself() external {
        vm.expectRevert(LibCustodyAccounting.InvalidSink.selector);
        harness.sweepSurplus(payable(address(0)));

        vm.expectRevert(LibCustodyAccounting.InvalidSink.selector);
        harness.sweepSurplus(payable(address(harness)));
    }

    function test_sweepSurplus_RevertRestoresSurplus() external {
        RevertingReceiver sink = new RevertingReceiver();
        _forceEth(3);
        vm.expectRevert(LibCustodyAccounting.NativeTransferFailed.selector);
        harness.sweepSurplus(payable(address(sink)));
        assertEq(address(harness).balance, 3);
        assertEq(harness.surplus(), 3);
        assertFalse(harness.entered());
    }

    function test_sweepSurplus_ZeroSurplusDoesNotCallSink() external {
        CountingReceiver sink = new CountingReceiver();
        harness.increaseReserve{ value: 5 }(5);
        assertEq(harness.sweepSurplus(payable(address(sink))), 0);
        assertEq(sink.calls(), 0);
    }

    function test_uintMaximumBoundary_AccountsWithoutNarrowing() external {
        vm.deal(address(harness), type(uint256).max);
        harness.increaseReserve(type(uint256).max);
        assertEq(harness.accounted(), type(uint256).max);
        assertEq(harness.surplus(), 0);

        vm.expectRevert(stdError.arithmeticError);
        harness.increaseReserve(1);
    }

    function test_assertSolvent_DetectsBalanceBelowAccountedValue() external {
        harness.increaseReserve{ value: 5 }(5);
        vm.deal(address(harness), 4);
        vm.expectRevert(abi.encodeWithSelector(LibCustodyAccounting.Insolvent.selector, 4, 5));
        harness.assertSolvent();
    }

    function _forceEth(uint256 _amount) private {
        ForceEth force = new ForceEth{ value: _amount }();
        force.destroy(payable(address(harness)));
    }
}

contract CustodyHarness {
    using LibCustodyAccounting for LibCustodyAccounting.State;

    LibCustodyAccounting.State private _custody;

    receive() external payable { }

    function increaseReserve(uint256 _amount) external payable {
        _custody.increaseReserve(_amount);
    }

    function releaseReserve(uint256 _amount) external {
        _custody.releaseReserve(_amount);
    }

    function reserveToPullCredit(address _beneficiary, uint256 _amount) external {
        _custody.reserveToPullCredit(_beneficiary, _amount);
    }

    function increasePullCredit(address _beneficiary, uint256 _amount) external {
        _custody.increasePullCredit(_beneficiary, _amount);
    }

    function claimPullCredit(address payable _recipient) external returns (uint256) {
        return _custody.claimPullCredit(_recipient);
    }

    function payReserve(address payable _recipient, uint256 _amount) external {
        _custody.payReserve(_recipient, _amount);
    }

    function sweepSurplus(address payable _sink) external returns (uint256) {
        return _custody.sweepSurplus(_sink);
    }

    function assertSolvent() external view {
        _custody.assertSolvent();
    }

    function reserves() external view returns (uint256) {
        return _custody.reserves;
    }

    function totalPullCredits() external view returns (uint256) {
        return _custody.totalPullCredits;
    }

    function creditOf(address _owner) external view returns (uint256) {
        return _custody.pullCreditOf(_owner);
    }

    function accounted() external view returns (uint256) {
        return _custody.accounted();
    }

    function surplus() external view returns (uint256) {
        return _custody.surplus();
    }

    function entered() external view returns (bool) {
        return _custody.entered;
    }
}

contract ForceEth {
    constructor() payable { }

    function destroy(address payable _recipient) external {
        selfdestruct(_recipient);
    }
}

contract RevertingReceiver {
    receive() external payable {
        revert();
    }
}

contract CountingReceiver {
    uint256 public calls;

    receive() external payable {
        ++calls;
    }
}

contract ReentrantReceiver {
    CustodyHarness private immutable _harness;
    bool private immutable _catchRevert;
    bool public sawReentrantRevert;

    constructor(CustodyHarness _harness_, bool _catchRevert_) {
        _harness = _harness_;
        _catchRevert = _catchRevert_;
    }

    receive() external payable {
        if (_catchRevert) {
            try _harness.increaseReserve(0) { }
            catch (bytes memory reason) {
                sawReentrantRevert = bytes4(reason) == LibCustodyAccounting.ReentrantCall.selector;
            }
        } else {
            _harness.increaseReserve(0);
        }
    }

    function claim() external {
        _harness.claimPullCredit(payable(address(this)));
    }
}
