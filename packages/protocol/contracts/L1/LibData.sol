// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
library LibData {
    struct Config {
        uint256 K_CHAIN_ID;
        // up to 2048 pending blocks
        uint256 K_MAX_NUM_BLOCKS;
        // This number is calculated from K_MAX_NUM_BLOCKS to make
        // the 'the maximum value of the multiplier' close to 20.0
        uint256 K_ZKPROOFS_PER_BLOCK;
        uint256 K_MAX_VERIFICATIONS_PER_TX;
        uint256 K_COMMIT_DELAY_CONFIRMS;
        uint256 K_MAX_PROOFS_PER_FORK_CHOICE;
        uint256 K_BLOCK_MAX_GAS_LIMIT;
        uint256 K_BLOCK_MAX_TXS;
        uint256 K_TXLIST_MAX_BYTES;
        uint256 K_TX_MIN_GAS_LIMIT;
        uint256 K_ANCHOR_TX_GAS_LIMIT;
        uint256 K_FEE_PREMIUM_LAMDA;
        uint256 K_REWARD_BURN_BP;
        uint256 K_PROPOSER_DEPOSIT_PCTG;
        // Moving average factors
        uint256 K_FEE_BASE_MAF;
        uint256 K_BLOCK_TIME_MAF;
        uint256 K_PROOF_TIME_MAF;
        uint64 K_REWARD_MULTIPLIER_PCTG;
        uint64 K_FEE_GRACE_PERIOD_PCTG;
        uint64 K_FEE_MAX_PERIOD_PCTG;
        uint64 K_BLOCK_TIME_CAP;
        uint64 K_PROOF_TIME_CAP;
        uint64 K_HALVING;
        uint64 K_INITIAL_UNCLE_DELAY;
        bool K_ENABLE_TOKENOMICS;
    }

    struct BlockMetadata {
        uint256 id;
        uint256 l1Height;
        bytes32 l1Hash;
        address beneficiary;
        bytes32 txListHash;
        bytes32 mixHash;
        bytes extraData;
        uint64 gasLimit;
        uint64 timestamp;
        uint64 commitHeight;
        uint64 commitSlot;
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
        bytes32 blockHash;
        uint64 provenAt;
        address[] provers;
    }

    // This struct takes 9 slots.
    struct State {
        // block id => block hash
        mapping(uint256 => bytes32) l2Hashes;
        // block id => ProposedBlock
        mapping(uint256 => ProposedBlock) proposedBlocks;
        // block id => parent hash => fork choice
        mapping(uint256 => mapping(bytes32 => ForkChoice)) forkChoices;
        // proposer => commitSlot => hash(commitHash, commitHeight)
        mapping(address => mapping(uint256 => bytes32)) commits;
        // Never or rarely changed
        uint64 genesisHeight;
        uint64 genesisTimestamp;
        uint64 __reservedA1;
        uint64 statusBits; // rarely change
        // Changed when a block is proposed or proven/finalized
        uint256 feeBase;
        // Changed when a block is proposed
        uint64 nextBlockId;
        uint64 lastProposedAt; // Timestamp when the last block is proposed.
        uint64 avgBlockTime; // The block time moving average
        uint64 __avgGasLimit; // the block gaslimit moving average, not updated.
        // Changed when a block is proven/finalized
        uint64 latestVerifiedHeight;
        uint64 latestVerifiedId;
        // the proof time moving average, note that for each block, only the
        // first proof's time is considered.
        uint64 avgProofTime;
        uint64 __reservedC1;
        // Reserved
        uint256[42] __gap;
    }

    struct TentativeState {
        mapping(address => bool) proposers; // Whitelisted proposers
        mapping(address => bool) provers; // Whitelisted provers
        bool whitelistProposers;
        bool whitelistProvers;
        // // Reserved
        uint256[46] __gap;
    }
}
