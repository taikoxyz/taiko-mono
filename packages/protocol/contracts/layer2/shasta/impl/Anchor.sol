// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISyncedBlockManager} from "src/shared/shasta/iface/ISyncedBlockManager.sol";
import {IAnchor} from "../iface/IAnchor.sol";

contract Anchor is IAnchor {
    // @dev The address of the anchor transactor which shall NOT have a private key.
    address public constant _ANCHOR_TRANSACTOR = 0x0000000000000000000000000000000000001670;

    ISyncedBlockManager public immutable _syncedBlockManager;

    ProtoState private _protoState;

    constructor(address _syncedBlockManagerAddress) {
        _syncedBlockManager = ISyncedBlockManager(_syncedBlockManagerAddress);
    }

    function get() external view returns (ProtoState memory) {
        return _protoState;
    }

    function set(ProtoState memory _newProtoState) external {
        if (msg.sender != _ANCHOR_TRANSACTOR) revert Unauthorized();
        if (_newProtoState.proposalId <= _protoState.proposalId) revert InvalidProposalId();

        _protoState = _newProtoState;
    }

    function anchorTransactor() external pure returns (address) {
        return _ANCHOR_TRANSACTOR;
    }

    error Unauthorized();
    error InvalidProposalId();
}
