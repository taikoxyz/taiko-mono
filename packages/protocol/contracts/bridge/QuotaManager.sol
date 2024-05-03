// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../libs/LibMath.sol";
import "./IQuotaManager.sol";

/// @title QuotaManager
/// @custom:security-contact security@taiko.xyz
contract QuotaManager is EssentialContract, IQuotaManager {
    using LibMath for uint256;
    using SafeCast for uint256;

    struct Quota {
        uint48 updatedAt;
        uint104 dailyQuota;
        uint104 available;
    }

    mapping(address token => Quota tokenLimit) public tokenQuota;
    uint256[49] private __gap;

    event DailyQuotaUpdated(address indexed token, uint256 oldDailyLimit, uint256 newDaiyLimit);

    error RL_OUT_OF_QUOTA();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    function updateDailyQuota(
        address _token,
        uint104 _dailyQuota
    )
        external
        onlyOwner
        whenNotPaused
    {
        emit DailyQuotaUpdated(_token, tokenQuota[_token].dailyQuota, _dailyQuota);
        tokenQuota[_token].dailyQuota = _dailyQuota;
    }

    function consumeQuota(
        address _token,
        uint256 _amount
    )
        external
        onlyFromNamedEither(LibStrings.B_BRIDGE, LibStrings.B_ERC20_VAULT)
    {
        uint256 available = availableQuota(_token);
        if (available == type(uint256).max) return;
        if (available < _amount) revert RL_OUT_OF_QUOTA();

        unchecked {
            available -= _amount;
        }
        tokenQuota[_token].available = available.toUint104();
        tokenQuota[_token].updatedAt = uint48(block.timestamp);
    }

    function availableQuota(address _token) public view returns (uint256) {
        Quota memory q = tokenQuota[_token];
        if (q.dailyQuota == 0) return type(uint256).max;
        if (q.updatedAt == 0) return q.dailyQuota;

        uint256 issuance = q.dailyQuota * (block.timestamp - q.updatedAt) / 24 hours;
        return (issuance + q.available).min(q.dailyQuota);
    }
}
