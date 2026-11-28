// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "../EtnaStakingTestBase.sol";
import { EtnaStakingHandler } from "./EtnaStakingHandler.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @title EtnaStakingInvariantTest
/// @notice The stake balance, the seat conditions, the seat views and key-to-seat words, the
/// snapshot records, exit heights, forfeiture flags and key registrations under random sequences
/// of registrations, top-ups, exits, withdrawals, double-sign slashes, forfeitures, block-start
/// calls and L2 blocks.
/// @dev The deployment has 8 seats, missLimit 2, missReleaseLimit 4 and minStake 1.25 * 10^26, so
/// 8 * minStake is TAIKO's 10^27 supply; the stand-in token mints freely, so more bonds than seats
/// can reach m. A run of misses is penalized at counts 2 and 4 and released at 4.
/// Foundry runs a separate campaign per invariant function and asserts only that function in it,
/// so every invariant also asserts that the handler saw no violation of any kind.
/// forge-config: default.invariant.depth = 50
/// forge-config: default.invariant.fail_on_revert = true
contract EtnaStakingInvariantTest is EtnaStakingTestBase {
    uint256 internal constant INVARIANT_N_MAX = 8;
    uint256 internal constant INVARIANT_MISS_LIMIT = 2;
    uint256 internal constant INVARIANT_MISS_RELEASE_LIMIT = 4;
    uint256 internal constant INVARIANT_MIN_STAKE = 1.25e26;

    /// @dev The number of snapshot records.
    uint256 internal constant MAX_RECORDS = 128;

    /// @dev Slot T + 398, whose low 128 bits are the occupancy bitmap.
    uint256 internal constant OCCUPANCY_OFFSET = 398;

    EtnaStakingHandler internal handler;

    function setUp() public override {
        super.setUp();
        IEtnaStaking.Config memory cfg = _config();
        cfg.nMax = INVARIANT_N_MAX;
        cfg.missLimit = INVARIANT_MISS_LIMIT;
        cfg.missReleaseLimit = INVARIANT_MISS_RELEASE_LIMIT;
        cfg.minStake = INVARIANT_MIN_STAKE;
        staking = _deploy(cfg);
        handler = new EtnaStakingHandler(staking, token, STAKING_OWNER);

        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = EtnaStakingHandler.register.selector;
        selectors[1] = EtnaStakingHandler.topUp.selector;
        selectors[2] = EtnaStakingHandler.requestExit.selector;
        selectors[3] = EtnaStakingHandler.withdraw.selector;
        selectors[4] = EtnaStakingHandler.slashDoubleSign.selector;
        selectors[5] = EtnaStakingHandler.forfeit.selector;
        selectors[6] = EtnaStakingHandler.blockStart.selector;
        selectors[7] = EtnaStakingHandler.roll.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /// @notice The contract's token balance is the effStake of its unwithdrawn bonds, a withdrawn
    /// bond keeps none, and both equal the stake pulled in minus the stake paid out; slashSink
    /// holds every penalty and the slashed principal less the bounties.
    function invariant_tokenBalanceEqualsUnwithdrawnStake() external view {
        _assertNoViolation();
        uint256 total;
        for (uint256 bondId; bondId < staking.bondCount(); ++bondId) {
            IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
            if (bond.withdrawn) assertEq(bond.effStake, 0, "a withdrawn bond keeps no stake");
            total += bond.effStake;
        }
        assertEq(token.balanceOf(address(staking)), total, "balance = unwithdrawn effStake");
        assertEq(total, handler.ghostDeposited() - handler.ghostPaidOut(), "deposits minus payouts");
        assertEq(token.balanceOf(SLASH_SINK), handler.ghostToSink(), "slashSink's share");
    }

    /// @notice A bond holds a seat exactly while it is issued, unwithdrawn, has no exit and has
    /// effStake >= m, unless a block-start call released its seat and no top-up has seated it
    /// since; an unissued id holds none.
    function invariant_seatHeldIffConditionsHoldAndNoReleaseSinceTopUp() external view {
        _assertNoViolation();
        uint256 count = staking.bondCount();
        assertEq(count, handler.bondTotal(), "one bond id per registration");
        for (uint256 bondId; bondId < count; ++bondId) {
            IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
            bool eligible = !bond.withdrawn && bond.exitHeight == NO_EXIT
                && bond.effStake >= INVARIANT_MIN_STAKE && !handler.releasedByBlockStart(bondId);
            assertEq(bond.holdsSeat, eligible, "the record's seat flag");
            _assertSeatOfBond(bondId, eligible, eligible ? bond.seat : 0, "seatOfBond");
        }
        uint256[3] memory unissued = [count, count + 1, 2 ** 200];
        for (uint256 i; i < unissued.length; ++i) {
            _assertSeatOfBond(unissued[i], false, 0, "an unissued id");
        }
    }

    /// @notice `bondInSeat`, `seatOfBond`, the occupancy bitmap and the key-to-seat word of every
    /// key agree: an occupied seat below nMax names a bond holding that seat, whose key's word is
    /// [holdsSeat = 1, seat]; every seat at or above nMax reads empty; and the word of a key whose
    /// bond holds no seat, or that no bond registered, is 0.
    function invariant_seatViewsAndKeySeatWordsAgree() external view {
        _assertNoViolation();
        uint256 occupancy;
        uint256 held;
        for (uint256 seat; seat < 256; ++seat) {
            (bool occupied, uint256 bondId) = staking.bondInSeat(uint8(seat));
            if (seat >= INVARIANT_N_MAX) {
                _assertBondInSeat(uint8(seat), false, 0, "a seat at or above nMax");
                continue;
            }
            if (!occupied) {
                assertEq(bondId, 0, "an empty seat names bond 0 only as absence");
                continue;
            }
            occupancy |= uint256(1) << seat;
            ++held;
            _assertSeatOfBond(bondId, true, uint8(seat), "the seated bond's seat");
        }
        assertEq(
            uint256(vm.load(address(staking), bytes32(uint256(T) + OCCUPANCY_OFFSET)))
                & type(uint128).max,
            occupancy,
            "the occupancy bitmap"
        );

        uint256 seatedBonds;
        for (uint256 bondId; bondId < staking.bondCount(); ++bondId) {
            (bool holdsSeat, uint8 seat) = staking.seatOfBond(bondId);
            if (!holdsSeat) continue;
            ++seatedBonds;
            _assertBondInSeat(seat, true, bondId, "the bond's seat names it");
        }
        assertEq(seatedBonds, held, "one bond per occupied seat");

        for (uint256 pk = 1; pk <= handler.KEY_COUNT(); ++pk) {
            bytes32 word = _keySeatWord(EtnaTestKeys.ckAddr(pk));
            (bool used, uint256 bondId) = handler.bondOfKey(pk);
            bool holdsSeat;
            uint8 seat;
            if (used) (holdsSeat, seat) = staking.seatOfBond(bondId);
            assertEq(
                word,
                holdsSeat ? bytes32(1 | uint256(seat) << 8) : bytes32(0),
                "the key-to-seat word"
            );
        }
    }

    /// @notice Between calls every occupied seat's miss count is below missReleaseLimit and every
    /// empty seat's is zero.
    function invariant_missCountsBelowReleaseLimit() external view {
        _assertNoViolation();
        for (uint256 seat; seat < INVARIANT_N_MAX; ++seat) {
            (bool occupied,) = staking.bondInSeat(uint8(seat));
            uint256 count = staking.missCount(uint8(seat));
            if (occupied) assertLt(count, INVARIANT_MISS_RELEASE_LIMIT, "an occupied seat");
            else assertEq(count, 0, "an empty seat");
        }
    }

    /// @notice The snapshot records, seat table entries and miss counts of seats at or above
    /// nMax stay zero.
    function invariant_recordsAtOrAboveNMaxAreZero() external view {
        _assertNoViolation();
        for (uint256 seat = INVARIANT_N_MAX; seat < MAX_RECORDS; ++seat) {
            assertEq(_word(3 + 2 * seat), 0, "record word 1");
            assertEq(_word(4 + 2 * seat), 0, "record word 2");
            assertEq(_word(262 + seat), 0, "the seat table entry");
            assertEq(staking.missCount(uint8(seat)), 0, "the miss count");
        }
    }

    /// @notice Right after each block-start call, the height is that block, the total the seated
    /// bonds' effStake and record s the key and power floor(effStake / vpUnit) of the bond in
    /// seat s, or zero; no later call changes those words, and before the first call they are
    /// zero. `snapshot()` returns the same words.
    function invariant_snapshotMatchesSeatTableAfterEachBlockStart() external view {
        _assertNoViolation();
        if (!handler.captured()) {
            for (uint256 i; i < handler.SNAPSHOT_WORDS(); ++i) {
                assertEq(_snapshotWord(i), 0, "no snapshot before the first call");
            }
            return;
        }
        (bytes32[] memory written, bytes32[] memory expected) = handler.capturedSnapshot();
        for (uint256 i; i < written.length; ++i) {
            assertEq(written[i], expected[i], "the call wrote the seat table");
            assertEq(_snapshotWord(i), written[i], "only the block-start call writes it");
        }

        (uint256 height, uint256 totalStake, IEtnaStaking.SeatMember[] memory members) =
            staking.snapshot();
        assertEq(height, uint256(expected[0]), "snapshot(): height");
        assertEq(totalStake, uint256(expected[1]), "snapshot(): total");
        uint256 m;
        for (uint256 seat; seat < MAX_RECORDS; ++seat) {
            if (expected[2 + 2 * seat] == 0 && expected[3 + 2 * seat] == 0) continue;
            IEtnaStaking.SeatMember memory member = members[m++];
            assertEq(member.seat, seat, "snapshot(): seat order");
            assertEq(member.ckX, expected[2 + 2 * seat], "snapshot(): ckX");
            uint256 word = uint256(expected[3 + 2 * seat]);
            assertEq(member.ckPrefix, uint8(word), "snapshot(): ckPrefix");
            assertEq(member.power, uint64(word >> 8), "snapshot(): power");
        }
        assertEq(members.length, m, "snapshot(): the occupied records");
    }

    /// @notice A bond's exit height starts at 2^48 - 1 and only moves earlier, never past the
    /// current block once set.
    function invariant_exitHeightOnlyDecreases() external view {
        _assertNoViolation();
        for (uint256 bondId; bondId < staking.bondCount(); ++bondId) {
            uint48 exitHeight = staking.bondAt(bondId).exitHeight;
            assertEq(exitHeight, handler.seenExitHeight(bondId), "the last seen exit height");
            if (exitHeight != NO_EXIT) assertLe(exitHeight, block.number, "an exit in the past");
        }
    }

    /// @notice A bond's forfeiture flag is set exactly once a forfeiture succeeded and stays set,
    /// withdrawn or not; a forfeited bond has an exit and holds no seat.
    function invariant_forfeitedNeverCleared() external view {
        _assertNoViolation();
        uint256 count = staking.bondCount();
        for (uint256 bondId; bondId < count; ++bondId) {
            bool flagged = staking.forfeited(bondId);
            assertEq(flagged, handler.ghostForfeited(bondId), "the forfeiture flag");
            if (!flagged) continue;
            IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
            assertTrue(bond.exitHeight != NO_EXIT, "a forfeited bond has an exit");
            assertFalse(bond.holdsSeat, "a forfeited bond holds no seat");
        }
        assertFalse(staking.forfeited(count), "an unissued id is not forfeited");
    }

    /// @notice Every key a registration used maps to its bond for good, withdrawn or not, and
    /// every other key maps to nothing.
    function invariant_keyBondNeverReleased() external view {
        _assertNoViolation();
        for (uint256 pk = 1; pk <= handler.KEY_COUNT(); ++pk) {
            (bool used, uint256 bondId) = handler.bondOfKey(pk);
            _assertBondForKey(EtnaTestKeys.ckAddr(pk), used, bondId, "bondForKey");
            if (used) assertEq(handler.keyOfBond(bondId), pk, "the bond's key");
        }
    }

    /// @dev Asserts that the handler recorded no violation.
    function _assertNoViolation() internal view {
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    /// @dev Returns the word at T + `_offset`.
    function _word(uint256 _offset) internal view returns (uint256) {
        return uint256(vm.load(address(staking), bytes32(uint256(T) + _offset)));
    }

    /// @dev Returns snapshot word `_index` as the handler numbers them.
    function _snapshotWord(uint256 _index) internal view returns (bytes32) {
        return vm.load(address(staking), handler.snapshotSlot(_index));
    }
}
