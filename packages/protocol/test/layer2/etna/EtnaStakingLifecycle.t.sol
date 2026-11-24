// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { EtnaVoteKeys } from "./EtnaVoteKeys.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { stdError } from "forge-std/src/StdError.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

contract EtnaStakingLifecycleTest is EtnaStakingTestBase {
    /// @dev Consensus private keys: K_i is the key of private key i.
    uint256 private constant _K1 = 1;
    uint256 private constant _K2 = 2;

    // ---------------------------------------------------------------
    // topUp
    // ---------------------------------------------------------------

    /// @dev A top-up of a seated bond adds to effStake in the call and emits only
    /// `TopUpDeposited`: the bond keeps its seat, owner and key.
    function test_topUp_AddsAtOnceAndEmits() external {
        uint256 bondId = _register(_K1, Bob, MIN_STAKE);
        IEtnaStaking.Bond memory before = staking.bondAt(bondId);
        uint256 a = 3 ether + 1;
        _fund(Bob, a);

        vm.recordLogs();
        vm.expectEmit(address(staking));
        emit IEtnaStaking.TopUpDeposited(bondId, a);
        vm.prank(Bob);
        staking.topUp(bondId, a);
        assertEq(_logsFrom(vm.getRecordedLogs(), address(staking)), 1, "no other staking event");

        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        assertEq(bond.effStake, MIN_STAKE + a, "effStake grows at once");
        assertEq(bond.owner, Bob, "owner unchanged");
        assertEq(bond.ckPrefix, before.ckPrefix, "prefix unchanged");
        assertEq(bond.ckX, before.ckX, "x unchanged");
        assertEq(bond.exitHeight, NO_EXIT, "no exit");
        _assertSeatOfBond(bondId, true, 0, "seat unchanged");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K1), true, bondId, "key unchanged");
        assertEq(token.balanceOf(address(staking)), MIN_STAKE + a, "stake held");
        assertEq(token.balanceOf(Bob), 0, "top-up pulled");
    }

    function test_topUp_RevertWhen_Overflow() external {
        uint256 bondId = _register(_K1, Bob, MIN_STAKE);
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(Bob);
        staking.topUp(bondId, type(uint256).max - MIN_STAKE + 1);
        assertEq(staking.bondAt(bondId).effStake, MIN_STAKE, "effStake unchanged");
    }

    function test_topUp_RevertWhen_NotOwnerZeroExitedOrWithdrawn() external {
        uint256 live = _register(_K1, Bob, MIN_STAKE);
        uint256 leaving = _register(_K2, Bob, MIN_STAKE);
        _fund(Bob, 1);
        _fund(Carol, 1);

        vm.expectRevert(IEtnaStaking.NotBondOwner.selector);
        vm.prank(Carol);
        staking.topUp(live, 1);

        vm.expectRevert(IEtnaStaking.ZeroAmount.selector);
        vm.prank(Bob);
        staking.topUp(live, 0);

        _requestExit(leaving);
        vm.expectRevert(IEtnaStaking.ExitAlreadySet.selector);
        vm.prank(Bob);
        staking.topUp(leaving, 1);

        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Bob);
        staking.withdraw(leaving, Bob);
        vm.expectRevert(IEtnaStaking.BondWithdrawn.selector);
        vm.prank(Bob);
        staking.topUp(leaving, 1);

        assertEq(staking.bondAt(live).effStake, MIN_STAKE, "live bond unchanged");
    }

    // ---------------------------------------------------------------
    // requestExit
    // ---------------------------------------------------------------

    /// @dev 2^48 - 1 is the no-exit value, so an exit can be set only below it.
    function test_requestExit_ProceedsBelowTheSentinel() external {
        uint256 first = _register(_K1, Bob, MIN_STAKE);
        uint256 second = _register(_K2, Carol, MIN_STAKE);

        vm.roll(2 ** 48 - 2);
        _requestExit(first);
        assertEq(staking.bondAt(first).exitHeight, 2 ** 48 - 2, "exit at 2^48 - 2");
        _assertSeatOfBond(first, false, 0, "seat released");

        vm.roll(2 ** 48 - 1);
        vm.expectRevert(IEtnaStaking.InvalidExitHeight.selector);
        vm.prank(Carol);
        staking.requestExit(second);
        assertEq(staking.bondAt(second).exitHeight, NO_EXIT, "no exit set");
        _assertSeatOfBond(second, true, 1, "seat kept");
    }

    function test_requestExit_ReleasesTheSeatInTheCall() external {
        for (uint256 pk = 11; pk < 16; ++pk) {
            _register(pk, Bob, MIN_STAKE);
        }
        uint256 bondId = _register(_K1, Carol, MIN_STAKE + 5);
        address ckAddr = EtnaTestKeys.ckAddr(_K1);
        _assertSeatOfBond(bondId, true, 5, "seat 5 before the exit");

        vm.expectEmit(address(staking));
        emit IEtnaStaking.ExitRequested(bondId, block.number);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.SeatReleased(bondId, 5);
        vm.prank(Carol);
        staking.requestExit(bondId);

        _assertSeatOfBond(bondId, false, 0, "bond holds no seat");
        _assertBondInSeat(5, false, 0, "seat 5 empty");
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        assertEq(bond.exitHeight, block.number, "exit height");
        assertFalse(bond.holdsSeat, "record holds no seat");
        assertEq(bond.seat, 0, "record seat cleared");
        assertEq(bond.effStake, MIN_STAKE + 5, "effStake kept");
        assertEq(bond.owner, Carol, "owner kept");
        _assertBondForKey(ckAddr, true, bondId, "key registration kept");
        for (uint8 seat; seat < 5; ++seat) {
            _assertBondInSeat(seat, true, seat, "other seats unchanged");
        }

        vm.expectRevert(IEtnaStaking.ExitAlreadySet.selector);
        vm.prank(Carol);
        staking.requestExit(bondId);

        vm.expectRevert(IEtnaStaking.NotBondOwner.selector);
        vm.prank(Bob);
        staking.requestExit(bondId);
        vm.expectRevert(IEtnaStaking.NotBondOwner.selector);
        vm.prank(Carol);
        staking.requestExit(0);
    }

    // ---------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------

    function test_withdraw_PaysAfterTheDelayAndKeepsIdentity() external {
        uint256 amount = MIN_STAKE + 11;
        uint256 bondId = _register(_K1, Bob, amount);
        IEtnaStaking.Bond memory before = staking.bondAt(bondId);
        uint256 exitAt = block.number;
        _requestExit(bondId);
        vm.roll(exitAt + WITHDRAWAL_DELAY);

        vm.expectEmit(address(staking));
        emit IEtnaStaking.Withdrawn(bondId, Carol, amount);
        vm.prank(Bob);
        staking.withdraw(bondId, Carol);

        assertEq(token.balanceOf(Carol), amount, "to receives effStake");
        assertEq(token.balanceOf(address(staking)), 0, "nothing left");
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        assertEq(bond.owner, address(0), "owner cleared");
        assertTrue(bond.withdrawn, "withdrawn");
        assertEq(bond.effStake, 0, "effStake zero");
        assertEq(bond.exitHeight, exitAt, "exit height kept");
        assertEq(bond.ckPrefix, before.ckPrefix, "prefix kept");
        assertEq(bond.ckX, before.ckX, "x kept");
        assertFalse(bond.holdsSeat, "no seat");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K1), true, bondId, "key registration kept");
        assertFalse(staking.forfeited(bondId), "forfeiture flag kept");
        assertEq(staking.bondCount(), 1, "id stays issued");

        vm.expectRevert(IEtnaStaking.BondWithdrawn.selector);
        vm.prank(Bob);
        staking.withdraw(bondId, Bob);
    }

    function test_withdraw_RevertWhen_NotOwnerOrZeroRecipient() external {
        uint256 bondId = _register(_K1, Bob, MIN_STAKE);
        _requestExit(bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);

        vm.expectRevert(IEtnaStaking.NotBondOwner.selector);
        vm.prank(Carol);
        staking.withdraw(bondId, Carol);

        vm.expectRevert(IEtnaStaking.InvalidRecipient.selector);
        vm.prank(Bob);
        staking.withdraw(bondId, address(0));

        assertFalse(staking.bondAt(bondId).withdrawn, "not withdrawn");
        vm.prank(Bob);
        staking.withdraw(bondId, Bob);
        assertEq(token.balanceOf(Bob), MIN_STAKE, "paid to the owner");
    }

    // ---------------------------------------------------------------
    // Reentrancy
    // ---------------------------------------------------------------

    /// @dev A token that re-enters `register`, `topUp` or `withdraw` from its transfer hits the
    /// staking contract's lock, and the outer call changes nothing.
    function test_entryPoints_RevertWhen_Reentered() external {
        ReentrantERC20 reentrant = new ReentrantERC20();
        IEtnaStaking.Config memory cfg = _config();
        cfg.token = address(reentrant);
        staking = _deploy(cfg);
        reentrant.mint(Bob, 2 * MIN_STAKE);
        vm.prank(Bob);
        reentrant.approve(address(staking), type(uint256).max);
        bytes memory publicKey = EtnaTestKeys.publicKey(_K1);
        bytes memory pop = EtnaVoteKeys.popSig(_K1, staking, Bob);

        reentrant.armReentry(
            address(staking), abi.encodeCall(staking.register, (publicKey, MIN_STAKE, pop))
        );
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Bob);
        staking.register(publicKey, MIN_STAKE, pop);
        assertEq(staking.bondCount(), 0, "no bond issued");
        _assertBondForKey(EtnaTestKeys.ckAddr(_K1), false, 0, "key unused");

        reentrant.armReentry(address(0), "");
        vm.prank(Bob);
        uint256 bondId = staking.register(publicKey, MIN_STAKE, pop);

        reentrant.armReentry(address(staking), abi.encodeCall(staking.topUp, (bondId, 1)));
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Bob);
        staking.topUp(bondId, 1);
        assertEq(staking.bondAt(bondId).effStake, MIN_STAKE, "effStake unchanged");

        reentrant.armReentry(address(0), "");
        _requestExit(bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        reentrant.armReentry(address(staking), abi.encodeCall(staking.withdraw, (bondId, Bob)));
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        vm.prank(Bob);
        staking.withdraw(bondId, Bob);
        assertFalse(staking.bondAt(bondId).withdrawn, "not withdrawn");
        assertEq(reentrant.balanceOf(address(staking)), MIN_STAKE, "stake held");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Counts the logs `_emitter` emitted.
    function _logsFrom(
        Vm.Log[] memory _logs,
        address _emitter
    )
        private
        pure
        returns (uint256 n_)
    {
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].emitter == _emitter) ++n_;
        }
    }
}
