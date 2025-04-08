// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/eip1559/LibEIP1559Classic.sol";

/// @title BaseFeeContract
/// @notice A simple contract with Taiko L2 base fee calculation logic.
/// @dev The implementation in this contract shall be the same as the one in ShastaAnchor.sol
contract BaseFeeContract {
    uint8 public immutable adjustmentQuotient;
    uint32 public immutable gasIssuancePerSecond;

    uint64 public accumulatedAncestorGasUsed;
    uint256 public parentBaseFee;

    constructor(uint256 _parentBaseFee, uint8 _adjustmentQuotient, uint32 _gasIssuancePerSecond) {
        adjustmentQuotient = _adjustmentQuotient;
        gasIssuancePerSecond = _gasIssuancePerSecond;
        parentBaseFee = _parentBaseFee;
    }

    function calculateAndUpdateBaseFee(
        uint64 _parentGasUsed,
        uint256 _blockTime
    )
        external
        returns (uint256 parentBaseFee_)
    {
        if (_blockTime == 0) {
            accumulatedAncestorGasUsed += _parentGasUsed;
        } else {
            accumulatedAncestorGasUsed = 0;
        }
        parentBaseFee_ = LibEIP1559Classic.calculateBaseFee(
            parentBaseFee,
            _parentGasUsed + accumulatedAncestorGasUsed,
            adjustmentQuotient,
            gasIssuancePerSecond,
            _blockTime
        );

        parentBaseFee = parentBaseFee_;
    }
}
