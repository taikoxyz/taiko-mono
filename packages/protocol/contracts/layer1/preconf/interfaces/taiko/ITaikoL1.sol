// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ITaikoL1 {
    struct BlockMetadata {
        bytes32 l1Hash;
        bytes32 difficulty;
        bytes32 blobHash;
        bytes32 extraData;
        bytes32 depositsHash;
        address coinbase;
        uint64 id;
        uint32 gasLimit;
        uint64 timestamp;
        uint64 l1Height;
        uint16 minTier;
        bool blobUsed;
        bytes32 parentMetaHash;
        address sender;
        uint32 blobTxListOffset;
        uint32 blobTxListLength;
    }

    struct EthDeposit {
        address recipient;
        uint96 amount;
        uint64 id;
    }

    struct SlotA {
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 lastSyncedBlockId;
        uint64 lastSynecdAt; // typo!
    }

    struct SlotB {
        uint64 numBlocks;
        uint64 lastVerifiedBlockId;
        bool provingPaused;
        uint8 __reservedB1;
        uint16 __reservedB2;
        uint32 __reservedB3;
        uint64 lastUnpausedAt;
    }

    struct Block {
        bytes32 metaHash;
        address assignedProver;
        uint96 livenessBond;
        uint64 blockId;
        uint64 proposedAt;
        uint64 proposedIn;
        uint32 nextTransitionId;
        uint32 verifiedTransitionId;
        uint64 timestamp;
        uint32 l1StateBlockNumber;
    }

    function proposeBlock(bytes calldata _params, bytes calldata _txList)
        external
        payable
        returns (BlockMetadata memory meta_, EthDeposit[] memory deposits_);

    function getStateVariables() external view returns (SlotA memory, SlotB memory);

    function getBlock(uint64 _blockId) external view returns (Block memory blk_);
}
