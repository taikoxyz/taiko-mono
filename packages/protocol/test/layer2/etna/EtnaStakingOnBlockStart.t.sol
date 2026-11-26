// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @dev The block-start call: miss counting, missed-signature penalties, seat releases and the
/// candidate snapshot. The penalty cases scale the spec's small examples by m = minStake =
/// 7,812,500 TAIKO, the least minStake the constructor allows with 128 seats.
contract EtnaStakingOnBlockStartTest is EtnaStakingTestBase {
    /// @dev Consensus private keys: K_i is the key of private key i. K9's prefix is 0x03.
    uint256 private constant _K1 = 1;
    uint256 private constant _K2 = 2;
    uint256 private constant _K3 = 3;
    uint256 private constant _K9 = 9;

    /// @dev minStake.
    uint256 private constant _M = MIN_STAKE;

    /// @dev The least minStake with 64 seats, ceil(10^27 / 64), which is 2m.
    uint256 private constant _M64 = 2 * MIN_STAKE;

    /// @dev The stakes `_seatZeroTwoFive` seats in seats 0, 2 and 5.
    uint256 private constant _STAKE0 = MIN_STAKE;
    uint256 private constant _STAKE2 = 2 * MIN_STAKE + 5;
    uint256 private constant _STAKE5 = 3 * MIN_STAKE + VP_UNIT - 1;

    /// @dev The gas the execution layer gives the call's frame.
    uint256 private constant _FRAME_GAS = 30_000_000;

    /// @dev The number of staking words at fixed slots, T to T + 398: the snapshot words, the
    /// seat table, the miss counts, the occupancy bitmap and the stored generation.
    uint256 private constant _FIXED_WORDS = 399;

    /// @dev The number of snapshot words, T to T + 258: the height, the total and the records.
    uint256 private constant _SNAPSHOT_WORDS = 259;

    bytes32 private constant _TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");

    // ---------------------------------------------------------------
    // Caller and calldata
    // ---------------------------------------------------------------

    function test_onBlockStart_RevertWhen_NotSystemCaller() external {
        address[3] memory callers = [Alice, STAKING_OWNER, address(staking)];
        for (uint256 i; i < callers.length; ++i) {
            vm.expectRevert(IEtnaStaking.NotSystemCaller.selector);
            vm.prank(callers[i]);
            staking.onBlockStart(1, 0);
        }
        assertEq(staking.lastGeneration(), 0, "no generation stored");
        assertEq(_word(0), 0, "no snapshot written");
    }

    /// @dev The execution layer's 68-byte calldata, the selector followed by both arguments as
    /// 32-byte words, decodes to the generation and the miss bitmap.
    function test_onBlockStart_AcceptsTheSpecCalldata() external {
        for (uint256 pk = 11; pk < 14; ++pk) {
            _register(pk, Bob, 2 * _M);
        }
        bytes memory data = abi.encodePacked(bytes4(0xea987592), uint256(3), uint256(4));
        assertEq(data.length, 68, "4 + 2 * 32 bytes");

        vm.prank(SYSTEM_CALLER);
        (bool ok,) = address(staking).call(data);
        assertTrue(ok, "the call succeeds");
        assertEq(staking.lastGeneration(), 3, "generation");
        assertEq(staking.missCount(2), 1, "bit 2 of the bitmap");
        assertEq(staking.missCount(0), 0, "seat 0 not missing");
        assertEq(staking.missCount(1), 0, "seat 1 not missing");
        assertEq(_word(0), block.number, "snapshot height");
    }

    function test_onBlockStart_StoresGenerationWithoutMonotonicity() external {
        _register(_K1, Bob, _M);
        _blockStart(3, 0);
        assertEq(staking.lastGeneration(), 3, "first");
        _blockStart(1, 0);
        assertEq(staking.lastGeneration(), 1, "a lower generation is stored as given");
        _blockStart(type(uint48).max, 0);
        assertEq(staking.lastGeneration(), type(uint48).max, "the largest generation");
        _blockStart(0, 0);
        assertEq(staking.lastGeneration(), 0, "zero");
        assertEq(_word(398), 1, "the occupancy bitmap shares the generation's word");
        _assertBondInSeat(0, true, 0, "seat kept");
    }

    // ---------------------------------------------------------------
    // Miss counting
    // ---------------------------------------------------------------

    function test_onBlockStart_CountsAndResetsMisses() external {
        for (uint256 pk = 11; pk < 15; ++pk) {
            _register(pk, Bob, 2 * _M);
        }
        _blockStart(0, 1 << 3);
        _blockStart(0, 1 << 3);
        assertEq(staking.missCount(3), 2, "seat 3 at count 2");
        _blockStart(0, 1 << 3);
        assertEq(staking.missCount(3), 3, "a set bit raises the count");
        _blockStart(0, 1 << 9);
        assertEq(staking.missCount(3), 0, "a clear bit resets the count");
        assertEq(staking.missCount(9), 0, "the bit of empty seat 9 counts nothing");
        _assertBondInSeat(9, false, 0, "seat 9 stays empty");
        _assertMissCounts([uint16(0), 0, 0, 0], "bit 9 changes no occupied seat");

        _blockStart(0, 0xf);
        _blockStart(0, 0xf);
        _assertMissCounts([uint16(2), 2, 2, 2], "every seat missing twice");
        _blockStart(0, 0);
        _assertMissCounts([uint16(0), 0, 0, 0], "a zero bitmap resets every count");
        _blockStart(0, 0xf);
        _blockStart(0, 4);
        _assertMissCounts([uint16(0), 0, 2, 0], "bitmap 4 counts only seat 2");

        IEtnaStaking.Config memory cfg = _config();
        cfg.nMax = 64;
        cfg.minStake = _M64;
        staking = _deploy(cfg);
        _register(_K1, Bob, _M64);
        _blockStart(0, 1);
        _blockStart(0, uint128(1) << 100 | 1);
        assertEq(staking.missCount(0), 2, "seat 0 counts");
        _blockStart(0, uint128(1) << 100);
        assertEq(staking.missCount(0), 0, "bit 100 is not seat 0's");
        for (uint8 seat = 1; seat < 128; ++seat) {
            assertEq(staking.missCount(seat), 0, "a bit at or above nMax counts nothing");
        }
    }

    /// @dev A seat that a bond leaves and another bond takes in the same block starts the new
    /// bond at count 0, and the records name the new bond only from the next block-start call.
    function test_onBlockStart_SeatVacatedAndRetakenInTheParentCarriesNoOldMisses() external {
        for (uint256 pk = 11; pk < 15; ++pk) {
            _register(pk, Bob, _M);
        }
        uint256 a = _register(_K1, Carol, _M);
        _blockStart(0, 1 << 4);
        _blockStart(0, 1 << 4);
        assertEq(staking.missCount(4), 2, "bond A in seat 4 at count 2");
        (, bytes32 xA) = EtnaTestKeys.fallbackKey(_K1);
        (, bytes32 xB) = EtnaTestKeys.fallbackKey(_K2);
        assertEq(bytes32(_word(3 + 2 * 4)), xA, "record 4 holds A");

        _requestExit(a);
        uint256 b = _register(_K2, David, _M);
        _assertSeatOfBond(b, true, 4, "B takes seat 4 in the same block");
        assertEq(staking.missCount(4), 0, "B starts at count 0");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(0), "A's key word is zero");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K2)), bytes32(uint256(0x0401)), "B's key word");
        assertEq(bytes32(_word(3 + 2 * 4)), xA, "record 4 still holds A within the block");

        _blockStart(0, 0);
        assertEq(staking.missCount(4), 0, "a clear bit leaves count 0");
        _assertRecord(4, _K2, _M / VP_UNIT, "record 4 holds B after the next call");
        assertEq(bytes32(_word(3 + 2 * 4)), xB, "record 4 word 1 is B's X");
        _blockStart(0, 1 << 4);
        assertEq(staking.missCount(4), 1, "B's own first miss");
    }

    // ---------------------------------------------------------------
    // Penalties
    // ---------------------------------------------------------------

    /// @dev missLimit 10 and missSlashBps 1000: a penalty is ceil(effStake / 10), taken when the
    /// count reaches 10, which the penalty leaves at 10, and all penalties of a call reach
    /// slashSink in one transfer.
    function test_onBlockStart_PenalizesAtMissLimitWithCeil() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 10;
        staking = _deploy(cfg);
        uint256 a = _register(_K1, Bob, 10 * _M);
        uint256 b = _register(_K2, Carol, 10 * _M + 1);
        uint256 c = _register(_K3, David, 2 * _M);
        for (uint256 i; i < 9; ++i) {
            _blockStart(0, 0x3);
        }
        assertEq(staking.missCount(0), 9, "count 9");
        assertEq(staking.bondAt(a).effStake, 10 * _M, "count 9 loses nothing");
        assertEq(staking.bondAt(b).effStake, 10 * _M + 1, "count 9 loses nothing either");
        assertEq(token.balanceOf(SLASH_SINK), 0, "nothing paid below the limit");

        vm.recordLogs();
        _blockStart(0, 0x3);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(staking.bondAt(a).effStake, 9 * _M, "10m loses exactly m");
        assertEq(staking.bondAt(b).effStake, 9 * _M, "10m + 1 loses m + 1");
        assertEq(staking.bondAt(c).effStake, 2 * _M, "a seat with no misses loses nothing");
        assertEq(staking.missCount(0), 10, "the count stays 10");
        assertEq(staking.missCount(1), 10, "the count stays 10 for B too");
        _assertSeatOfBond(a, true, 0, "A keeps its seat");
        _assertSeatOfBond(b, true, 1, "B keeps its seat");

        uint256 transfers;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(token) || logs[i].topics[0] != _TRANSFER_TOPIC) {
                continue;
            }
            ++transfers;
            assertEq(logs[i].topics[1], bytes32(uint256(uint160(address(staking)))), "from");
            assertEq(logs[i].topics[2], bytes32(uint256(uint160(SLASH_SINK))), "to slashSink");
            assertEq(abi.decode(logs[i].data, (uint256)), 2 * _M + 1, "the total");
        }
        assertEq(transfers, 1, "one transfer for both penalties");
        assertEq(_logsFrom(logs, address(staking)), 0, "the call emits no events");
        assertEq(token.balanceOf(SLASH_SINK), 2 * _M + 1, "slashSink receives the total");
        assertEq(token.balanceOf(address(staking)), 20 * _M, "the rest stays staked");
        assertEq(token.balanceOf(Bob), 0, "no bounty to A's owner");
        assertEq(token.balanceOf(Carol), 0, "no bounty to B's owner");
        assertEq(token.balanceOf(David), 0, "no bounty to C's owner");
        assertEq(token.balanceOf(SYSTEM_CALLER), 0, "no bounty to the caller");

        assertEq(_word(1), 20 * _M, "this call's snapshot holds the reduced stakes");
        _assertRecord(0, _K1, 9 * _M / VP_UNIT, "record 0");
        _assertRecord(1, _K2, 9 * _M / VP_UNIT, "record 1");
        _assertRecord(2, _K3, 2 * _M / VP_UNIT, "record 2");
    }

    /// @dev A penalty that leaves a bond below minStake releases its seat in the call without
    /// setting an exit, and the same call's snapshot leaves it out. The owner can then top up,
    /// taking the lowest empty seat, or request an exit.
    function test_onBlockStart_PenaltyBelowMinStakeReleasesSeatWithoutExit() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 1;
        staking = _deploy(cfg);
        uint256 a = _register(_K1, Bob, _M);
        uint256 b = _register(_K2, Carol, _M);
        uint256 c = _register(_K3, David, 2 * _M);

        _blockStart(1, 0x3);

        uint256 penalty = _M / 10;
        for (uint256 i; i < 2; ++i) {
            uint256 bondId = i == 0 ? a : b;
            IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
            assertEq(bond.effStake, _M - penalty, "loses 10%");
            assertEq(bond.exitHeight, NO_EXIT, "no exit set");
            assertFalse(bond.holdsSeat, "the record holds no seat");
            _assertSeatOfBond(bondId, false, 0, "seat released");
            _assertBondInSeat(uint8(i), false, 0, "the seat is empty");
            assertEq(staking.missCount(uint8(i)), 0, "the seat's count is reset");
            assertEq(
                _keySeatWord(EtnaTestKeys.ckAddr(i == 0 ? _K1 : _K2)), bytes32(0), "key word zero"
            );
            _assertEmptyRecord(i, "released in this call's snapshot");
        }
        _assertSeatOfBond(c, true, 2, "C keeps its seat");
        _assertRecord(2, _K3, 2 * _M / VP_UNIT, "record 2");
        assertEq(_word(1), 2 * _M, "the total leaves the released bonds out");
        assertEq(token.balanceOf(SLASH_SINK), 2 * penalty, "both penalties paid");

        // B tops up to minStake and takes the lowest empty seat, seat 0, not its old seat 1.
        _fund(Carol, penalty);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.TopUpDeposited(b, penalty);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.SeatTaken(b, 0);
        vm.prank(Carol);
        staking.topUp(b, penalty);
        _assertSeatOfBond(b, true, 0, "B re-seated");
        _assertBondInSeat(0, true, b, "seat 0 holds B");
        assertEq(
            _keySeatWord(EtnaTestKeys.ckAddr(_K2)),
            bytes32(uint256(0x0001)),
            "B's key word: holdsSeat 1, seat 0"
        );
        assertEq(staking.missCount(0), 0, "B starts at count 0");

        // A requests an exit instead, which only sets the exit height.
        vm.recordLogs();
        vm.expectEmit(address(staking));
        emit IEtnaStaking.ExitRequested(a, block.number);
        vm.prank(Bob);
        staking.requestExit(a);
        assertEq(_logsFrom(vm.getRecordedLogs(), address(staking)), 1, "no seat to release");
        assertEq(staking.bondAt(a).exitHeight, block.number, "exit at the current block");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(0), "A's key word stays zero");

        _blockStart(2, 0);
        _assertRecord(0, _K2, _M / VP_UNIT, "record 0 holds B");
        _assertEmptyRecord(1, "record 1");
        assertEq(_word(1), 3 * _M, "the total holds B and C");
    }

    function test_onBlockStart_MissLimitOnePenalizesAtOnce() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 1;
        staking = _deploy(cfg);
        uint256 a = _register(_K1, Bob, 2 * _M);

        _blockStart(1, 1);
        uint256 effStake = 2 * _M - 2 * _M / 10;
        assertEq(staking.bondAt(a).effStake, effStake, "the first miss is penalized");
        assertEq(staking.missCount(0), 1, "the count is not reset");
        _assertSeatOfBond(a, true, 0, "still at or above minStake");
        assertEq(token.balanceOf(SLASH_SINK), 2 * _M / 10, "penalty paid");
        assertEq(_word(1), effStake, "the snapshot holds the reduced stake");

        _blockStart(1, 1);
        assertEq(staking.bondAt(a).effStake, effStake - effStake / 10, "and again at count 2");
        assertEq(staking.missCount(0), 2, "count 2");
    }

    /// @dev missLimit 10 and missReleaseLimit 30: a seated bond well above minStake that misses
    /// 20 blocks in a row is penalized at counts 10 and 20, the second time on the stake the first
    /// left, and at no count from 11 to 19; the count is never reset by a penalty.
    function test_onBlockStart_PenalizesAtEveryMultipleOfMissLimit() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 10 * _M);
        uint256 c = _register(_K2, Carol, 2 * _M);
        uint256 stake = 10 * _M;
        uint256 paid;
        for (uint256 count = 1; count <= 20; ++count) {
            _blockStart(1, 1);
            if (count % 10 == 0) {
                paid += _penaltyOf(stake);
                stake -= _penaltyOf(stake);
            }
            assertEq(staking.missCount(0), count, "the count keeps rising");
            assertEq(staking.bondAt(a).effStake, stake, "penalized at multiples of 10 only");
            assertEq(token.balanceOf(SLASH_SINK), paid, "the sink holds the penalties so far");
        }
        assertEq(stake, 10 * _M - _M - 9 * _M / 10, "10m, then 9m, then 8.1m");
        _assertSeatOfBond(a, true, 0, "A keeps its seat");
        assertEq(staking.bondAt(c).effStake, 2 * _M, "a signing bond loses nothing");
        assertEq(staking.missCount(1), 0, "C's count");
    }

    /// @dev A count of 0 is not a multiple of missLimit, even of missLimit 1: a seat whose bit is
    /// 0 is never penalized.
    function test_onBlockStart_ZeroCountIsNeverPenalized() external {
        _deployMissLimits(1, 30);
        uint256 a = _register(_K1, Bob, 2 * _M);
        for (uint256 i; i < 5; ++i) {
            _blockStart(1, 0);
            assertEq(staking.missCount(0), 0, "count 0");
        }
        assertEq(staking.bondAt(a).effStake, 2 * _M, "no deduction");
        assertEq(token.balanceOf(SLASH_SINK), 0, "nothing paid");
    }

    /// @dev missLimit 10: after the penalty at count 10 a 0 bit resets the count, so the next
    /// penalty needs 10 further consecutive misses.
    function test_onBlockStart_ClearBitAfterPenaltyRestartsTheRun() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 10 * _M);
        _blockStarts(10, 1);
        assertEq(staking.missCount(0), 10, "count 10 after the penalty");
        assertEq(staking.bondAt(a).effStake, 9 * _M, "the first penalty");

        _blockStart(1, 0);
        assertEq(staking.missCount(0), 0, "a clear bit resets the count");
        assertEq(staking.bondAt(a).effStake, 9 * _M, "no deduction at count 0");
        _blockStarts(9, 1);
        assertEq(staking.missCount(0), 9, "count 9");
        assertEq(staking.bondAt(a).effStake, 9 * _M, "none below 10 further misses");
        _blockStart(1, 1);
        assertEq(staking.missCount(0), 10, "count 10 again");
        assertEq(staking.bondAt(a).effStake, 9 * _M - 9 * _M / 10, "the second penalty");
        assertEq(token.balanceOf(SLASH_SINK), _M + 9 * _M / 10, "two penalties paid");
    }

    function test_onBlockStart_FullSlashBpsTakesWholeStake() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 1;
        cfg.missSlashBps = 10_000;
        staking = _deploy(cfg);
        uint256 a = _register(_K1, Bob, 2 * _M);
        uint256 b = _register(_K2, Carol, 2 * _M);

        _blockStart(1, 1);
        IEtnaStaking.Bond memory bond = staking.bondAt(a);
        assertEq(bond.effStake, 0, "effStake zero");
        assertEq(bond.exitHeight, NO_EXIT, "no exit set");
        _assertSeatOfBond(a, false, 0, "seat released");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(0), "key word zero");
        _assertEmptyRecord(0, "record 0");
        assertEq(token.balanceOf(SLASH_SINK), 2 * _M, "the whole stake paid");
        _assertSeatOfBond(b, true, 1, "B kept");
        assertEq(_word(1), 2 * _M, "the total holds B only");
    }

    // ---------------------------------------------------------------
    // Releases at missReleaseLimit
    // ---------------------------------------------------------------

    /// @dev missLimit 10 and missReleaseLimit 30: at count 30 the bond, still above minStake, is
    /// penalized first and then releases its seat, with no exit set, nothing more deducted and no
    /// event; the release discards the count and the same call's snapshot leaves the bond out.
    function test_onBlockStart_ReleasesAtMissReleaseLimitAfterThePenalty() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 10 * _M);
        uint256 b = _register(_K2, Carol, 2 * _M);
        _blockStarts(29, 1);
        uint256 stake = 10 * _M - _M - 9 * _M / 10;
        assertEq(staking.bondAt(a).effStake, stake, "penalized at 10 and 20");
        assertEq(staking.missCount(0), 29, "count 29");
        _assertSeatOfBond(a, true, 0, "still seated at count 29");
        uint256 paidBefore = token.balanceOf(SLASH_SINK);

        vm.recordLogs();
        _blockStart(1, 1);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        IEtnaStaking.Bond memory bond = staking.bondAt(a);
        assertEq(bond.effStake, stake - _penaltyOf(stake), "the penalty of count 30 applies");
        assertGe(bond.effStake, _M, "the bond stays above minStake");
        assertEq(
            token.balanceOf(SLASH_SINK) - paidBefore, _penaltyOf(stake), "only that penalty paid"
        );
        assertEq(bond.exitHeight, NO_EXIT, "no exit set");
        assertFalse(bond.holdsSeat, "the record holds no seat");
        _assertSeatOfBond(a, false, 0, "seat released");
        _assertBondInSeat(0, false, 0, "seat 0 is empty");
        assertEq(staking.missCount(0), 0, "the count is discarded");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(0), "key word zero");
        _assertEmptyRecord(0, "released in this call's snapshot");
        _assertRecord(1, _K2, 2 * _M / VP_UNIT, "B in record 1");
        assertEq(_word(1), 2 * _M, "the total holds B only");
        _assertSeatOfBond(b, true, 1, "B keeps its seat");
        assertEq(_logsFrom(logs, address(staking)), 0, "the call emits no events");
    }

    /// @dev missLimit 10 and missReleaseLimit 25: at count 25, not a multiple of 10, the bond
    /// releases its seat with no deduction in that call.
    function test_onBlockStart_ReleasesAtMissReleaseLimitWithoutAPenalty() external {
        _deployMissLimits(10, 25);
        uint256 a = _register(_K1, Bob, 10 * _M);
        _blockStarts(24, 1);
        uint256 stake = 10 * _M - _M - 9 * _M / 10;
        assertEq(staking.bondAt(a).effStake, stake, "penalized at 10 and 20");
        uint256 paidBefore = token.balanceOf(SLASH_SINK);

        _blockStart(1, 1);
        assertEq(staking.bondAt(a).effStake, stake, "nothing deducted at count 25");
        assertEq(token.balanceOf(SLASH_SINK), paidBefore, "nothing paid at count 25");
        _assertSeatOfBond(a, false, 0, "seat released");
        assertEq(staking.bondAt(a).exitHeight, NO_EXIT, "no exit set");
        assertEq(staking.missCount(0), 0, "the count is discarded");
        _assertSnapshotEmpty("no seat left");
    }

    /// @dev missReleaseLimit 30: a 0 bit at count 29 resets the count and the bond keeps its seat;
    /// 29 further misses still do not release it.
    function test_onBlockStart_ClearBitBeforeMissReleaseLimitKeepsTheSeat() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 10 * _M);
        _blockStarts(29, 1);
        _blockStart(1, 0);
        assertEq(staking.missCount(0), 0, "the count resets");
        _assertSeatOfBond(a, true, 0, "the bond keeps its seat");
        _blockStarts(29, 1);
        assertEq(staking.missCount(0), 29, "count 29 again");
        _assertSeatOfBond(a, true, 0, "still seated");
    }

    /// @dev missLimit = missReleaseLimit = 10: at count 10 one call deducts the penalty and then
    /// releases the seat.
    function test_onBlockStart_EqualLimitsPenalizeThenReleaseInOneCall() external {
        _deployMissLimits(10, 10);
        uint256 a = _register(_K1, Bob, 10 * _M);
        _blockStarts(9, 1);
        _assertSeatOfBond(a, true, 0, "seated at count 9");

        _blockStart(1, 1);
        assertEq(staking.bondAt(a).effStake, 9 * _M, "one deduction");
        assertEq(token.balanceOf(SLASH_SINK), _M, "one penalty paid");
        _assertSeatOfBond(a, false, 0, "then the release");
        assertEq(staking.bondAt(a).exitHeight, NO_EXIT, "no exit set");
        _assertEmptyRecord(0, "released in this call's snapshot");
    }

    /// @dev missReleaseLimit 30: the penalty at count 20 leaves a bond of 1.2m below minStake, so
    /// it releases its seat then, and the release limit is never reached for it. With
    /// missReleaseLimit 20 both reasons hold in the same call and the seat is released once,
    /// touching no other seat.
    function test_onBlockStart_PenaltyBelowMinStakeReleasesBeforeTheLimit() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 6 * _M / 5);
        uint256 b = _register(_K2, Carol, 2 * _M);
        _blockStarts(19, 1);
        uint256 stake = 6 * _M / 5 - _penaltyOf(6 * _M / 5);
        assertEq(staking.bondAt(a).effStake, stake, "penalized at 10, still at or above m");
        _assertSeatOfBond(a, true, 0, "seated at count 19");

        _blockStart(1, 1);
        stake -= _penaltyOf(stake);
        assertLt(stake, _M, "the penalty at 20 leaves the bond below m");
        assertEq(staking.bondAt(a).effStake, stake, "the second penalty");
        _assertSeatOfBond(a, false, 0, "released by the penalty");
        assertEq(staking.bondAt(a).exitHeight, NO_EXIT, "no exit set");
        assertEq(staking.missCount(0), 0, "the count is discarded");
        uint256 paid = token.balanceOf(SLASH_SINK);
        _blockStarts(15, 1);
        assertEq(staking.bondAt(a).effStake, stake, "a seatless bond loses nothing more");
        assertEq(token.balanceOf(SLASH_SINK), paid, "nothing more paid");
        _assertSeatOfBond(b, true, 1, "B keeps its seat");

        _deployMissLimits(10, 20);
        a = _register(_K1, Bob, 6 * _M / 5);
        b = _register(_K2, Carol, 2 * _M);
        _blockStarts(20, 1);
        assertEq(staking.bondAt(a).effStake, stake, "two penalties");
        assertEq(token.balanceOf(SLASH_SINK) - paid, 6 * _M / 5 - stake, "both paid once");
        _assertSeatOfBond(a, false, 0, "released once");
        _assertBondInSeat(0, false, 0, "seat 0 is empty");
        _assertSeatOfBond(b, true, 1, "B keeps seat 1");
        _assertBondInSeat(1, true, b, "seat 1 holds B");
        assertEq(staking.missCount(1), 0, "B's count");
    }

    /// @dev A bond released at missReleaseLimit keeps effStake >= minStake and no exit, yet holds no
    /// seat: later block-start calls and another bond's registration give it none, its effStake
    /// does not change while its key keeps missing, for more than three release limits, and a
    /// top-up of one base unit gives it the lowest empty seat with count 0.
    function test_onBlockStart_BondReleasedAtTheLimitTakesASeatOnlyThroughATopUp() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 10 * _M);
        uint256 b = _register(_K2, Carol, 2 * _M);
        _blockStarts(30, 1);
        uint256 stake = staking.bondAt(a).effStake;
        assertGe(stake, _M, "at or above minStake");
        _assertSeatOfBond(a, false, 0, "released at the limit");
        uint256 paid = token.balanceOf(SLASH_SINK);

        // Every bit but B's: seat 0 is empty, so its bit counts nothing.
        _blockStarts(100, ~uint128(2));
        _assertSeatOfBond(a, false, 0, "no block-start call gives it a seat");
        assertEq(staking.bondAt(a).effStake, stake, "no miss counted, no penalty");
        assertEq(token.balanceOf(SLASH_SINK), paid, "nothing paid");
        assertEq(staking.missCount(0), 0, "seat 0 counts nothing");

        uint256 c = _register(_K3, David, _M);
        _assertSeatOfBond(c, true, 0, "a new bond takes seat 0");
        _assertSeatOfBond(a, false, 0, "another bond's registration gives A no seat");

        _fund(Bob, 1);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.TopUpDeposited(a, 1);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.SeatTaken(a, 2);
        vm.prank(Bob);
        staking.topUp(a, 1);
        _assertSeatOfBond(a, true, 2, "the lowest empty seat");
        assertEq(staking.missCount(2), 0, "count 0");
        assertEq(staking.bondAt(a).effStake, stake + 1, "one base unit added");
        _assertSeatOfBond(b, true, 1, "B kept");
    }

    /// @dev A bond released at missReleaseLimit in block H's call and topped up in H's
    /// transactions takes a seat with count 0 in that transaction; H's snapshot, already written,
    /// leaves it out and H + 1's holds it.
    function test_onBlockStart_TopUpInTheReleasingBlockReachesTheNextSnapshot() external {
        _deployMissLimits(10, 30);
        uint256 a = _register(_K1, Bob, 10 * _M);
        _blockStarts(30, 1);
        _assertSeatOfBond(a, false, 0, "released in H's call");
        _assertSnapshotEmpty("H's snapshot");

        _topUp(a, 1);
        _assertSeatOfBond(a, true, 0, "seated again in H");
        assertEq(staking.missCount(0), 0, "count 0");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(uint256(0x0001)), "key word");
        _assertSnapshotEmpty("H's snapshot is unchanged within H");

        uint256 stake = staking.bondAt(a).effStake;
        _blockStart(1, 0);
        _assertRecord(0, _K1, stake / VP_UNIT, "record 0 holds A at H + 1");
        assertEq(_word(1), stake, "the total at H + 1");
    }

    /// @dev Block H's call releases bond A from seat 4 at missReleaseLimit and bond B takes seat 4
    /// in H's transactions. H's post-state maps A's key to no seat, so A's further misses set no
    /// bit at H + 1, and B starts at count 0 and is charged nothing.
    function test_onBlockStart_SeatReleasedAtTheLimitAndRetakenCarriesNoOldMisses() external {
        _deployMissLimits(10, 30);
        for (uint256 pk = 11; pk < 15; ++pk) {
            _register(pk, Bob, _M);
        }
        uint256 a = _register(_K1, Carol, 10 * _M);
        _blockStarts(30, 1 << 4);
        _assertSeatOfBond(a, false, 0, "A released from seat 4");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(0), "A's key word is zero");

        uint256 b = _register(_K2, David, _M);
        _assertSeatOfBond(b, true, 4, "B takes seat 4 in H");
        assertEq(staking.missCount(4), 0, "B starts at count 0");

        _blockStart(1, 0);
        assertEq(staking.missCount(4), 0, "no miss of A reaches B");
        assertEq(staking.bondAt(b).effStake, _M, "B is charged nothing");
        _assertRecord(4, _K2, _M / VP_UNIT, "record 4 holds B");
        _blockStart(1, 1 << 4);
        assertEq(staking.missCount(4), 1, "B's own first miss");
    }

    // ---------------------------------------------------------------
    // Candidate snapshot
    // ---------------------------------------------------------------

    function test_onBlockStart_WritesRecordsTotalAndHeight() external {
        _seatZeroTwoFive();
        (uint8 prefix9,) = EtnaTestKeys.fallbackKey(_K9);
        assertEq(prefix9, 3, "K9 covers prefix 0x03");

        _blockStart(7, 0);
        for (uint256 seat; seat < 128; ++seat) {
            if (seat == 0) _assertRecord(0, _K1, _STAKE0 / VP_UNIT, "record 0");
            else if (seat == 2) _assertRecord(2, _K9, _STAKE2 / VP_UNIT, "record 2");
            else if (seat == 5) _assertRecord(5, _K3, _STAKE5 / VP_UNIT, "record 5");
            else _assertEmptyRecord(seat, "an empty seat's record");
        }
        assertEq(_word(1), _STAKE0 + _STAKE2 + _STAKE5, "the total at T + 1");
        assertEq(_word(0), block.number, "the height at T");
    }

    function test_onBlockStart_EmptySeatTableWritesZeros() external {
        _blockStart(0, type(uint128).max);
        _assertSnapshotEmpty("a contract with no bond");

        uint256 a = _register(_K1, Bob, _M);
        _blockStart(0, 0);
        assertEq(_word(1), _M, "one bond");
        _requestExit(a);
        _blockStart(0, 0);
        _assertSnapshotEmpty("after the only bond exits");
    }

    /// @dev The power is floor(effStake / vpUnit); with nMax 64 and every seat held the records at
    /// and above 64 stay zero.
    function test_onBlockStart_PowerIsFloored() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.nMax = 64;
        cfg.minStake = _M64;
        cfg.vpUnit = _M64;
        staking = _deploy(cfg);
        _register(_K1, Bob, _M64 * 5 / 2);
        _register(_K2, Bob, _M64);
        _register(_K3, Bob, 2 * _M64 - 1);
        for (uint256 pk = 100; pk < 161; ++pk) {
            _register(pk, Bob, _M64);
        }
        _assertBondInSeat(63, true, 63, "every seat is held");

        _blockStart(0, type(uint128).max);
        _assertRecord(0, _K1, 2, "2.5 vpUnit gives power 2");
        _assertRecord(1, _K2, 1, "effStake = minStake = vpUnit gives power 1");
        _assertRecord(2, _K3, 1, "just under 2 vpUnit gives power 1");
        for (uint256 seat = 3; seat < 64; ++seat) {
            assertEq(_word(4 + 2 * seat) >> 8, 1, "power 1");
        }
        for (uint256 seat = 64; seat < 128; ++seat) {
            _assertEmptyRecord(seat, "a record at or above nMax");
        }
    }

    /// @dev A top-up and an exit in block X leave X's snapshot as X's call wrote it; X + 1's call
    /// takes them in.
    function test_onBlockStart_TransactionsReachTheSnapshotAtTheNextCall() external {
        uint256 a = _register(_K1, Bob, _M);
        uint256 b = _register(_K2, Carol, _M);
        _blockStart(0, 0);
        bytes32[] memory atX = _words(0, _SNAPSHOT_WORDS);

        _topUp(a, 3 * VP_UNIT);
        _requestExit(b);
        assertEq(_words(0, _SNAPSHOT_WORDS), atX, "X's transactions leave X's snapshot");

        _blockStart(0, 0);
        _assertRecord(0, _K1, _M / VP_UNIT + 3, "the top-up at X + 1");
        _assertEmptyRecord(1, "the exit at X + 1");
        assertEq(_word(1), _M + 3 * VP_UNIT, "the total at X + 1");
    }

    function test_snapshot_ReturnsTheWholeHeightWordAndOccupiedRecords() external {
        _seatZeroTwoFive();
        _blockStart(0, 0);
        uint256 h = block.number;

        (uint256 height, uint256 total, IEtnaStaking.SeatMember[] memory members) =
            staking.snapshot();
        assertEq(height, h, "height");
        assertEq(total, _STAKE0 + _STAKE2 + _STAKE5, "total");
        assertEq(members.length, 3, "the occupied records only");
        _assertMember(members[0], 0, _K1, _STAKE0 / VP_UNIT);
        _assertMember(members[1], 2, _K9, _STAKE2 / VP_UNIT);
        _assertMember(members[2], 5, _K3, _STAKE5 / VP_UNIT);

        vm.store(address(staking), T, bytes32(h | (1 << 48)));
        (height,,) = staking.snapshot();
        assertEq(height, h + 2 ** 48, "the whole word at T, unmasked");
    }

    // ---------------------------------------------------------------
    // A failing call changes nothing
    // ---------------------------------------------------------------

    function test_onBlockStart_RevertWhen_PowerExceedsUint64_ChangesNothing() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.vpUnit = 867_361_738;
        staking = _deploy(cfg);
        uint256 a = _register(_K1, Bob, _M);
        _register(_K2, Carol, _M);
        uint256 limit = (2 ** 64) * cfg.vpUnit;
        _topUp(a, limit - 1 - _M);
        _blockStart(1, 0x2);
        assertEq(_word(4) >> 8, type(uint64).max, "the largest power fits");
        assertEq(staking.missCount(1), 1, "seat 1 at count 1");

        _topUp(a, 1);
        bytes memory revertData = _assertBlockStartFailsWithoutChange(2, 0x3, _FRAME_GAS);
        assertEq(
            revertData,
            abi.encodeWithSignature("Error(string)", "SafeCast: value doesn't fit in 64 bits"),
            "the power of 2^64 does not fit"
        );
        assertEq(staking.bondAt(a).effStake, limit, "effStake kept");
    }

    function test_onBlockStart_RevertWhen_PenaltyTransferFails_ChangesNothing() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 1;
        staking = _deploy(cfg);
        uint256 a = _register(_K1, Bob, _M);
        uint256 b = _register(_K2, Carol, 2 * _M);
        _blockStart(1, 0);

        bytes memory refusal = abi.encodeWithSignature("SinkRefuses()");
        vm.mockCallRevert(
            address(token), abi.encodeWithSelector(token.transfer.selector, SLASH_SINK), refusal
        );
        bytes memory revertData = _assertBlockStartFailsWithoutChange(2, 0x3, _FRAME_GAS);
        assertEq(revertData, refusal, "the penalty transfer reverts");
        assertEq(staking.bondAt(a).effStake, _M, "A's effStake kept");
        assertEq(staking.bondAt(b).effStake, 2 * _M, "B's effStake kept");
        _assertSeatOfBond(a, true, 0, "A keeps the seat the penalty would release");
        assertEq(_keySeatWord(EtnaTestKeys.ckAddr(_K1)), bytes32(uint256(0x0001)), "A's key word");
        assertEq(token.balanceOf(SLASH_SINK), 0, "nothing paid");

        vm.clearMockedCalls();
        _blockStart(2, 0x3);
        assertEq(token.balanceOf(SLASH_SINK), _M / 10 + 2 * _M / 10, "paid once the sink accepts");
        _assertSeatOfBond(a, false, 0, "A released");
    }

    function test_onBlockStart_OutOfGas_ChangesNothing() external {
        for (uint256 pk = 1; pk <= N_MAX; ++pk) {
            _register(pk, Bob, _M);
        }
        _blockStart(1, 0xff);
        bytes memory revertData = _assertBlockStartFailsWithoutChange(2, type(uint128).max, 100_000);
        assertEq(revertData.length, 0, "out of gas");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Seats K1 (stake `_STAKE0`) in seat 0, K9 (`_STAKE2`) in seat 2 and K3 (`_STAKE5`) in
    /// seat 5; the bonds that took seats 1, 3 and 4 exit.
    function _seatZeroTwoFive() private {
        _register(_K1, Bob, _STAKE0);
        uint256 one = _register(21, Bob, _M);
        _register(_K9, Carol, _STAKE2);
        uint256 three = _register(23, Bob, _M);
        uint256 four = _register(24, Bob, _M);
        _register(_K3, David, _STAKE5);
        _requestExit(one);
        _requestExit(three);
        _requestExit(four);
    }

    /// @dev Deploys a staking contract with the base's configuration and the given miss limits.
    function _deployMissLimits(uint256 _missLimit, uint256 _missReleaseLimit) private {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = _missLimit;
        cfg.missReleaseLimit = _missReleaseLimit;
        staking = _deploy(cfg);
    }

    /// @dev Makes `_n` block-start calls of generation 1 with `_missBitmap`, one block each.
    function _blockStarts(uint256 _n, uint128 _missBitmap) private {
        for (uint256 i; i < _n; ++i) {
            _blockStart(1, _missBitmap);
        }
    }

    /// @dev The penalty at the base's missSlashBps of 1000: ceil(`_effStake` / 10).
    function _penaltyOf(uint256 _effStake) private pure returns (uint256) {
        return (_effStake + 9) / 10;
    }

    /// @dev Funds bond `_bondId`'s owner with `_amount`, which it then tops up.
    function _topUp(uint256 _bondId, uint256 _amount) private {
        address owner = staking.bondAt(_bondId).owner;
        _fund(owner, _amount);
        vm.prank(owner);
        staking.topUp(_bondId, _amount);
    }

    /// @dev Rolls one block and makes its block-start call with `_gas` gas, which must fail, then
    /// asserts that the call left every fixed staking word as it was: T, T + 1, the 128 records,
    /// the seat table, every miss count, the occupancy bitmap and the stored generation.
    /// @return revertData_ The call's revert data.
    function _assertBlockStartFailsWithoutChange(
        uint48 _generation,
        uint128 _missBitmap,
        uint256 _gas
    )
        private
        returns (bytes memory revertData_)
    {
        bytes32[] memory before = _words(0, _FIXED_WORDS);
        bytes memory data = abi.encodeCall(IEtnaStaking.onBlockStart, (_generation, _missBitmap));
        address target = address(staking);
        vm.roll(block.number + 1);
        vm.prank(SYSTEM_CALLER);
        bool ok;
        (ok, revertData_) = target.call{ gas: _gas }(data);
        assertFalse(ok, "the call fails");
        assertEq(_words(0, _FIXED_WORDS), before, "the fixed staking words are unchanged");
    }

    /// @dev Asserts that snapshot record `_seat` holds the key of `_pk` with power `_power`: word 1
    /// at T + 3 + 2s is ckX and word 2 at T + 4 + 2s is ckPrefix | power << 8.
    function _assertRecord(
        uint256 _seat,
        uint256 _pk,
        uint256 _power,
        string memory _label
    )
        private
    {
        (uint8 prefix, bytes32 x) = EtnaTestKeys.fallbackKey(_pk);
        assertEq(bytes32(_word(3 + 2 * _seat)), x, string.concat(_label, ": ckX"));
        assertEq(
            _word(4 + 2 * _seat),
            uint256(prefix) | _power << 8,
            string.concat(_label, ": ckPrefix and power")
        );
    }

    /// @dev Asserts that snapshot record `_seat` is all zero.
    function _assertEmptyRecord(uint256 _seat, string memory _label) private view {
        string memory label = string.concat(_label, " ", vm.toString(_seat));
        assertEq(_word(3 + 2 * _seat), 0, string.concat(label, ": word 1"));
        assertEq(_word(4 + 2 * _seat), 0, string.concat(label, ": word 2"));
    }

    /// @dev Asserts an empty snapshot written at the current block: 128 zero records, a zero
    /// total and the current height.
    function _assertSnapshotEmpty(string memory _label) private view {
        for (uint256 seat; seat < 128; ++seat) {
            _assertEmptyRecord(seat, _label);
        }
        assertEq(_word(1), 0, string.concat(_label, ": total"));
        assertEq(_word(0), block.number, string.concat(_label, ": height"));
    }

    /// @dev Asserts a `snapshot()` member.
    function _assertMember(
        IEtnaStaking.SeatMember memory _member,
        uint8 _seat,
        uint256 _pk,
        uint256 _power
    )
        private
    {
        (uint8 prefix, bytes32 x) = EtnaTestKeys.fallbackKey(_pk);
        string memory label = string.concat("member in seat ", vm.toString(_seat));
        assertEq(_member.seat, _seat, string.concat(label, ": seat"));
        assertEq(_member.ckPrefix, prefix, string.concat(label, ": ckPrefix"));
        assertEq(_member.ckX, x, string.concat(label, ": ckX"));
        assertEq(_member.power, _power, string.concat(label, ": power"));
    }

    /// @dev Asserts the miss counts of seats 0 to 3.
    function _assertMissCounts(
        uint16[4] memory _counts,
        string memory _label
    )
        private
        view
    {
        for (uint8 seat; seat < 4; ++seat) {
            assertEq(staking.missCount(seat), _counts[seat], _label);
        }
    }

    /// @dev Returns the word at T + `_offset`.
    function _word(uint256 _offset) private view returns (uint256) {
        return uint256(vm.load(address(staking), bytes32(uint256(T) + _offset)));
    }

    /// @dev Returns the `_count` words from T + `_offset` on.
    function _words(
        uint256 _offset,
        uint256 _count
    )
        private
        view
        returns (bytes32[] memory words_)
    {
        words_ = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            words_[i] = vm.load(address(staking), bytes32(uint256(T) + _offset + i));
        }
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
