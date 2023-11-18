// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "../../common/AddressResolver.sol";
import "../TaikoData.sol";
import "../TaikoToken.sol";

library LibTaikoToken {
    event TokenDeposited(uint256 amount);
    event TokenWithdrawn(uint256 amount);
    event TokenCredited(address to, uint256 amount);
    event TokenDebited(address from, uint256 amount);

    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_ADDRESS();
    error L1_INVALID_AMOUNT();

    function depositTaikoToken(
        TaikoData.State storage state,
        AddressResolver resolver,
        uint256 amount
    )
        external
    {
        if (amount == 0) revert L1_INVALID_AMOUNT();
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
        external
    {
        if (amount == 0) revert L1_INVALID_AMOUNT();
        if (state.tokenBalances[msg.sender] < amount) {
            revert L1_INSUFFICIENT_TOKEN();
        }
        // Unchecked is safe per above check
        unchecked {
            state.tokenBalances[msg.sender] -= amount;
        }

        TaikoToken(resolver.resolve("taiko_token", false)).transfer(msg.sender, amount);

        emit TokenWithdrawn(amount);
    }

    function creditTaikoToken(TaikoData.State storage state, address to, uint256 amount) internal {
        if (amount == 0 || to == address(0)) return;
        unchecked {
            state.tokenBalances[to] += amount;
        }
        emit TokenCredited(to, amount);
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
        } else {
            unchecked {
                state.tokenBalances[from] -= amount;
            }
        }
        emit TokenDebited(from, amount);
    }
}
