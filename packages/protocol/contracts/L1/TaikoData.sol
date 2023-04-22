// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

library TaikoData {
    struct Config {
        uint256 chainId;
        uint256 maxNumProposedBlocks;
        uint256 ringBufferSize;
        uint256 maxNumVerifiedBlocks;
        // This number is calculated from maxNumProposedBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 maxVerificationsPerTx;
        uint256 blockMaxGasLimit;
        uint256 maxTransactionsPerBlock;
        uint256 maxBytesPerTxList;
        uint256 minTxGasLimit;
        uint256 txListCacheExpiry;
        uint64 minEthDepositsPerBlock;
        uint64 maxEthDepositsPerBlock;
        uint96 maxEthDepositAmount;
        uint96 minEthDepositAmount;
        uint64 proofTimeTarget;
        uint8 adjustmentQuotient;
        bool relaySignalRoot;
        bool enableSoloProposer;
        bool enableOracleProver;
        bool enableTokenomics;
        bool skipZKPVerification;
    }

    struct StateVariables {
        uint64 basefee;
        uint64 accBlockFees;
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 numBlocks;
        uint64 proofTimeIssued;
        uint64 lastVerifiedBlockId;
        uint64 accProposedAt;
        uint64 nextEthDepositToProcess;
        uint64 numEthDeposits;
    }

    // 3 slots
    struct BlockMetadataInput {
        bytes32 txListHash;
        address beneficiary;
        uint32 gasLimit;
        uint24 txListByteStart; // byte-wise start index (inclusive)
        uint24 txListByteEnd; // byte-wise end index (exclusive)
        uint8 cacheTxListInfo; // non-zero = True
    }

    // Changing this struct requires changing LibUtils.hashMetadata accordingly.
    struct BlockMetadata {
        uint64 id;
        uint64 timestamp;
        uint64 l1Height;
        bytes32 l1Hash;
        bytes32 mixHash;
        bytes32 depositsRoot; // match L2 header's withdrawalsRoot
        bytes32 txListHash;
        uint24 txListByteStart;
        uint24 txListByteEnd;
        uint32 gasLimit;
        address beneficiary;
        uint8 cacheTxListInfo;
        address treasure;
        TaikoData.EthDeposit[] depositsProcessed;
    }

    struct ZKProof {
        bytes data;
        uint16 verifierId;
    }

    struct BlockEvidence {
        TaikoData.BlockMetadata meta;
        ZKProof zkproof;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 signalRoot;
        bytes32 graffiti;
        address prover;
        uint32 parentGasUsed;
        uint32 gasUsed;
    }

    struct BlockOracle {
        bytes32 blockHash;
        uint32 gasUsed;
        bytes32 signalRoot;
    }

    struct BlockOracles {
        bytes32 parentHash;
        uint32 parentGasUsed;
        BlockOracle[] blks;
    }

    // 4 slots
    struct ForkChoice {
        bytes32 key; // only written/read for the 1st fork choice.
        bytes32 blockHash;
        bytes32 signalRoot;
        uint64 provenAt;
        address prover;
        uint32 gasUsed;
    }

    // 4 slots
    struct Block {
        // ForkChoice storage are reusable
        mapping(uint256 forkChoiceId => ForkChoice) forkChoices;
        uint64 blockId;
        uint64 proposedAt;
        uint64 deposit;
        uint24 nextForkChoiceId;
        uint24 verifiedForkChoiceId;
        bytes32 metaHash;
        address proposer;
    }

    // This struct takes 9 slots.
    struct TxListInfo {
        uint64 validSince;
        uint24 size;
    }

    // 1 slot
    struct EthDeposit {
        address recipient;
        uint96 amount;
    }

    struct State {
        // Ring buffer for proposed blocks and a some recent verified blocks.
        mapping(uint256 blockId_mode_ringBufferSize => Block) blocks;
        // solhint-disable-next-line max-line-length
        mapping(uint256 blockId => mapping(bytes32 parentHash => mapping(uint32 parentGasUsed => uint256 forkChoiceId))) forkChoiceIds;
        mapping(address account => uint256 balance) balances;
        mapping(bytes32 txListHash => TxListInfo) txListInfo;
        EthDeposit[] ethDeposits;
        // Slot 6: never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 __reserved61;
        uint64 __reserved62;
        // Slot 7
        uint64 accProposedAt;
        uint64 accBlockFees;
        uint64 numBlocks;
        uint64 nextEthDepositToProcess;
        // Slot 8
        uint64 basefee;
        uint64 proofTimeIssued;
        uint64 lastVerifiedBlockId;
        uint64 __reserved81;
        // Reserved
        uint256[42] __gap;
    }
}
