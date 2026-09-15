// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibSlotChainL1Resources
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainL1Resources.sol";
import { Test } from "forge-std/src/Test.sol";

contract LibSlotChainL1ResourcesTest is Test {
    uint64 private constant _CAP = 16_777_216;
    L1ResourcesHarness private harness;

    function setUp() external {
        harness = new L1ResourcesHarness();
    }

    function test_constants_MatchNormativeResourcePolicy() external pure {
        assertEq(LibSlotChainL1Resources.L1_TRANSACTION_GAS_LIMIT, _CAP);
        assertEq(LibSlotChainL1Resources.TRANSACTION_BASE_GAS, 21_000);
        assertEq(LibSlotChainL1Resources.NONZERO_BYTE_TOKENS, 4);
        assertEq(LibSlotChainL1Resources.STANDARD_TOKEN_GAS, 4);
        assertEq(LibSlotChainL1Resources.FLOOR_TOKEN_GAS, 10);
        assertEq(LibSlotChainL1Resources.HEADROOM_PERCENT, 130);
        assertEq(LibSlotChainL1Resources.EIP150_DENOMINATOR, 63);
    }

    function test_requiredTransactionGas_MatchesModelFixturesAndUsesFloorWhenCalldataDominates()
        external
        pure
    {
        // Ordinary settlement fixture: 65,536 proof bytes above the verifier's 2,510,006 budget.
        assertEq(LibSlotChainL1Resources.requiredTransactionGas(0, 65_536, 2_510_006), 3_579_582);
        // Release registration fixture: 149,220 calldata bytes above a 9,600,000 execution bound.
        assertEq(LibSlotChainL1Resources.requiredTransactionGas(0, 149_220, 9_600_000), 12_008_520);
        // The EIP-7623 floor replaces, never adds to, the ordinary charge.
        assertEq(LibSlotChainL1Resources.requiredTransactionGas(0, 1_000_000, 0), 40_021_000);
        assertEq(LibSlotChainL1Resources.requiredTransactionGas(0, 0, 1), 21_001);
        assertEq(LibSlotChainL1Resources.requiredTransactionGas(5, 7, 100), 21_330);
        assertEq(LibSlotChainL1Resources.calldataTokens(5, 7), 33);
    }

    function test_requiredTransactionGas_RevertWhen_AnyIntermediateOverflowsUint64() external {
        vm.expectRevert(LibSlotChainL1Resources.L1ResourceOverflow.selector);
        harness.requiredTransactionGas(0, type(uint64).max, 0);
        vm.expectRevert(LibSlotChainL1Resources.L1ResourceOverflow.selector);
        harness.requiredTransactionGas(0, 0, type(uint64).max);
        vm.expectRevert(LibSlotChainL1Resources.L1ResourceOverflow.selector);
        harness.calldataTokens(type(uint64).max, 1);
    }

    function test_gasWithHeadroom_RoundsUpAtExactBoundaries() external pure {
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(0), 0);
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(1), 2);
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(100), 130);
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(3_579_582), 4_653_457);
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(12_008_520), 15_611_076);
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(12_905_550), 16_777_215);
        assertEq(LibSlotChainL1Resources.gasWithHeadroom(12_905_551), 16_777_217);
    }

    function test_gasWithHeadroom_RevertWhen_ScaledValueOverflowsUint64() external {
        vm.expectRevert(LibSlotChainL1Resources.L1ResourceOverflow.selector);
        harness.gasWithHeadroom(type(uint64).max / 130 + 1);
    }

    function test_transactionCap_UsesSmallerOfBlockLimitAndFixedCap() external {
        assertEq(LibSlotChainL1Resources.transactionCap(30_000_000), _CAP);
        assertEq(LibSlotChainL1Resources.transactionCap(_CAP), _CAP);
        assertEq(LibSlotChainL1Resources.transactionCap(_CAP - 1), _CAP - 1);
        assertEq(LibSlotChainL1Resources.transactionCap(1), 1);
        vm.expectRevert(LibSlotChainL1Resources.InvalidSupportedL1BlockGasLimit.selector);
        harness.transactionCap(0);
    }

    function test_fitsTransactionCap_AppliesMarginUnderBothCaps() external {
        assertTrue(LibSlotChainL1Resources.fitsTransactionCap(12_905_550, 30_000_000));
        assertFalse(LibSlotChainL1Resources.fitsTransactionCap(12_905_551, 30_000_000));
        assertTrue(LibSlotChainL1Resources.fitsTransactionCap(3_579_582, 4_653_457));
        assertFalse(LibSlotChainL1Resources.fitsTransactionCap(3_579_582, 4_653_456));
        LibSlotChainL1Resources.requireTransactionFits(12_905_550, 30_000_000);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibSlotChainL1Resources.L1TransactionBudgetExceeded.selector, 16_777_217, _CAP
            )
        );
        harness.requireTransactionFits(12_905_551, 30_000_000);
        vm.expectRevert(LibSlotChainL1Resources.InvalidSupportedL1BlockGasLimit.selector);
        harness.fitsTransactionCap(1, 0);
    }

    function test_callSequenceMinimumGas_RetainsLargerOfEip150HeadroomAndReserve() external pure {
        assertEq(LibSlotChainL1Resources.singleCallMinimumGas(2_000_000, 500_000), 2_500_000);
        assertEq(LibSlotChainL1Resources.singleCallMinimumGas(2_000_000, 0), 2_031_747);
        assertEq(LibSlotChainL1Resources.singleCallMinimumGas(63, 0), 64);
        assertEq(LibSlotChainL1Resources.singleCallMinimumGas(1, 0), 2);

        // PVM release fixture: Router, Market, six postreads, and the retained callback reserve.
        assertEq(
            LibSlotChainL1Resources.callSequenceMinimumGas(
                _releaseStipends(6_000_000, 1_000_000, 100_000), 2_000_000
            ),
            9_600_000
        );
        assertEq(
            LibSlotChainL1Resources.callSequenceMinimumGas(
                _releaseStipends(15_000_000, 1_000_000, 500_000), 2_000_000
            ),
            21_000_000
        );
        assertEq(
            LibSlotChainL1Resources.callSequenceMinimumGas(
                _releaseStipends(100_018, 100_019, 100_020), 100_021
            ),
            900_178
        );
        assertEq(LibSlotChainL1Resources.callSequenceMinimumGas(new uint64[](0), 7), 7);
    }

    function test_releaseResourceFixtures_FitOrExceedTheTransactionCapAsInTheModel() external pure {
        uint64 accepted = LibSlotChainL1Resources.requiredTransactionGas(
            0,
            149_220,
            LibSlotChainL1Resources.callSequenceMinimumGas(
                _releaseStipends(6_000_000, 1_000_000, 100_000), 2_000_000
            )
        );
        assertEq(accepted, 12_008_520);
        assertTrue(LibSlotChainL1Resources.fitsTransactionCap(accepted, _CAP));
        uint64 rejected = LibSlotChainL1Resources.requiredTransactionGas(
            0,
            149_220,
            LibSlotChainL1Resources.callSequenceMinimumGas(
                _releaseStipends(15_000_000, 1_000_000, 500_000), 2_000_000
            )
        );
        assertEq(rejected, 23_408_520);
        assertFalse(LibSlotChainL1Resources.fitsTransactionCap(rejected, _CAP));
    }

    function test_callSequenceMinimumGas_RevertWhen_StipendIsZeroOrOverflows() external {
        uint64[] memory stipends = new uint64[](2);
        stipends[0] = 1;
        vm.expectRevert(LibSlotChainL1Resources.InvalidL1CallStipend.selector);
        harness.callSequenceMinimumGas(stipends, 0);
        vm.expectRevert(LibSlotChainL1Resources.InvalidL1CallStipend.selector);
        harness.singleCallMinimumGas(0, 1);
        stipends[1] = type(uint64).max;
        vm.expectRevert(LibSlotChainL1Resources.L1ResourceOverflow.selector);
        harness.callSequenceMinimumGas(stipends, 0);
        vm.expectRevert(LibSlotChainL1Resources.L1ResourceOverflow.selector);
        harness.singleCallMinimumGas(1, type(uint64).max);
    }

    function _releaseStipends(
        uint64 _routerGas,
        uint64 _marketGas,
        uint64 _postreadGas
    )
        private
        pure
        returns (uint64[] memory stipends_)
    {
        stipends_ = new uint64[](8);
        stipends_[0] = _routerGas;
        stipends_[1] = _marketGas;
        for (uint256 i = 2; i < 8; ++i) {
            stipends_[i] = _postreadGas;
        }
    }
}

