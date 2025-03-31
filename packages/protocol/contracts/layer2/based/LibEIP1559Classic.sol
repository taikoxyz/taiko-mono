// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibEIP1559Classic
/// @notice Implements classic EIP-1559 base fee calculation.
/// @custom:security-contact security@taiko.xyz
library LibEIP1559Classic {
    /// @notice Calculates the classic base fee using the given parameters.
    /// @param _parentBasefee The base fee of the parent block.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _baseFeeChangeDenominator The denominator for base fee change calculation.
    /// @param _gasPerSeconds The gas issuance rate per second.
    /// @param _blockTime The time duration of the block.
    /// @return The calculated classic base fee.
    function calculateClassicBaseFee(
        uint256 _parentBasefee,
        uint256 _parentGasUsed,
        uint256 _baseFeeChangeDenominator,
        uint256 _gasPerSeconds,
        uint256 _blockTime
    )
        internal
        pure
        returns (uint256)
    {
        uint256 gasIssuance = _gasPerSeconds * _blockTime;
        if (gasIssuance == 0) {
            gasIssuance = 1;
        }
        return calculateClassicBaseFee(
            _parentBasefee, _parentGasUsed, _baseFeeChangeDenominator, gasIssuance
        );
    }

    /// @notice Calculates the classic base fee using the given parameters.
    /// @param _parentBasefee The base fee of the parent block.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _baseFeeChangeDenominator The denominator for base fee change calculation.
    /// @param _gasIssuance The gas issuance for the block.
    /// @return The calculated classic base fee.
    function calculateClassicBaseFee(
        uint256 _parentBasefee,
        uint256 _parentGasUsed,
        uint256 _baseFeeChangeDenominator,
        uint256 _gasIssuance
    )
        internal
        pure
        returns (uint256)
    {
        if (_parentGasUsed >= _gasIssuance) {
            return _parentBasefee
                + _parentBasefee * (_parentGasUsed - _gasIssuance) / _baseFeeChangeDenominator
                    / _gasIssuance;
        } else {
            return _parentBasefee
                - _parentBasefee * (_gasIssuance - _parentGasUsed) / _baseFeeChangeDenominator
                    / _gasIssuance;
        }
    }
}
