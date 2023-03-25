// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
import {TaikoData} from "../TaikoData.sol";

library Lib1559 {
    using LibMath for uint256;

    function getGasFeeStatus(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 gasPurchaseAmount
    )
        internal
        view
        returns (
            uint256 basefeePerGas,
            uint256 gasPurchaseCost,
            uint256 maxGasPurchaseAmount
        )
    {
        (basefeePerGas, gasPurchaseCost, ) = purchaseGas(
            config,
            state.gasExcess,
            gasPurchaseAmount
        );
        maxGasPurchaseAmount = getMaxGasPurchaseAmount(state, config);
    }

    function getMaxGasPurchaseAmount(
        TaikoData.State storage state,
        TaikoData.Config memory config
    ) internal view returns (uint256 amount) {
        amount = config.blockGasThrottle * 2;

        if (state.lastProposedHeight == block.number) {
            amount -= state.gasSoldThisBlock;
        }
    }

    function purchaseGas(
        TaikoData.Config memory config,
        uint256 gasExcess,
        uint256 gasPurchaseAmount
    )
        internal
        pure
        returns (
            uint64 basefeePerGas,
            uint256 gasPurchaseCost,
            uint256 newGasExcess
        )
    {
        uint256 t = config.blockGasTarget;
        uint256 q = config.basefeePerGasQuotient;
        uint256 eq1 = exp(gasExcess / t / q);
        basefeePerGas = uint64(eq1 / t / q);

        gasExcess += gasPurchaseAmount;
        uint256 eq2 = exp(gasExcess / t / q);
        gasPurchaseCost = eq2 - eq1; // Queston: is this correct???

        newGasExcess = t.max(gasExcess) - t;
    }

    // Return `2.71828 ** x`.
    function exp(uint256 x) internal pure returns (uint256 y) {
        // TODO
    }
}
