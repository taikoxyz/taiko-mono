// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../common/IAddressResolver.sol";
import "../../common/LibStrings.sol";
import "../TaikoData.sol";

library LibL1BaseFee {
    function updateBaseFeeStat(TaikoData.State storage _state) internal {
        uint64 epoch = uint64(block.number / 32) + 1;
        TaikoData.BaseFeeStat memory stat = _state.basefeeStats[epoch % 2];

        if (stat.epoch != epoch) {
            stat = TaikoData.BaseFeeStat(0, 0, 0, 0);
        }

        _state.basefeeStats[epoch % 2] = TaikoData.BaseFeeStat({
            baseFeeSum: stat.baseFeeSum + uint64(block.basefee),
            blobBaseFeeSum: stat.blobBaseFeeSum + uint64(block.blobbasefee),
            epoch: epoch,
            count: stat.count + 1
        });
    }

    function getPrevEpocAvgBaseFees(TaikoData.State storage _state)
        internal
        view
        returns (uint64 consolidatedBaseFee_)
    {
        uint64 epoch = uint64(block.number / 32);
        TaikoData.BaseFeeStat memory stat = _state.basefeeStats[epoch % 2];

        if (stat.epoch == epoch) {
            // TODO: figure out the parameters
            consolidatedBaseFee_ =
                (stat.baseFeeSum * 10 + stat.blobBaseFeeSum * 9) / stat.count / 19 / 100;
        }
    }
}
