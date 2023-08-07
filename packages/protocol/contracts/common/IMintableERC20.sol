// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title IMintableERC20
 * @dev Interface for ERC20 tokens with mint and burn functionality.
 *
 * This interface extends the standard IERC20Upgradeable interface with
 * additional methods for minting and burning tokens. Contracts that
 * implement this interface can mint new tokens to an account or
 * burn tokens from an account.
 */
interface IMintableERC20 is IERC20Upgradeable {
    /**
     * @notice Creates `amount` tokens and assigns them to `account`.
     * @dev This can increase the total supply of the token.
     *
     * @param account The account to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount) external;

    /**
     * @notice Destroys `amount` tokens from `from`.
     * @dev This can decrease the total supply of the token.
     *
     * @param from The account from which the tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external;
}
