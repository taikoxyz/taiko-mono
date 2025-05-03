// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IProverBlacklist.sol";

/// @title ProverBlacklist
/// @custom:security-contact security@taiko.xyz
contract ProverBlacklist is IProverBlacklist {
    error ZeroAddress();
    error SameAddress();
    error InvalidStatus();

    mapping(address proveer => mapping(address proposer => bool isBlacklisted)) public blacklists;

    /// @inheritdoc IProverBlacklist
    function addToBlackList(address _proposer) external {
        _blacklist(_proposer, true);
    }

    /// @inheritdoc IProverBlacklist
    function removeFromBlackList(address _proposer) external {
        _blacklist(_proposer, false);
    }

    /// @inheritdoc IProverBlacklist
    function isBlacklistedBy(address _proposer, address _prover) external view returns (bool) {
        return blacklists[_prover][_proposer];
    }

    function _blacklist(address _proposer, bool _blacklisted) internal {
        require(_proposer != address(0), ZeroAddress());
        require(_proposer != msg.sender, SameAddress());
        require(blacklists[msg.sender][_proposer] != _blacklisted, InvalidStatus());
        blacklists[msg.sender][_proposer] = _blacklisted;
        emit ProposerBlacklisted(_proposer, msg.sender, _blacklisted);
    }
}
