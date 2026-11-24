// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @dev The block-start call: the stored generation and the candidate snapshot. The call changes
/// no stake, seat or exit, so a member that stops signing keeps its seat and power.
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

    /// @dev The number of staking words at fixed slots, T to T + 389: the snapshot words, the
    /// roots of the key lookup and the bond records, the bond count, the seat table and the word
    /// of the occupancy bitmap and the stored generation.
    uint256 private constant _FIXED_WORDS = 390;

    /// @dev The number of snapshot words, T to T + 257: the height, the total and the records.
    uint256 private constant _SNAPSHOT_WORDS = 258;

    /// @dev The offset from T of the word holding the occupancy bitmap and the stored generation.
    uint256 private constant _GENERATION_WORD = 389;

    // ---------------------------------------------------------------
    // Caller and calldata
    // ---------------------------------------------------------------

    function test_onBlockStart_RevertWhen_NotSystemCaller() external {
        address[3] memory callers = [Alice, STAKING_OWNER, address(staking)];
        for (uint256 i; i < callers.length; ++i) {
            vm.expectRevert(IEtnaStaking.NotSystemCaller.selector);
            vm.prank(callers[i]);
            staking.onBlockStart(1);
        }
        assertEq(staking.lastGeneration(), 0, "no generation stored");
        assertEq(_word(0), 0, "no snapshot written");
    }

    /// @dev The execution layer's 36-byte calldata, selector 0xaa28c32e followed by the
    /// generation as one 32-byte word, stores the generation and then the snapshot.
    function test_onBlockStart_AcceptsTheSpecCalldata() external {
        for (uint256 pk = 11; pk < 14; ++pk) {
            _register(pk, Bob, 2 * _M);
        }
        bytes memory data = abi.encodePacked(bytes4(0xaa28c32e), uint256(3));
        assertEq(data.length, 36, "4 + 32 bytes");

        vm.roll(block.number + 1);
        vm.prank(SYSTEM_CALLER);
        (bool ok,) = address(staking).call(data);
        assertTrue(ok, "the call succeeds");
        assertEq(staking.lastGeneration(), 3, "generation");
        for (uint256 seat; seat < 3; ++seat) {
            _assertRecord(seat, 11 + seat, 2 * _M / VP_UNIT, "a seated bond's record");
        }
        _assertEmptyRecord(3, "the first empty seat");
        assertEq(_word(1), 6 * _M, "the total");
        assertEq(_word(0), block.number, "snapshot height");
    }

    function test_onBlockStart_StoresGenerationWithoutMonotonicity() external {
        _register(_K1, Bob, _M);
        _blockStart(3);
        assertEq(staking.lastGeneration(), 3, "first");
        _blockStart(1);
        assertEq(staking.lastGeneration(), 1, "a lower generation is stored as given");
        _blockStart(type(uint48).max);
        assertEq(staking.lastGeneration(), type(uint48).max, "the largest generation");
        _blockStart(0);
        assertEq(staking.lastGeneration(), 0, "zero");
        assertEq(_word(_GENERATION_WORD), 1, "the occupancy bitmap shares the generation's word");
        _assertBondInSeat(0, true, 0, "seat kept");
    }

    // ---------------------------------------------------------------
    // No consequence for members that do not sign
    // ---------------------------------------------------------------

    /// @dev Members that stop signing lose nothing: over 12 blocks the calls move no token,
    /// emit nothing, and leave every bond record, seat and lookup as the transactions left them,
    /// so each seated member keeps its seat and its whole power in every snapshot. Each call
    /// writes only the snapshot words and the generation's word.
    function test_onBlockStart_OfflineMembersKeepStakeAndSeat() external {
        for (uint256 pk = 11; pk < 16; ++pk) {
            _register(pk, Bob, _M + pk);
        }
        _requestExit(2);
        uint256 count = staking.bondCount();
        IEtnaStaking.Bond[] memory before = new IEtnaStaking.Bond[](count);
        for (uint256 bondId; bondId < count; ++bondId) {
            before[bondId] = staking.bondAt(bondId);
        }
        uint256 held = token.balanceOf(address(staking));

        vm.recordLogs();
        for (uint256 i; i < 12; ++i) {
            vm.record();
            _blockStart(uint48(i % 3));
            (, bytes32[] memory writes) = vm.accesses(address(staking));
            for (uint256 w; w < writes.length; ++w) {
                uint256 slot = uint256(writes[w]);
                assertTrue(
                    slot >= uint256(T)
                        && (slot - uint256(T) < _SNAPSHOT_WORDS
                            || slot - uint256(T) == _GENERATION_WORD),
                    "only the snapshot and the generation are written"
                );
            }
        }
        assertEq(vm.getRecordedLogs().length, 0, "no event and no transfer");

        assertEq(token.balanceOf(address(staking)), held, "no stake leaves");
        assertEq(token.balanceOf(SLASH_SINK), 0, "nothing to slashSink");
        for (uint256 bondId; bondId < count; ++bondId) {
            assertEq(
                keccak256(abi.encode(staking.bondAt(bondId))),
                keccak256(abi.encode(before[bondId])),
                "the bond record is unchanged"
            );
        }
        for (uint8 seat; seat < 5; ++seat) {
            if (seat == 2) {
                _assertBondInSeat(seat, false, 0, "the exited bond's seat stays empty");
                _assertEmptyRecord(seat, "the exited bond's record");
                continue;
            }
            _assertSeatOfBond(seat, true, seat, "the member keeps its seat");
            _assertBondInSeat(seat, true, seat, "the seat keeps its member");
            _assertRecord(seat, 11 + seat, (_M + 11 + seat) / VP_UNIT, "the member's whole power");
        }
        assertEq(_word(1), 4 * _M + 11 + 12 + 14 + 15, "the total keeps every member's stake");
        assertEq(staking.lastGeneration(), 2, "the last generation");
    }

    // ---------------------------------------------------------------
    // Candidate snapshot
    // ---------------------------------------------------------------

    function test_onBlockStart_WritesRecordsTotalAndHeight() external {
        _seatZeroTwoFive();
        (uint8 prefix9,) = EtnaTestKeys.fallbackKey(_K9);
        assertEq(prefix9, 3, "K9 covers prefix 0x03");

        _blockStart(7);
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
        _blockStart(0);
        _assertSnapshotEmpty("a contract with no bond");

        uint256 a = _register(_K1, Bob, _M);
        _blockStart(0);
        assertEq(_word(1), _M, "one bond");
        _requestExit(a);
        _blockStart(0);
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

        _blockStart(0);
        _assertRecord(0, _K1, 2, "2.5 vpUnit gives power 2");
        _assertRecord(1, _K2, 1, "effStake = minStake = vpUnit gives power 1");
        _assertRecord(2, _K3, 1, "just under 2 vpUnit gives power 1");
        for (uint256 seat = 3; seat < 64; ++seat) {
            assertEq(_word(3 + 2 * seat) >> 8, 1, "power 1");
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
        _blockStart(0);
        bytes32[] memory atX = _words(0, _SNAPSHOT_WORDS);

        _topUp(a, 3 * VP_UNIT);
        _requestExit(b);
        assertEq(_words(0, _SNAPSHOT_WORDS), atX, "X's transactions leave X's snapshot");

        _blockStart(0);
        _assertRecord(0, _K1, _M / VP_UNIT + 3, "the top-up at X + 1");
        _assertEmptyRecord(1, "the exit at X + 1");
        assertEq(_word(1), _M + 3 * VP_UNIT, "the total at X + 1");
    }

    /// @dev A seat that a bond leaves and another bond takes in the same block keeps the old
    /// bond's record until the next block-start call, which names the new bond.
    function test_onBlockStart_SeatVacatedAndRetakenInOneBlockReachesTheNextCall() external {
        for (uint256 pk = 11; pk < 15; ++pk) {
            _register(pk, Bob, _M);
        }
        uint256 a = _register(_K1, Carol, _M);
        _blockStart(0);
        _assertRecord(4, _K1, _M / VP_UNIT, "record 4 holds A");

        _requestExit(a);
        uint256 b = _register(_K2, David, 2 * _M);
        _assertSeatOfBond(b, true, 4, "B takes seat 4 in the same block");
        _assertRecord(4, _K1, _M / VP_UNIT, "record 4 still holds A within the block");

        _blockStart(0);
        _assertRecord(4, _K2, 2 * _M / VP_UNIT, "record 4 holds B after the next call");
        assertEq(_word(1), 6 * _M, "the total holds B's stake, not A's");
    }

    function test_snapshot_ReturnsTheWholeHeightWordAndOccupiedRecords() external {
        _seatZeroTwoFive();
        _blockStart(0);
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
        _blockStart(1);
        assertEq(_word(3) >> 8, type(uint64).max, "the largest power fits");

        _topUp(a, 1);
        bytes memory revertData = _assertBlockStartFailsWithoutChange(2, _FRAME_GAS);
        assertEq(
            revertData,
            abi.encodeWithSignature("Error(string)", "SafeCast: value doesn't fit in 64 bits"),
            "the power of 2^64 does not fit"
        );
        assertEq(staking.bondAt(a).effStake, limit, "effStake kept");
        assertEq(staking.lastGeneration(), 1, "the generation of the last successful call");
    }

    function test_onBlockStart_OutOfGas_ChangesNothing() external {
        for (uint256 pk = 1; pk <= N_MAX; ++pk) {
            _register(pk, Bob, _M);
        }
        _blockStart(1);
        bytes memory revertData = _assertBlockStartFailsWithoutChange(2, 100_000);
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

    /// @dev Funds bond `_bondId`'s owner with `_amount`, which it then tops up.
    function _topUp(uint256 _bondId, uint256 _amount) private {
        address owner = staking.bondAt(_bondId).owner;
        _fund(owner, _amount);
        vm.prank(owner);
        staking.topUp(_bondId, _amount);
    }

    /// @dev Rolls one block and makes its block-start call with `_gas` gas, which must fail, then
    /// asserts that the call left every fixed staking word as it was: T, T + 1, the 128 records,
    /// the seat table, the occupancy bitmap and the stored generation.
    /// @return revertData_ The call's revert data.
    function _assertBlockStartFailsWithoutChange(
        uint48 _generation,
        uint256 _gas
    )
        private
        returns (bytes memory revertData_)
    {
        bytes32[] memory before = _words(0, _FIXED_WORDS);
        bytes memory data = abi.encodeCall(IEtnaStaking.onBlockStart, (_generation));
        address target = address(staking);
        vm.roll(block.number + 1);
        vm.prank(SYSTEM_CALLER);
        bool ok;
        (ok, revertData_) = target.call{ gas: _gas }(data);
        assertFalse(ok, "the call fails");
        assertEq(_words(0, _FIXED_WORDS), before, "the fixed staking words are unchanged");
    }

    /// @dev Asserts that snapshot record `_seat` holds the key of `_pk` with power `_power`: word 1
    /// at T + 2 + 2s is ckX and word 2 at T + 3 + 2s is ckPrefix | power << 8.
    function _assertRecord(
        uint256 _seat,
        uint256 _pk,
        uint256 _power,
        string memory _label
    )
        private
    {
        (uint8 prefix, bytes32 x) = EtnaTestKeys.fallbackKey(_pk);
        assertEq(bytes32(_word(2 + 2 * _seat)), x, string.concat(_label, ": ckX"));
        assertEq(
            _word(3 + 2 * _seat),
            uint256(prefix) | _power << 8,
            string.concat(_label, ": ckPrefix and power")
        );
    }

    /// @dev Asserts that snapshot record `_seat` is all zero.
    function _assertEmptyRecord(uint256 _seat, string memory _label) private view {
        string memory label = string.concat(_label, " ", vm.toString(_seat));
        assertEq(_word(2 + 2 * _seat), 0, string.concat(label, ": word 1"));
        assertEq(_word(3 + 2 * _seat), 0, string.concat(label, ": word 2"));
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
}
