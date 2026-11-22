// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";

/// @dev The `cool` cheatcode, which the pinned forge-std does not declare: it marks an account's
/// storage cold.
interface ICoolCheatcode {
    function cool(address _target) external;
}

/// @title EtnaStakingOnBlockStartWorstCaseGasTest
/// @notice The block-start call's worst case, with all 128 seats occupied, every bit set and every
/// seated bond reaching missLimit in the same call, must fit the 30,000,000 gas of the call's frame.
/// @dev missLimit is 2: a warm-up call with every bit set brings each count to 1, so the measured
/// call penalizes all 128 bonds. The proxy, its implementation and the token are cooled before the
/// measured call, which a block makes with that storage cold.
contract EtnaStakingOnBlockStartWorstCaseGasTest is EtnaStakingTestBase {
    /// @dev The gas the execution layer gives the call's frame.
    uint256 private constant _FRAME_GAS = 30_000_000;

    /// @dev The EIP-170 contract size limit in bytes.
    uint256 private constant _EIP170_LIMIT = 24_576;

    /// @dev The EIP-1967 implementation slot.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    function setUp() public override {
        super.setUp();
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 2;
        staking = _deploy(cfg);
    }

    /// @dev Bonds of 2m each lose 10% and keep their seats.
    function test_gas_onBlockStart_WorstCasePenaltiesKeepSeats() external {
        _measureWorstCase("on_block_start_128_penalties_keep_seats", 2 * MIN_STAKE);
        for (uint8 seat; seat < N_MAX; ++seat) {
            _assertBondInSeat(seat, true, seat, "seat kept");
        }
        assertEq(
            uint256(vm.load(address(staking), bytes32(uint256(T) + 1))),
            N_MAX * (2 * MIN_STAKE - 2 * MIN_STAKE / 10),
            "the total holds every reduced stake"
        );
    }

    /// @dev Bonds of m each lose 10% and release their seats, one key decompression each.
    function test_gas_onBlockStart_WorstCasePenaltiesReleaseSeats() external {
        _measureWorstCase("on_block_start_128_penalties_release_seats", MIN_STAKE);
        for (uint8 seat; seat < N_MAX; ++seat) {
            _assertBondInSeat(seat, false, 0, "seat released");
        }
        assertEq(uint256(vm.load(address(staking), bytes32(uint256(T) + 1))), 0, "empty total");
    }

    /// @dev The implementation stays deployable under EIP-170.
    function test_size_EtnaStakingBelowEip170() external {
        uint256 size = _implementation().code.length;
        emit log_named_uint("EtnaStaking runtime bytes", size);
        assertLe(size, _EIP170_LIMIT, "EIP-170");
    }

    /// @dev Seats 128 bonds of `_stake` each, makes the warm-up call, cools the storage and
    /// measures the call that penalizes every bond as `_label`.
    function _measureWorstCase(string memory _label, uint256 _stake) private {
        for (uint256 pk = 1; pk <= N_MAX; ++pk) {
            _register(pk, Bob, _stake);
        }
        _blockStart(1, type(uint128).max);
        for (uint8 seat; seat < N_MAX; ++seat) {
            assertEq(staking.missCount(seat), 1, "warm-up count");
        }

        ICoolCheatcode(address(vm)).cool(address(staking));
        ICoolCheatcode(address(vm)).cool(_implementation());
        ICoolCheatcode(address(vm)).cool(address(token));
        bytes memory data =
            abi.encodeCall(IEtnaStaking.onBlockStart, (uint48(1), type(uint128).max));
        address target = address(staking);
        vm.roll(block.number + 1);
        vm.prank(SYSTEM_CALLER);
        (bool ok,) = target.call{ gas: _FRAME_GAS }(data);
        uint256 gasUsed = vm.snapshotGasLastCall(_label);

        assertTrue(ok, "the worst case succeeds within the frame");
        emit log_named_uint(_label, gasUsed);
        assertLe(gasUsed, _FRAME_GAS, _label);
        assertEq(token.balanceOf(SLASH_SINK), N_MAX * (_stake / 10), "every bond penalized");
    }

    /// @dev Returns the staking proxy's implementation.
    function _implementation() private view returns (address impl_) {
        impl_ = address(uint160(uint256(vm.load(address(staking), _IMPLEMENTATION_SLOT))));
        assertGt(impl_.code.length, 0, "the proxy's implementation");
    }
}
