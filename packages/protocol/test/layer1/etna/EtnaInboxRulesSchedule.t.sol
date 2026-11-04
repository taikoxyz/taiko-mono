// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";

/// @title EtnaInboxRulesScheduleTest
/// @notice The rules schedule in slot 293 (spec 10.1): `scheduleRules`, `scheduleStop` and
/// `recover`'s `rules`, with the vector numbers of rules/vectors/10.1.md (scaled to K = 6) and
/// 8.md 47a. M is `maxAnchorAge`, two hours.
contract EtnaInboxRulesScheduleTest is EtnaLandTestBase {
    uint256 private constant _NOW = 1_000_000;
    uint256 private constant _M = MAX_ANCHOR_AGE;
    uint48 private constant _MAX = type(uint48).max;

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
        _scheduleRules(1, _NOW + _M, [uint256(0), 1, _NOW + _M, 0, 0]);
    }

    /// @dev 5a.c, 5a.d, 5a.e, 5a.i, 5a.j: before its deadline a pending ruleset can be
    /// rescheduled, cancelled with 2^48 - 1 or replaced by the next number; a cancelled number is
    /// never reused.
    function test_scheduleRules_ReschedulesCancelsAndReplaces() external {
        uint256 t = _NOW + _M + 100;
        _plant([uint256(0), 1, t, 0, 0]);
        _scheduleRules(1, t + 3600, [uint256(0), 1, t + 3600, 0, 0]);
        _scheduleRules(1, _MAX, [uint256(0), 1, _MAX, 0, 0]);
        _scheduleRules(2, t, [uint256(0), 2, t, 0, 0]);
        _scheduleRules(2, _MAX, [uint256(0), 2, _MAX, 0, 0]);
        _expectScheduleRulesRevert(1, _NOW + _M, IEtnaInbox.InvalidRules.selector);
        _scheduleRules(3, _NOW + _M, [uint256(0), 3, _NOW + _M, 0, 0]);
    }

    /// @dev 5a.f, 5a.g, 5a.k: a pending ruleset is locked from M before its time, strictly, and
    /// numbers cannot be skipped.
    function test_scheduleRules_RevertWhen_PendingRulesetIsLockedOrNumberSkips() external {
        _plant([uint256(0), 1, _NOW + _M, 0, 0]);
        _expectScheduleRulesRevert(1, _NOW + _M + 3600, IEtnaInbox.RulesLocked.selector);
        _plant([uint256(0), 1, _NOW + 1, 0, 0]);
        _expectScheduleRulesRevert(2, _NOW + _M, IEtnaInbox.RulesLocked.selector);

        _plant([uint256(0), 1, _NOW + _M + 1, 0, 0]);
        _expectScheduleRulesRevert(5, _NOW + _M, IEtnaInbox.InvalidRules.selector);
    }

    /// @dev 5a.h, 5a.l, 5c.e: once rulesTime is reached the call first promotes nextRules; a
    /// call that then fails keeps nothing, the promotion included.
    function test_scheduleRules_PromotesDueRulesetFirst() external {
        _plant([uint256(0), 1, _NOW, 0, 0]);
        _expectScheduleRulesRevert(0, _NOW + _M, IEtnaInbox.InvalidRules.selector);
        _scheduleRules(2, _NOW + _M, [uint256(1), 2, _NOW + _M, 0, 0]);
    }

    /// @dev 5c.f: nextRules = 2^48 - 1 has no successor in 48 bits.
    function test_scheduleRules_RevertWhen_NextRulesetWouldOverflow() external {
        _plant([uint256(0), _MAX, _MAX, 0, 0]);
        _expectScheduleRulesRevert(0, _NOW + _M, IEtnaInbox.InvalidRules.selector);
    }

    // ---------------------------------------------------------------
    // scheduleStop (START-10.1-5b)
    // ---------------------------------------------------------------

    /// @dev 5b.a, 5b.b, 5b.f, 5b.g: a stop needs a time at least now + M and a positive multiple
    /// of K; (0, 0) is the only stop without them. The rules fields are kept.
    function test_scheduleStop_SchedulesAStop() external {
        _plant([uint256(1), 2, _MAX, 0, 0]);
        bytes4 invalid = IEtnaInbox.InvalidStop.selector;
        _expectScheduleStopRevert(_NOW + _M - 1, 6, invalid);
        _expectScheduleStopRevert(_NOW + _M, 4, invalid);
        _expectScheduleStopRevert(_NOW + _M, 0, invalid);
        _expectScheduleStopRevert(0, 6, invalid);
        _scheduleStop(0, 0, [uint256(1), 2, _MAX, 0, 0]);
        _scheduleStop(_NOW + _M, 6, [uint256(1), 2, _MAX, _NOW + _M, 6]);
    }

    /// @dev 5b.c, 5b.d: before its deadline a stop can be moved or cancelled.
    function test_scheduleStop_MovesAndCancels() external {
        uint256 stop = _NOW + _M + 100;
        _plant([uint256(0), 0, 0, stop, 6]);
        _scheduleStop(stop + 3600, 12, [uint256(0), 0, 0, stop + 3600, 12]);
        _scheduleStop(0, 0, [uint256(0), 0, 0, 0, 0]);
    }

    /// @dev 5b.e: from M before the stop on, no call changes it, a cancellation included.
    function test_scheduleStop_RevertWhen_StopIsLocked() external {
        _plant([uint256(0), 0, 0, _NOW + _M, 6]);
        _expectScheduleStopRevert(0, 0, IEtnaInbox.StopLocked.selector);
        _plant([uint256(0), 0, 0, _NOW, 6]);
        _expectScheduleStopRevert(_NOW + _M + 100, 12, IEtnaInbox.StopLocked.selector);
    }

    // ---------------------------------------------------------------
    // Callers (START-10.1-5c)
    // ---------------------------------------------------------------

    /// @dev 5c.a: both calls are owner-only and need an initialized Inbox.
    function test_schedule_RevertWhen_NotOwnerOrNotInitialized() external {
        vm.startPrank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        _inbox().scheduleRules(1, uint48(_NOW + _M));
        vm.expectRevert("Ownable: caller is not the owner");
        _inbox().scheduleStop(uint48(_NOW + _M), 6);
        vm.stopPrank();

        _deployFreshInbox(false);
        _inbox().upgradeTo(address(inboxImpl));
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().scheduleRules(1, uint48(_NOW + _M));
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().scheduleStop(uint48(_NOW + _M), 6);
    }

    // ---------------------------------------------------------------
    // recover (RECOV-8-47a)
    // ---------------------------------------------------------------

    /// @dev 47a.a: rules 0 clears the stop and keeps the pending ruleset.
    function test_recover_ClearsTheStopAndKeepsThePendingRuleset() external {
        uint256 t = _NOW + 3600;
        _plant([uint256(1), 2, t, _NOW + 60, 6]);
        _recover(0, [uint256(1), 2, t, 0, 0]);
    }

    /// @dev 47a.b: a non-zero rules runs the new generation on it from its first block.
    function test_recover_InstallsTheNextRuleset() external {
        _plant([uint256(1), 2, _NOW + 3600, _NOW + 60, 6]);
        _recover(3, [uint256(3), 3, 0, 0, 0]);
    }

    /// @dev 47a.c, 47a.d: a non-zero rules must be nextRules + 1; the whole recovery reverts.
    function test_recover_RevertWhen_RulesIsNotNextPlusOne() external {
        _plant([uint256(1), 2, _NOW + 3600, 0, 0]);
        _expectRecoverRevert(2);
        _expectRecoverRevert(4);
        _plant([uint256(0), _MAX, _MAX, 0, 0]);
        _expectRecoverRevert(_MAX);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The packed slot 293 word of `_s` = (activeRules, nextRules, rulesTime, stopTime,
    /// stopGrid).
    function _pack(uint256[5] memory _s) private pure returns (uint256) {
        return _s[0] | _s[1] << 48 | _s[2] << 96 | _s[3] << 144 | _s[4] << 192;
    }

    function _plant(uint256[5] memory _s) private {
        _storeInboxWord(RULES_SCHEDULE_SLOT, bytes32(_pack(_s)));
    }

    /// @dev Checks `rulesSchedule()` and slot 293 against `_s`.
    function _assertSchedule(uint256[5] memory _s) private view {
        IEtnaInbox.RulesSchedule memory schedule = _inbox().rulesSchedule();
        assertEq(schedule.activeRules, _s[0], "activeRules");
        assertEq(schedule.nextRules, _s[1], "nextRules");
        assertEq(schedule.rulesTime, _s[2], "rulesTime");
        assertEq(schedule.stopTime, _s[3], "stopTime");
        assertEq(schedule.stopGrid, _s[4], "stopGrid");
        assertEq(uint256(_inboxWord(RULES_SCHEDULE_SLOT)), _pack(_s), "slot 293");
    }

    function _scheduleRules(
        uint48 _rules,
        uint256 _time,
        uint256[5] memory _expected
    )
        private
    {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.RulesScheduleUpdated(_pack(_expected));
        _inbox().scheduleRules(_rules, uint48(_time));
        _assertSchedule(_expected);
    }

    function _scheduleStop(
        uint256 _time,
        uint48 _grid,
        uint256[5] memory _expected
    )
        private
    {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.RulesScheduleUpdated(_pack(_expected));
        _inbox().scheduleStop(uint48(_time), _grid);
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
        vm.expectRevert(_selector);
        _inbox().scheduleRules(_rules, uint48(_time));
        assertEq(_inboxWord(RULES_SCHEDULE_SLOT), before, "slot 293 unchanged");
    }

    function _expectScheduleStopRevert(
        uint256 _time,
        uint48 _grid,
        bytes4 _selector
    )
        private
    {
        bytes32 before = _inboxWord(RULES_SCHEDULE_SLOT);
        vm.expectRevert(_selector);
        _inbox().scheduleStop(uint48(_time), _grid);
        assertEq(_inboxWord(RULES_SCHEDULE_SLOT), before, "slot 293 unchanged");
    }

    /// @dev The owner recovers at c = 0 with `_rules`, expecting `RulesScheduleUpdated` with
    /// `_expected`.
    function _recover(uint48 _rules, uint256[5] memory _expected) private {
        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.RulesScheduleUpdated(_pack(_expected));
        _inbox().recover(0, 0, 0, _NOW, _noExclusions(), new uint256[](0), _rules);
        assertEq(_inbox().recoveryGeneration(), 1, "recovered");
        _assertSchedule(_expected);
    }

    function _expectRecoverRevert(uint48 _rules) private {
        bytes32 before = _inboxWord(RULES_SCHEDULE_SLOT);
        vm.expectRevert(IEtnaInbox.InvalidRules.selector);
        _inbox().recover(0, 0, 0, _NOW, _noExclusions(), new uint256[](0), _rules);
        assertEq(_inboxWord(RULES_SCHEDULE_SLOT), before, "slot 293 unchanged");
        assertEq(_inbox().recoveryGeneration(), 0, "no recovery");
    }
}
