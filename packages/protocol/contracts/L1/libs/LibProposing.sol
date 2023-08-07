// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { LibMath } from "../../libs/LibMath.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";
import { IMintableERC20 } from "../../common/IMintableERC20.sol";
import { IProverPool } from "../ProverPool.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibEthDepositing } from "./LibEthDepositing.sol";
import { LibUtils } from "./LibUtils.sol";
import { SafeCastUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { TaikoData } from "../TaikoData.sol";

library LibProposing {
    using LibAddress for address;
    using LibAddress for address payable;
    using LibMath for uint256;
    using LibUtils for TaikoData.State;
    using SafeCastUpgradeable for uint256;

    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint32 rewardPerGas,
        uint64 feePerGas,
        TaikoData.BlockMetadata meta
    );

    error L1_BLOCK_ID();
    error L1_INSUFFICIENT_TOKEN();
    error L1_INVALID_METADATA();
    error L1_PERMISSION_DENIED();
    error L1_TOO_MANY_BLOCKS();
    error L1_TOO_MANY_OPEN_BLOCKS();
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
    )
        internal
        returns (TaikoData.BlockMetadata memory meta)
    {
        {
            address proposer = resolver.resolve("proposer", true);
            if (proposer != address(0) && msg.sender != proposer) {
                revert L1_PERMISSION_DENIED();
            }
        }
        // Try to select a prover first to revert as earlier as possible
        (address assignedProver, uint32 rewardPerGas) = IProverPool(
            resolver.resolve("prover_pool", false)
        ).assignProver(state.numBlocks, state.feePerGas);

        assert(assignedProver != address(1));

        {
            // Validate block input then cache txList info if requested
            bool cacheTxListInfo = _validateBlock({
                state: state,
                config: config,
                input: input,
                txList: txList
            });

            if (cacheTxListInfo) {
                unchecked {
                    state.txListInfo[input.txListHash] = TaikoData.TxListInfo({
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
        meta.gasLimit = config.blockMaxGasLimit;
        meta.beneficiary = input.beneficiary;
        meta.treasury = resolver.resolve(config.chainId, "treasury", false);
        meta.depositsProcessed =
            LibEthDepositing.processDeposits(state, config, input.beneficiary);

        // Init the block
        TaikoData.Block storage blk =
            state.blocks[state.numBlocks % config.blockRingBufferSize];

        blk.metaHash = LibUtils.hashMetadata(meta);
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
            blk.rewardPerGas = rewardPerGas;
            uint256 _window = uint256(state.avgProofDelay)
                * config.proofWindowMultiplier / 100;
            blk.proofWindow = uint16(
                _window.min(config.proofMaxWindow).max(config.proofMinWindow)
            );
        }

        uint64 blockFee = LibUtils.getBlockFee(state, config, meta.gasLimit);

        if (state.taikoTokenBalances[msg.sender] < blockFee) {
            revert L1_INSUFFICIENT_TOKEN();
        }

        emit BlockProposed({
            blockId: state.numBlocks,
            assignedProver: blk.assignedProver,
            rewardPerGas: blk.rewardPerGas,
            feePerGas: state.feePerGas,
            meta: meta
        });

        unchecked {
            ++state.numBlocks;
            state.taikoTokenBalances[msg.sender] -= blockFee;
        }
    }

    function getBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 blockId
    )
        internal
        view
        returns (TaikoData.Block storage blk)
    {
        blk = state.blocks[blockId % config.blockRingBufferSize];
        if (blk.blockId != blockId) revert L1_BLOCK_ID();
    }

    function _validateBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.BlockMetadataInput memory input,
        bytes calldata txList
    )
        private
        view
        returns (bool cacheTxListInfo)
    {
        if (input.beneficiary == address(0)) revert L1_INVALID_METADATA();

        if (
            state.numBlocks
                >= state.lastVerifiedBlockId + config.blockMaxProposals + 1
        ) {
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
                    TaikoData.TxListInfo memory info =
                        state.txListInfo[input.txListHash];

                    if (input.txListByteEnd > info.size) {
                        revert L1_TX_LIST_RANGE();
                    }

                    if (
                        info.size == 0
                            || info.validSince + config.blockTxListExpiry < timeNow
                    ) {
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
