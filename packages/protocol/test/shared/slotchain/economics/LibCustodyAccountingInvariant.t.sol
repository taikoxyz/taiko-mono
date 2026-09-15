// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibCustodyAccounting
} from "../../../../contracts/shared/slotchain/libs/LibCustodyAccounting.sol";
import { StdInvariant } from "forge-std/src/StdInvariant.sol";
import { Test } from "forge-std/src/Test.sol";

contract LibCustodyAccountingInvariantTest is StdInvariant, Test {
    InvariantCustodyHarness private harness;
    CustodyAccountingHandler private handler;

    function setUp() external {
        harness = new InvariantCustodyHarness();
        handler = new CustodyAccountingHandler(harness);
        vm.deal(address(handler), 1000 ether);
        targetContract(address(handler));
    }

    function invariant_balanceAlwaysCoversAccountedValue() external view {
        assertGe(address(harness).balance, harness.accounted());
        assertEq(harness.surplus(), address(harness).balance - harness.accounted());
    }

    function invariant_aggregateCreditEqualsAllReachableOwnerRows() external view {
        assertEq(harness.totalPullCredits(), harness.creditOf(address(handler)));
        assertEq(harness.accounted(), harness.reserves() + harness.totalPullCredits());
    }

    function invariant_guardIsClearAtEveryExternalBoundary() external view {
        assertFalse(harness.entered());
    }
}

contract CustodyAccountingHandler {
    InvariantCustodyHarness private immutable _harness;

    constructor(InvariantCustodyHarness _harness_) {
        _harness = _harness_;
    }

    receive() external payable { }

    function increaseReserve(uint96 _rawAmount) external {
        uint256 amount = _bounded(_rawAmount, address(this).balance);
        _harness.increaseReserve{ value: amount }(amount);
    }

    function forceSurplus(uint96 _rawAmount) external {
        uint256 amount = _bounded(_rawAmount, address(this).balance);
        InvariantForceEth force = new InvariantForceEth{ value: amount }();
        force.destroy(payable(address(_harness)));
    }

    function releaseReserve(uint96 _rawAmount) external {
        uint256 amount = _bounded(_rawAmount, _harness.reserves());
        _harness.releaseReserve(amount);
    }

    function reserveToPullCredit(uint96 _rawAmount) external {
        uint256 amount = _bounded(_rawAmount, _harness.reserves());
        _harness.reserveToPullCredit(address(this), amount);
    }

    function increasePullCredit(uint96 _rawAmount) external {
        uint256 amount = _bounded(_rawAmount, _harness.surplus());
        _harness.increasePullCredit(address(this), amount);
    }

    function claimPullCredit() external {
        if (_harness.creditOf(address(this)) != 0) {
            _harness.claimPullCredit(payable(address(this)));
        }
    }

    function sweepSurplus() external {
        _harness.sweepSurplus(payable(address(this)));
    }

    function _bounded(uint256 _rawAmount, uint256 _available) private pure returns (uint256) {
        if (_available == 0) return 0;
        return _rawAmount % (_available + 1);
    }
}

contract InvariantCustodyHarness {
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

    function sweepSurplus(address payable _sink) external returns (uint256) {
        return _custody.sweepSurplus(_sink);
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

contract InvariantForceEth {
    constructor() payable { }

    function destroy(address payable _recipient) external {
        selfdestruct(_recipient);
    }
}
