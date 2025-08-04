// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAnchor {

    struct ProtoState {
        uint256 proposalId;
    }

    function get() external view returns (ProtoState memory);

    function set(ProtoState memory _coreState) external;

    function anchorTransactor() external pure returns (address);
}
