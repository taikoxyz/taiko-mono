// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

/// @title PIDBaseFeeController
/// @notice Implements a Proportional-Integral-Derivative (PID) controller for dynamic base fee
/// adjustment
/// @dev This contract manages base fee adjustments using a PID control algorithm to maintain
///      gas usage around a target level. The controller responds to differences between actual
///      gas usage and the target, making smooth adjustments to incentivize optimal block
/// utilization.
///      Uses uint256 for PID coefficients as they are always non-negative values.
/// @custom:security-contact security@taiko.xyz
contract PIDBaseFeeController is EssentialContract {
    /// @notice Minimum and maximum gas target bounds
    uint32 public constant MIN_GAS_TARGET = 1_000_000; // 1M gas minimum
    uint32 public constant MAX_GAS_TARGET = 100_000_000; // 100M gas maximum

    /// @notice Minimum base fee (must be at least 1)
    uint64 public constant MIN_BASE_FEE = 1;

    /// @notice Maximum base fee to prevent overflow
    uint64 public constant MAX_BASE_FEE = type(uint64).max / 2; // Leave room for calculations

    /// @notice Address authorized to update gas target and base fee
    address public immutable anchor;

    /// @notice Proportional coefficient for PID controller, scaled by 1000
    /// @dev Controls immediate response to error
    uint256 public immutable kP;

    /// @notice Integral coefficient for PID controller, scaled by 1000
    /// @dev Controls response to accumulated error over time
    uint256 public immutable kI;

    /// @notice Derivative coefficient for PID controller, scaled by 1000
    /// @dev Controls response to rate of error change
    uint256 public immutable kD;

    /// @notice Accumulated error integral for PID controller
    /// @dev Tracks cumulative difference between actual and target gas usage
    int256 public integral;

    /// @notice Previous error value for derivative calculation
    /// @dev Used to calculate rate of change in error
    int256 public previousError;

    /// @notice Current base fee in wei
    uint64 public baseFee;

    /// @notice Current gas usage target
    uint32 public gasTarget;

    /// @notice Options for gas target adjustment
    enum GasTargetOption {
        NoChange,
        Increase,
        Decrease
    }

    /// @notice Emitted when base fee is updated
    event BaseFeeUpdated(uint64 oldBaseFee, uint64 newBaseFee);

    /// @notice Emitted when gas target is updated
    event GasTargetUpdated(uint32 oldGasTarget, uint32 newGasTarget);

    /// @notice Error thrown when PID coefficients are invalid
    error InvalidPIDCoefficients();

    /// @notice Error thrown when initial parameters are invalid
    error InvalidInitialParameters();

    /// @notice Initializes the PID controller with specified parameters
    /// @param _anchor Address authorized to update controller parameters
    /// @param _kP Proportional coefficient (scaled by 1000, must be positive)
    /// @param _kI Integral coefficient (scaled by 1000, can be zero or positive)
    /// @param _kD Derivative coefficient (scaled by 1000, can be zero or positive)
    constructor(
        address _anchor,
        uint256 _kP,
        uint256 _kI,
        uint256 _kD
    )
        nonZeroAddr(_anchor)
        EssentialContract()
    {
        // Validate PID coefficients
        require(_kP != 0, "InvalidPIDCoefficients");

        anchor = _anchor;
        kP = _kP;
        kI = _kI;
        kD = _kD;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _baseFee Initial base fee in wei
    /// @param _gasTarget Initial gas usage target
    function init(address _owner, uint64 _baseFee, uint32 _gasTarget) external initializer {
        // Validate initial parameters
        require(
            _baseFee != 0 && _gasTarget >= MIN_GAS_TARGET && _gasTarget <= MAX_GAS_TARGET,
            "InvalidInitialParameters"
        );

        __Essential_init(_owner);

        baseFee = _baseFee;
        gasTarget = _gasTarget;

        // Initialize PID state (assume initial error is 0)
        integral = 0;
        previousError = 0;
    }

    /// @notice Updates gas target and base fee based on parent block gas usage
    /// @dev Only callable by the anchor address. Updates are performed in correct order:
    ///      1. Calculate new base fee using CURRENT gas target
    ///      2. Adjust gas target for NEXT iteration
    /// @param _gasTargetOption Option for adjusting the gas target
    /// @param _parentGasUsed Gas used in the parent block
    function updateGasTargetAndBaseFee(
        GasTargetOption _gasTargetOption,
        uint32 _parentGasUsed
    )
        external
        onlyFrom(anchor)
    {
        // Step 1: Calculate new base fee using CURRENT gas target
        uint64 oldBaseFee = baseFee;
        uint64 newBaseFee = _calculateNewBaseFee(_parentGasUsed, gasTarget, oldBaseFee);

        if (newBaseFee != oldBaseFee) {
            baseFee = newBaseFee;
            emit BaseFeeUpdated(oldBaseFee, newBaseFee);
        }

        // Step 2: Update gas target for NEXT iteration
        uint32 oldGasTarget = gasTarget;
        uint32 newGasTarget = _calculateNewGasTarget(_gasTargetOption, oldGasTarget);

        if (newGasTarget != oldGasTarget) {
            gasTarget = newGasTarget;
            emit GasTargetUpdated(oldGasTarget, newGasTarget);
        }
    }

    /// @notice Returns current base fee and gas target
    /// @return Current base fee in wei and gas usage target
    function getBaseFeeAndGasTarget() external view returns (uint64, uint32) {
        return (baseFee, gasTarget);
    }

    /// @notice Calculates new gas target based on adjustment option
    /// @param _option Gas target adjustment option
    /// @param _currentTarget Current gas target value
    /// @return New gas target value, clamped to valid bounds
    function _calculateNewGasTarget(
        GasTargetOption _option,
        uint32 _currentTarget
    )
        private
        pure
        returns (uint32)
    {
        if (_option == GasTargetOption.NoChange) return _currentTarget;

        uint256 adjustedTarget = _option == GasTargetOption.Increase
            ? uint256(_currentTarget) * 101 / 100
            : uint256(_currentTarget) * 100 / 101;

        // Clamp to valid bounds
        if (adjustedTarget > MAX_GAS_TARGET) return MAX_GAS_TARGET;
        if (adjustedTarget < MIN_GAS_TARGET) return MIN_GAS_TARGET;

        return uint32(adjustedTarget);
    }

    /// @notice Calculates new base fee using PID control algorithm
    /// @dev Implements PID control formula with proper overflow protection and anti-windup
    /// @param _parentGasUsed Gas used in the parent block
    /// @param _gasTarget Current gas usage target
    /// @param _currentBaseFee Current base fee
    /// @return New base fee, clamped to valid range
    function _calculateNewBaseFee(
        uint32 _parentGasUsed,
        uint32 _gasTarget,
        uint64 _currentBaseFee
    )
        private
        returns (uint64)
    {
        int256 newError = int256(uint256(_parentGasUsed)) - int256(uint256(_gasTarget));

        // Apply integral decay BEFORE adding new error
        int256 newIntegral = (integral * 999) / 1000;

        // Calculate derivative
        int256 derivative = newError - previousError;

        // Calculate PID adjustment with overflow protection
        int256 adjustment = _calculatePIDOutput(newError, newIntegral, derivative);

        // Apply anti-windup: only update integral if output won't saturate
        int256 potentialBaseFee = int256(uint256(_currentBaseFee)) + adjustment;
        if (potentialBaseFee > 0 && potentialBaseFee <= int256(uint256(MAX_BASE_FEE))) {
            newIntegral += newError;
        }

        // Update state for next iteration
        previousError = newError;
        integral = newIntegral;

        // Apply adjustment to base fee with proper bounds checking
        if (potentialBaseFee < int256(uint256(MIN_BASE_FEE))) return MIN_BASE_FEE;
        if (potentialBaseFee > int256(uint256(type(uint64).max))) return type(uint64).max;

        return uint64(uint256(potentialBaseFee));
    }

    /// @notice Calculates PID output with overflow protection
    /// @param error Current error value
    /// @param integralValue Current integral value
    /// @param derivative Current derivative value
    /// @return PID adjustment value
    function _calculatePIDOutput(
        int256 error,
        int256 integralValue,
        int256 derivative
    )
        private
        view
        returns (int256)
    {
        // Use assembly for overflow-safe multiplication or implement safe math
        // For simplicity, using unchecked with bounds checking
        unchecked {
            // Check for potential overflow before calculation
            int256 maxSafeError = type(int256).max / int256(kP > 0 ? kP : 1) / 1000;
            int256 maxSafeIntegral = type(int256).max / int256(kI > 0 ? kI : 1) / 1000;
            int256 maxSafeDerivative = type(int256).max / int256(kD > 0 ? kD : 1) / 1000;

            // Clamp values to prevent overflow
            if (error > maxSafeError) error = maxSafeError;
            if (error < -maxSafeError) error = -maxSafeError;
            if (integralValue > maxSafeIntegral) integralValue = maxSafeIntegral;
            if (integralValue < -maxSafeIntegral) integralValue = -maxSafeIntegral;
            if (derivative > maxSafeDerivative) derivative = maxSafeDerivative;
            if (derivative < -maxSafeDerivative) derivative = -maxSafeDerivative;

            return
                (int256(kP) * error + int256(kI) * integralValue + int256(kD) * derivative) / 1000;
        }
    }
}
