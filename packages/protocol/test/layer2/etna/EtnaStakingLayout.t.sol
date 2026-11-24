// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @dev Pins the staking storage that appendix B fixes, and the bond records and seat table that
/// follow it in the namespace, to their raw slots.
contract EtnaStakingLayoutTest is EtnaStakingTestBase {
    /// @dev Consensus private keys: K_i is the key of private key i.
    uint256 private constant _K1 = 1;

    function test_layout_NamespaceBaseIsT() external pure {
        assertEq(_erc7201("taiko.etna.staking"), T, "T");
    }

    /// @dev With K1's bond in seat 5, the block-start call writes the height at T, the total at
    /// T + 1 and record s at T + 2 + 2s and T + 3 + 2s: record 5 at T + 12 (word 1, ckX) and
    /// T + 13 (word 2, [ckPrefix (8 bits), power (64 bits)] from the least-significant bit).
    /// Record 0, whose bond exited, and the records of the empty seats from 6 on are zero.
    function test_layout_SnapshotRecordsAtTheSpecSlots() external {
        for (uint256 pk = 11; pk < 16; ++pk) {
            _register(pk, Bob, MIN_STAKE);
        }
        uint256 bondId = _register(_K1, Carol, MIN_STAKE + 7 * VP_UNIT);
        _assertSeatOfBond(bondId, true, 5, "the sixth bond takes seat 5");
        _requestExit(0);
        _blockStart(0);

        uint256 base = uint256(T);
        (uint8 prefix, bytes32 x) = EtnaTestKeys.fallbackKey(_K1);
        assertEq(_word(base), block.number, "snapshotHeight at T");
        assertEq(_word(base + 1), 5 * MIN_STAKE + 7 * VP_UNIT, "snapshotTotalStake at T + 1");
        assertEq(bytes32(_word(base + 12)), x, "record 5 word 1 at T + 12");
        assertEq(
            _word(base + 13),
            uint256(prefix) | (MIN_STAKE / VP_UNIT + 7) << 8,
            "record 5 word 2 at T + 13"
        );
        assertEq(_word(base + 2), 0, "record 0 word 1 at T + 2: the exited bond's seat");
        assertEq(_word(base + 3), 0, "record 0 word 2 at T + 3");
        assertGt(_word(base + 4), 0, "record 1 word 1 at T + 4");
        assertEq(_word(base + 14), 0, "record 6 word 1 at T + 14: an empty seat");
        assertEq(_word(base + 257), 0, "record 127 word 2 at T + 257");
    }

    /// @dev No transaction writes `snapshotHeight` (T), `snapshotTotalStake` (T + 1) or a snapshot
    /// seat record (T + 2 to T + 257): only the block-start call writes them.
    function test_layout_TransactionsNeverWriteSnapshotWords() external {
        vm.record();
        uint256 bondId = _register(_K1, Bob, MIN_STAKE);
        _register(2, Carol, MIN_STAKE);
        _fund(Bob, 1 ether);
        vm.prank(Bob);
        staking.topUp(bondId, 1 ether);
        _requestExit(bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(Bob);
        staking.withdraw(bondId, Bob);
        (, bytes32[] memory writes) = vm.accesses(address(staking));

        assertGt(writes.length, 0, "the calls write staking storage");
        uint256 base = uint256(T);
        for (uint256 i; i < writes.length; ++i) {
            uint256 slot = uint256(writes[i]);
            assertTrue(slot != base, "snapshotHeight written");
            assertTrue(slot != base + 1, "snapshotTotalStake written");
            assertTrue(slot < base + 2 || slot > base + 257, "a snapshot seat record written");
        }
        for (uint256 offset; offset < 258; ++offset) {
            assertEq(vm.load(address(staking), bytes32(base + offset)), bytes32(0), "still zero");
        }
    }

    /// @dev A bond's three words sit at keccak256(abi.encode(id, T + 259)) + 0..2, word 0 packing
    /// [owner (160 bits), ckPrefix, withdrawn, holdsSeat, seat (8 bits each), exitHeight
    /// (48 bits)] from the least-significant bit; `seatBond[s]` (bond id + 1) sits at
    /// T + 261 + s, the key lookup (bond id + 1) at T + 258, the bond count at T + 260 and the
    /// occupancy bitmap at T + 389.
    function test_layout_BondsAndSeatTableAtTheirSlots() external {
        _register(_K1, Bob, MIN_STAKE);
        _register(2, Bob, MIN_STAKE);
        uint256 amount = MIN_STAKE + 9;
        uint256 bondId = _register(3, Carol, amount);
        uint256 exitAt = block.number;
        _requestExit(1);

        uint256 base = uint256(T);
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        _assertBondWords(bondId, Carol, bond.ckPrefix, false, true, 2, NO_EXIT, bond.ckX, amount);
        IEtnaStaking.Bond memory exited = staking.bondAt(1);
        _assertBondWords(
            1, Bob, exited.ckPrefix, false, false, 0, uint48(exitAt), exited.ckX, MIN_STAKE
        );

        assertEq(_word(base + 261), 1, "seat 0 holds bond 0");
        assertEq(_word(base + 262), 0, "seat 1 is empty");
        assertEq(_word(base + 263), bondId + 1, "seat 2 holds bond 2");
        assertEq(
            uint256(
                vm.load(address(staking), keccak256(abi.encode(EtnaTestKeys.ckAddr(3), base + 258)))
            ),
            bondId + 1,
            "key lookup"
        );
        assertEq(_word(base + 260), 3, "bond count");
        assertEq(_word(base + 389), 0x5, "occupancy bitmap: seats 0 and 2");
    }

    function _assertBondWords(
        uint256 _bondId,
        address _owner,
        uint8 _ckPrefix,
        bool _withdrawn,
        bool _holdsSeat,
        uint8 _seat,
        uint48 _exitHeight,
        bytes32 _ckX,
        uint256 _effStake
    )
        private
        view
    {
        uint256 slot = uint256(keccak256(abi.encode(_bondId, uint256(T) + 259)));
        uint256 word0 = uint256(uint160(_owner)) | uint256(_ckPrefix) << 160
            | uint256(_withdrawn ? 1 : 0) << 168 | uint256(_holdsSeat ? 1 : 0) << 176
            | uint256(_seat) << 184 | uint256(_exitHeight) << 192;
        assertEq(_word(slot), word0, "bond word 0");
        assertEq(bytes32(_word(slot + 1)), _ckX, "bond word 1: ckX");
        assertEq(_word(slot + 2), _effStake, "bond word 2: effStake");
    }

    function _word(uint256 _slot) private view returns (uint256) {
        return uint256(vm.load(address(staking), bytes32(_slot)));
    }
}
