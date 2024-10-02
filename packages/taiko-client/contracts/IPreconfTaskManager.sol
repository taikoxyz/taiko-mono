// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

interface IPreconfTaskManager {
    struct LookaheadSetParam {
        // The timestamp of the slot
        uint256 timestamp;
        // The AVS operator who is also the L1 validator for the slot and will preconf L2 transactions
        address preconfer;
    }

    struct LookaheadBufferEntry {
        // True when the preconfer is randomly selected
        bool isFallback;
        // Timestamp of the slot at which the provided preconfer is the L1 validator
        uint40 timestamp;
        // Timestamp of the last slot that had a valid preconfer
        uint40 prevTimestamp;
        // Address of the preconfer who is also the L1 validator
        // The preconfer will have rights to propose a block in the range (prevTimestamp, timestamp]
        address preconfer;
    }

    /// @dev Accepts block proposal by an operator and forwards it to TaikoL1 contract
    function newBlockProposal(
        bytes calldata blockParams,
        bytes calldata txList,
        uint256 lookaheadPointer,
        LookaheadSetParam[] calldata lookaheadSetParams
    ) external payable;

    function getLookaheadBuffer() external view returns (LookaheadBufferEntry[64] memory);
}
