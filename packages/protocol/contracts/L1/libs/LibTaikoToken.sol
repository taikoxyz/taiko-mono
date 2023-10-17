// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";

import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from "../TaikoToken.sol";

library LibTaikoToken {
    event TokenDeposited(uint256 amount);
    event TokenWithdrawn(uint256 amount);
    event TokenCredited(uint256 amount, bool minted);
    event TokenDebited(uint256 amount, bool fromLocalBalance);
    event TokenWithdrawnByOwner(address to, uint256 amount);

    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_ADDRESS();

    function depositTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    )
        internal
    {
        if (amount == 0) return;
        TaikoToken(resolver.resolve("taiko_token", false)).transferFrom(
            msg.sender, address(this), amount
        );
        unchecked {
            state.tokenBalances[msg.sender] += amount;
        }
        emit TokenDeposited(amount);
    }

    function withdrawTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    )
        internal
    {
        if (amount == 0) return;
        if (state.tokenBalances[msg.sender] < amount) {
            revert L1_INSUFFICIENT_TOKEN();
        }
        // Unchecked is safe per above check
        unchecked {
            state.tokenBalances[msg.sender] -= amount;
        }

        TaikoToken(resolver.resolve("taiko_token", false)).transfer(
            msg.sender, amount
        );

        emit TokenWithdrawn(amount);
    }

    function creditTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        address to,
        uint256 amount,
        bool mint
    )
        internal
    {
        if (amount == 0) return;
        if (mint) {
            TaikoToken(resolver.resolve("taiko_token", false)).mint(
                address(this), amount
            );
        }

        state.tokenBalances[to] += amount;
        emit TokenCredited(amount, mint);
    }

    function debitTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        address from,
        uint256 amount
    )
        internal
    {
        if (amount == 0) return;
        if (state.tokenBalances[from] < amount) {
            TaikoToken(resolver.resolve("taiko_token", false)).transferFrom(
                from, address(this), amount
            );
            emit TokenDebited(amount, false);
        } else {
            unchecked {
                state.tokenBalances[from] -= amount;
            }
            emit TokenDebited(amount, true);
        }
    }

    function ownerWithdrawTaikoToken(
        AddressResolver resolver,
        address to,
        uint256 amount
    )
        internal
    {
        if (to == address(0)) revert L1_INVALID_ADDRESS();
        TaikoToken(resolver.resolve("taiko_token", false)).transferFrom(
            address(this), to, amount
        );
        emit TokenWithdrawnByOwner(to, amount);
    }
}
