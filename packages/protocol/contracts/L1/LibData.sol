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

/// @author dantaik <dan@taiko.xyz>
library LibData {
    struct BlockMetadata {
        uint256 id;
        uint256 l1Height;
        bytes32 l1Hash;
        address beneficiary;
        uint64 gasLimit;
        uint64 timestamp;
        bytes32 txListHash;
        bytes32 mixHash;
        bytes extraData;
    }

    struct ProposedBlock {
        bytes32 metaHash;
    }

    struct ForkChoice {
        bytes32 blockHash;
        uint64 proposedAt;
        uint64 provenAt;
        address[] provers;
    }

    struct State {
        // block id => block hash
        mapping(uint256 => bytes32) l2Hashes;
        // block id => ProposedBlock
        mapping(uint256 => ProposedBlock) proposedBlocks;
        // block id => parent hash => fork choice
        mapping(uint256 => mapping(bytes32 => ForkChoice)) forkChoices;
        mapping(bytes32 => uint256) commits;
        uint64 genesisHeight;
        uint64 latestFinalizedHeight;
        uint64 latestFinalizedId;
        uint64 nextBlockId;
        uint64 lastBlockTime;
        // weighted average of proposing/proving delay
        uint64 maProposingDelay;
        uint64 maProvingDelay;
        // weighted average of proposing/proving fees
        uint128 maProposingFee;
        uint128 maProvingFee;
    }

    function saveProposedBlock(
        LibData.State storage s,
        uint256 id,
        ProposedBlock memory blk
    ) internal {
        s.proposedBlocks[id % LibConstants.TAIKO_MAX_PROPOSED_BLOCKS] = blk;
    }

    function getProposedBlock(State storage s, uint256 id)
        internal
        view
        returns (ProposedBlock storage)
    {
        return s.proposedBlocks[id % LibConstants.TAIKO_MAX_PROPOSED_BLOCKS];
    }

    function getL2BlockHash(State storage s, uint256 number)
        internal
        view
        returns (bytes32)
    {
        require(number <= s.latestFinalizedHeight, "L1:id");
        return s.l2Hashes[number];
    }

    function getStateVariables(State storage s)
        internal
        view
        returns (
            uint64 genesisHeight,
            uint64 latestFinalizedHeight,
            uint64 latestFinalizedId,
            uint64 nextBlockId,
            uint64 lastBlockTime,
            uint64 maProposingDelay,
            uint64 maProvingDelay,
            uint128 maProposingFee,
            uint128 maProvingFee
        )
    {
        genesisHeight = s.genesisHeight;
        latestFinalizedHeight = s.latestFinalizedHeight;
        latestFinalizedId = s.latestFinalizedId;
        nextBlockId = s.nextBlockId;

        lastBlockTime = s.lastBlockTime;
        maProposingDelay = s.maProposingDelay;
        maProvingDelay = s.maProvingDelay;

        maProposingFee = s.maProposingFee;
        maProvingFee = s.maProvingFee;
    }

    function hashMetadata(BlockMetadata memory meta)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(meta));
    }

    function calcMovingAvg(
        uint256 mv,
        uint256 v,
        uint256 factor
    ) internal pure returns (uint256) {
        return mv == 0 ? v : (mv * (factor - 1) + v) / factor;
    }
}
