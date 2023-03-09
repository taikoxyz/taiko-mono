// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {Snippet} from "../common/IXchainSync.sol";

library TaikoData {
    struct Config {
        uint256 chainId;
        // up to 2048 pending blocks
        uint256 maxNumBlocks;
        uint256 blockHashHistory;
        // This number is calculated from maxNumBlocks to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 maxVerificationsPerTx;
        uint256 blockMaxGasLimit;
        uint256 maxTransactionsPerBlock;
        uint256 minTxGasLimit;
        uint256 anchorTxGasLimit;
        uint256 slotSmoothingFactor;
        uint256 rewardBurnBips;
        uint256 proposerDepositPctg;
        // Moving average factors
        uint256 feeBaseMAF;
        uint256 blockTimeMAF;
        uint256 proofTimeMAF;
        uint64 rewardMultiplierPctg;
        uint64 feeGracePeriodPctg;
        uint64 feeMaxPeriodPctg;
        uint64 blockTimeCap;
        uint64 proofTimeCap;
        uint64 bootstrapDiscountHalvingPeriod;
        bool enableTokenomics;
        bool skipZKPVerification;
    }

    struct BlockMetadataInput {
        address beneficiary;
        uint64 gasLimit;
        bytes32 txListHash;
    }

    struct BlockHeader {
        bytes32 parentHash;
        // bytes32 ommersHash;
        address beneficiary;
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptsRoot;
        // bytes32[8] logsBloom; // must be 0s.
        // uint256 difficulty; // must be 0
        uint128 height;
        uint64 gasLimit;
        uint64 gasUsed;
        uint64 timestamp;
        // bytes extraData; // must be `new bytes(0)`
        bytes32 mixHash;
        // uint64 nonce; // must be 0
        uint256 baseFeePerGas;
    }

    struct BlockMetadata {
        uint256 id;
        uint256 l1Height;
        bytes32 l1Hash;
        address beneficiary;
        bytes32 txListHash;
        uint256 mixHash;
        uint64 gasLimit;
        uint64 timestamp;
    }

    struct ZKProof {
        bytes data;
        uint256 circuitId;
    }

    struct BlockEvidence {
        TaikoData.BlockMetadata meta;
        ZKProof zkproof;
        bytes32 parentHash;
        bytes32 blockHash;
        bytes32 signalRoot;
        address prover;
    }

    // 3 slots
    struct ProposedBlock {
        bytes32 metaHash;
        uint256 deposit;
        address proposer;
        uint64 proposedAt;
    }

    // 3 + n slots
    struct ForkChoice {
        Snippet snippet;
        address prover;
        uint64 provenAt;
    }

    // This struct takes 9 slots.
    struct State {
        mapping(uint256 blockId => ProposedBlock proposedBlock) proposedBlocks;
        // solhint-disable-next-line max-line-length
        mapping(uint256 blockId => mapping(bytes32 parentHash => ForkChoice forkChoice)) forkChoices;
        // solhint-disable-next-line max-line-length
        mapping(uint256 blockNumber => Snippet) l2Snippets;
        mapping(address prover => uint256 outstandingReward) balances;
        // Never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 __reserved1;
        uint64 __reserved2;
        // Changed when a block is proposed or proven/finalized
        // Changed when a block is proposed
        uint64 nextBlockId;
        uint64 lastProposedAt; // Timestamp when the last block is proposed.
        uint64 avgBlockTime; // The block time moving average
        uint64 __reserved3;
        // Changed when a block is proven/finalized
        uint64 latestVerifiedHeight;
        uint64 latestVerifiedId;
        // the proof time moving average, note that for each block, only the
        // first proof's time is considered.
        uint64 avgProofTime;
        uint64 feeBaseSzabo;
        // Reserved
        uint256[42] __gap;
    }
}
