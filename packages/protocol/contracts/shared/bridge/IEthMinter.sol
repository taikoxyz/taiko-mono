// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEthMinter
/// @notice Interface for trusted protocols to mint ETH.
/// @custom:security-contact security@taiko.xyz
interface IEthMinter {
    /// @notice Emitted when ETH is minted.
    /// @param recipient The address of the recipient.
    /// @param amount The amount of ETH minted.
    event EthMinted(address indexed recipient, uint256 amount);

    /// @notice Mints ETH to the recipient.
    /// @param _recipient The address of the recipient.
    /// @param _amount The amount of ETH to mint.
    function mintEth(address _recipient, uint256 _amount) external;
}
