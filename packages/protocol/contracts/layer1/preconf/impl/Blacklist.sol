// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IBlacklist.sol";

/// @title Blacklist
/// @notice A database of operators that have been blacklisted for subjective faults.
/// For instance, non-adherence to fair exchange.
/// @dev Blacklisted operators are not inserted in the lookahead. This is done to
/// prevent the lookahead from being polluted by invalid operators.
/// @custom:security-contact security@taiko.xyz
abstract contract Blacklist is IBlacklist {
    /// @dev The entity authorised to blacklist operators
    mapping(address overseer => bool isOverseer) public overseers;

    /// @dev Maps operator registration roots to the timestamp at which they
    /// were blacklisted or unblacklisted.
    mapping(bytes32 operatorRegistrationRoot => BlacklistTimestamps blacklistTimestamps) internal
        blacklist;

    uint256[48] private __gap;

    constructor(address[] memory _overseers) {
        for (uint256 i = 0; i < _overseers.length; i++) {
            overseers[_overseers[i]] = true;
        }
    }

    modifier onlyOverseer() {
        require(overseers[msg.sender], NotOverseer());
        _;
    }

    /// @notice Blacklists a preconf operator for subjective faults
    /// @param _operatorRegistrationRoot registration root of the operator being blacklisted
    function blacklistOperator(bytes32 _operatorRegistrationRoot) external onlyOverseer {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_operatorRegistrationRoot];

        // The operator must not be already blacklisted
        require(
            blacklistTimestamps.blacklistedAt <= blacklistTimestamps.unBlacklistedAt,
            OperatorAlreadyBlacklisted()
        );

        // If the operator was unblacklisted, the overseer must wait for a delay before
        // blacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp
                > blacklistTimestamps.unBlacklistedAt + getBlacklistConfig().blacklistDelay,
            BlacklistDelayNotMet()
        );

        blacklist[_operatorRegistrationRoot].blacklistedAt = uint48(block.timestamp);

        emit Blacklisted(_operatorRegistrationRoot, uint48(block.timestamp));
    }

    /// @notice Removes an operator from the blacklist
    /// @param _operatorRegistrationRoot registration root of the operator to unblacklist
    function unblacklistOperator(bytes32 _operatorRegistrationRoot) external onlyOverseer {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_operatorRegistrationRoot];

        // The operator must be blacklisted
        require(
            blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt,
            OperatorNotBlacklisted()
        );

        // If the operator was blacklisted, the overseer must wait for a delay before
        // unblacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp
                > blacklistTimestamps.blacklistedAt + getBlacklistConfig().unblacklistDelay,
            UnblacklistDelayNotMet()
        );

        blacklist[_operatorRegistrationRoot].unBlacklistedAt = uint48(block.timestamp);

        emit Unblacklisted(_operatorRegistrationRoot, uint48(block.timestamp));
    }

    /// @inheritdoc IBlacklist
    function addOverseers(address[] calldata _overseers) external virtual;

    /// @inheritdoc IBlacklist
    function removeOverseers(address[] calldata _overseers) external virtual;

    // Views
    // -----------------------------------------------------------------------------------

    function getBlacklistConfig() public pure returns (BlacklistConfig memory) {
        return BlacklistConfig({ blacklistDelay: 1 days, unblacklistDelay: 1 days });
    }

    function getBlacklist(bytes32 operatorRegistrationRoot)
        public
        view
        returns (BlacklistTimestamps memory)
    {
        return blacklist[operatorRegistrationRoot];
    }

    function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) public view returns (bool) {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[operatorRegistrationRoot];
        return blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt;
    }
}
