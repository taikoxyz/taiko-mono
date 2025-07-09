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
///      Uses int256 for PID coefficients to properly handle both positive and negative adjustments.
/// @custom:security-contact security@taiko.xyz
contract PIDBaseFeeController is EssentialContract {
    /// @notice Address authorized to update gas target and base fee
    address public immutable anchor;

    /// @notice Proportional coefficient for PID controller, scaled by 1000
    /// @dev Controls immediate response to error
    int256 public immutable kP;

    /// @notice Integral coefficient for PID controller, scaled by 1000
    /// @dev Controls response to accumulated error over time
    int256 public immutable kI;

    /// @notice Derivative coefficient for PID controller, scaled by 1000
    /// @dev Controls response to rate of error change
    int256 public immutable kD;

    /// @notice Accumulated error integral for PID controller
    /// @dev Tracks cumulative difference between actual and target gas usage
    int256 public integral; // slot 1

    /// @notice Previous error value for derivative calculation
    /// @dev Used to calculate rate of change in error
    int256 public previousError; // slot 2

    /// @notice Current base fee in wei
    uint64 public baseFee; // slot 3

    /// @notice Current gas usage target
    uint32 public gasTarget;

    /// @notice Options for gas target adjustment
    /// @param NoChange Keep the current gas target
    /// @param Increase Increase gas target by 1%
    /// @param Decrease Decrease gas target by approximately 0.99%
    enum GasTargetOption {
        NoChange,
        Increase,
        Decrease
    }

    /// @notice Emitted when base fee is updated
    /// @param oldBaseFee Previous base fee value
    /// @param newBaseFee New base fee value
    event BaseFeeUpdated(uint64 oldBaseFee, uint64 newBaseFee);

    /// @notice Emitted when gas target is updated
    /// @param oldGasTarget Previous gas target value
    /// @param newGasTarget New gas target value
    event GasTargetUpdated(uint32 oldGasTarget, uint32 newGasTarget);

    /// @notice Initializes the PID controller with specified parameters
    /// @param _anchor Address authorized to update controller parameters
    /// @param _kP Proportional coefficient (scaled by 1000)
    /// @param _kI Integral coefficient (scaled by 1000)
    /// @param _kD Derivative coefficient (scaled by 1000)
    constructor(
        address _anchor,
        int256 _kP,
        int256 _kI,
        int256 _kD
    )
        nonZeroAddr(_anchor)
        EssentialContract()
    {
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
        __Essential_init(_owner);

        baseFee = _baseFee;
        gasTarget = _gasTarget;
    }

    /// @notice Updates gas target and base fee based on parent block gas usage
    /// @dev Only callable by the anchor address. Updates are performed in two steps:
    ///      1. Adjust gas target based on the provided option
    ///      2. Calculate new base fee using PID controller based on gas usage error
    /// @param _gasTargetOption Option for adjusting the gas target
    /// @param _parentGasUsed Gas used in the parent block
    function updateGasTargetAndBaseFee(
        GasTargetOption _gasTargetOption,
        uint32 _parentGasUsed
    )
        external
        onlyFrom(anchor)
    {
        // Update gas target based on the option provided
        uint32 oldGasTarget = gasTarget;
        uint32 newGasTarget = _calculateNewGasTarget(_gasTargetOption, oldGasTarget);

        if (newGasTarget != oldGasTarget) {
            gasTarget = newGasTarget;
            emit GasTargetUpdated(oldGasTarget, newGasTarget);
        }

        // Calculate the PID adjustment to update the base fee
        uint64 oldBaseFee = baseFee;
        uint64 newBaseFee = _calculateNewBaseFee(_parentGasUsed, newGasTarget, oldBaseFee);

        if (newBaseFee != oldBaseFee) {
            baseFee = newBaseFee;
            emit BaseFeeUpdated(oldBaseFee, newBaseFee);
        }
    }

    /// @notice Returns current base fee and gas target
    /// @return baseFee Current base fee in wei
    /// @return gasTarget Current gas usage target
    function getBaseFeeAndGasTarget() external view returns (uint64, uint32) {
        return (baseFee, gasTarget);
    }

    /// @notice Calculates new gas target based on adjustment option
    /// @dev Increases by 1% for Increase option, decreases by ~0.99% for Decrease option
    /// @param _option Gas target adjustment option
    /// @param _currentTarget Current gas target value
    /// @return New gas target value, clamped between 1 and uint32.max
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

        if (adjustedTarget > type(uint32).max) return type(uint32).max;
        if (adjustedTarget == 0) return 1;

        return uint32(adjustedTarget);
    }

    /// @notice Calculates new base fee using PID control algorithm
    /// @dev Implements PID control formula: output = kP*e + kI*∫e + kD*de/dt
    ///      where e is the error (gas used - gas target)
    /// @param _parentGasUsed Gas used in the parent block
    /// @param _gasTarget Current gas usage target
    /// @param _currentBaseFee Current base fee
    /// @return New base fee, clamped between 0 and uint64.max
    function _calculateNewBaseFee(
        uint32 _parentGasUsed,
        uint32 _gasTarget,
        uint64 _currentBaseFee
    )
        private
        returns (uint64)
    {
        int256 newError = int256(uint256(_parentGasUsed)) - int256(uint256(_gasTarget));

        // Apply anti-windup: skip integral update if base fee is saturated
        int256 newIntegral = integral;
        if (
            !(
                (_currentBaseFee == 0 && newError < 0)
                    || (_currentBaseFee == type(uint64).max && newError > 0)
            )
        ) {
            newIntegral += newError;
        }

        // Optionally decay integral to prevent long-term buildup
        newIntegral = (newIntegral * 999) / 1000;

        int256 derivative = newError - previousError;
        int256 adjustment = (kP * newError + kI * newIntegral + kD * derivative) / 1000;

        previousError = newError;
        integral = newIntegral;

        int256 newBaseFee = int256(uint256(_currentBaseFee)) + adjustment;

        if (newBaseFee <= 0) return 0;
        if (newBaseFee > int256(uint256(type(uint64).max))) return type(uint64).max;

        return uint64(uint256(newBaseFee));
    }
}
