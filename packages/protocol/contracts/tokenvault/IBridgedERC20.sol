// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IBridgedERC20
/// @notice Interface for all bridged tokens.
/// @dev To facilitate compatibility with third-party bridged tokens, such as USDC's native
/// standard, it's necessary to implement an intermediary adapter contract which should conform to
/// this interface, enabling effective interaction with third-party contracts.
/// @custom:security-contact security@taiko.xyz
interface IBridgedERC20 {
    /// @notice Mints `amount` tokens and assigns them to the `account` address.
    /// @param _account The account to receive the minted tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _account, uint256 _amount) external;

    /// @notice Burns tokens from msg.sender. This is only allowed if:
    /// - 1) tokens are migrating out to a new bridged token
    /// - 2) The token is burned by ERC20Vault to bridge back to the canonical chain.
    /// @param _amount The amount of tokens to burn.
    function burn(uint256 _amount) external;

    /// @notice Starts or stops migration to/from a specified contract.
    /// @param _addr The address migrating 'to' or 'from'.
    /// @param _inbound If false then signals migrating 'from', true if migrating 'into'.
    function changeMigrationStatus(address _addr, bool _inbound) external;

    /// @notice Returns the owner.
    /// @return The address of the owner.
    function owner() external view returns (address);
}
