// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer2/based/eip1559/LibEIP1559Classic.sol";
import "forge-std/src/console2.sol";
/// @title BaseFeeContract
/// @notice A simple contract with Taiko L2 base fee calculation logic.
/// @dev The implementation in this contract shall be the same as the one in ShastaAnchor.sol
contract BaseFeeContract {
    uint8 public immutable adjustmentQuotient;

    uint32 public gasIssuancePerSecond;
    uint64 public accumulatedAncestorGasUsed;
    uint256 public parentBaseFee;

    constructor(uint256 _parentBaseFee, uint8 _adjustmentQuotient) {
        adjustmentQuotient = _adjustmentQuotient;
        parentBaseFee = _parentBaseFee;
    }

    function calculateAndUpdateBaseFee(
        uint64 _parentGasUsed,
        uint256 _blockTime
    )
        external
        returns (uint256, uint32)
    {
        if (_blockTime == 0) {
            accumulatedAncestorGasUsed += _parentGasUsed;
            return (parentBaseFee, gasIssuancePerSecond);
        }

        uint64 gasUsed = _parentGasUsed + accumulatedAncestorGasUsed;

        if (gasIssuancePerSecond == 0) {
            gasIssuancePerSecond = uint32(gasUsed / _blockTime);
        } else {
            gasIssuancePerSecond = uint32(
                (uint256(gasIssuancePerSecond) * (24 - 1) + gasUsed / _blockTime)
                    / 24
            );
        }

        require(gasIssuancePerSecond != 0, "gasIssuancePerSecond is 0");

        accumulatedAncestorGasUsed = 0;
        parentBaseFee = _blockTime == 0 || gasIssuancePerSecond == 0
            ? parentBaseFee
            : LibEIP1559Classic.calculateBaseFee(
                parentBaseFee, gasUsed, adjustmentQuotient, gasIssuancePerSecond, _blockTime
            );

        return (parentBaseFee, gasIssuancePerSecond);
    }
}
