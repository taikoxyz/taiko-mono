// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISpecs {
    struct Block {
        uint256 timestamp;
        address feeRecipient;
        Transaction[] transactions;
    }

    struct ProposalData {
        uint256 gasIssuancePerSecond;
        Block[] blocks;
    }

    struct ProtocolState {
        uint256 gasIssuancePerSecond;
    }

    /// @dev The exact fields of this sturct do not matter.
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bytes signature;
    }

    // @david @gavin plase check if these information are sufficient for building a block
    struct BuildBlockInput {
        uint256 timestamp;
        bytes32 parentHash;
        address feeRecipient;
        uint256 number;
        uint256 gasLimit;
        bytes32 prevRandao;
        bytes32 extraData;
        bytes32 withdrawalsRoot;
        Transaction[] transactions;
    }
}
