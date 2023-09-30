// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibMath } from "../../libs/LibMath.sol";

import { I1559Manager } from "./I1559Manager.sol";
import { Lib1559Math } from "./Lib1559Math.sol";

/// @title Standard1559Manager
/// @notice Contract that implements the standard EIP-1559 base fee update
/// algorithm.

// function calcBaseFeePerGasAMM(
//      uint256 poolProduct,
//      uint256 gasIssuePerSecond,
//      uint256 maxGasInPool,
//      uint256 gasInPool,
//      uint256 blockTime,
//      uint256 gasToBuy
//  )
//      public
//      pure
//      returns (uint256 _baseFeePerGas, uint256 _gasInPool)
//  {
//      _gasInPool = maxGasInPool.min(gasInPool + gasIssuePerSecond *
// blockTime);
//      uint256 _ethInPool = poolProduct / _gasInPool;

//      if (gasToBuy == 0) {
//          _baseFeePerGas = _ethInPool / _gasInPool;
//      } else {
//          if (gasToBuy >= _gasInPool) revert EIP1559_OUT_OF_GAS();
//          _gasInPool -= gasToBuy;

//          uint256 _ethInPoolNew = poolProduct / _gasInPool;
//          _baseFeePerGas = (_ethInPoolNew - _ethInPool) / gasToBuy;
//          _ethInPool = _ethInPoolNew;
//      }
//  }

contract Standard1559Manager is EssentialContract, I1559Manager {
    using LibMath for uint256;

    uint64 public constant POOL_PRODUCT = 500_000;
    uint64 public constant GAS_ISSUE_PER_SECOND = 1;
    uint64 public constant MAX_GAS_IN_POOL = 1000;

    uint128 public gasInPool;
    uint64 public parentTimestamp;
    uint256[49] private __gap;

    /// @notice Initializes the TaikoL2 contract.
    /// @param _gasInPool The initial value of gasInPool
    function init(
        address _addressManager,
        uint64 _gasInPool
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        gasInPool = _gasInPool;
        parentTimestamp = uint64(block.timestamp);
        emit BaseFeeUpdated(POOL_PRODUCT / gasInPool / gasInPool);
    }

    /// @inheritdoc I1559Manager
    function updateBaseFeePerGas(uint32 gasUsed)
        external
        onlyFromNamed("taiko")
        returns (uint64 baseFeePerGas)
    {
        uint256 _baseFeePerGas;
        (_baseFeePerGas, gasInPool) = Lib1559Math.calcBaseFeePerGasAMM({
            poolProduct: POOL_PRODUCT,
            gasIssuePerSecond: GAS_ISSUE_PER_SECOND,
            maxGasInPool: MAX_GAS_IN_POOL,
            gasInPool: gasInPool,
            blockTime: block.timestamp - parentTimestamp,
            gasToBuy: gasUsed
        });

        baseFeePerGas = uint64(_baseFeePerGas.min(type(uint64).max));
        parentTimestamp = uint64(block.timestamp);
        emit BaseFeeUpdated(baseFeePerGas);
    }

    /// @inheritdoc I1559Manager
    function calcBaseFeePerGas(uint32 gasUsed) public view returns (uint64) {
        (uint256 _baseFeePerGas,) = Lib1559Math.calcBaseFeePerGasAMM({
            poolProduct: POOL_PRODUCT,
            gasIssuePerSecond: GAS_ISSUE_PER_SECOND,
            maxGasInPool: MAX_GAS_IN_POOL,
            gasInPool: gasInPool,
            blockTime: block.timestamp - parentTimestamp,
            gasToBuy: gasUsed
        });

        return uint64(_baseFeePerGas.min(type(uint64).max));
    }
}
