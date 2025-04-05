// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";

/// @title LibEIP1559Classic
/// @notice Implements classic EIP-1559 base fee calculation.
/// @custom:security-contact security@taiko.xyz
library LibEIP1559Classic {
    using LibMath for uint256;

    error ZeroBlockTime();
    error ZeroGasPerSecond();

    /// @dev This value is the minimum base fee for Ontake.
    uint256 public constant MIN_BASE_FEE = 0.008847185 gwei;
    uint256 public constant MAX_BASE_FEE = 100 gwei;

    /// @dev Max value for block time calculation.
    /// @dev This value is set to 13 to ensure calculation never overflow or underflow.
    uint256 public constant BLOCK_TIME_CALCULATION_CAP = LibNetwork.ETHEREUM_BLOCK_TIME;

    /// @notice Calculates the classic base fee using the given parameters.
    /// @param _parentBasefee The base fee of the parent block.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _adjustmentQuotient The denominator for base fee change calculation per 12-second.
    /// @param _gasPerSeconds The gas issuance rate per second.
    /// @param _blockTime The time duration of the block.
    /// @return The calculated classic base fee.
    function calculateBaseFee(
        uint256 _parentBasefee,
        uint256 _parentGasUsed,
        uint8 _adjustmentQuotient,
        uint32 _gasPerSeconds,
        uint256 _blockTime
    )
        internal
        pure
        returns (uint256)
    {
        require(_blockTime != 0, ZeroBlockTime());
        require(_gasPerSeconds != 0, ZeroGasPerSecond());

        // The following calculation will shall never overflow or underflow.
        uint256 changePerSecondDenominator =
            uint256(_adjustmentQuotient) * LibNetwork.ETHEREUM_BLOCK_TIME;
        uint256 effectiveBlockTime = _blockTime.min(BLOCK_TIME_CALCULATION_CAP);
        uint256 changeDenominator = changePerSecondDenominator ** effectiveBlockTime;
        uint256 changeNumerator =
            (changePerSecondDenominator + 1) ** effectiveBlockTime - changeDenominator;

        uint256 gasIssuance = effectiveBlockTime * _gasPerSeconds;

        return _calculateBaseFee(
            _parentBasefee, _parentGasUsed, gasIssuance, changeNumerator, changeDenominator
        ).max(MIN_BASE_FEE).min(MAX_BASE_FEE);
    }

    function _calculateBaseFee(
        uint256 _parentBasefee,
        uint256 _parentGasUsed,
        uint256 _gasIssuance,
        uint256 _changeNumerator,
        uint256 _changeDenominator
    )
        private
        pure
        returns (uint256)
    {
        return _parentGasUsed >= _gasIssuance
            ? _parentBasefee
                + _parentBasefee * (_parentGasUsed - _gasIssuance) / _gasIssuance * _changeNumerator
                    / _changeDenominator
            : _parentBasefee
                - _parentBasefee * (_gasIssuance - _parentGasUsed) / _gasIssuance * _changeNumerator
                    / _changeDenominator;
    }
}
