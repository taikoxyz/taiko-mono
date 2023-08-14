// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/// @title IMintableERC20
/// @notice Interface for ERC20 tokens with mint and burn functionality.
interface IMintableERC20 is IERC20Upgradeable {
    /// @notice Mints `amount` tokens and assigns them to the `account` address.
    /// @param account The account to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external;

    /// @notice Burns `amount` tokens from the `from` address.
    /// @param from The account from which the tokens will be burned.
    /// @param amount The amount of tokens to burn.
    function burn(address from, uint256 amount) external;
}
