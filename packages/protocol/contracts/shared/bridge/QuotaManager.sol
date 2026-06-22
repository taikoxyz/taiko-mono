// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "../libs/LibMath.sol";
import "./IQuotaManager.sol";

/// @title QuotaManager
/// @dev A non-upgradeable implementation of IQuotaManager for Ether and ERC20 tokens.
/// @custom:security-contact security@taiko.xyz
contract QuotaManager is Ownable2Step, IQuotaManager {
    using LibMath for uint256;

    struct Quota {
        uint48 updatedAt;
        uint104 quota;
        uint104 available;
    }

    address public immutable bridge;
    address public immutable erc20Vault;

    mapping(address token => Quota tokenLimit) public tokenQuota;
    uint24 public quotaPeriod;

    event QuotaUpdated(address indexed token, uint256 oldQuota, uint256 newQuota);
    event QuotaPeriodUpdated(uint256 quotaPeriod);

    error QM_INVALID_PARAM();
    error QM_OUT_OF_QUOTA();
    error QM_PERMISSION_DENIED();

    /// @notice Deploys the QuotaManager.
    /// @param _owner The owner of this contract. msg.sender is used if this value is zero.
    /// @param _bridge The bridge address allowed to consume quota.
    /// @param _erc20Vault The ERC20 vault address allowed to consume quota.
    /// @param _quotaPeriod The time required to restore all quota.
    constructor(address _owner, address _bridge, address _erc20Vault, uint24 _quotaPeriod) {
        bridge = _bridge;
        erc20Vault = _erc20Vault;
        if (_owner != address(0)) _transferOwnership(_owner);
        _setQuotaPeriod(_quotaPeriod);
    }

    /// @notice Updates the quota for a given token.
    /// @param _token The token address with Ether represented by address(0).
    /// @param _quota The new quota for the defined period.
    function updateQuota(address _token, uint104 _quota) external onlyOwner {
        emit QuotaUpdated(_token, tokenQuota[_token].quota, _quota);
        tokenQuota[_token] = Quota(0, _quota, _quota);
    }

    /// @notice Updates the period required to fully restore quota.
    /// @param _quotaPeriod The new quota period.
    function setQuotaPeriod(uint24 _quotaPeriod) external onlyOwner {
        _setQuotaPeriod(_quotaPeriod);
    }

    /// @inheritdoc IQuotaManager
    function consumeQuota(address _token, uint256 _amount) external {
        if (msg.sender != bridge && msg.sender != erc20Vault) revert QM_PERMISSION_DENIED();

        uint256 available = availableQuota(_token, 0);
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
    /// @param _leap Amount of seconds in the future.
    /// @return The available quota.
    function availableQuota(address _token, uint256 _leap) public view returns (uint256) {
        Quota memory q = tokenQuota[_token];
        if (q.quota == 0) return type(uint256).max;
        if (q.updatedAt == 0) return q.quota;

        uint256 issuance = q.quota * (block.timestamp + _leap - q.updatedAt) / quotaPeriod;
        return (issuance + q.available).min(q.quota);
    }

    /// @dev Sets the quota period, reverting if it is zero.
    /// @param _quotaPeriod The new quota period.
    function _setQuotaPeriod(uint24 _quotaPeriod) private {
        if (_quotaPeriod == 0) revert QM_INVALID_PARAM();
        quotaPeriod = _quotaPeriod;
        emit QuotaPeriodUpdated(_quotaPeriod);
    }
}
