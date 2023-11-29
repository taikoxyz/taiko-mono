// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IBaseAdapter
/// @notice It serves as a wrapper between the token and the ERC20Vault - an extra layer for
/// flexibility. It is not an ERC20 contract, but we need to implement the interfaces the ERC20Vault
/// calls and relay over to other bridged (native or not) contracts.
interface IBaseAdapter {
    /// @notice Mints `amount` tokens and assigns them to the `account` address.
    /// @param token The erc20 token contract.
    /// @param account The account to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address token, address account, uint256 amount) external;

    /// @notice Burns `amount` tokens from the `from` address.
    /// @param token The erc20 token contract.
    /// @param from The account from which the tokens will be burned.
    /// @param amount The amount of tokens to burn.
    function burn(address token, address from, uint256 amount) external;
}
