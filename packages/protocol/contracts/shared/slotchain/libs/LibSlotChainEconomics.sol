// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain economic arithmetic
/// @dev Implements the checked and explicitly rounded arithmetic shared by Slot Chain components.
/// @custom:security-contact security@taiko.xyz
library LibSlotChainEconomics {
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant BLOB_GAS_PER_BLOB = 131_072;

    /// @dev Returns the smaller operand.
    /// @param _a The first operand.
    /// @param _b The second operand.
    /// @return result_ The smaller operand.
    function min(uint256 _a, uint256 _b) internal pure returns (uint256 result_) {
        return _a < _b ? _a : _b;
    }

    /// @dev Divides and rounds toward positive infinity without evaluating `_numerator +
    /// `_denominator - 1`.
    /// @param _numerator The dividend.
    /// @param _denominator The nonzero divisor.
    /// @return result_ The ceiling of the quotient.
    function ceilDiv(
        uint256 _numerator,
        uint256 _denominator
    )
        internal
        pure
        returns (uint256 result_)
    {
        if (_denominator == 0) revert DivisionByZero();
        result_ = _numerator / _denominator;
        if (_numerator % _denominator != 0) {
            // The quotient cannot already be uint256.max when there is a remainder: for a
            // nonzero divisor it is strictly smaller than the numerator.
            unchecked {
                ++result_;
            }
        }
    }

    /// @dev Computes floor(`_a * _b / _denominator`) using the full 512-bit product. Reverts when
    /// the denominator is zero or the result does not fit uint256.
    /// @param _a The first multiplicand.
    /// @param _b The second multiplicand.
    /// @param _denominator The nonzero divisor.
    /// @return result_ The floor-rounded quotient.
    function mulDivDown(
        uint256 _a,
        uint256 _b,
        uint256 _denominator
    )
        internal
        pure
        returns (uint256 result_)
    {
        if (_denominator == 0) revert DivisionByZero();

        uint256 productLow;
        uint256 productHigh;
        assembly ("memory-safe") {
            let mm := mulmod(_a, _b, not(0))
            productLow := mul(_a, _b)
            productHigh := sub(sub(mm, productLow), lt(mm, productLow))
        }

        if (productHigh == 0) return productLow / _denominator;
        if (_denominator <= productHigh) revert MulDivOverflow();

        uint256 remainder;
        assembly ("memory-safe") {
            remainder := mulmod(_a, _b, _denominator)
            productHigh := sub(productHigh, gt(remainder, productLow))
            productLow := sub(productLow, remainder)
        }

        // Factor powers of two out of the denominator. `denominator <= productHigh` was rejected,
        // so the denominator is nonzero throughout this unchecked exact-division algorithm.
        uint256 twos = _denominator & (~_denominator + 1);
        assembly ("memory-safe") {
            _denominator := div(_denominator, twos)
            productLow := div(productLow, twos)
            twos := add(div(sub(0, twos), twos), 1)
        }
        unchecked {
            // Both operations intentionally use arithmetic modulo 2^256 to fold the high product
            // word into the now-exact low-word division.
            productLow |= productHigh * twos;
        }

        // Newton-Raphson inverse modulo 2^256. Each step doubles the number of correct bits.
        uint256 inverse;
        unchecked {
            inverse = (3 * _denominator) ^ 2;
            inverse *= 2 - _denominator * inverse;
            inverse *= 2 - _denominator * inverse;
            inverse *= 2 - _denominator * inverse;
            inverse *= 2 - _denominator * inverse;
            inverse *= 2 - _denominator * inverse;
            inverse *= 2 - _denominator * inverse;
            result_ = productLow * inverse;
        }
    }

    /// @dev Computes ceil(`_a * _b / _denominator`) using the full 512-bit product. Reverts when
    /// the denominator is zero or the result does not fit uint256.
    /// @param _a The first multiplicand.
    /// @param _b The second multiplicand.
    /// @param _denominator The nonzero divisor.
    /// @return result_ The ceiling-rounded quotient.
    function mulDivUp(
        uint256 _a,
        uint256 _b,
        uint256 _denominator
    )
        internal
        pure
        returns (uint256 result_)
    {
        result_ = mulDivDown(_a, _b, _denominator);
        if (mulmod(_a, _b, _denominator) != 0) {
            if (result_ == type(uint256).max) revert MulDivOverflow();
            unchecked {
                ++result_;
            }
        }
    }

    /// @dev Computes the exact DataSession post rent from the profile coefficients. Geometry
    /// validation (blob count and per-record byte bounds) remains the DataSession's responsibility.
    /// @param _publishedBytes The checked sum of declared published bytes.
    /// @param _blobCount The number of blobs attached to the post.
    /// @param _rentPerPublishedByteWei The immutable per-byte rent.
    /// @param _blobBaseFeeMultiplierBps The immutable multiplier, at most 10,000 BPS.
    /// @param _blobBaseFee The protocol-visible `block.blobbasefee` value.
    /// @return rentWei_ The exact byte rent plus upward-rounded blob surcharge.
    function dataSessionPostRent(
        uint256 _publishedBytes,
        uint256 _blobCount,
        uint256 _rentPerPublishedByteWei,
        uint256 _blobBaseFeeMultiplierBps,
        uint256 _blobBaseFee
    )
        internal
        pure
        returns (uint256 rentWei_)
    {
        if (_blobBaseFeeMultiplierBps > BPS_DENOMINATOR) revert InvalidBps();
        uint256 byteRent = _publishedBytes * _rentPerPublishedByteWei;
        uint256 blobGas = BLOB_GAS_PER_BLOB * _blobCount;
        uint256 blobWeight = blobGas * _blobBaseFeeMultiplierBps;
        uint256 blobSurcharge = mulDivUp(blobWeight, _blobBaseFee, BPS_DENOMINATOR);
        rentWei_ = byteRent + blobSurcharge;
    }

    /// @dev Computes the exact payable value for opening a DataSession.
    /// @param _refundableBondWei The refundable bond.
    /// @param _baseRentWei The immediately unaccounted base rent.
    /// @return paymentWei_ The exact required payment.
    function dataSessionOpenPayment(
        uint256 _refundableBondWei,
        uint256 _baseRentWei
    )
        internal
        pure
        returns (uint256 paymentWei_)
    {
        return _refundableBondWei + _baseRentWei;
    }

    /// @dev Computes the exact shared-schedule forced-envelope deposit and enforces its immutable
    /// maximum. All rate/cap nonzero checks belong to release-profile validation.
    /// @param _fixedIngressWei The fixed ingress charge.
    /// @param _accountedGas The normalized accounted gas.
    /// @param _executionWeiPerAccountedGas The execution rate.
    /// @param _proofWeiPerAccountedGas The proof rate.
    /// @param _byteLength The durable raw-input byte length.
    /// @param _permanentWeiPerByte The permanent publication/storage rate.
    /// @param _maximumAcceptedFeeWei The maximum accepted deposit.
    /// @return depositWei_ The exact required deposit.
    function forcedEnvelopeDeposit(
        uint256 _fixedIngressWei,
        uint256 _accountedGas,
        uint256 _executionWeiPerAccountedGas,
        uint256 _proofWeiPerAccountedGas,
        uint256 _byteLength,
        uint256 _permanentWeiPerByte,
        uint256 _maximumAcceptedFeeWei
    )
        internal
        pure
        returns (uint256 depositWei_)
    {
        uint256 gasRate = _executionWeiPerAccountedGas + _proofWeiPerAccountedGas;
        depositWei_ = _fixedIngressWei + _accountedGas * gasRate;
        depositWei_ += _byteLength * _permanentWeiPerByte;
        if (depositWei_ > _maximumAcceptedFeeWei) {
            revert FeeCapExceeded(depositWei_, _maximumAcceptedFeeWei);
        }
    }

    /// @dev Computes the exact premium reserve needed for a seat ask and duration.
    /// @param _askWeiPerSecond The reverse-auction ask.
    /// @param _durationSeconds The funded service duration.
    /// @return reserveWei_ The exact reserve.
    function seatPremiumReserve(
        uint256 _askWeiPerSecond,
        uint256 _durationSeconds
    )
        internal
        pure
        returns (uint256 reserveWei_)
    {
        return _askWeiPerSecond * _durationSeconds;
    }

    /// @dev Computes premium earned over one checked monotonic interval.
    /// @param _askWeiPerSecond The installed seat ask.
    /// @param _fromTimestamp The inclusive accrual start.
    /// @param _toTimestamp The exclusive accrual end, not earlier than the start.
    /// @return earnedWei_ The exact earned premium.
    function seatPremiumAccrual(
        uint256 _askWeiPerSecond,
        uint64 _fromTimestamp,
        uint64 _toTimestamp
    )
        internal
        pure
        returns (uint256 earnedWei_)
    {
        if (_toTimestamp < _fromTimestamp) revert InvalidTimeRange();
        return _askWeiPerSecond * uint256(_toTimestamp - _fromTimestamp);
    }

    /// @dev Adds one linear reward term while saturating at `_cap`. This formulation never
    /// evaluates an overflowing `_rate * _units` product.
    /// @param _total The reward accumulated so far.
    /// @param _rate The rate per unit.
    /// @param _units The metered units.
    /// @param _cap The immutable reward-class cap.
    /// @return result_ The cap-aware sum.
    function addCappedProduct(
        uint256 _total,
        uint256 _rate,
        uint256 _units,
        uint256 _cap
    )
        internal
        pure
        returns (uint256 result_)
    {
        if (_total >= _cap || _rate == 0 || _units == 0) return min(_total, _cap);
        uint256 remaining = _cap - _total;
        if (_units > remaining / _rate) return _cap;
        return _total + _rate * _units;
    }

    /// @dev Computes the exact fixed-plus-gas-plus-byte reward, capped after every term.
    /// @param _fixedWei The fixed reward.
    /// @param _perExecutionGasWei The rate per proved execution-gas unit.
    /// @param _executionGas The proof-authenticated execution-gas total.
    /// @param _perPublishedByteWei The rate per proof-authenticated published byte.
    /// @param _publishedBytes The proof-authenticated published-byte total.
    /// @param _capWei The reward-class cap.
    /// @return rewardWei_ The capped reward.
    function rewardAmount(
        uint256 _fixedWei,
        uint256 _perExecutionGasWei,
        uint256 _executionGas,
        uint256 _perPublishedByteWei,
        uint256 _publishedBytes,
        uint256 _capWei
    )
        internal
        pure
        returns (uint256 rewardWei_)
    {
        rewardWei_ = min(_fixedWei, _capWei);
        rewardWei_ = addCappedProduct(rewardWei_, _perExecutionGasWei, _executionGas, _capWei);
        rewardWei_ = addCappedProduct(rewardWei_, _perPublishedByteWei, _publishedBytes, _capWei);
    }

    /// @dev Computes the reporter and penalty shares of one builder-token slash.
    /// @param _slashAmount The slash amount in builder-token atomic units.
    /// @param _reporterRewardCap The immutable reporter cap in the same atomic units.
    /// @return reporterAmount_ The reporter share.
    /// @return penaltyAmount_ The builder-penalty sink share.
    function reporterRewardSplit(
        uint256 _slashAmount,
        uint256 _reporterRewardCap
    )
        internal
        pure
        returns (uint256 reporterAmount_, uint256 penaltyAmount_)
    {
        reporterAmount_ = min(_slashAmount, _reporterRewardCap);
        penaltyAmount_ = _slashAmount - reporterAmount_;
    }

    /// @dev Computes the full-lineup reverse-ask replacement threshold.
    /// @param _incumbentAsk The incumbent ask in wei per second.
    /// @param _absoluteImprovement The immutable absolute improvement floor.
    /// @param _relativeImprovementBps The immutable relative floor, at most 10,000 BPS.
    /// @return required_ The exact required ask reduction.
    function requiredAskImprovement(
        uint256 _incumbentAsk,
        uint256 _absoluteImprovement,
        uint256 _relativeImprovementBps
    )
        internal
        pure
        returns (uint256 required_)
    {
        if (_relativeImprovementBps > BPS_DENOMINATOR) revert InvalidBps();
        uint256 relative = mulDivUp(_incumbentAsk, _relativeImprovementBps, BPS_DENOMINATOR);
        uint256 floor = _absoluteImprovement > relative ? _absoluteImprovement : relative;
        return min(_incumbentAsk, floor);
    }

    /// @dev Returns whether a candidate ask satisfies the exact full-lineup replacement rule.
    /// @param _incumbentAsk The incumbent ask in wei per second.
    /// @param _candidateAsk The candidate ask in wei per second.
    /// @param _absoluteImprovement The immutable absolute improvement floor.
    /// @param _relativeImprovementBps The immutable relative floor.
    /// @return improves_ Whether the candidate strictly and sufficiently improves the ask.
    function improvesAsk(
        uint256 _incumbentAsk,
        uint256 _candidateAsk,
        uint256 _absoluteImprovement,
        uint256 _relativeImprovementBps
    )
        internal
        pure
        returns (bool improves_)
    {
        uint256 required =
            requiredAskImprovement(_incumbentAsk, _absoluteImprovement, _relativeImprovementBps);
        if (_candidateAsk >= _incumbentAsk) return false;
        return _incumbentAsk - _candidateAsk >= required;
    }

    /// @dev Adds two uint64 values and saturates at uint64.max.
    /// @param _a The first operand.
    /// @param _b The second operand.
    /// @return result_ The exact sum or uint64.max on overflow.
    function saturatingAdd64(uint64 _a, uint64 _b) internal pure returns (uint64 result_) {
        if (_b > type(uint64).max - _a) return type(uint64).max;
        return _a + _b;
    }

    /// @dev Narrows a uint256 only when it is representable as uint64.
    /// @param _value The value to narrow.
    /// @return result_ The narrowed value.
    function toUint64(uint256 _value) internal pure returns (uint64 result_) {
        if (_value > type(uint64).max) revert Uint64Overflow();
        return uint64(_value);
    }

    error DivisionByZero();
    error MulDivOverflow();
    error InvalidBps();
    error Uint64Overflow();
    error FeeCapExceeded(uint256 requiredFee, uint256 maximumFee);
    error InvalidTimeRange();
}
