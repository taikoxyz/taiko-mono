// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/IQuotaManager.sol";
import "src/shared/bridge/QuotaManager.sol";

/// @dev A test-only IQuotaManager that records how much quota is consumed per token (and in total)
/// and optionally enforces a single shared limit, reverting with `QM_OUT_OF_QUOTA` when exceeded.
/// It skips the bridge/vault caller check so it can be wired into unit-test harnesses directly.
contract CountingQuotaManager is IQuotaManager {
    uint256 public totalConsumed;
    uint256 public limit;
    uint256 public calls;
    mapping(address token => uint256 amount) public consumed;

    function setLimit(uint256 _limit) external {
        limit = _limit;
    }

    function consumeQuota(address _token, uint256 _amount) external {
        ++calls;
        if (limit != 0 && totalConsumed + _amount > limit) revert QuotaManager.QM_OUT_OF_QUOTA();
        totalConsumed += _amount;
        consumed[_token] += _amount;
    }
}
