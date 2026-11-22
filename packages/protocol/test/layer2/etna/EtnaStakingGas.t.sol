// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";

/// @title EtnaStakingOnBlockStartGasBase
/// @notice Gas snapshots of the block-start call with all 128 seats occupied, every bit set and
/// every seated bond reaching missLimit in the same call; each must stay below the 30,000,000 gas
/// of the call's frame.
/// @dev `setUp` registers the bonds and makes any earlier call, and the measured test is a
/// separate transaction. The measured call therefore finds the staking and token storage cold
/// and pays for each write against the storage `setUp` committed, as a block's call does. A test
/// reads no staking or token storage before the measured call, since a read would warm it.
abstract contract EtnaStakingOnBlockStartGasBase is EtnaStakingTestBase {
    /// @dev The gas the execution layer gives the call's frame.
    uint256 internal constant FRAME_GAS = 30_000_000;

    /// @dev Deploys a staking contract with `_missLimit` and seats 128 bonds of `_stake` each.
    function _seatEveryBond(uint256 _missLimit, uint256 _stake) internal {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = _missLimit;
        staking = _deploy(cfg);
        for (uint256 pk = 1; pk <= N_MAX; ++pk) {
            _register(pk, Bob, _stake);
        }
    }

    /// @dev Measures, as `_label`, the next block's call with every bit set, which must succeed
    /// below the frame gas and penalize every one of the 128 bonds of `_stake`.
    function _measure(string memory _label, uint256 _stake) internal {
        bytes memory data =
            abi.encodeCall(IEtnaStaking.onBlockStart, (uint48(1), type(uint128).max));
        address target = address(staking);
        vm.roll(block.number + 1);
        vm.prank(SYSTEM_CALLER);
        (bool ok,) = target.call{ gas: FRAME_GAS }(data);
        uint256 gasUsed = vm.snapshotGasLastCall(_label);

        assertTrue(ok, "the call succeeds within the frame");
        emit log_named_uint(_label, gasUsed);
        assertLt(gasUsed, FRAME_GAS, _label);
        assertEq(token.balanceOf(SLASH_SINK), N_MAX * (_stake / 10), "every bond penalized");
    }

    /// @dev Returns the word at T + `_offset`.
    function _word(uint256 _offset) internal view returns (uint256) {
        return uint256(vm.load(address(staking), bytes32(uint256(T) + _offset)));
    }
}

/// @title EtnaStakingOnBlockStartWorstCaseGasTest
/// @notice The worst case. missLimit is 1 and no call has run since the 128 registrations, so the
/// measured call penalizes every bond, each bond of 2m keeps its seat, and every one of the 256
/// snapshot record words, the 8 miss-count words and slashSink's balance goes from zero to
/// nonzero.
contract EtnaStakingOnBlockStartWorstCaseGasTest is EtnaStakingOnBlockStartGasBase {
    /// @dev The EIP-170 contract size limit in bytes.
    uint256 private constant _EIP170_LIMIT = 24_576;

    /// @dev The EIP-1967 implementation slot.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    function setUp() public override {
        super.setUp();
        _seatEveryBond(1, 2 * MIN_STAKE);
        // Checked here, not in the test: reading the words there would warm them.
        for (uint256 offset; offset < 259; ++offset) {
            assertEq(_word(offset), 0, "no snapshot before the call");
        }
    }

    function test_gas_onBlockStart_WorstCasePenaltiesKeepSeats() external {
        _measure("on_block_start_worst_case", 2 * MIN_STAKE);

        for (uint8 seat; seat < N_MAX; ++seat) {
            _assertBondInSeat(seat, true, seat, "seat kept");
            assertGt(_word(3 + 2 * uint256(seat)), 0, "record word 1 written");
            assertGt(_word(4 + 2 * uint256(seat)), 0, "record word 2 written");
        }
        assertEq(
            _word(1),
            N_MAX * (2 * MIN_STAKE - 2 * MIN_STAKE / 10),
            "the total of the reduced stakes"
        );
    }

    /// @dev The implementation stays deployable under EIP-170.
    function test_size_EtnaStakingBelowEip170() external {
        address impl = address(uint160(uint256(vm.load(address(staking), _IMPLEMENTATION_SLOT))));
        assertGt(impl.code.length, 0, "the proxy's implementation");
        emit log_named_uint("EtnaStaking runtime bytes", impl.code.length);
        assertLe(impl.code.length, _EIP170_LIMIT, "EIP-170");
    }
}

/// @title EtnaStakingOnBlockStartReleaseSeatsGasTest
/// @notice Every bond of m loses 10% and releases its seat, one key decompression each. missLimit
/// is 2 and `setUp` makes a call with every bit set first, so the measured call clears 256
/// nonzero snapshot record words.
contract EtnaStakingOnBlockStartReleaseSeatsGasTest is EtnaStakingOnBlockStartGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond(2, MIN_STAKE);
        _blockStart(1, type(uint128).max);
        for (uint8 seat; seat < N_MAX; ++seat) {
            assertEq(staking.missCount(seat), 1, "count 1 after the first call");
        }
    }

    function test_gas_onBlockStart_PenaltiesReleaseEverySeat() external {
        _measure("on_block_start_128_penalties_seats_released", MIN_STAKE);

        for (uint8 seat; seat < N_MAX; ++seat) {
            _assertBondInSeat(seat, false, 0, "seat released");
        }
        for (uint256 offset = 1; offset < 259; ++offset) {
            assertEq(_word(offset), 0, "an empty snapshot");
        }
    }
}
