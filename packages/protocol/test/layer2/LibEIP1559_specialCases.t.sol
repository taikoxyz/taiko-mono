// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Layer2Test.sol";

contract TestLibEIP1559 is Layer2Test {
    using LibMath for uint256;

    uint8 internal constant adjustmentQuotient = 192;
    uint32 internal constant gasIssuancePerSecond = 5_000_000;

    uint64 internal constant minGasExcess = 1_340_000_000;
    uint32 internal constant maxGasIssuancePerBlock = 600_000_000;

    uint64 internal constant parentGasExcess = 1_340_000_000;
    uint64 internal constant parentTimestamp = 1_744_229_616;
    uint64 internal constant parentGasTarget = 40_000_000;

    uint32 internal constant _parentGasUsed = 181_563;
    uint64 internal constant _blockTimestamp = 1_744_229_840;

    function test_helder_block_23140() external view {
        // function getBasefeeV2(
        //     uint32 _parentGasUsed,
        //     uint64 _blockTimestamp,
        //     LibSharedData.BaseFeeConfig calldata _baseFeeConfig
        // )
        //     public
        //     view
        //     returns (uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_)
        // {
        //     // uint32 * uint8 will never overflow
        //     uint64 newGasTarget =
        //         uint64(_baseFeeConfig.gasIssuancePerSecond) * _baseFeeConfig.adjustmentQuotient;

        //     (newGasTarget_, newGasExcess_) =
        //         LibEIP1559.adjustExcess(parentGasTarget, newGasTarget, parentGasExcess);

        //     uint64 gasIssuance =
        //         (_blockTimestamp - parentTimestamp) * _baseFeeConfig.gasIssuancePerSecond;

        //     if (
        //         _baseFeeConfig.maxGasIssuancePerBlock != 0
        //             && gasIssuance > _baseFeeConfig.maxGasIssuancePerBlock
        //     ) {
        //         gasIssuance = _baseFeeConfig.maxGasIssuancePerBlock;
        //     }

        //     (basefee_, newGasExcess_) = LibEIP1559.calc1559BaseFee(
        //         newGasTarget_, newGasExcess_, gasIssuance, _parentGasUsed,
        // _baseFeeConfig.minGasExcess
        //     );
        // }

        uint64 newGasTarget = uint64(gasIssuancePerSecond) * adjustmentQuotient;

        (uint64 newGasTarget_, uint64 newGasExcess_) =
            LibEIP1559.adjustExcess(parentGasTarget, newGasTarget, parentGasExcess);

        uint64 gasIssuance = (_blockTimestamp - parentTimestamp) * gasIssuancePerSecond;

        if (maxGasIssuancePerBlock != 0 && gasIssuance > maxGasIssuancePerBlock) {
            gasIssuance = maxGasIssuancePerBlock;
        }
        uint256 newBaseFee;

        (newBaseFee, newGasExcess_) = LibEIP1559.calc1559BaseFee(
            newGasTarget_, newGasExcess_, gasIssuance, _parentGasUsed, minGasExcess
        );

        console2.log("calc1559BaseFee: ", newBaseFee);
        console2.log("newGasExcess_: ", newGasExcess_);
        console2.log("newGasTarget_: ", newGasTarget_);
    }
}
