// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { LibFixedPointMath as Math } from
    "../../thirdparty/LibFixedPointMath.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibTaikoToken {
    error L1_INSUFFICIENT_TOKEN();

    function withdrawTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    )
        internal
    {
        uint256 balance = state.taikoTokenBalances[msg.sender];
        if (balance < amount) revert L1_INSUFFICIENT_TOKEN();
        // Unchecked is safe per above check
        unchecked {
            state.taikoTokenBalances[msg.sender] -= amount;
        }

        TaikoToken(resolver.resolve("taiko_token", false)).transfer(
            msg.sender, amount
        );
    }

    function depositTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    )
        internal
    {
        if (amount > 0) {
            TaikoToken(resolver.resolve("taiko_token", false)).transferFrom(
                msg.sender, address(this), amount
            );
            state.taikoTokenBalances[msg.sender] += amount;
        }
    }

    function receiveTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        address from,
        uint256 amount
    )
        internal
        returns (TaikoToken tt)
    {
        tt = TaikoToken(resolver.resolve("taiko_token", false));
        if (state.taikoTokenBalances[from] >= amount) {
            // Safe, see the above constraint
            unchecked {
                state.taikoTokenBalances[from] -= amount;
            }
        } else {
            tt.transferFrom(from, address(this), amount);
        }
    }
}
