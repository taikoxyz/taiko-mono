// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Anchor is IAnchor {
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000000000000000000000000000000000001670;

    ProtoState private _protoState;

    struct ProtoState {
        uint256 proposalId;
    }

    function get() external view returns (ProtoState memory) {
        return _protoState;
    }

    function set(ProtoState memory _newProtoState) external {
        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert Unauthorized();
        if (_newProtoState.proposalId <= _protoState.proposalId) revert InvalidProposalId();

        _protoState = _newProtoState;
    }

    error Unauthorized();
    error InvalidProposalId();
}
