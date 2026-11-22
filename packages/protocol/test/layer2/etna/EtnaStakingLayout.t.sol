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

    /// @dev K1 in seat 5 maps, at keccak256(abi.encode(ckAddr(K1), T + 2)), to holdsSeat = 1 and
    /// seat = 5 packed from the least-significant bit, and to the zero word once it leaves.
    function test_layout_KeySeatWordAtTheSpecSlot() external {
        for (uint256 pk = 11; pk < 16; ++pk) {
            _register(pk, Bob, MIN_STAKE);
        }
        uint256 bondId = _register(_K1, Carol, MIN_STAKE);
        bytes32 slot = 0x5aed0c9b66e2d0fa057ebed89e910688ada65f4c543b321333450c21264ccf27;
        assertEq(
            slot,
            keccak256(abi.encode(EtnaTestKeys.ckAddr(_K1), uint256(T) + 2)),
            "the slot of K1's key"
        );
        _assertSeatOfBond(bondId, true, 5, "the sixth bond takes seat 5");
        assertEq(vm.load(address(staking), slot), bytes32(uint256(0x0501)), "holds seat 5");

        _requestExit(bondId);
        assertEq(vm.load(address(staking), slot), bytes32(0), "zero after the exit");
    }

    /// @dev No transaction writes `snapshotHeight` (T), `snapshotTotalStake` (T + 1) or a snapshot
    /// seat record (T + 3 to T + 258): only the block-start call writes them.
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
            assertTrue(slot < base + 3 || slot > base + 258, "a snapshot seat record written");
        }
        for (uint256 offset; offset < 259; ++offset) {
            assertEq(vm.load(address(staking), bytes32(base + offset)), bytes32(0), "still zero");
        }
    }

    /// @dev A bond's three words sit at keccak256(abi.encode(id, T + 260)) + 0..2, word 0 packing
    /// [owner (160 bits), ckPrefix, withdrawn, holdsSeat, seat (8 bits each), exitHeight
    /// (48 bits)] from the least-significant bit; `seatBond[s]` (bond id + 1) sits at
    /// T + 262 + s, the key lookup (bond id + 1) at T + 259, the bond count at T + 261 and the
    /// occupancy bitmap at T + 398.
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

        assertEq(_word(base + 262), 1, "seat 0 holds bond 0");
        assertEq(_word(base + 263), 0, "seat 1 is empty");
        assertEq(_word(base + 264), bondId + 1, "seat 2 holds bond 2");
        assertEq(
            uint256(
                vm.load(address(staking), keccak256(abi.encode(EtnaTestKeys.ckAddr(3), base + 259)))
            ),
            bondId + 1,
            "key lookup"
        );
        assertEq(_word(base + 261), 3, "bond count");
        assertEq(_word(base + 398), 0x5, "occupancy bitmap: seats 0 and 2");
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
        uint256 slot = uint256(keccak256(abi.encode(_bondId, uint256(T) + 260)));
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
