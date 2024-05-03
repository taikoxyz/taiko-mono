// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IQuotaManager
/// @custom:security-contact security@taiko.xyz
interface IQuotaManager {
    function consumeQuota(address token, uint256 amount) external;
    function availableQuota(address _token) external view returns (uint256);
}
