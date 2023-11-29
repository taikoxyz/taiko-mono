// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "./IBaseAdapter.sol";
import "../../IMintableERC20.sol";

/// @title BridgedERC20Adapter
/// @notice It serves as an extension for the ERC20Vault to handle BridgedERC20 tokens in a same
/// fashion as it handles native tokens, so the interface can be unified.
contract BridgedERC20Adapter is IBaseAdapter {
    /// @notice Mints tokens to an account.
    /// @param account The account to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address token, address account, uint256 amount) public {
        IMintableERC20(token).mint(account, amount);
    }

    /// @notice Burns tokens from an account.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address token, address account, uint256 amount) public {
        IMintableERC20(token).burn(account, amount);
    }
}
