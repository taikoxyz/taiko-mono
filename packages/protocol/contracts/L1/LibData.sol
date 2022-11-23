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
        mapping(address => bool) provers; // Whitelisted provers
        uint64 statusBits;
        uint64 genesisHeight;
        uint64 latestVerifiedHeight;
        uint64 latestVerifiedId;
        uint64 nextBlockId;
    }

    function saveProposedBlock(
        LibData.State storage s,
        uint256 id,
        ProposedBlock memory blk
    ) internal {
        s.proposedBlocks[id % LibConstants.TAIKO_MAX_PROPOSED_BLOCKS] = blk;
    }

    function getProposedBlock(
        State storage s,
        uint256 id
    ) internal view returns (ProposedBlock storage) {
        return s.proposedBlocks[id % LibConstants.TAIKO_MAX_PROPOSED_BLOCKS];
    }

    function getL2BlockHash(
        State storage s,
        uint256 number
    ) internal view returns (bytes32) {
        require(number <= s.latestVerifiedHeight, "L1:id");
        return s.l2Hashes[number];
    }

    function getStateVariables(
        State storage s
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
        genesisHeight = s.genesisHeight;
        latestVerifiedHeight = s.latestVerifiedHeight;
        latestVerifiedId = s.latestVerifiedId;
        nextBlockId = s.nextBlockId;
    }

    function hashMetadata(
        BlockMetadata memory meta
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(meta));
    }
}
