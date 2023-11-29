// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "./IBaseAdapter.sol";

interface IUsdc {
    /// @notice Burns `amount` tokens from address(this)
    /// @param amount The amount of tokens to burn.
    function burn(uint256 amount) external;
    /// @notice Mint `amount` tokens to `to`
    /// @param to The address minting to.
    /// @param amount The amount of tokens to burn.
    function mint(address to, uint256 amount) external;
    /// @notice Transfers `amount` tokens to `to` from `from`
    /// @param from The address minting to.
    /// @param to The address minting to.
    /// @param amount The amount of tokens to burn.
    function transferFrom(address from, address to, uint256 amount) external;
}

/// @title UsdcAdapter
/// @notice It serves as a wrapper between the deployed USDC and the ERC20Vault - an extra layer for
/// flexibility. It is not an ERC20 contract, but we need to implement the interfaces the ERC20Vault
/// calls and relay over to the USDC contract. The reason this contract needs to be 'custom' is the
/// different mechanisms how each native tokens handling some functions. In this case the
/// 'troublemaker' is the burn() function which behaves differently (in USDC) than usual.
contract UsdcAdapter is IBaseAdapter {
    /// @notice Mints tokens to an account.
    /// @param account The account to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address token, address account, uint256 amount) public {
        IUsdc(token).mint(account, amount);
    }

    /// @notice Burns tokens from an account.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address token, address account, uint256 amount) public {
        // Same as USDC does.
        // 1. transferFrom() to this account
        // 2. burn() it the way USDC burns
        IUsdc(token).transferFrom({
            from: account,
            to: address(this), //ERC20Vault - via delegatecall()
            amount: amount
        });
        IUsdc(token).burn(amount);
    }
}
