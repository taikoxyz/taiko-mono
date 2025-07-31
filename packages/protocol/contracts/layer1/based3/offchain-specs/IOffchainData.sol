// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IOffchainData {
    struct BlockParams {
        uint256 timestamp;
        address feeRecipient;
    }

    struct ProposalSpec {
        uint256 gasIssuancePerSecond;
        BlockParams[] blocks;
    }

    struct L1LatestBlockData {
        uint256 timestamp;
        bytes32 prevRando;
    }

    struct L2ParentBlockData {
        uint256 number;
        uint256 timestamp;
        bytes32 blockHash;
    }

    struct L2ProtocolState {
        uint256 gasIssuancePerSecond;
    }

    struct BuildBlockInputs {
        uint256 timestamp;
        bytes32 parentHash;
        address feeRecipient;
        uint256 number;
        uint256 gasLimit;
        bytes32 prevRando;
        bytes32 extraData;
        bytes32 withdrawalsRoot;
    }
}
