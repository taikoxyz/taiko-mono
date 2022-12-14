// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../libs/LibConstants.sol";

/// hello this is an update1
/// @author dantaik <dan@taiko.xyz>
library LibData {
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

    function saveProposedBlock(
        LibData.State storage state,
        uint256 id,
        ProposedBlock memory blk
    ) internal {
        state.proposedBlocks[id % LibConstants.K_MAX_NUM_BLOCKS] = blk;
    }

    function getProposedBlock(
        State storage state,
        uint256 id
    ) internal view returns (ProposedBlock storage) {
        return state.proposedBlocks[id % LibConstants.K_MAX_NUM_BLOCKS];
    }

    function getL2BlockHash(
        State storage state,
        uint256 number
    ) internal view returns (bytes32) {
        require(number <= state.latestVerifiedHeight, "L1:id");
        return state.l2Hashes[number];
    }

    function getStateVariables(
        State storage state
    )
        internal
        view
        returns (
            uint64 genesisHeight,
            uint64 latestVerifiedHeight,
            uint64 latestVerifiedId,
            uint64 nextBlockId
        )
    {
        genesisHeight = state.genesisHeight;
        latestVerifiedHeight = state.latestVerifiedHeight;
        latestVerifiedId = state.latestVerifiedId;
        nextBlockId = state.nextBlockId;
    }

    function hashMetadata(
        BlockMetadata memory meta
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(meta));
    }
}
