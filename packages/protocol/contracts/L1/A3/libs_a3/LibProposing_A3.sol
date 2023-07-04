// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../../../common/AddressResolver.sol";
import {LibAddress} from "../../../libs/LibAddress.sol";
import {LibEthDepositing_A3} from "./LibEthDepositing_A3.sol";
import {LibUtils_A3} from "./LibUtils_A3.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData_A3} from "../TaikoData_A3.sol";

library LibProposing_A3 {
    using SafeCastUpgradeable for uint256;
    using LibAddress for address;
    using LibAddress for address payable;
    using LibUtils_A3 for TaikoData_A3.State;

    event BlockProposed(uint256 indexed id, TaikoData_A3.BlockMetadata meta, uint64 blockFee);

    error L1_BLOCK_ID();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_METADATA();
    error L1_TOO_MANY_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData_A3.State storage state,
        TaikoData_A3.Config memory config,
        AddressResolver resolver,
        TaikoData_A3.BlockMetadataInput memory input,
        bytes calldata txList
    ) internal returns (TaikoData_A3.BlockMetadata memory meta) {
        uint8 cacheTxListInfo =
            _validateBlock({state: state, config: config, input: input, txList: txList});

        if (cacheTxListInfo != 0) {
            state.txListInfo[input.txListHash] = TaikoData_A3.TxListInfo({
                validSince: uint64(block.timestamp),
                size: uint24(txList.length)
            });
        }

        // After The Merge, L1 mixHash contains the prevrandao
        // from the beacon chain. Since multiple Taiko blocks
        // can be proposed in one Ethereum block, we need to
        // add salt to this random number as L2 mixHash

        meta.id = state.numBlocks;
        meta.txListHash = input.txListHash;
        meta.txListByteStart = input.txListByteStart;
        meta.txListByteEnd = input.txListByteEnd;
        meta.gasLimit = input.gasLimit;
        meta.beneficiary = input.beneficiary;
        meta.treasury = resolver.resolve(config.chainId, "treasury", false);
        meta.depositsProcessed =
            LibEthDepositing_A3.processDeposits(state, config, input.beneficiary);

        unchecked {
            meta.timestamp = uint64(block.timestamp);
            meta.l1Height = uint64(block.number - 1);
            meta.l1Hash = blockhash(block.number - 1);
            meta.mixHash = bytes32(block.difficulty * state.numBlocks);
        }

        TaikoData_A3.Block storage blk = state.blocks[state.numBlocks % config.ringBufferSize];

        blk.blockId = state.numBlocks;
        blk.proposedAt = meta.timestamp;
        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = 0;
        blk.metaHash = LibUtils_A3.hashMetadata(meta);
        blk.proposer = msg.sender;

        uint64 blockFee = state.blockFee;
        if (state.taikoTokenBalances[msg.sender] < blockFee) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        unchecked {
            state.taikoTokenBalances[msg.sender] -= blockFee;
            state.accBlockFees += blockFee;
            state.accProposedAt += meta.timestamp;
        }

        emit BlockProposed(state.numBlocks, meta, blockFee);
        unchecked {
            ++state.numBlocks;
        }
    }

    function getBlock(
        TaikoData_A3.State storage state,
        TaikoData_A3.Config memory config,
        uint256 blockId
    ) internal view returns (TaikoData_A3.Block storage blk) {
        blk = state.blocks[blockId % config.ringBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();
    }

    function _validateBlock(
        TaikoData_A3.State storage state,
        TaikoData_A3.Config memory config,
        TaikoData_A3.BlockMetadataInput memory input,
        bytes calldata txList
    ) private view returns (uint8 cacheTxListInfo) {
        if (
            input.beneficiary == address(0) || input.gasLimit == 0
                || input.gasLimit > config.blockMaxGasLimit
        ) revert L1_INVALID_METADATA();

        if (state.numBlocks >= state.lastVerifiedBlockId + config.maxNumProposedBlocks + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        uint64 timeNow = uint64(block.timestamp);
        // handling txList
        {
            uint24 size = uint24(txList.length);
            if (size > config.maxBytesPerTxList) revert L1_TX_LIST();

            if (input.txListByteStart > input.txListByteEnd) {
                revert L1_TX_LIST_RANGE();
            }

            if (config.txListCacheExpiry == 0) {
                // caching is disabled
                if (input.txListByteStart != 0 || input.txListByteEnd != size) {
                    revert L1_TX_LIST_RANGE();
                }
            } else {
                // caching is enabled
                if (size == 0) {
                    // This blob shall have been submitted earlier
                    TaikoData_A3.TxListInfo memory info = state.txListInfo[input.txListHash];

                    if (input.txListByteEnd > info.size) {
                        revert L1_TX_LIST_RANGE();
                    }

                    if (info.size == 0 || info.validSince + config.txListCacheExpiry < timeNow) {
                        revert L1_TX_LIST_NOT_EXIST();
                    }
                } else {
                    if (input.txListByteEnd > size) revert L1_TX_LIST_RANGE();
                    if (input.txListHash != keccak256(txList)) {
                        revert L1_TX_LIST_HASH();
                    }

                    cacheTxListInfo = input.cacheTxListInfo;
                }
            }
        }
    }
}
