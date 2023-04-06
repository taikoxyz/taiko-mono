// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {LibL2Consts} from "../../L2/LibL2Consts.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibProposing {
    using SafeCastUpgradeable for uint256;
    using LibAddress for address;
    using LibAddress for address payable;
    using LibUtils for TaikoData.State;

    event BlockProposed(
        uint256 indexed id,
        TaikoData.BlockMetadata meta,
        bool txListCached
    );

    error L1_BLOCK_ID();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_METADATA();
    error L1_NOT_SOLO_PROPOSER();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadataInput memory input,
        bytes calldata txList
    ) internal {
        bool cacheTxList = _validateBlock({
            state: state,
            config: config,
            resolver: resolver,
            input: input,
            txList: txList
        });

        if (cacheTxList) {
            state.txListInfo[input.txListHash] = TaikoData.TxListInfo({
                validSince: uint64(block.timestamp),
                size: uint24(txList.length)
            });
        }

        // After The Merge, L1 mixHash contains the prevrandao
        // from the beacon chain. Since multiple Taiko blocks
        // can be proposed in one Ethereum block, we need to
        // add salt to this random number as L2 mixHash
        TaikoData.BlockMetadata memory meta;
        unchecked {
            meta = TaikoData.BlockMetadata({
                id: state.numBlocks,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                l1Hash: blockhash(block.number - 1),
                mixHash: bytes32(block.prevrandao * state.numBlocks),
                txListHash: input.txListHash,
                txListByteStart: input.txListByteStart,
                txListByteEnd: input.txListByteEnd,
                gasLimit: input.gasLimit,
                beneficiary: input.beneficiary
            });
        }

        TaikoData.Block storage blk = state.blocks[
            state.numBlocks % config.ringBufferSize
        ];

        blk.blockId = state.numBlocks;
        blk.proposedAt = meta.timestamp;
        blk.deposit = 0;
        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = 0;
        blk.metaHash = LibUtils.hashMetadata(meta);
        blk.proposer = msg.sender;

        if (config.proofTimeTarget != 0) {
            uint64 fee = LibTokenomics.getProverFee(state);
            if (state.balances[msg.sender] < fee)
                revert L1_INSUFFICIENT_TOKEN();

            unchecked {
                state.balances[msg.sender] -= fee;
                if (!config.allowMinting) {
                    state.rewardPool += fee;
                    if (config.useTimeWeightedReward) {
                        state.accProposedAt += meta.timestamp;
                    }
                }
            }
        }

        emit BlockProposed(state.numBlocks, meta, cacheTxList);
        unchecked {
            ++state.numBlocks;
            state.lastProposedAt = meta.timestamp;
        }
    }

    function getBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId
    ) internal view returns (TaikoData.Block storage blk) {
        blk = state.blocks[blockId % config.ringBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();
    }

    function _validateBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadataInput memory input,
        bytes calldata txList
    ) private view returns (bool cacheTxList) {
        // For alpha-2 testnet, the network only allows an special address
        // to propose but anyone to prove. This is the first step of testing
        // the tokenomics.
        if (
            config.enableSoloProposer &&
            msg.sender != resolver.resolve("solo_proposer", false)
        ) revert L1_NOT_SOLO_PROPOSER();

        if (
            input.beneficiary == address(0) ||
            input.gasLimit < LibL2Consts.ANCHOR_GAS_COST ||
            input.gasLimit > config.blockMaxGasLimit
        ) revert L1_INVALID_METADATA();

        if (
            state.numBlocks >=
            state.lastVerifiedBlockId + config.maxNumProposedBlocks + 1
        ) revert L1_TOO_MANY_BLOCKS();

        uint64 timeNow = uint64(block.timestamp);
        // hanlding txList
        {
            uint24 size = uint24(txList.length);
            if (size > config.maxBytesPerTxList) revert L1_TX_LIST();

            if (input.txListByteStart > input.txListByteEnd)
                revert L1_TX_LIST_RANGE();

            if (config.txListCacheExpiry == 0) {
                // caching is disabled
                if (input.txListByteStart != 0 || input.txListByteEnd != size)
                    revert L1_TX_LIST_RANGE();
            } else {
                // caching is enabled
                if (size == 0) {
                    // This blob shall have been submitted earlier
                    TaikoData.TxListInfo memory info = state.txListInfo[
                        input.txListHash
                    ];

                    if (input.txListByteEnd > info.size)
                        revert L1_TX_LIST_RANGE();

                    if (
                        info.size == 0 ||
                        info.validSince + config.txListCacheExpiry < timeNow
                    ) revert L1_TX_LIST_NOT_EXIST();
                } else {
                    if (input.txListByteEnd > size) revert L1_TX_LIST_RANGE();
                    if (input.txListHash != keccak256(txList))
                        revert L1_TX_LIST_HASH();

                    cacheTxList = (input.cacheTxListInfo != 0);
                }
            }
        }
    }
}
