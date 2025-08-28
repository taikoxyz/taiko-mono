// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IOverseer.sol";

contract MockOverseer {
    mapping(bytes32 => IOverseer.BlacklistTimestamps) internal _blacklist;

    /// @notice Manually set blacklist timestamps for testing
    /// @param _operatorRegistrationRoot The operator registration root
    /// @param _blacklistedAt Timestamp when blacklisted
    /// @param _unblacklistedAt Timestamp when unblacklisted
    function setBlacklistTimestamps(
        bytes32 _operatorRegistrationRoot,
        uint48 _blacklistedAt,
        uint48 _unblacklistedAt
    )
        external
    {
        _blacklist[_operatorRegistrationRoot] = IOverseer.BlacklistTimestamps({
            blacklistedAt: _blacklistedAt,
            unBlacklistedAt: _unblacklistedAt,
            _reserved: 0
        });
    }

    /// @notice Mock implementation of the blacklist getter
    /// @param _operatorRegistrationRoot The operator registration root
    /// @return The blacklist timestamps
    function blacklist(bytes32 _operatorRegistrationRoot)
        external
        view
        returns (IOverseer.BlacklistTimestamps memory)
    {
        return _blacklist[_operatorRegistrationRoot];
    }

    /// @notice Mock implementation of isOperatorBlacklisted
    /// @param operatorRegistrationRoot The operator registration root
    /// @return Whether the operator is currently blacklisted
    function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) external view returns (bool) {
        IOverseer.BlacklistTimestamps memory timestamps = _blacklist[operatorRegistrationRoot];
        return timestamps.blacklistedAt > timestamps.unBlacklistedAt;
    }
}
