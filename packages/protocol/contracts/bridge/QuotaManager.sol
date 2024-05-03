// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibMath.sol";
import "./IQuotaManager.sol";

/// @title QuotaManager
/// @dev An implementation of IQuotaManager for Ether and ERC20 tokens.
/// @custom:security-contact security@taiko.xyz
contract QuotaManager is EssentialContract, IQuotaManager {
    using LibMath for uint256;

    struct Quota {
        uint48 updatedAt;
        uint104 dailyQuota;
        uint104 available;
    }

    mapping(address token => Quota tokenLimit) public tokenQuota;
    uint256[49] private __gap;

    event DailyQuotaUpdated(address indexed token, uint256 oldDailyLimit, uint256 newDaiyLimit);

    error QM_OUT_OF_QUOTA();
    error QM_SAME_QUOTA();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @notice Updates the daily quota for a given address.
    /// @param _token The token address with Ether represented by address(0).
    /// @param _dailyQuota The new daily quota.
    function updateDailyQuota(
        address _token,
        uint104 _dailyQuota
    )
        external
        onlyOwner
        whenNotPaused
    {
        if (_dailyQuota == tokenQuota[_token].dailyQuota) revert QM_SAME_QUOTA();

        emit DailyQuotaUpdated(_token, tokenQuota[_token].dailyQuota, _dailyQuota);
        tokenQuota[_token].dailyQuota = _dailyQuota;
    }

    /// @inheritdoc IQuotaManager
    function consumeQuota(
        address _token,
        uint256 _amount
    )
        external
        whenNotPaused
        onlyFromNamedEither(LibStrings.B_BRIDGE, LibStrings.B_ERC20_VAULT)
    {
        uint256 available = availableQuota(_token);
        if (available == type(uint256).max) return;
        if (available < _amount) revert QM_OUT_OF_QUOTA();

        unchecked {
            available -= _amount;
        }
        tokenQuota[_token].available = uint104(available);
        tokenQuota[_token].updatedAt = uint48(block.timestamp);
    }

    /// @notice Returns the available quota for a given token.
    /// @param _token The token address with Ether represented by address(0).
    function availableQuota(address _token) public view returns (uint256) {
        Quota memory q = tokenQuota[_token];
        if (q.dailyQuota == 0) return type(uint256).max;
        if (q.updatedAt == 0) return q.dailyQuota;

        uint256 issuance = q.dailyQuota * (block.timestamp - q.updatedAt) / 24 hours;
        return (issuance + q.available).min(q.dailyQuota);
    }
}
