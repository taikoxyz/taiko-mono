// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";

/// @title MockUnzenInbox
/// @notice The Unzen Inbox's `getCoreState()`, the only call the EtnaInbox makes to it.
contract MockUnzenInbox {
    IInbox.CoreState internal _state;

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

    function getCoreState() external view returns (IInbox.CoreState memory) {
        return _state;
    }
}
