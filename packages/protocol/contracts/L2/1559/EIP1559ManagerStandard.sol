// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibMath } from "../../libs/LibMath.sol";

import { EIP1559Manager } from "./EIP1559Manager.sol";

library Lib1559Standard {
    function calcBaseFeePerGas(
        uint256 prevBaseFeePerGas,
        uint256 gasUsed,
        uint256 blockGasTarget
    )
        public
        pure
        returns (uint256)
    {
        // Formula:
        // base_fee * (1 + 1/8 * (block_gas_used / block_gas_target - 1))
        return prevBaseFeePerGas * (gasUsed + blockGasTarget * 7)
            / (blockGasTarget * 8);
    }
}

/// @title EIP1559ManagerStandard
/// @notice Contract that implements the standard EIP-1559 base fee update
/// algorithm.
contract EIP1559ManagerStandard is EssentialContract, EIP1559Manager {
    using LibMath for uint256;

    uint64 public constant BLOCK_GAS_TARGET = 500_000;
    uint64 public constant MIN_BASE_FEE_PER_GAS = 1000; // 1000 Wei;

    uint64 public baseFeePerGas;
    uint256[49] private __gap;

    /// @notice Initializes the TaikoL2 contract.
    /// @param _baseFeePerGas The initial value of base fee per gas
    function init(
        address _addressManager,
        uint64 _baseFeePerGas
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        baseFeePerGas = _baseFeePerGas;
        emit BaseFeeUpdated(baseFeePerGas);
    }

    /// @inheritdoc EIP1559Manager
    function updateBaseFeePerGas(uint32 gasUsed)
        external
        onlyFromNamed("taiko")
        returns (uint64)
    {
        baseFeePerGas = calcBaseFeePerGas(gasUsed);
        emit BaseFeeUpdated(baseFeePerGas);
        return baseFeePerGas;
    }

    /// @inheritdoc EIP1559Manager
    function calcBaseFeePerGas(uint32 gasUsed) public view returns (uint64) {
        uint256 _baseFeePerGas = Lib1559Standard.calcBaseFeePerGas(
            baseFeePerGas, gasUsed, BLOCK_GAS_TARGET
        );
        if (_baseFeePerGas < MIN_BASE_FEE_PER_GAS) {
            _baseFeePerGas = MIN_BASE_FEE_PER_GAS;
        }
        return uint64(_baseFeePerGas.min(type(uint64).max));
    }
}
