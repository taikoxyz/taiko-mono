// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../libs/LibMath.sol";

library LibVestAndUnlock {
    using LibMath for uint256;

    function calcVestedAmount(
        uint256 _grantAmount,
        uint256 _vestDuration,
        uint256 _unlockDuration,
        uint256 _time
    )
        internal
        pure
        returns (uint256)
    {
        if (_vestDuration == 0) return _grantAmount;
        return _grantAmount * _time.min(_vestDuration) / _vestDuration;
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
        uint256 a = _vestDuration.min(_unlockDuration);
        uint256 b = _vestDuration.max(_unlockDuration);

        return _uint(_grantAmount, a, b, _time, 0) + _uint(_grantAmount, a, b, _time, a + b)
            - _uint(_grantAmount, a, b, _time, a) - _uint(_grantAmount, a, b, _time, b);
    }

    function _uint(
        uint256 z,
        uint256 a,
        uint256 b,
        uint256 t,
        uint256 tMin
    )
        private
        pure
        returns (uint256 r)
    {
        assert(a < b);
        uint256 _t = t.max(tMin) - tMin;
        r = z * _t / b;
        if (a != 0) {
            r = r * _t / a / 2;
        }
    }
}
