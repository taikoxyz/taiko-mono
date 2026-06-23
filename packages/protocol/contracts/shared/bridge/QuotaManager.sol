// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContract.sol";
import "../libs/LibMath.sol";
import "./IQuotaManager.sol";

/// @title QuotaManager
/// @dev A UUPS-compatible implementation of IQuotaManager for Ether and ERC20 tokens.
/// @custom:security-contact security@taiko.xyz
contract QuotaManager is EssentialContract, IQuotaManager {
    using LibMath for uint256;

    struct Quota {
        uint48 updatedAt;
        uint104 quota;
        uint104 available;
    }

    /// @notice Sentinel value returned by `availableQuota` and recognized by `consumeQuota` to mean
    /// "unlimited": a token with no configured quota (quota == 0) is never rate-limited.
    /// @dev Intentional sentinel. Always treat `availableQuota(...) == UNLIMITED_QUOTA` as "no
    /// limit" and never as a real, consumable amount.
    uint256 public constant UNLIMITED_QUOTA = type(uint256).max;

    address public immutable bridge;
    address public immutable erc20Vault;

    mapping(address token => Quota tokenLimit) public tokenQuota;
    uint24 public quotaPeriod;

    uint256[48] private __gap;

    event QuotaUpdated(address indexed token, uint256 oldQuota, uint256 newQuota);
    event QuotaPeriodUpdated(uint256 quotaPeriod);
    event QuotaConsumed(address indexed token, uint256 amount, uint256 available);

    error QM_INVALID_PARAM();
    error QM_OUT_OF_QUOTA();
    error QM_PERMISSION_DENIED();

    /// @notice Deploys the QuotaManager.
    /// @param _owner The owner of this contract. msg.sender is used if this value is zero.
    /// @param _bridge The bridge address allowed to consume quota.
    /// @param _erc20Vault The ERC20 vault address allowed to consume quota.
    /// @param _quotaPeriod The time required to restore all quota.
    constructor(address _owner, address _bridge, address _erc20Vault, uint24 _quotaPeriod) EssentialContract() {
        bridge = _bridge;
        erc20Vault = _erc20Vault;
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        _setQuotaPeriod(_quotaPeriod);
    }

    /// @notice Updates the quota for a given token.
    /// @param _token The token address with Ether represented by address(0).
    /// @param _quota The new quota for the defined period.
    function updateQuota(address _token, uint104 _quota) external onlyOwner whenNotPaused {
        emit QuotaUpdated(_token, tokenQuota[_token].quota, _quota);
        tokenQuota[_token] = Quota(0, _quota, _quota);
    }

    /// @notice Updates the period required to fully restore quota.
    /// @param _quotaPeriod The new quota period.
    function setQuotaPeriod(uint24 _quotaPeriod) external onlyOwner whenNotPaused {
        _setQuotaPeriod(_quotaPeriod);
    }

    /// @inheritdoc IQuotaManager
    function consumeQuota(address _token, uint256 _amount) external whenNotPaused {
        if (msg.sender != bridge && msg.sender != erc20Vault) revert QM_PERMISSION_DENIED();

        uint256 available = availableQuota(_token, 0);
        if (available == UNLIMITED_QUOTA) return;
        if (available < _amount) revert QM_OUT_OF_QUOTA();

        unchecked {
            available -= _amount;
        }
        tokenQuota[_token].available = uint104(available);
        tokenQuota[_token].updatedAt = uint48(block.timestamp);
        emit QuotaConsumed(_token, _amount, available);
    }

    /// @notice Returns the available quota for a given token.
    /// @param _token The token address with Ether represented by address(0).
    /// @param _leap Number of seconds in the future to look ahead. Values greater than or equal
    /// to `quotaPeriod` are treated as a full period (the quota is fully restored), so arbitrarily
    /// large values are safe and never overflow.
    /// @return The available quota.
    function availableQuota(address _token, uint256 _leap) public view returns (uint256) {
        Quota memory q = tokenQuota[_token];
        if (q.quota == 0) return UNLIMITED_QUOTA;
        if (q.updatedAt == 0) return q.quota;

        // Cap the elapsed time at `quotaPeriod`: once a full period has passed the quota is
        // fully restored, so a larger elapsed value would not change the result (it is capped
        // at `q.quota` below anyway). A `_leap` of at least `quotaPeriod` already implies full
        // restoration, so it is short-circuited; this also avoids overflowing `block.timestamp +
        // _leap` for extreme caller-supplied lookahead values. Capping `elapsed` bounds the
        // multiplication to `q.quota * quotaPeriod`, which can never overflow uint256, so
        // `consumeQuota` keeps working even though `block.timestamp - q.updatedAt` grows without
        // bound.
        uint256 elapsed = _leap >= quotaPeriod ? quotaPeriod : (block.timestamp + _leap - q.updatedAt).min(quotaPeriod);
        uint256 issuance = q.quota * elapsed / quotaPeriod;
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
