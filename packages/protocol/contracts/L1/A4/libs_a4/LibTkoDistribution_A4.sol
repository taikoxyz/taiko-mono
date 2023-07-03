// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../../../common/a4/AddressResolver_A4.sol";
import {LibMath} from "../../../libs/LibMath.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData_A4.sol";
import {TaikoToken} from "../TaikoToken_A4.sol";
import {LibFixedPointMath as Math} from "../../../thirdparty/LibFixedPointMath.sol";

library LibTkoDistribution {
    error L1_INSUFFICIENT_TOKEN();

    function withdrawTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    ) internal {
        uint256 balance = state.taikoTokenBalances[msg.sender];
        if (balance < amount) revert L1_INSUFFICIENT_TOKEN();

        unchecked {
            state.taikoTokenBalances[msg.sender] -= amount;
        }

        TaikoToken(resolver.resolve("taiko_token", false)).mint(msg.sender, amount);
    }

    function depositTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    ) internal {
        if (amount > 0) {
            TaikoToken(resolver.resolve("taiko_token", false)).burn(msg.sender, amount);
            state.taikoTokenBalances[msg.sender] += amount;
        }
    }
}
