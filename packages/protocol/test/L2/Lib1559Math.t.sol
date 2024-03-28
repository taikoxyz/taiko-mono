// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestLib1559Math is TaikoTest {
    using LibMath for uint256;

    function test_eip1559_math() external {
        uint256 gasTarget = 15 * 1e6 * 10;
        uint256 adjustmentQuotient = 8;
        uint256 adjustmentFactor = gasTarget * adjustmentQuotient;
        // The expected values are calculated in eip1559_util.py

        uint256 baseFee =
            Lib1559Math.basefee({ _gasExcess: 49_954_623_777, _adjustmentFactor: adjustmentFactor });
        _assertAmostEq(baseFee, 1_199_999_900_175_871_825);

        baseFee = Lib1559Math.basefee({
            _gasExcess: LibFixedPointMath.MAX_EXP_INPUT * adjustmentFactor
                / LibFixedPointMath.SCALING_FACTOR,
            _adjustmentFactor: adjustmentFactor
        });
        _assertAmostEq(
            baseFee, 57_896_044_586_242_203_305_830_093_650_308_530_112_287_501_933_378_291_142_596
        );
    }

    // Assert the different between two number is smaller than 1/1000000
    function _assertAmostEq(uint256 _a, uint256 _b) private {
        uint256 min = _a.min(_b);
        uint256 max = _a.max(_b);
        assertTrue(max > 0 && ((max - min) * 1_000_000) / max <= 1);
        console2.log(_a, " <> ", _b);
    }
}
