// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Mock Address Manager
/// @notice Provides a simplified mock-up of an address manager for testing purposes,
/// substituting for a more complex AddressManager in test environments.
/// @dev This mock manager is used in tests to simulate interactions with a vault system
/// that typically involves managing addresses of various contracts like an ERC20Vault.
contract MockAddressManager {
    /// @notice The address of the mocked ERC20 Vault.
    /// @dev This address is set at construction and returned whenever getAddress is called.
    address private mockERC20Vault;

    /// @param _mockERC20Vault The address to be used as the mock ERC20Vault.
    constructor(address _mockERC20Vault) {
        mockERC20Vault = _mockERC20Vault;
    }

    /// @notice Returns the address of the mock ERC20Vault regardless of the inputs provided.
    /// @param /*chainId*/ The chain ID input, which is ignored in this mock.
    /// @param /*name*/ The name input, which is ignored in this mock.
    /// @return The address of the mock ERC20 vault.
    /// @dev In a real AddressManager, the returned address would depend on both the chainId and the
    /// name.
    function getAddress(uint64, bytes32) public view returns (address) {
        return mockERC20Vault;
    }
}
