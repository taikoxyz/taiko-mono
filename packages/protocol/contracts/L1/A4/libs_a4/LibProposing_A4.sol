// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {LibMath} from "../../../libs/LibMath.sol";
import {AddressResolver} from "../../../common/AddressResolver.sol";
import {IMintableERC20} from "../../../common/IMintableERC20.sol";
import {IProverPool} from "../ProverPool_A4.sol";
import {LibAddress} from "../../../libs/LibAddress.sol";
import {LibEthDepositing_A4} from "./LibEthDepositing_A4.sol";
import {LibL2Consts} from "../../../L2/a4/LibL2Consts_A4.sol";
import {LibUtils_A4} from "./LibUtils_A4.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData_A4} from "../TaikoData_A4.sol";

library LibProposing_A4 {
    using LibAddress for address;
    using LibAddress for address payable;
    using LibMath for uint256;
    using LibUtils_A4 for TaikoData_A4.State;
    using SafeCastUpgradeable for uint256;

    event BlockProposed(uint256 indexed id, TaikoData_A4.BlockMetadata meta, uint64 blockFee);

    error L1_BLOCK_ID();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_METADATA();
    error L1_TOO_MANY_BLOCKS();
    error L1_TOO_MANY_OPEN_BLOCKS();
    error L1_TX_LIST_NOT_EXIST();
    error L1_TX_LIST_HASH();
    error L1_TX_LIST_RANGE();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData_A4.State storage state,
        TaikoData_A4.Config memory config,
        AddressResolver resolver,
        TaikoData_A4.BlockMetadataInput memory input,
        bytes calldata txList
    ) internal returns (TaikoData_A4.BlockMetadata memory meta) {
        // Try to select a prover first to revert as earlier as possible
        (address assignedProver, uint32 rewardPerGas) = IProverPool(
            resolver.resolve("prover_pool", false)
        ).assignProver(state.numBlocks, state.feePerGas);

        assert(assignedProver != address(1));

        {
            // Validate block input then cache txList info if requested
            bool cacheTxListInfo =
                _validateBlock({state: state, config: config, input: input, txList: txList});

            if (cacheTxListInfo) {
                unchecked {
                    state.txListInfo[input.txListHash] = TaikoData_A4.TxListInfo({
                        validSince: uint64(block.timestamp),
                        size: uint24(txList.length)
                    });
                }
            }
        }

        // Init the metadata
        meta.id = state.numBlocks;

        unchecked {
            meta.timestamp = uint64(block.timestamp);
            meta.l1Height = uint64(block.number - 1);
            meta.l1Hash = blockhash(block.number - 1);

            // After The Merge, L1 mixHash contains the prevrandao
            // from the beacon chain. Since multiple Taiko blocks
            // can be proposed in one Ethereum block, we need to
            // add salt to this random number as L2 mixHash
            meta.mixHash = bytes32(block.prevrandao * state.numBlocks);
        }

        meta.txListHash = input.txListHash;
        meta.txListByteStart = input.txListByteStart;
        meta.txListByteEnd = input.txListByteEnd;
        meta.gasLimit = input.gasLimit;
        meta.beneficiary = input.beneficiary;
        meta.treasury = resolver.resolve(config.chainId, "treasury", false);
        meta.depositsProcessed =
            LibEthDepositing_A4.processDeposits(state, config, input.beneficiary);

        // Init the block
        TaikoData_A4.Block storage blk = state.blocks[state.numBlocks % config.blockRingBufferSize];

        blk.metaHash = LibUtils_A4.hashMetadata(meta);
        blk.blockId = state.numBlocks;
        blk.gasLimit = meta.gasLimit;
        blk.nextForkChoiceId = 1;
        blk.verifiedForkChoiceId = 0;
        blk.proverReleased = false;

        blk.proposer = msg.sender;
        blk.feePerGas = state.feePerGas;
        blk.proposedAt = meta.timestamp;

        if (assignedProver == address(0)) {
            if (state.numOpenBlocks >= config.rewardOpenMaxCount) {
                revert L1_TOO_MANY_OPEN_BLOCKS();
            }
            blk.rewardPerGas = state.feePerGas;
            ++state.numOpenBlocks;
        } else {
            blk.assignedProver = assignedProver;

            // Cap the reward to a range of [95%, 105%] * blk.feePerGas, if
            // rewardPerGasRange is set to 5% (500 bp)
            uint32 diff = blk.feePerGas * config.rewardPerGasRange / 10_000;
            blk.rewardPerGas = uint32(
                uint256(rewardPerGas).min(state.feePerGas + diff).max(state.feePerGas - diff)
            );

            blk.proofWindow = uint16(
                uint256(state.avgProofDelay * 3).min(config.proofMaxWindow).max(
                    config.proofMinWindow
                )
            );
        }

        uint64 blockFee = getBlockFee(state, config, meta.gasLimit);

        if (state.taikoTokenBalances[msg.sender] < blockFee) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        emit BlockProposed(state.numBlocks, meta, blockFee);

        unchecked {
            ++state.numBlocks;
            state.taikoTokenBalances[msg.sender] -= blockFee;
        }
    }

    function getBlock(
        TaikoData_A4.State storage state,
        TaikoData_A4.Config memory config,
        uint256 blockId
    ) internal view returns (TaikoData_A4.Block storage blk) {
        blk = state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();
    }

    // If auction is tied to gas, we should charge users based on gas as well. At
    // this point gasUsed (in proposeBlock()) is always gasLimit, so use it and
    // in case of differences refund after verification
    function getBlockFee(
        TaikoData_A4.State storage state,
        TaikoData_A4.Config memory config,
        uint32 gasLimit
    ) internal view returns (uint64) {
        // The diff between gasLimit and gasUsed will be redistributed back to
        // the balance of proposer
        return state.feePerGas * (gasLimit + LibL2Consts.ANCHOR_GAS_COST + config.blockFeeBaseGas);
    }

    function _validateBlock(
        TaikoData_A4.State storage state,
        TaikoData_A4.Config memory config,
        TaikoData_A4.BlockMetadataInput memory input,
        bytes calldata txList
    ) private view returns (bool cacheTxListInfo) {
        if (
            input.beneficiary == address(0)
            //
            || input.gasLimit == 0
            //
            || input.gasLimit > config.blockMaxGasLimit
        ) revert L1_INVALID_METADATA();

        if (state.numBlocks >= state.lastVerifiedBlockId + config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        uint64 timeNow = uint64(block.timestamp);
        // handling txList
        {
            uint24 size = uint24(txList.length);
            if (size > config.blockMaxTxListBytes) revert L1_TX_LIST();

            if (input.txListByteStart > input.txListByteEnd) {
                revert L1_TX_LIST_RANGE();
            }

            if (config.blockTxListExpiry == 0) {
                // caching is disabled
                if (input.txListByteStart != 0 || input.txListByteEnd != size) {
                    revert L1_TX_LIST_RANGE();
                }
            } else {
                // caching is enabled
                if (size == 0) {
                    // This blob shall have been submitted earlier
                    TaikoData_A4.TxListInfo memory info = state.txListInfo[input.txListHash];

                    if (input.txListByteEnd > info.size) {
                        revert L1_TX_LIST_RANGE();
                    }

                    if (info.size == 0 || info.validSince + config.blockTxListExpiry < timeNow) {
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
