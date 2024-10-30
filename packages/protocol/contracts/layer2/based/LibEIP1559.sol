// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@solady/src/utils/FixedPointMathLib.sol";
import "src/shared/common/LibMath.sol";

/// @title LibEIP1559
/// @notice Implements e^(x) based bonding curve for EIP-1559
/// @dev See https://ethresear.ch/t/make-eip-1559-more-like-an-amm-curve/9082 but some minor
/// difference as stated in docs/eip1559_on_l2.md.
/// @custom:security-contact security@taiko.xyz
library LibEIP1559 {
    using LibMath for uint256;

    /// @notice The maximum allowable input value for the exp() function.
    uint128 public constant MAX_EXP_INPUT = 135_305_999_368_893_231_588;

    error EIP1559_INVALID_PARAMS();

    /// @notice Calculates the base fee and gas excess for EIP-1559
    /// @param _gasTarget The target gas usage
    /// @param _gasExcess The current gas excess
    /// @param _gasIssuance The gas issuance
    /// @param _parentGasUsed The gas used by the parent block
    /// @param _minGasExcess The minimum gas excess
    /// @return basefee_ The calculated base fee
    /// @return gasExcess_ The calculated gas excess
    function calc1559BaseFee(
        uint64 _gasTarget,
        uint64 _gasExcess,
        uint64 _gasIssuance,
        uint32 _parentGasUsed,
        uint64 _minGasExcess
    )
        internal
        pure
        returns (uint256 basefee_, uint64 gasExcess_)
    {
        // We always add the gas used by parent block to the gas excess
        // value as this has already happened
        uint256 excess = uint256(_gasExcess) + _parentGasUsed;
        excess = excess > _gasIssuance ? excess - _gasIssuance : 1;
        gasExcess_ = uint64(excess.max(_minGasExcess).min(type(uint64).max));

        // The base fee per gas used by this block is the spot price at the
        // bonding curve, regardless the actual amount of gas used by this
        // block, however, this block's gas used will affect the next
        // block's base fee.
        basefee_ = basefee(gasExcess_, _gasTarget);
    }

    /// @dev Adjusts the gas excess to maintain the same base fee when the gas target changes.
    /// The formula used for adjustment is:
    /// `_newGasTarget*ln(_newGasTarget/_gasTarget)+_gasExcess*_newGasTarget/_gasTarget`
    /// @param _gasExcess The current gas excess.
    /// @param _gasTarget The current gas target.
    /// @param _newGasTarget The new gas target.
    /// @return success_ Indicates if the adjustment was successful.
    /// @return newGasExcess_ The adjusted gas excess.
    function adjustExcess(
        uint64 _gasExcess,
        uint64 _gasTarget,
        uint64 _newGasTarget
    )
        internal
        pure
        returns (bool success_, uint64 newGasExcess_)
    {
        if (_gasTarget == 0 || _newGasTarget == 0) {
            return (false, 0);
        }

        uint256 f = FixedPointMathLib.WAD;
        uint256 ratio = f * _newGasTarget / _gasTarget;

        if (ratio == 0 || ratio > uint256(type(int256).max)) {
            return (false, 0);
        }

        int256 lnRatio = FixedPointMathLib.lnWad(int256(ratio)); // may be negative

        uint256 newGasExcess;

        assembly {
            // compute x = (_newGasTarget * lnRatio + _gasExcess * ratio)
            let x := add(mul(_newGasTarget, lnRatio), mul(_gasExcess, ratio))

            // If x < 0, set newGasExcess to 0, otherwise calculate newGasExcess = x / f
            switch slt(x, 0)
            case 1 { newGasExcess := 0 }
            default { newGasExcess := div(x, f) }
        }

        return (true, uint64(newGasExcess.min(type(uint64).max)));
    }

    /// @dev Calculates the base fee using the formula: exp(_gasExcess/_gasTarget)/_gasTarget
    /// @param _gasExcess The current gas excess.
    /// @param _gasTarget The current gas target.
    /// @return The calculated base fee.
    function basefee(uint64 _gasExcess, uint64 _gasTarget) internal pure returns (uint256) {
        if (_gasTarget == 0) return 1;
        uint256 fee = ethQty(_gasExcess, _gasTarget) / _gasTarget;
        return fee == 0 ? 1 : fee;
    }

    /// @dev Calculates the exponential of the ratio of gas excess to gas target.
    /// @param _gasExcess The current gas excess.
    /// @param _gasTarget The current gas target.
    /// @return The calculated exponential value.
    function ethQty(uint64 _gasExcess, uint64 _gasTarget) internal pure returns (uint256) {
        if (_gasTarget == 0) revert EIP1559_INVALID_PARAMS();

        uint256 input = FixedPointMathLib.WAD * _gasExcess / _gasTarget;
        if (input > MAX_EXP_INPUT) {
            input = MAX_EXP_INPUT;
        }
        return uint256(FixedPointMathLib.expWad(int256(input))) / FixedPointMathLib.WAD;
    }
}
