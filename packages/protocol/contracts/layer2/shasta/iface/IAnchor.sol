// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAnchor {
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000000000000000000000000000000000001670;

    struct ProtoState {
        uint256 proposalId;
    }

    function get() external view returns (ProtoState memory);

    function set(ProtoState memory _coreState) external;
}
