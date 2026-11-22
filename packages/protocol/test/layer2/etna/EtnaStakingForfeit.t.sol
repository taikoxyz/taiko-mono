// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { EtnaVoteKeys } from "./EtnaVoteKeys.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibCometVote } from "src/layer2/etna/libs/LibCometVote.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @dev Responsibility forfeiture by the staking owner, the DAO's execution address on L2, and
/// how it combines with top-ups, withdrawals and double-sign slashing. Every test starts at L2
/// block 110 with bond 0 registered by Alice at block 100 with `MIN_STAKE` in seat 0, and the
/// default forfeiture rate of 1000 bps.
contract EtnaStakingForfeitTest is EtnaStakingTestBase {
    /// @dev Consensus private keys.
    uint256 private constant _PK = 0xC0A;
    uint256 private constant _PK_B = 0xC0B;
    uint256 private constant _PK_C = 0xC0C;
    uint256 private constant _PK_D = 0xC0D;
    /// @dev The keys that fill seats are `_FILLER_KEYS + i`.
    uint256 private constant _FILLER_KEYS = 0x1000;

    /// @dev The incident id the DAO publishes.
    bytes32 private constant _INCIDENT = keccak256("incident");

    /// @dev 1000 bps of `MIN_STAKE` (7,812,500 ether), and what it leaves.
    uint256 private constant _PENALTY = 781_250 ether;
    uint256 private constant _REMAINDER = 7_031_250 ether;

    /// @dev What a double sign of a bond of `MIN_STAKE` sends to slashSink, after the bounty.
    uint256 private constant _SLASH_TO_SINK = 7_031_250 ether;

    function setUp() public override {
        super.setUp();
        vm.roll(100);
        assertEq(_register(_PK, Alice, MIN_STAKE), 0, "bond 0");
        vm.roll(110);
    }

    // ---------------------------------------------------------------
    // Authority and deadline
    // ---------------------------------------------------------------

    /// @dev Only the staking owner may forfeit: neither the bond owner, nor a stranger, nor the
    /// system caller.
    function test_forfeit_RevertWhen_NotOwner() external {
        address[3] memory callers = [Alice, Bob, SYSTEM_CALLER];
        for (uint256 i; i < callers.length; ++i) {
            vm.expectRevert("Ownable: caller is not the owner");
            vm.prank(callers[i]);
            staking.forfeit(0, _INCIDENT, block.timestamp);
        }
        assertFalse(staking.forfeited(0), "not forfeited");
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "stake unchanged");
        assertEq(token.balanceOf(SLASH_SINK), 0, "nothing paid");
    }

    /// @dev `validUntil` is an inclusive deadline in L2 seconds: one second past it the call
    /// reverts and changes nothing, at it the forfeiture executes.
    function test_forfeit_ValidUntilIsInclusive() external {
        vm.warp(1000);
        vm.expectRevert(IEtnaStaking.AuthorizationExpired.selector);
        vm.prank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT, block.timestamp - 1);
        assertFalse(staking.forfeited(0), "expired: not forfeited");
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "expired: stake unchanged");

        vm.prank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT, block.timestamp);
        assertTrue(staking.forfeited(0), "forfeited at the deadline");
        assertEq(token.balanceOf(SLASH_SINK), _PENALTY, "penalty paid");
    }

    // ---------------------------------------------------------------
    // Execution
    // ---------------------------------------------------------------

    /// @dev Bond 1 in seat 1 stakes m + 1. At 1000 bps it loses ceil((m + 1) / 10) = m / 10 + 1,
    /// all of it to slashSink with no bounty. The call sets the lifetime flag and an exit at the
    /// current block, releases seat 1 and clears the key-to-seat word, and emits `Forfeited` with
    /// the balance before the deduction, then `SeatReleased`.
    function test_forfeit_DeductsCeilFlagsExitsAndReleases() external {
        uint256 stake = MIN_STAKE + 1;
        uint256 penalty = MIN_STAKE / 10 + 1;
        assertEq(_register(_PK_B, Bob, stake), 1, "bond 1");
        address ckAddr = EtnaTestKeys.ckAddr(_PK_B);
        assertEq(_keySeatWord(ckAddr), bytes32(uint256(0x0101)), "seat 1 before");

        vm.recordLogs();
        vm.expectEmit(address(staking));
        emit IEtnaStaking.Forfeited(1, _INCIDENT, stake, penalty);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.SeatReleased(1, 1);
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(staking), SLASH_SINK, penalty);
        _forfeit(1);
        assertEq(_logsFrom(vm.getRecordedLogs(), address(staking)), 2, "two staking events");

        IEtnaStaking.Bond memory bond = staking.bondAt(1);
        assertEq(bond.effStake, stake - penalty, "ceil deducted");
        assertEq(bond.exitHeight, block.number, "exit set now");
        assertFalse(bond.holdsSeat, "no seat");
        assertEq(bond.owner, Bob, "owner kept");
        assertFalse(bond.withdrawn, "not withdrawn");
        assertTrue(staking.forfeited(1), "flag set");
        assertFalse(staking.forfeited(0), "bond 0 untouched");
        _assertSeatOfBond(1, false, 0, "bond 1");
        _assertBondInSeat(1, false, 0, "seat 1");
        assertEq(_keySeatWord(ckAddr), bytes32(0), "key-to-seat word cleared");
        _assertBondForKey(ckAddr, true, 1, "key registration kept");
        assertEq(token.balanceOf(SLASH_SINK), penalty, "penalty to the sink");
        assertEq(token.balanceOf(STAKING_OWNER), 0, "no bounty");
        assertEq(token.balanceOf(address(staking)), MIN_STAKE + stake - penalty, "rest held");
    }

    /// @dev An exit set earlier keeps its height, so the withdrawal delay is not restarted; the
    /// bond, which holds no seat, releases none. The owner withdraws the rest when the delay from
    /// the earlier exit has passed, and the flag survives the withdrawal.
    function test_forfeit_KeepsAnEarlierExitHeight() external {
        _requestExit(0);
        vm.roll(150);
        vm.recordLogs();
        vm.expectEmit(address(staking));
        emit IEtnaStaking.Forfeited(0, _INCIDENT, MIN_STAKE, _PENALTY);
        _forfeit(0);
        assertEq(_logsFrom(vm.getRecordedLogs(), address(staking)), 1, "no seat event");
        assertEq(staking.bondAt(0).exitHeight, 110, "earlier exit kept");

        vm.roll(110 + WITHDRAWAL_DELAY - 1);
        vm.expectRevert(IEtnaStaking.WithdrawalNotReady.selector);
        vm.prank(Alice);
        staking.withdraw(0, Carol);

        vm.roll(110 + WITHDRAWAL_DELAY);
        vm.prank(Alice);
        staking.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), _REMAINDER, "the rest withdrawn");
        assertTrue(staking.forfeited(0), "withdrawal does not clear the flag");
    }

    /// @dev Top-ups made before execution are part of the forfeited balance: with 2,500,000
    /// ether topped up, 1000 bps of 10,312,500 ether goes to slashSink.
    function test_forfeit_IncludesTopUpsBeforeExecution() external {
        _deposit(2_500_000 ether);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.Forfeited(0, _INCIDENT, 10_312_500 ether, 1_031_250 ether);
        _forfeit(0);
        assertEq(staking.bondAt(0).effStake, 9_281_250 ether, "the rest of both");
        assertEq(token.balanceOf(SLASH_SINK), 1_031_250 ether, "penalty on both");
        assertEq(token.balanceOf(Bob), 0, "no bounty");
    }

    /// @dev The remainder of a forfeited bond follows the normal withdrawal rules: only its owner
    /// can withdraw it, to any recipient, once the delay has passed.
    function test_forfeit_RemainderStillNeedsTheOwnerToWithdraw() external {
        _forfeit(0);
        vm.roll(110 + WITHDRAWAL_DELAY);
        vm.expectRevert(IEtnaStaking.NotBondOwner.selector);
        vm.prank(Bob);
        staking.withdraw(0, Bob);
        vm.prank(Alice);
        staking.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), _REMAINDER, "the rest to the owner's recipient");
        assertTrue(staking.forfeited(0), "flag kept");
    }

    /// @dev An incident id may name several bonds, and a generation change does not cancel an
    /// authorization: after the block-start call stores generation 10, the same incident
    /// forfeits bond 0 and bond 1, which already has an exit.
    function test_forfeit_IncidentIdMayRepeatAcrossBondsAndGenerationChangeDoesNotCancel()
        external
    {
        assertEq(_register(_PK_B, Bob, MIN_STAKE), 1, "bond 1");
        _requestExit(1);
        uint256 validUntil = block.timestamp + 1 days;
        _blockStart(10, 0);
        assertEq(staking.lastGeneration(), 10, "generation changed");

        vm.startPrank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT, validUntil);
        staking.forfeit(1, _INCIDENT, validUntil);
        vm.stopPrank();
        assertTrue(staking.forfeited(0), "bond 0");
        assertTrue(staking.forfeited(1), "bond 1");
        assertEq(token.balanceOf(SLASH_SINK), 2 * _PENALTY, "both penalties");
    }

    /// @dev A withdrawal that comes first leaves nothing to forfeit (`BondWithdrawn`); a
    /// forfeiture that comes first leaves the owner the rest.
    function test_forfeit_WithdrawFirstRejectsAndForfeitFirstPaysOnlyRemainder() external {
        _requestExit(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        uint256 snapshot = vm.snapshotState();
        vm.prank(Alice);
        staking.withdraw(0, Carol);
        vm.expectRevert(IEtnaStaking.BondWithdrawn.selector);
        vm.prank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT, block.timestamp);
        assertFalse(staking.forfeited(0), "withdrawn first: no flag");
        assertEq(token.balanceOf(Carol), MIN_STAKE, "withdrawn first: all to the owner");
        vm.revertToState(snapshot);

        _forfeit(0);
        vm.prank(Alice);
        staking.withdraw(0, Carol);
        assertEq(token.balanceOf(Carol), _REMAINDER, "forfeited first: the rest");
        assertEq(token.balanceOf(SLASH_SINK), _PENALTY, "forfeited first: the penalty");
    }

    // ---------------------------------------------------------------
    // Rejected forfeitures
    // ---------------------------------------------------------------

    /// @dev In the order the contract checks them: an unissued id (`UnknownBond`), a withdrawn
    /// bond (`BondWithdrawn`), even one whose seat another bond took, a bond already forfeited
    /// (`AlreadyForfeited`, for any incident), an expired deadline (`AuthorizationExpired`) and a
    /// bond a double sign emptied (`NothingToForfeit`). An expired deadline does not mask the
    /// earlier checks. None of them writes the flag or pays anything.
    function test_forfeit_RevertWhen_RepeatedZeroOrWithdrawn() external {
        uint256 expired = block.timestamp - 1;

        // Bond 0 is forfeited; a second forfeiture fails, under any incident id.
        _forfeit(0);
        _assertForfeitReverts(0, block.timestamp, IEtnaStaking.AlreadyForfeited.selector, "again");
        _assertForfeitReverts(0, expired, IEtnaStaking.AlreadyForfeited.selector, "again, expired");
        vm.expectRevert(IEtnaStaking.AlreadyForfeited.selector);
        vm.prank(STAKING_OWNER);
        staking.forfeit(0, keccak256("other incident"), block.timestamp);

        // Bond 1 is emptied by a double sign: nothing is left, and an exit is set.
        assertEq(_register(_PK_B, Bob, MIN_STAKE), 1, "bond 1");
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_PK_B);
        vm.prank(Carol);
        staking.slashDoubleSign(1, a, b);
        _assertForfeitReverts(1, block.timestamp, IEtnaStaking.NothingToForfeit.selector, "zero");
        _assertForfeitReverts(1, expired, IEtnaStaking.AuthorizationExpired.selector, "zero, late");

        // Bond 2 is withdrawn and bond 3 takes its seat.
        assertEq(_register(_PK_C, Carol, MIN_STAKE), 2, "bond 2");
        _assertSeatOfBond(2, true, 0, "bond 2 in seat 0");
        _requestExit(2);
        assertEq(_register(_PK_D, David, MIN_STAKE), 3, "bond 3");
        _assertSeatOfBond(3, true, 0, "bond 3 takes seat 0");
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Carol);
        staking.withdraw(2, Carol);
        _assertForfeitReverts(2, block.timestamp, IEtnaStaking.BondWithdrawn.selector, "withdrawn");
        _assertForfeitReverts(2, expired, IEtnaStaking.BondWithdrawn.selector, "withdrawn, late");

        // Ids 4 and 2^256 - 1 were never issued.
        _assertForfeitReverts(4, block.timestamp, IEtnaStaking.UnknownBond.selector, "next id");
        _assertForfeitReverts(
            type(uint256).max, block.timestamp, IEtnaStaking.UnknownBond.selector, "max"
        );
        _assertForfeitReverts(4, expired, IEtnaStaking.UnknownBond.selector, "next id, late");

        assertEq(token.balanceOf(SLASH_SINK), _PENALTY + _SLASH_TO_SINK, "paid once each");
        assertEq(staking.bondAt(3).effStake, MIN_STAKE, "bond 3 untouched");
        assertFalse(staking.forfeited(3), "bond 3 not forfeited");
        assertEq(staking.bondCount(), 4, "no bond issued");
    }

    /// @dev A failing penalty transfer reverts every earlier write: the flag, the balance, the
    /// exit and the seat.
    function test_forfeit_RevertWhen_TokenTransferFails() external {
        vm.mockCallRevert(
            address(token),
            abi.encodeCall(IERC20.transfer, (SLASH_SINK, _PENALTY)),
            abi.encodeWithSignature("Error(string)", "sink rejected")
        );
        vm.expectRevert("sink rejected");
        vm.prank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT, block.timestamp);
        _assertUntouched("transfer failed");
    }

    // ---------------------------------------------------------------
    // Seats
    // ---------------------------------------------------------------

    /// @dev A forfeiture in block X releases the seat and zeroes the key-to-seat word in X, but
    /// X's snapshot stays as X's block-start call wrote it; X + 1's call drops the record and the
    /// stake from the total.
    function test_forfeit_SeatChangesLiveRecordsAtNextCall() external {
        assertEq(_register(_PK_B, Bob, 2 * MIN_STAKE), 1, "bond 1 in seat 1");
        _blockStart(0, 0);
        uint256 x = block.number;
        (, bytes32 ckX) = EtnaTestKeys.fallbackKey(_PK);
        assertEq(bytes32(_word(3)), ckX, "record 0 holds bond 0 at X");
        assertEq(_word(1), 3 * MIN_STAKE, "total at X");

        _forfeit(0);
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_PK)), bytes32(0), "key word zero in X");
        _assertBondInSeat(0, false, 0, "seat 0 empty in X");
        assertEq(bytes32(_word(3)), ckX, "record 0 unchanged in X");
        assertEq(_word(1), 3 * MIN_STAKE, "total unchanged in X");
        assertEq(_word(0), x, "height X");

        _blockStart(0, 0);
        assertEq(_word(3), 0, "record 0 word 1 cleared at X + 1");
        assertEq(_word(4), 0, "record 0 word 2 cleared at X + 1");
        assertEq(_word(1), 2 * MIN_STAKE, "total without bond 0 at X + 1");
        assertEq(_word(0), x + 1, "height X + 1");
    }

    /// @dev The lifetime flag is keyed by bond id: bond 1, which takes the seat that bond 0's
    /// forfeiture released, starts unforfeited and can be forfeited on its own.
    function test_forfeit_NewBondInReleasedSeatHasItsOwnFlag() external {
        _forfeit(0);
        assertEq(_register(_PK_B, Bob, MIN_STAKE), 1, "bond 1");
        _assertSeatOfBond(1, true, 0, "bond 1 takes seat 0");
        assertTrue(staking.forfeited(0), "the former bond keeps its flag");
        assertFalse(staking.forfeited(1), "the new bond has its own flag");
        _assertSeatOfBond(0, false, 0, "a forfeited bond never holds a seat again");

        _forfeit(1);
        assertTrue(staking.forfeited(1), "bond 1 forfeited on its own");
        assertEq(token.balanceOf(SLASH_SINK), 2 * _PENALTY, "two penalties");
    }

    /// @dev With every seat held a registration finds none. A forfeiture at the full rate of
    /// 10,000 bps takes all of bond 0's stake and releases seat 0, which the next registration
    /// takes.
    function test_forfeit_FullRateFreesTheSeatOfAFullTable() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.forfeitBps = 10_000;
        staking = _deploy(cfg);
        assertEq(_register(_PK, Alice, MIN_STAKE), 0, "bond 0");
        for (uint256 i = 1; i < N_MAX; ++i) {
            _register(_FILLER_KEYS + i, Carol, MIN_STAKE);
        }
        _fund(Bob, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_PK_B);
        bytes memory pop = EtnaVoteKeys.popSig(_PK_B, staking, Bob);
        vm.expectRevert(IEtnaStaking.NoEmptySeat.selector);
        vm.prank(Bob);
        staking.register(publicKey, MIN_STAKE, pop);

        _forfeit(0);
        assertEq(staking.bondAt(0).effStake, 0, "all stake forfeited");
        assertEq(token.balanceOf(SLASH_SINK), MIN_STAKE, "all to the sink");
        _assertBondInSeat(0, false, 0, "seat 0 released");

        vm.prank(Bob);
        assertEq(staking.register(publicKey, MIN_STAKE, pop), N_MAX, "the next bond");
        _assertSeatOfBond(N_MAX, true, 0, "it takes seat 0");
    }

    // ---------------------------------------------------------------
    // Combined with double-sign slashing
    // ---------------------------------------------------------------

    /// @dev Votes signed before a top-up are evidence against the whole stake, the top-up
    /// included. The slash leaves nothing to forfeit and sets an exit, so no top-up follows.
    function test_slashDoubleSign_TakesLaterTopUpsAndBlocksLaterForfeit() external {
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_PK);
        _deposit(7 ether);
        vm.prank(Bob);
        staking.slashDoubleSign(0, a, b);
        assertEq(token.balanceOf(Bob), 781_250.7 ether, "bounty on both");
        assertEq(token.balanceOf(SLASH_SINK), 7_031_256.3 ether, "the rest of both");
        assertEq(staking.bondAt(0).effStake, 0, "nothing left");

        vm.expectRevert(IEtnaStaking.NothingToForfeit.selector);
        vm.prank(STAKING_OWNER);
        staking.forfeit(0, _INCIDENT, block.timestamp);
        assertFalse(staking.forfeited(0), "no flag");
        _fund(Alice, 1);
        vm.expectRevert(IEtnaStaking.ExitAlreadySet.selector);
        vm.prank(Alice);
        staking.topUp(0, 1);
    }

    /// @dev After a forfeiture, valid double-sign evidence still takes all that remains, and the
    /// flag stays.
    function test_slashDoubleSign_AfterForfeitTakesTheRemainder() external {
        _deposit(2_500_000 ether);
        _forfeit(0);
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_PK);
        vm.prank(Bob);
        staking.slashDoubleSign(0, a, b);
        assertEq(staking.bondAt(0).effStake, 0, "nothing left");
        assertEq(token.balanceOf(Bob), 928_125 ether, "bounty on the rest");
        assertEq(token.balanceOf(SLASH_SINK), 9_384_375 ether, "penalty and the rest");
        assertTrue(staking.forfeited(0), "flag kept");
    }

    // ---------------------------------------------------------------
    // Reentrancy
    // ---------------------------------------------------------------

    /// @dev A token that re-enters from the transfers of `slashDoubleSign` or `forfeit`, into
    /// `slashDoubleSign` or another entry point, hits the staking contract's lock, and the outer
    /// call changes nothing: no stake moves, no flag, exit or seat changes, and nothing is paid.
    /// (A re-entered `forfeit` would fail its owner check first, since the token is not the
    /// owner.)
    function test_slashAndForfeit_RevertWhen_Reentered() external {
        ReentrantERC20 reentrant = new ReentrantERC20();
        IEtnaStaking.Config memory cfg = _config();
        cfg.token = address(reentrant);
        staking = _deploy(cfg);
        reentrant.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        reentrant.approve(address(staking), type(uint256).max);
        bytes memory publicKey = EtnaTestKeys.publicKey(_PK);
        bytes memory pop = EtnaVoteKeys.popSig(_PK, staking, Alice);
        vm.prank(Alice);
        staking.register(publicKey, MIN_STAKE, pop);
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_PK);

        bytes[3] memory reentries = [
            abi.encodeCall(staking.slashDoubleSign, (0, a, b)),
            abi.encodeCall(staking.requestExit, (0)),
            abi.encodeCall(staking.topUp, (0, 1))
        ];
        string[3] memory labels = ["slashDoubleSign", "requestExit", "topUp"];
        for (uint256 i; i < reentries.length; ++i) {
            reentrant.armReentry(address(staking), reentries[i]);
            vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
            vm.prank(Bob);
            staking.slashDoubleSign(0, a, b);
            _assertUntouched(string.concat("slash re-entering ", labels[i]));

            reentrant.armReentry(address(staking), reentries[i]);
            vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
            vm.prank(STAKING_OWNER);
            staking.forfeit(0, _INCIDENT, block.timestamp);
            _assertUntouched(string.concat("forfeit re-entering ", labels[i]));
        }
        assertEq(reentrant.balanceOf(address(staking)), MIN_STAKE, "stake held");
        assertEq(reentrant.balanceOf(Bob), 0, "no bounty");
        assertEq(reentrant.balanceOf(SLASH_SINK), 0, "nothing to the sink");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The staking owner forfeits `_bondId` under `_INCIDENT`, valid until now.
    function _forfeit(uint256 _bondId) private {
        vm.prank(STAKING_OWNER);
        staking.forfeit(_bondId, _INCIDENT, block.timestamp);
    }

    /// @dev Alice tops bond 0 up by `_amount`.
    function _deposit(uint256 _amount) private {
        _fund(Alice, _amount);
        vm.prank(Alice);
        staking.topUp(0, _amount);
    }

    /// @dev Asserts that the staking owner's forfeiture of `_bondId` valid until `_validUntil`
    /// reverts with `_error` and leaves the bond's flag unset or, if already set, set.
    function _assertForfeitReverts(
        uint256 _bondId,
        uint256 _validUntil,
        bytes4 _error,
        string memory _label
    )
        private
    {
        bool flagged = staking.forfeited(_bondId);
        uint256 sinkBefore = token.balanceOf(SLASH_SINK);
        vm.prank(STAKING_OWNER);
        try staking.forfeit(_bondId, _INCIDENT, _validUntil) {
            assertTrue(false, string.concat(_label, ": forfeited"));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(_error), _label);
        }
        assertEq(staking.forfeited(_bondId), flagged, string.concat(_label, ": flag"));
        assertEq(token.balanceOf(SLASH_SINK), sinkBefore, string.concat(_label, ": nothing paid"));
    }

    /// @dev Asserts that bond 0 is as registered: unforfeited with all of `MIN_STAKE`, no exit
    /// and seat 0, with its key-to-seat word set.
    function _assertUntouched(string memory _label) private view {
        IEtnaStaking.Bond memory bond = staking.bondAt(0);
        assertFalse(staking.forfeited(0), string.concat(_label, ": no flag"));
        assertEq(bond.effStake, MIN_STAKE, string.concat(_label, ": stake"));
        assertEq(bond.exitHeight, NO_EXIT, string.concat(_label, ": no exit"));
        assertTrue(bond.holdsSeat && bond.seat == 0, string.concat(_label, ": seat 0"));
        assertEq(
            _keySeatWord(EtnaTestKeys.ckAddr(_PK)),
            bytes32(uint256(0x0001)),
            string.concat(_label, ": key-to-seat word")
        );
    }

    /// @dev Two generation-0 precommits for different blocks at the same height and round,
    /// signed by `_pk` under the chain id of the base's deployment.
    function _conflict(uint256 _pk)
        private
        pure
        returns (IEtnaStaking.Vote memory a_, IEtnaStaking.Vote memory b_)
    {
        bytes memory chainId =
            LibCometVote.chainId(LibCometVote.chainDomain(L1_CHAIN_ID, L2_CHAIN_ID, INBOX, 0));
        a_ = EtnaVoteKeys.signVote(_pk, _precommit(keccak256("block a")), chainId);
        b_ = EtnaVoteKeys.signVote(_pk, _precommit(keccak256("block b")), chainId);
    }

    /// @dev A generation-0 precommit at height 1000, round 3, for `_blockHash` with a one-part
    /// part set header.
    function _precommit(bytes32 _blockHash) private pure returns (IEtnaStaking.Vote memory v_) {
        v_.voteType = 2;
        v_.height = 1000;
        v_.round = 3;
        v_.blockHash = abi.encodePacked(_blockHash);
        v_.partsTotal = 1;
        v_.partsHash = abi.encodePacked(keccak256(abi.encode(_blockHash)));
        v_.timestampSeconds = 1_700_000_000;
    }

    /// @dev Returns the word at T + `_offset`.
    function _word(uint256 _offset) private view returns (uint256) {
        return uint256(vm.load(address(staking), bytes32(uint256(T) + _offset)));
    }

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
