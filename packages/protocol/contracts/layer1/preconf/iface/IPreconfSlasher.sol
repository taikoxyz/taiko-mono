// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ITaikoInbox } from "src/layer1/based/ITaikoInbox.sol";
import { ISlasher } from "@eth-fabric/urc/ISlasher.sol";

interface IPreconfSlasher is ISlasher {
    // Byte-encoded and used as `ISlasher.Commitment.payload`.
    struct CommitmentPayload {
        // Taiko specific DS
        bytes32 domainSeparator;
        // Chainid of Taiko
        uint256 chainId;
        // Timestamp of the L1 slot in which the preconfer is the proposer.
        // In the case of falback preconfer, this will be the timestamp of the last slot of the
        // epoch.
        uint256 l1ProposalSlotTimestamp;
        // Height of the L1 anchor block
        uint256 anchorId;
        // Blockhash of the L1 anchor block
        bytes32 anchorHash;
        // ID of the batch that will be containing this block in TaikoInbox
        uint256 batchId;
        // Hash of the header of the preconfirmed block
        bytes32 blockHash;
        // `true` if this preconfer is not going to deliver anymore
        // preconfirmations after this block
        bool eop; // End-Of-Preconf flag
    }

    // Evidence to prove preconfirmation violation of a block at a certain height X
    struct Evidence {
        // Type of preconfirmation violation
        ViolationType violationType;
        // This is the BatchInfo of the batch that contains the block at height X
        ITaikoInbox.BatchInfo batchInfo;
        // This is the BatchMetadata of the batch that contains the block at height X
        ITaikoInbox.BatchMetadata batchMetadata;
        // This is the BatchMetadata of the next batch that contains the block at height X + 1
        // This is only used for EOP violations
        ITaikoInbox.BatchMetadata nextBatchMetadata;
        // Header of the preconfirmed block at height X
        BlockHeader preconfedBlockHeader;
        // Merkle trie proof for a blockhash stored in L2 TaikoAnchor contract.
        // This is the blockhash of the block that was proposed at height X,
        // but does not match with the blockhash of the preconfirmed block at the same height.
        BlockhashProofs blockhashProofs;
        // Merkle trie proof for a blockhash stored in L2 TaikoAnchor contract.
        // This is the blockhash of the parent of the block referred to by the above field.
        // In other words, this is the blockhash of block at height X - 1.
        // If this parent block is not in the same batch as the above block,
        // this field remains empty.
        BlockhashProofs parentBlockhashProofs;
    }

    // Merkle trie proof for a blockhash stored in L2 TaikoAnchor contract.
    // The EVM `slot` containing the blockhash is calculated dynamically based on the block number.
    struct BlockhashProofs {
        // Blockhash value
        bytes32 value;
        // Patricia trie account proof
        bytes[] accountProof;
        // Patricia trie storage proof
        bytes[] storageProof;
    }

    // Ethereum block header
    struct BlockHeader {
        bytes32 parentHash;
        bytes32 ommersHash;
        address coinbase;
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptRoot;
        bytes bloom; // 256 bytes
        uint256 difficulty;
        uint256 number;
        uint256 gasLimit;
        uint256 gasUsed;
        uint256 timestamp;
        bytes extraData;
        bytes32 prevRandao;
        bytes8 nonce;
        uint256 baseFeePerGas;
        bytes32 withdrawalsRoot;
        uint64 blobGasUsed;
        uint64 excessBlobGas;
        bytes32 parentBeaconBlockRoot;
    }

    enum ViolationType {
        InvalidPreconfirmation,
        InvalidEOP,
        MissingEOP
    }

    event SlashAmountUpdated(uint256 newAmount);
    event SlashedInvalidPreconfirmation(
        address indexed committer, CommitmentPayload commitmentPayload, uint256 slashAmount
    );
    event SlashedInvalidEOP(
        address indexed committer, CommitmentPayload commitmentPayload, uint256 slashAmount
    );
    event SlashedMissingEOP(
        address indexed committer, CommitmentPayload commitmentPayload, uint256 slashAmount
    );

    error InvalidDomainSeparator();
    error InvalidChainId();
    error BatchNotVerified();
    error InvalidBlockHeader();
    error InvalidBatchMetadata();
    error InvalidBatchInfo();
    error PossibleReorgAtProposalSlot();
    error PossibleReorgOfAnchorBlock();
    error ParentHashMismatch();
    error PreconfirmationIsValid();
    error InvalidNextBatchMetadata();
    error NotEndOfPreconfirmation();
    error EOPIsValid();
    error EOPIsPresent();
    error EOPIsNotMissing();

    /// @notice Allows the owner to update the slash amount
    /// @param _newAmount The new slash amount in wei
    function updateSlashAmount(uint256 _newAmount) external;
}
