// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";

/// @title EtnaInboxRulesScheduleTest
/// @notice The rules schedule in slot 293 (spec 10.1): `scheduleRules`, `scheduleStop` and
/// `recover`'s `rules`, with the vector numbers of rules/vectors/10.1.md and 8.md 47a. M is
/// `maxAnchorAge`, two hours. The schedule helpers authorize the current generation `_g`.
contract EtnaInboxRulesScheduleTest is EtnaLandTestBase {
    uint256 private constant _NOW = 1_000_000;
    uint256 private constant _M = MAX_ANCHOR_AGE;
    uint48 private constant _MAX = type(uint48).max;

    /// @dev The generation the helpers' schedule calls are authorized for.
    uint48 private _g;

    function setUp() public override {
        super.setUp();
        vm.warp(_NOW);
    }

    // ---------------------------------------------------------------
    // scheduleRules (START-10.1-5a)
    // ---------------------------------------------------------------

    /// @dev 5a.a, 5a.b: from slot 0, ruleset 1 needs a time at least now + M.
    function test_scheduleRules_SchedulesTheNextRuleset() external {
        _expectScheduleRulesRevert(1, _NOW + _M - 1, IEtnaInbox.InvalidScheduleTime.selector);
        _scheduleRules(1, _NOW + _M, [uint256(0), 1, _NOW + _M, 0]);
    }

    /// @dev 5a.c, 5a.d, 5a.e, 5a.i, 5a.j: before its deadline a pending ruleset can be
    /// rescheduled, cancelled with 2^48 - 1 or replaced by the next number; a cancelled number is
    /// never reused.
    function test_scheduleRules_ReschedulesCancelsAndReplaces() external {
        uint256 t = _NOW + _M + 100;
        _plant([uint256(0), 1, t, 0]);
        _scheduleRules(1, t + 3600, [uint256(0), 1, t + 3600, 0]);
        _scheduleRules(1, _MAX, [uint256(0), 1, _MAX, 0]);
        _scheduleRules(2, t, [uint256(0), 2, t, 0]);
        _scheduleRules(2, _MAX, [uint256(0), 2, _MAX, 0]);
        _expectScheduleRulesRevert(1, _NOW + _M, IEtnaInbox.InvalidRules.selector);
        _scheduleRules(3, _NOW + _M, [uint256(0), 3, _NOW + _M, 0]);
    }

    /// @dev 5a.f, 5a.g, 5a.k: a pending ruleset is locked from M before its time, strictly, and
    /// numbers cannot be skipped.
    function test_scheduleRules_RevertWhen_PendingRulesetIsLockedOrNumberSkips() external {
        _plant([uint256(0), 1, _NOW + _M, 0]);
        _expectScheduleRulesRevert(1, _NOW + _M + 3600, IEtnaInbox.RulesLocked.selector);
        _plant([uint256(0), 1, _NOW + 1, 0]);
        _expectScheduleRulesRevert(2, _NOW + _M, IEtnaInbox.RulesLocked.selector);

        _plant([uint256(0), 1, _NOW + _M + 1, 0]);
        _expectScheduleRulesRevert(5, _NOW + _M, IEtnaInbox.InvalidRules.selector);
    }

    /// @dev 5a.h, 5a.l, 5c.e: once rulesTime is reached the call first promotes nextRules; a
    /// call that then fails keeps nothing, the promotion included.
    function test_scheduleRules_PromotesDueRulesetFirst() external {
        _plant([uint256(0), 1, _NOW, 0]);
        _expectScheduleRulesRevert(0, _NOW + _M, IEtnaInbox.InvalidRules.selector);
        _scheduleRules(2, _NOW + _M, [uint256(1), 2, _NOW + _M, 0]);
    }

    /// @dev 5c.f: nextRules = 2^48 - 1 has no successor in 48 bits.
    function test_scheduleRules_RevertWhen_NextRulesetWouldOverflow() external {
        _plant([uint256(0), _MAX, _MAX, 0]);
        _expectScheduleRulesRevert(0, _NOW + _M, IEtnaInbox.InvalidRules.selector);
    }

    // ---------------------------------------------------------------
    // scheduleStop (START-10.1-5b)
    // ---------------------------------------------------------------

    /// @dev 5b.a, 5b.b, 5b.f: a stop takes any time at least now + M, and 0 is the only earlier
    /// value. The rules fields are kept.
    function test_scheduleStop_anyTime() external {
        _plant([uint256(1), 2, _MAX, 0]);
        _expectScheduleStopRevert(_NOW + _M - 1, IEtnaInbox.InvalidStop.selector);
        _expectScheduleStopRevert(1, IEtnaInbox.InvalidStop.selector);
        _scheduleStop(0, [uint256(1), 2, _MAX, 0]);

        uint256[4] memory times = [_NOW + _M, _NOW + _M + 1, _NOW + _M + 7, _MAX];
        for (uint256 i; i < times.length; ++i) {
            _plant([uint256(1), 2, _MAX, 0]);
            _scheduleStop(times[i], [uint256(1), 2, _MAX, times[i]]);
        }
    }

    /// @dev 5b.c, 5b.d: before its deadline a stop can be moved or cancelled.
    function test_scheduleStop_MovesAndCancels() external {
        uint256 stop = _NOW + _M + 100;
        _plant([uint256(0), 0, 0, stop]);
        _scheduleStop(stop + 3600, [uint256(0), 0, 0, stop + 3600]);
        _scheduleStop(0, [uint256(0), 0, 0, 0]);
    }

    /// @dev 5b.e: from M before the stop on, no call changes it, a cancellation included.
    function test_scheduleStop_RevertWhen_StopIsLocked() external {
        _plant([uint256(0), 0, 0, _NOW + _M]);
        _expectScheduleStopRevert(0, IEtnaInbox.StopLocked.selector);
        _plant([uint256(0), 0, 0, _NOW]);
        _expectScheduleStopRevert(_NOW + _M + 100, IEtnaInbox.StopLocked.selector);
    }

    /// @dev 5b.e, ACCEPTANCE 10.1 item 2: one second after now + M the stop is not yet locked,
    /// so it can still be cancelled.
    function test_scheduleStop_CancelsOneSecondBeforeTheLock() external {
        _plant([uint256(0), 0, 0, _NOW + _M + 1]);
        _scheduleStop(0, [uint256(0), 0, 0, 0]);
    }

    // ---------------------------------------------------------------
    // Callers (START-10.1-5c)
    // ---------------------------------------------------------------

    /// @dev 5c.a: both calls are owner-only and need an initialized Inbox.
    function test_schedule_RevertWhen_NotOwnerOrNotInitialized() external {
        vm.startPrank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        _inbox().scheduleRules(0, 1, uint48(_NOW + _M));
        vm.expectRevert("Ownable: caller is not the owner");
        _inbox().scheduleStop(0, uint48(_NOW + _M));
        vm.stopPrank();

        _deployFreshInbox(false);
        _inbox().upgradeTo(address(inboxImpl));
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().scheduleRules(0, 1, uint48(_NOW + _M));
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().scheduleStop(0, uint48(_NOW + _M));
    }

    /// @dev 5c.g: a rule update or stop authorized for generation 0 reverts once `recover`
    /// advanced to generation 1, with c unchanged and ample lead, before slot 293 is written or a
    /// schedule update is emitted. The generation is checked before the schedule itself: a
    /// pending ruleset that would be locked still reports the mismatch.
    function test_schedule_RevertWhen_AuthorizedForAnEarlierGeneration() external {
        _recover(0, [uint256(0), 0, 0, 0]);
        _expectScheduleRulesRevert(1, _NOW + _M, IEtnaInbox.GenerationMismatch.selector);
        _expectScheduleStopRevert(_NOW + _M, IEtnaInbox.GenerationMismatch.selector);
        _plant([uint256(0), 1, _NOW + 1, 0]);
        _expectScheduleRulesRevert(1, _NOW + _M, IEtnaInbox.GenerationMismatch.selector);

        // A future generation is no better.
        _g = 2;
        _expectScheduleRulesRevert(1, _NOW + _M, IEtnaInbox.GenerationMismatch.selector);
        _expectScheduleStopRevert(_NOW + _M, IEtnaInbox.GenerationMismatch.selector);
    }

    /// @dev 5c.h: a cancellation authorized for generation 0 reverts after recovery into
    /// generation 1, even though the schedule would admit cancelling (the stop is far ahead).
    function test_scheduleStop_RevertWhen_CancellationIsForAnEarlierGeneration() external {
        _plant([uint256(0), 0, 0, _NOW + 10 * _M]);
        _inbox().recover(0, 0, 0, _NOW, new uint256[](0), 0);
        _plant([uint256(0), 0, 0, _NOW + 10 * _M]);
        _expectScheduleStopRevert(0, IEtnaInbox.GenerationMismatch.selector);
        _expectScheduleRulesRevert(0, _MAX, IEtnaInbox.GenerationMismatch.selector);
    }

    /// @dev 5c.i: a new authorization naming generation 1 changes the schedule in generation 1
    /// and emits its new value.
    function test_schedule_AuthorizedForTheCurrentGeneration() external {
        _recover(0, [uint256(0), 0, 0, 0]);
        _g = 1;
        _scheduleRules(1, _NOW + _M, [uint256(0), 1, _NOW + _M, 0]);
        _scheduleStop(_NOW + _M + 1, [uint256(0), 1, _NOW + _M, _NOW + _M + 1]);
        _scheduleStop(0, [uint256(0), 1, _NOW + _M, 0]);
    }

    // ---------------------------------------------------------------
    // recover (RECOV-8-47a)
    // ---------------------------------------------------------------

    /// @dev 47a.a: rules 0 clears the stop and keeps the pending ruleset.
    function test_recover_ClearsTheStopAndKeepsThePendingRuleset() external {
        uint256 t = _NOW + 3600;
        _plant([uint256(1), 2, t, _NOW + 60]);
        _recover(0, [uint256(1), 2, t, 0]);
    }

    /// @dev 47a.b: a non-zero rules runs the new generation on it from its first block.
    function test_recover_InstallsTheNextRuleset() external {
        _plant([uint256(1), 2, _NOW + 3600, _NOW + 60]);
        _recover(3, [uint256(3), 3, 0, 0]);
    }

    /// @dev 47a.c, 47a.d: a non-zero rules must be nextRules + 1; the whole recovery reverts.
    function test_recover_RevertWhen_RulesIsNotNextPlusOne() external {
        _plant([uint256(1), 2, _NOW + 3600, 0]);
        _expectRecoverRevert(2);
        _expectRecoverRevert(4);
        _plant([uint256(0), _MAX, _MAX, 0]);
        _expectRecoverRevert(_MAX);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The packed slot 293 word of `_s` = (activeRules, nextRules, rulesTime, stopTime).
    function _pack(uint256[4] memory _s) private pure returns (uint256) {
        return _s[0] | _s[1] << 48 | _s[2] << 96 | _s[3] << 144;
    }

    function _plant(uint256[4] memory _s) private {
        _storeInboxWord(RULES_SCHEDULE_SLOT, bytes32(_pack(_s)));
    }

    /// @dev Checks `rulesSchedule()` and slot 293 against `_s`.
    function _assertSchedule(uint256[4] memory _s) private view {
        IEtnaInbox.RulesSchedule memory schedule = _inbox().rulesSchedule();
        assertEq(schedule.activeRules, _s[0], "activeRules");
        assertEq(schedule.nextRules, _s[1], "nextRules");
        assertEq(schedule.rulesTime, _s[2], "rulesTime");
        assertEq(schedule.stopTime, _s[3], "stopTime");
        assertEq(uint256(_inboxWord(RULES_SCHEDULE_SLOT)), _pack(_s), "slot 293");
    }

    function _scheduleRules(
        uint48 _rules,
        uint256 _time,
        uint256[4] memory _expected
    )
        private
    {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.RulesScheduleUpdated(_pack(_expected));
        _inbox().scheduleRules(_g, _rules, uint48(_time));
        _assertSchedule(_expected);
    }

    function _scheduleStop(uint256 _time, uint256[4] memory _expected) private {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.RulesScheduleUpdated(_pack(_expected));
        _inbox().scheduleStop(_g, uint48(_time));
        _assertSchedule(_expected);
    }

    function _expectScheduleRulesRevert(
        uint48 _rules,
        uint256 _time,
        bytes4 _selector
    )
        private
    {
        bytes32 before = _inboxWord(RULES_SCHEDULE_SLOT);
        vm.recordLogs();
        vm.expectRevert(_selector);
        _inbox().scheduleRules(_g, _rules, uint48(_time));
        assertEq(vm.getRecordedLogs().length, 0, "no schedule update");
        assertEq(_inboxWord(RULES_SCHEDULE_SLOT), before, "slot 293 unchanged");
    }

    function _expectScheduleStopRevert(uint256 _time, bytes4 _selector) private {
        bytes32 before = _inboxWord(RULES_SCHEDULE_SLOT);
        vm.recordLogs();
        vm.expectRevert(_selector);
        _inbox().scheduleStop(_g, uint48(_time));
        assertEq(vm.getRecordedLogs().length, 0, "no schedule update");
        assertEq(_inboxWord(RULES_SCHEDULE_SLOT), before, "slot 293 unchanged");
    }

    /// @dev The owner recovers at c = 0 with `_rules`, expecting `RulesScheduleUpdated` with
    /// `_expected`.
    function _recover(uint48 _rules, uint256[4] memory _expected) private {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.RulesScheduleUpdated(_pack(_expected));
        _inbox().recover(0, 0, 0, _NOW, new uint256[](0), _rules);
        assertEq(_inbox().recoveryGeneration(), 1, "recovered");
        _assertSchedule(_expected);
    }

    function _expectRecoverRevert(uint48 _rules) private {
        bytes32 before = _inboxWord(RULES_SCHEDULE_SLOT);
        vm.expectRevert(IEtnaInbox.InvalidRules.selector);
        _inbox().recover(0, 0, 0, _NOW, new uint256[](0), _rules);
        assertEq(_inboxWord(RULES_SCHEDULE_SLOT), before, "slot 293 unchanged");
        assertEq(_inbox().recoveryGeneration(), 0, "no recovery");
    }
}
