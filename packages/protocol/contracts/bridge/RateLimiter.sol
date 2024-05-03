// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "./IRateLimiter.sol";

/// @title RateLimiter
/// @custom:security-contact security@taiko.xyz
contract RateLimiter is EssentialContract, IRateLimiter {
    uint256 public constant PERIOD = 1 days;

    struct TokenLimit {
        // The timestamp when the amount is updated.
        uint48 lastUpdateAt;
        // The token limit.
        uint104 limit;
        // The amount of token in current period.
        uint104 consumed;
    }

    mapping(address token => TokenLimit tokenLimit) public tokenLimit;
    uint256[49] private __gap;

    event LimitUpdated(address indexed token, uint256 oldLimit, uint256 newLimit);

    error RL_LIMIT_EXCEEDED();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function updateLimit(address _token, uint104 _limit) external onlyOwner whenNotPaused {
        emit LimitUpdated(_token, tokenLimit[_token].limit, _limit);
        tokenLimit[_token].limit = _limit;
    }

    function consumeAmount(
        address _token,
        uint256 _amount
    )
        external
        onlyFromNamedEither(LibStrings.B_BRIDGE, LibStrings.B_ERC20_VAULT)
    {
        if (_amount == 0) return;

        // check total limit, `0` means no limit at all.
        TokenLimit memory _tokenLimit = tokenLimit[_token];
        if (_tokenLimit.limit == 0) return;

        uint256 periodStart = (block.timestamp / PERIOD) * PERIOD;
        uint256 consumed =
            _tokenLimit.lastUpdateAt < periodStart ? _amount : _tokenLimit.consumed + _amount;

        if (consumed > _tokenLimit.limit) revert RL_LIMIT_EXCEEDED();

        _tokenLimit.lastUpdateAt = uint48(block.timestamp);
        _tokenLimit.consumed = SafeCast.toUint104(consumed);

        tokenLimit[_token] = _tokenLimit;
    }
}
