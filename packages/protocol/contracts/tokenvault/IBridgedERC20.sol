// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title IBridgedERC20
/// @notice Interface for all bridged tokens.
/// @dev To facilitate compatibility with third-party bridged tokens, such as USDC's native
/// standard, it's necessary to implement an intermediary adapter contract which should conform to
/// this interface, enabling effective interaction with third-party contracts.
interface IBridgedERC20 {
    /// @notice Mints `amount` tokens and assigns them to the `account` address.
    /// @param account The account to receive the minted tokens.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external;

    /// @notice Burns `amount` tokens from the `from` address.
    /// @param from The account from which the tokens will be burned.
    /// @param amount The amount of tokens to burn.
    function burn(address from, uint256 amount) external;

    /// @notice Configures this contract for token migration to another specified contract.
    /// @dev Restricts function access exclusively to the vault.
    /// @param to Target IBridgedERC20 contract designated for receiving the migrated tokens.
    function startOutboundMigration(address to) external;

    /// @notice Grants permission to a specified contract for migrating tokens to this contract.
    /// @dev Restricts function access exclusively to the vault.
    /// @param from An external IBridgedERC20 contract authorized for token migration into this
    /// contract.
    function startInboundMigration(address from) external;
}
