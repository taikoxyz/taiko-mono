// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibMath } from "../../libs/LibMath.sol";

import { EIP1559Manager } from "./EIP1559Manager.sol";

library Lib1559AMM {
    using LibMath for uint256;

    error EIP1559_OUT_OF_GAS();

    function calcBaseFeePerGas(
        uint256 poolProduct,
        uint256 gasIssuePerSecond,
        uint256 maxGasInPool,
        uint256 gasInPool,
        uint256 blockTime,
        uint256 gasToBuy
    )
        internal
        pure
        returns (uint256 _baseFeePerGas, uint256 _gasInPool)
    {
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

/// @title EIP1559ManagerAMM
/// @notice Contract that implements EIP-1559 using Uinswap AMM math.
contract EIP1559ManagerAMM is EssentialContract, EIP1559Manager {
    using LibMath for uint256;

    uint256 public constant AVG_BLOCK_TIME = 3;
    uint128 public constant BLOCK_GAS_TARGET = 5_000_000; // 5 million
    uint128 public constant INIT_GAS_IN_POOL = BLOCK_GAS_TARGET * 1000;
    uint256 public constant MAX_GAS_IN_POOL = INIT_GAS_IN_POOL * 10;
    uint64 public constant INIT_BASEFEE_PER_GAS = 10 gwei;

    uint256 public constant GAS_ISSUE_PER_SECOND =
        BLOCK_GAS_TARGET / AVG_BLOCK_TIME;

    uint256 public constant POOL_PRODUCT =
        INIT_BASEFEE_PER_GAS * INIT_GAS_IN_POOL * INIT_GAS_IN_POOL;

    uint128 public gasInPool;
    uint64 public parentTimestamp;
    uint256[49] private __gap;

    /// @notice Initializes the TaikoL2 contract.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
        gasInPool = INIT_GAS_IN_POOL;
        parentTimestamp = uint64(block.timestamp);

        emit BaseFeeUpdated(POOL_PRODUCT / gasInPool / gasInPool);
    }

    /// @inheritdoc EIP1559Manager
    function updateBaseFeePerGas(uint32 gasUsed)
        external
        onlyFromNamed("taiko")
        returns (uint64 baseFeePerGas)
    {
        uint256 _baseFeePerGas;
        uint256 _gasInPool;
        (_baseFeePerGas, _gasInPool) = Lib1559AMM.calcBaseFeePerGas({
            poolProduct: POOL_PRODUCT,
            gasIssuePerSecond: GAS_ISSUE_PER_SECOND,
            maxGasInPool: MAX_GAS_IN_POOL,
            gasInPool: gasInPool,
            blockTime: block.timestamp - parentTimestamp,
            gasToBuy: gasUsed
        });

        parentTimestamp = uint64(block.timestamp);
        gasInPool = uint128(_gasInPool.min(type(uint128).max));
        baseFeePerGas = uint64(_baseFeePerGas.min(type(uint64).max));

        emit BaseFeeUpdated(baseFeePerGas);
    }

    /// @inheritdoc EIP1559Manager
    function calcBaseFeePerGas(uint32 gasUsed) public view returns (uint64) {
        (uint256 _baseFeePerGas,) = Lib1559AMM.calcBaseFeePerGas({
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
