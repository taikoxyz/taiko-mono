// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ILookahead
/// @custom:security-contact security@taiko.xyz
interface ILookahead {
    struct LookaheadSetParam {
        // The timestamp of the slot
        uint256 timestamp;
        // The AVS operator who is also the L1 validator for the slot and will preconf L2
        // transactions
        address preconfer;
    }

    function updateLookahead(LookaheadSetParam calldata _lookaheadSetParams) external;
    function isLookaheadRequired() external view returns (bool);
    function isCurrentPreconfer(address addr) external view returns (bool);
}