contract L1ResourcesHarness {
    function calldataTokens(
        uint64 _zeroBytes,
        uint64 _nonzeroBytes
    )
        external
        pure
        returns (uint64 tokens_)
    {
        return LibSlotChainL1Resources.calldataTokens(_zeroBytes, _nonzeroBytes);
    }

    function requiredTransactionGas(
        uint64 _zeroBytes,
        uint64 _nonzeroBytes,
        uint64 _executionGas
    )
        external
        pure
        returns (uint64 requiredGas_)
    {
        return
            LibSlotChainL1Resources.requiredTransactionGas(_zeroBytes, _nonzeroBytes, _executionGas);
    }

    function gasWithHeadroom(uint64 _requiredGas) external pure returns (uint64 gasWithHeadroom_) {
        return LibSlotChainL1Resources.gasWithHeadroom(_requiredGas);
    }

    function transactionCap(uint64 _supportedL1BlockGasLimit) external pure returns (uint64 cap_) {
        return LibSlotChainL1Resources.transactionCap(_supportedL1BlockGasLimit);
    }

    function fitsTransactionCap(
        uint64 _requiredGas,
        uint64 _supportedL1BlockGasLimit
    )
        external
        pure
        returns (bool fits_)
    {
        return LibSlotChainL1Resources.fitsTransactionCap(_requiredGas, _supportedL1BlockGasLimit);
    }

    function requireTransactionFits(
        uint64 _requiredGas,
        uint64 _supportedL1BlockGasLimit
    )
        external
        pure
    {
        LibSlotChainL1Resources.requireTransactionFits(_requiredGas, _supportedL1BlockGasLimit);
    }

    function callSequenceMinimumGas(
        uint64[] memory _stipends,
        uint64 _retainedReserve
    )
        external
        pure
        returns (uint64 minimumGas_)
    {
        return LibSlotChainL1Resources.callSequenceMinimumGas(_stipends, _retainedReserve);
    }

    function singleCallMinimumGas(
        uint64 _stipend,
        uint64 _retainedReserve
    )
        external
        pure
        returns (uint64 minimumGas_)
    {
        return LibSlotChainL1Resources.singleCallMinimumGas(_stipend, _retainedReserve);
    }
}
