// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibAddress} from "../../libs/LibAddress.sol";
import {LibEthDepositing} from "./LibEthDepositing.sol";
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
    error L1_INSUFFICIENT_ETHER();
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

        meta.id = state.numBlocks;
        meta.txListHash = input.txListHash;
        meta.txListByteStart = input.txListByteStart;
        meta.txListByteEnd = input.txListByteEnd;
        meta.gasLimit = input.gasLimit;
        meta.beneficiary = input.beneficiary;
        meta.treasure = resolver.resolve(config.chainId, "treasure", false);

        (meta.depositsRoot, meta.depositsProcessed) = LibEthDepositing
            .calcDepositsRoot(
                state,
                config,
                input.ethDepositIds,
                input.beneficiary
            );

        unchecked {
            meta.timestamp = uint64(block.timestamp);
            meta.l1Height = uint64(block.number - 1);
            meta.l1Hash = blockhash(block.number - 1);
            meta.mixHash = bytes32(block.prevrandao * state.numBlocks);
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

        if (config.enableTokenomics) {
            (uint256 newFeeBase, uint256 fee, uint64 deposit) = LibTokenomics
                .getBlockFee(state, config);

            uint256 burnAmount = fee + deposit;
            if (state.balances[msg.sender] < burnAmount)
                revert L1_INSUFFICIENT_TOKEN();

            unchecked {
                state.balances[msg.sender] -= burnAmount;
            }

            // Update feeBase and avgBlockTime
            state.feeBase = LibUtils
                .movingAverage({
                    maValue: state.feeBase,
                    newValue: newFeeBase,
                    maf: config.feeBaseMAF
                })
                .toUint64();

            blk.deposit = uint64(deposit);
        }
        {
            unchecked {
                state.avgBlockTime = LibUtils
                    .movingAverage({
                        maValue: state.avgBlockTime,
                        newValue: (meta.timestamp - state.lastProposedAt) *
                            1000,
                        maf: config.proposingConfig.avgTimeMAF
                    })
                    .toUint64();
                state.lastProposedAt = meta.timestamp;
            }

            emit BlockProposed(state.numBlocks, meta, cacheTxList);

            unchecked {
                ++state.numBlocks;
            }
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
            input.gasLimit == 0 ||
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
