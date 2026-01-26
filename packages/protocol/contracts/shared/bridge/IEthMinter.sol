// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEthMinter
/// @notice Interface for trusted protocols to provide ETH to recipients.
/// @dev In the current implementation, "minting" is actually a transfer of pre-minted ETH
/// held by the minter contract, not the creation of new ETH. The minter contract must hold
/// sufficient ETH balance to fulfill mint requests.
///
/// In a future release, native ETH minting may be enabled at the protocol level, allowing
/// this interface to create new ETH directly without requiring pre-funded balances.
/// @custom:security-contact security@taiko.xyz
interface IEthMinter {
    /// @notice Emitted when ETH is provided to a recipient.
    /// @param recipient The address that received the ETH.
    /// @param amount The amount of ETH transferred.
    event EthMinted(address indexed recipient, uint256 amount);

    /// @notice Provides ETH to the specified recipient.
    /// @dev Currently transfers pre-minted ETH from the minter's balance.
    /// Callers must be authorized by the minter contract.
    /// @param _recipient The address to receive the ETH.
    /// @param _amount The amount of ETH to transfer.
    function mintEth(address _recipient, uint256 _amount) external;
}
