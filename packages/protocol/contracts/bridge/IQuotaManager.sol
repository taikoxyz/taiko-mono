// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IQuotaManager
/// @custom:security-contact security@taiko.xyz
interface IQuotaManager {
    /// @notice Consumes a specific amount of quota for a given address.
    /// This function must revert if available quota is smaller than the given amount of quota.
    /// @param _token The token address. Ether is represented with address(0).
    /// @param _amount The amount of quota to consume.
    function consumeQuota(address _token, uint256 _amount) external;
}
