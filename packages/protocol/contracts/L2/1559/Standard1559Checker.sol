// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../../common/EssentialContract.sol";
import { LibMath } from "../../libs/LibMath.sol";

import { I1559Checker } from "./I1559Checker.sol";
import { Lib1559Math } from "./Lib1559Math.sol";

/// @title TaikoL2
/// @notice Taiko L2 is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
contract Standard1559Checker is EssentialContract, I1559Checker {
    using LibMath for uint256;

    uint64 public constant BLOCK_GAS_TARGET = 500_000;
    uint64 public constant MIN_BASE_FEE_PER_GAS = 1000; // 1000 Wei;

    uint64 public baseFeePerGas;
    uint256[49] private __gap;

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_BASEFEE();

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

        if (_baseFeePerGas < MIN_BASE_FEE_PER_GAS) {
            revert L2_INVALID_BASEFEE();
        }
        baseFeePerGas = _baseFeePerGas;
    }

    function checkBaseFeePerGas(uint32 gasUsed)
        external
        onlyFromNamed("taiko")
        returns (uint64)
    {
        // Verify the base fee is correct
        baseFeePerGas = calcBaseFeePerGas(gasUsed);
        if (block.basefee != baseFeePerGas) {
            revert L2_BASEFEE_MISMATCH();
        }

        return baseFeePerGas;
    }

    function calcBaseFeePerGas(uint32 gasUsed)
        public
        view
        virtual
        returns (uint64)
    {
        uint256 _baseFeePerGas = Lib1559Math.calcBaseFeePerGas(
            baseFeePerGas, gasUsed, BLOCK_GAS_TARGET
        );
        if (_baseFeePerGas < MIN_BASE_FEE_PER_GAS) {
            _baseFeePerGas = MIN_BASE_FEE_PER_GAS;
        }
        return uint64(_baseFeePerGas.min(type(uint64).max));
    }
}
