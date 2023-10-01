// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { SafeCastUpgradeable } from "@ozu/utils/math/SafeCastUpgradeable.sol";

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibMath } from "../../libs/LibMath.sol";

import { LibFixedPointMath } from "../thirdparty/LibFixedPointMath.sol";

import { EIP1559Manager } from "./EIP1559Manager.sol";

library Lib1559Exp {
    using LibMath for uint256;
    using SafeCastUpgradeable for uint256;

    error EIP1559_OUT_OF_GAS();

    function calcBaseFeePerGas(
        uint256 poolProduct,
        uint256 gasIssuePerSecond,
        uint256 maxGasInPool,
        uint256 gasInPool,
        uint256 blockTime,
        uint256 gasToBuy
    )
        public
        pure
        returns (uint256 _baseFeePerGas, uint256 _gasInPool)
    { }
}

/// @title EIP1559ManagerExp
/// @notice Contract that implements EIP-1559 using
contract EIP1559ManagerExp is EssentialContract, EIP1559Manager {
    uint256[49] private __gap;

    /// @notice Initializes the TaikoL2 contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);

        emit BaseFeeUpdated(POOL_PRODUCT / gasInPool / gasInPool);
    }

    /// @inheritdoc EIP1559Manager
    function updateBaseFeePerGas(uint32 gasUsed)
        external
        onlyFromNamed("taiko")
        returns (uint64 baseFeePerGas)
    {
        emit BaseFeeUpdated(baseFeePerGas);
    }

    /// @inheritdoc EIP1559Manager
    function calcBaseFeePerGas(uint32 gasUsed) public view returns (uint64) { }
}
