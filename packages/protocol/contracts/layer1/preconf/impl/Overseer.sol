// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IOverseer.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/governance/SimpleMultisig.sol";

/// @title Overseer
/// @notice The Overseer is responsible for blacklisting preconf operators based on
/// subjective faults. For instance, non-adherence to fair exchange.
/// @dev Blacklisted operators are not inserted in the lookahead. This is done to
/// prevent the lookahead from being polluted by invalid operators.
/// @custom:security-contact security@taiko.xyz
contract Overseer is IOverseer, SimpleMultisig, EssentialContract {
    /// @dev Maps operator registration roots to the timestamp at which they
    /// were blacklisted or unblacklisted.
    mapping(bytes32 operatorRegistrationRoot => BlacklistTimestamps blacklistTimestamps) internal
        blacklist;

    uint256[49] private __gap;

    function init(uint64 _signingThreshold, address[] memory _signers) external initializer {
        __Essential_init(address(0));
        __SimpleMultisig_init(_signingThreshold, _signers);
    }

    // Blacklist functions
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IOverseer
    function blacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external
    {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_operatorRegistrationRoot];

        // The operator must not be already blacklisted
        require(
            blacklistTimestamps.blacklistedAt <= blacklistTimestamps.unBlacklistedAt,
            OperatorAlreadyBlacklisted()
        );

        // If the operator was unblacklisted, the overseer must wait for a delay before
        // blacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.unBlacklistedAt + getConfig().blacklistDelay,
            BlacklistDelayNotMet()
        );

        // The signatures must be valid
        _verifySignatures(_getBlacklistDomainSeparator(), _operatorRegistrationRoot, _signatures);

        blacklist[_operatorRegistrationRoot].blacklistedAt = uint48(block.timestamp);

        emit Blacklisted(_operatorRegistrationRoot, uint48(block.timestamp));
    }

    /// @inheritdoc IOverseer
    function unblacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external
    {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_operatorRegistrationRoot];

        // The operator must be blacklisted
        require(
            blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt,
            OperatorNotBlacklisted()
        );

        // If the operator was blacklisted, the overseer must wait for a delay before
        // unblacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.blacklistedAt + getConfig().unblacklistDelay,
            UnblacklistDelayNotMet()
        );

        // The signatures must be valid
        _verifySignatures(_getUnblacklistDomainSeparator(), _operatorRegistrationRoot, _signatures);

        blacklist[_operatorRegistrationRoot].unBlacklistedAt = uint48(block.timestamp);

        emit Unblacklisted(_operatorRegistrationRoot, uint48(block.timestamp));
    }

    // Views
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IOverseer
    function getConfig() public pure returns (Config memory) {
        return Config({ blacklistDelay: 1 days, unblacklistDelay: 1 days });
    }

    /// @inheritdoc IOverseer
    function getBlacklist(bytes32 operatorRegistrationRoot)
        external
        view
        returns (BlacklistTimestamps memory)
    {
        return blacklist[operatorRegistrationRoot];
    }

    /// @inheritdoc IOverseer
    function isOperatorBlacklisted(bytes32 operatorRegistrationRoot) external view returns (bool) {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[operatorRegistrationRoot];
        return blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt;
    }

    // Internal functions
    // -----------------------------------------------------------------------------------

    function _getBlacklistDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_BLACKLIST_OVERSEER");
    }

    function _getUnblacklistDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_UNBLACKLIST_OVERSEER");
    }

    // Overrides
    // -----------------------------------------------------------------------------------

    function _getAddSignerDomainSeparator() internal pure override returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_OVERSEER_ADD_SIGNER");
    }

    function _getRemoveSignerDomainSeparator() internal pure override returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_OVERSEER_REMOVE_SIGNER");
    }

    function _getUpdateSigningThresholdDomainSeparator() internal pure override returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_OVERSEER_UPDATE_SIGNING_THRESHOLD");
    }
}
