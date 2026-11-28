// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";

/// @title MockUnzenInbox
/// @notice The Unzen Inbox's `getCoreState()` and `proposeCutoff()`, the only calls the EtnaInbox
/// makes to it (START-10-5a, LAND-6.1-8a).
/// @dev `proposeCutoff()` returns the stored value, zero until set, or reverts once told to.
contract MockUnzenInbox {
    IInbox.CoreState internal _state;
    uint48 internal _proposeCutoff;
    bool internal _proposeCutoffReverts;

    function setCoreState(
        uint48 _nextProposalId,
        uint48 _lastFinalizedProposalId,
        bytes32 _lastFinalizedBlockHash
    )
        external
    {
        _state.nextProposalId = _nextProposalId;
        _state.lastFinalizedProposalId = _lastFinalizedProposalId;
        _state.lastFinalizedBlockHash = _lastFinalizedBlockHash;
    }

    function setProposeCutoff(uint48 _cutoff) external {
        _proposeCutoff = _cutoff;
    }

    function setProposeCutoffReverts(bool _reverts) external {
        _proposeCutoffReverts = _reverts;
    }

    function getCoreState() external view returns (IInbox.CoreState memory) {
        return _state;
    }

    function proposeCutoff() external view returns (uint48) {
        require(!_proposeCutoffReverts, ProposeCutoffUnavailable());
        return _proposeCutoff;
    }

    error ProposeCutoffUnavailable();
}
