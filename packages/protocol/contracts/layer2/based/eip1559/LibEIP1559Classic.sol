// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";

/// @title LibEIP1559Classic
/// @notice Implements classic EIP-1559 base fee calculation.
/// @custom:security-contact security@taiko.xyz
library LibEIP1559Classic {
    using LibMath for uint256;

    /// @dev This value is the minimum base fee for Ontake.
    uint256 public constant MIN_BASE_FEE = 0.008847185 gwei;

    /// @dev Gas should not be issued for more than 12 seconds.
    uint256 public constant GAS_ISSUANCE_TIME_CAP = 12 seconds;

    /// @notice Calculates the classic base fee using the given parameters.
    /// @param _parentBasefee The base fee of the parent block.
    /// @param _parentGasUsed The gas used in the parent block.
    /// @param _adjustmentQuotient The denominator for base fee change calculation.
    /// @param _gasPerSeconds The gas issuance rate per second.
    /// @param _blockTime The time duration of the block.
    /// @return The calculated classic base fee.
    function calculateClassicBaseFee(
        uint256 _parentBasefee,
        uint256 _parentGasUsed,
        uint256 _adjustmentQuotient,
        uint256 _gasPerSeconds,
        uint256 _blockTime
    )
        internal
        pure
        returns (uint256)
    {
        uint256 gasIssuance = _gasPerSeconds * _blockTime.min(GAS_ISSUANCE_TIME_CAP);
        if (gasIssuance == 0) {
            return _parentBasefee;
        }
        return _calculateClassicBaseFee(
            _parentBasefee, _parentGasUsed, _adjustmentQuotient, gasIssuance
        ).max(MIN_BASE_FEE);
    }

    function _calculateClassicBaseFee(
        uint256 _parentBasefee,
        uint256 _parentGasUsed,
        uint256 _adjustmentQuotient,
        uint256 _gasIssuance
    )
        private
        pure
        returns (uint256)
    {
        if (_parentGasUsed >= _gasIssuance) {
            return _parentBasefee
                + _parentBasefee * (_parentGasUsed - _gasIssuance) / _adjustmentQuotient / _gasIssuance;
        } else {
            return _parentBasefee
                - _parentBasefee * (_gasIssuance - _parentGasUsed) / _adjustmentQuotient / _gasIssuance;
        }
    }
}
