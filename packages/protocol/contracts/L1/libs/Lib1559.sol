// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibMath} from "../../libs/LibMath.sol";
// import {
//     SafeCastUpgradeable
// } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";
// import {TaikoToken} from "../TaikoToken.sol";

library LibTokenomics {
    using LibMath for uint256;
    uint256 private constant ADJUSTMENT_QUOTIENT = 1E12;

    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_PARAM();

    function withdraw(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    ) internal {
        uint256 balance = state.balances[msg.sender];
        if (balance < amount) revert L1_INSUFFICIENT_TOKEN();

        unchecked {
            state.balances[msg.sender] -= amount;
        }

        TaikoToken(resolver.resolve("taiko_token", false)).mint(
            msg.sender,
            amount
        );
    }

    function calcGasFee(uint256 TARGET, uint256 excessGasIssued, uint256 gasLimit) internal pure returns (uint256 fee, uint256 newExcessGasIssued) {
        uint a = eth_qty(TARGET, excessGasIssued+ gasLimit) - eth_qty(TARGET, excessGasIssued);
        newExcessGasIssued = (excessGasIssued + gasLimit).max(TARGET) - TARGET;

    }

    function eth_qty(uint256 TARGET, uint256 gasQuantity) internal pure returns (uint256) {
        return exp(gasQuantity / TARGET / ADJUSTMENT_QUOTIENT);
    }

    function exp(uint256 b) internal pure returns(uint256 c) {}
}
