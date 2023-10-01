// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibFixedPointMath } from "../../thirdparty/LibFixedPointMath.sol";

import { EIP1559Manager } from "./EIP1559Manager.sol";

library Lib1559Exp {
    using LibMath for uint256;

    error EIP1559_OUT_OF_GAS();

    function calcBaseFeePerGas(
        uint256 gasIssuePerSecond,
        uint256 xscale,
        uint256 yscale,
        uint256 gasExcessMax,
        uint256 gasExcess,
        uint256 blockTime,
        uint256 gasToBuy
    )
        internal
        pure
        returns (uint256 _baseFeePerGas, uint256 _gasExcess)
    {
        uint256 issued = gasIssuePerSecond * blockTime;
        uint256 _gasExcessOld = gasExcess.max(issued) - issued;
        _gasExcess = _gasExcessOld + gasToBuy;

        if (_gasExcess > gasExcessMax) revert EIP1559_OUT_OF_GAS();

        uint256 _gasToBuy = gasToBuy == 0 ? 1 : gasToBuy;
        uint256 _before = _calcY(_gasExcessOld, xscale);
        uint256 _after = _calcY(_gasExcess, xscale);
        _baseFeePerGas = (_after - _before) / _gasToBuy / yscale;
    }
    /// @dev Internal function to calculate y value based on x value and scale.
    /// @param x The x value.
    /// @param xscale The x scale value.
    /// @return The calculated y value.

    function _calcY(uint256 x, uint256 xscale) private pure returns (uint256) {
        uint256 _x = x * xscale;
        if (_x >= LibFixedPointMath.MAX_EXP_INPUT) {
            revert EIP1559_OUT_OF_GAS();
        }
        return uint256(LibFixedPointMath.exp(int256(_x)));
    }
}

/// @title EIP1559ManagerExp
/// @notice Contract that implements EIP-1559 using Uinswap Exp math.
contract EIP1559ManagerExp is EssentialContract, EIP1559Manager {
    using LibMath for uint256;

    uint128 public constant X_SCALE = 1_488_514_844;
    uint128 public constant Y_SCALE = 358_298_803_609_133_338_138_868_404_779;
    uint32 public constant GAS_ISSUE_PER_SECOND = 12_500_000;
    uint64 public constant MAX_GAS_EXCESS = 90_900_000_000;

    uint128 public gasExcess;
    uint64 public parentTimestamp;
    uint256[49] private __gap;

    /// @notice Initializes the TaikoL2 contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
        gasExcess = MAX_GAS_EXCESS / 2;
        parentTimestamp = uint64(block.timestamp);

        emit BaseFeeUpdated(calcBaseFeePerGas(1));
    }

    /// @inheritdoc EIP1559Manager
    function updateBaseFeePerGas(uint32 gasUsed)
        external
        onlyFromNamed("taiko")
        returns (uint64 baseFeePerGas)
    {
        uint256 _baseFeePerGas;
        uint256 _gasExcess;
        (_baseFeePerGas, _gasExcess) = Lib1559Exp.calcBaseFeePerGas({
            gasIssuePerSecond: GAS_ISSUE_PER_SECOND,
            xscale: X_SCALE,
            yscale: Y_SCALE,
            gasExcessMax: MAX_GAS_EXCESS,
            gasExcess: gasExcess,
            blockTime: block.timestamp - parentTimestamp,
            gasToBuy: gasUsed
        });

        parentTimestamp = uint64(block.timestamp);
        gasExcess = uint128(_gasExcess.min(type(uint128).max));
        baseFeePerGas = uint64(_baseFeePerGas.min(type(uint64).max));

        emit BaseFeeUpdated(baseFeePerGas);
    }

    /// @inheritdoc EIP1559Manager
    function calcBaseFeePerGas(uint32 gasUsed) public view returns (uint64) {
        (uint256 _baseFeePerGas,) = Lib1559Exp.calcBaseFeePerGas({
            gasIssuePerSecond: GAS_ISSUE_PER_SECOND,
            xscale: X_SCALE,
            yscale: Y_SCALE,
            gasExcessMax: MAX_GAS_EXCESS,
            gasExcess: gasExcess,
            blockTime: block.timestamp - parentTimestamp,
            gasToBuy: gasUsed
        });

        return uint64(_baseFeePerGas.min(type(uint64).max));
    }
}
