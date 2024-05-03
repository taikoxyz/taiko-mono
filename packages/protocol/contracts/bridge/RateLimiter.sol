// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "./IRateLimiter.sol";

/// @title RateLimiter
/// @custom:security-contact security@taiko.xyz
contract RateLimiter is EssentialContract, IRateLimiter {
    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function consumeAmount(address, uint256) external virtual { }

    function availableAmount(address _token) public pure virtual returns (uint256) {
        return type(uint256).max;
    }
}
