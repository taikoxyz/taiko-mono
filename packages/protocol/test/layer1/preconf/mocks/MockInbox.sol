// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockInbox
/// @notice Minimal Inbox mock for ProposerAuction tests: serves getProposalHash against a
///         settable mapping of ring-buffer hashes.
contract MockInbox {
    mapping(uint256 proposalId => bytes32 hash) public proposalHashes;

    function setProposalHash(uint256 _proposalId, bytes32 _hash) external {
        proposalHashes[_proposalId] = _hash;
    }

    function getProposalHash(uint256 _proposalId) external view returns (bytes32 proposalHash_) {
        return proposalHashes[_proposalId];
    }
}
