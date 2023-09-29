// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";

import { LibMath } from "../libs/LibMath.sol";

library Lib1559Math {
    using LibMath for uint256;

    error EIP1559_OUT_OF_GAS();

    function calcBaseFeePerGas(
        uint256 prevBaseFeePerGas,
        uint256 gasUsed,
        uint256 blockGasTarget
    )
        public
        view
        returns (uint256)
    {
        // console2.log(prevBaseFeePerGas);
        // console2.log(gasUsed);
        // console2.log(blockGasTarget);
        // Formula:
        // base_fee * (1 + 1/8 * (block_gas_used / block_gas_target - 1))
        return prevBaseFeePerGas * (gasUsed + blockGasTarget * 7)
            / (blockGasTarget * 8);
    }

    function calcBaseFeePerGasFromPool(
        uint256 poolProduct,
        uint256 gasIssuePerSecond,
        uint256 maxGasInPool,
        uint256 gasInPool,
        uint256 blockTime,
        uint256 gasToBuy
    )
        public
        view
        returns (uint256 _baseFeePerGas, uint256 _gasInPool)
    {
        // console2.log(poolProduct);
        // console2.log(gasIssuePerSecond);
        // console2.log(maxGasInPool);
        // console2.log(gasInPool);
        // console2.log(blockTime);
        // console2.log(gasToBuy);

        _gasInPool = maxGasInPool.min(gasInPool + gasIssuePerSecond * blockTime);
        uint256 _ethInPool = poolProduct / _gasInPool;

        if (gasToBuy == 0) {
            _baseFeePerGas = _ethInPool / _gasInPool;
        } else {
            if (gasToBuy >= _gasInPool) revert EIP1559_OUT_OF_GAS();
            _gasInPool -= gasToBuy;

            uint256 _ethInPoolNew = poolProduct / _gasInPool;
            _baseFeePerGas = (_ethInPoolNew - _ethInPool) / gasToBuy;
            _ethInPool = _ethInPoolNew;
        }
    }
}
