// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../libs/LibMath.sol";

library LibTokenGrant {
    using LibMath for uint256;

    error INVALID_PARAMS();

    function calcVestedAmount(
        uint256 _grantAmount,
        uint256 _vestDuration,
        uint256 _time
    )
        internal
        pure
        returns (uint256)
    {
        if (_vestDuration == 0) return _grantAmount;
        return _portion(_grantAmount, _time, _vestDuration);
    }

    function calcUnlockedAmount(
        uint256 _grantAmount,
        uint256 _vestDuration,
        uint256 _unlockDuration,
        uint256 _time
    )
        internal
        pure
        returns (uint256)
    {
        if (_vestDuration == 0 && _unlockDuration == 0) revert INVALID_PARAMS();

        uint256 a = _vestDuration.min(_unlockDuration);
        uint256 b = _vestDuration.max(_unlockDuration);

        if (a == 0) {
            return _portion(_grantAmount, _time, b);
        }

        return _triagleArea(_grantAmount, a, b, _time, 0)
            + _triagleArea(_grantAmount, a, b, _time, a + b)
            - _triagleArea(_grantAmount, a, b, _time, a) //
            - _triagleArea(_grantAmount, a, b, _time, b);
    }

    function _portion(uint256 z, uint256 t, uint256 tMax) private pure returns (uint256) {
        return z * t.min(tMax) / tMax;
    }

    function _triagleArea(
        uint256 z,
        uint256 a,
        uint256 b,
        uint256 t,
        uint256 tMin
    )
        private
        pure
        returns (uint256)
    {
        if (a > b) revert INVALID_PARAMS();
        uint256 _t = t.max(tMin) - tMin;
        return z * _t * _t / b / a / 2;
    }
}
