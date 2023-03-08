// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../TaikoData.sol";

library LibProposing {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockProposed(uint256 indexed id, TaikoData.BlockMetadata meta);

    error L1_GAS_LIMIT();
    error L1_ID();
    error L1_INPUT_SIZE();
    error L1_INSUFFICIENT_TOKEN();
    error L1_METADATA_FIELD();
    error L1_SOLO_PROPOSER();
    error L1_TOO_MANY_BLOCKS();
    error L1_INVALID_PROOF();
    error L1_TX_LIST();

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        bytes[] calldata inputs
    ) internal returns (TaikoData.BlockMetadata memory meta) {
        // For alpha-2 testnet, the network only allows an special address
        // to propose but anyone to prove. This is the first step of testing
        // the tokenomics.

        address soloProposer = resolver.resolve("solo_proposer", true);
        if (soloProposer != address(0) && soloProposer != msg.sender)
            revert L1_SOLO_PROPOSER();

        if (inputs.length != 2) revert L1_INPUT_SIZE();
        // inputs[0]: the block's metadata
        // inputs[1]: the txList (future 4844 blob)

        meta = abi.decode(inputs[0], (TaikoData.BlockMetadata));

        {
            // Validating the metadata
            if (
                meta.id != 0 ||
                meta.l1Height != 0 ||
                meta.l1Hash != 0 ||
                meta.timestamp != 0 ||
                meta.mixHash != 0 ||
                meta.beneficiary == address(0)
            ) revert L1_METADATA_FIELD();

            if (meta.gasLimit > config.blockMaxGasLimit) revert L1_GAS_LIMIT();

            if (
                inputs[1].length > config.maxBytesPerTxList ||
                meta.txListHash != LibUtils.hashTxList(inputs[1])
            ) revert L1_TX_LIST();

            if (
                state.nextBlockId >=
                state.latestVerifiedId + config.maxNumBlocks
            ) revert L1_TOO_MANY_BLOCKS();

            meta.id = state.nextBlockId;
            meta.l1Height = block.number - 1;
            meta.l1Hash = blockhash(block.number - 1);
            meta.timestamp = uint64(block.timestamp);

            // After The Merge, L1 mixHash contains the prevrandao
            // from the beacon chain. Since multiple Taiko blocks
            // can be proposed in one Ethereum block, we need to
            // add salt to this random number as L2 mixHash

            unchecked {
                meta.mixHash = block.prevrandao * state.nextBlockId;
            }
        }

        uint256 deposit;
        if (config.enableTokenomics) {
            uint256 newFeeBase;
            {
                uint256 fee;
                (newFeeBase, fee, deposit) = getBlockFee(state, config);

                uint256 burnAmount = fee + deposit;
                if (state.balances[msg.sender] <= burnAmount)
                    revert L1_INSUFFICIENT_TOKEN();

                state.balances[msg.sender] -= burnAmount;
            }
            // Update feeBase and avgBlockTime
            state.feeBaseSzabo = LibTokenomics.toSzabo(
                LibUtils.movingAverage({
                    maValue: LibTokenomics.fromSzabo(state.feeBaseSzabo),
                    newValue: newFeeBase,
                    maf: config.feeBaseMAF
                })
            );
        }

        state.proposedBlocks[
            state.nextBlockId % config.maxNumBlocks
        ] = TaikoData.ProposedBlock({
            metaHash: LibUtils.hashMetadata(meta),
            deposit: deposit,
            proposer: msg.sender,
            proposedAt: meta.timestamp
        });

        state.avgBlockTime = LibUtils
            .movingAverage({
                maValue: state.avgBlockTime,
                newValue: meta.timestamp - state.lastProposedAt,
                maf: config.blockTimeMAF
            })
            .toUint64();

        state.lastProposedAt = meta.timestamp;

        emit BlockProposed(state.nextBlockId, meta);
        unchecked {
            state.nextBlockId;
        }
    }

    function getBlockFee(
        TaikoData.State storage state,
        TaikoData.Config memory config
    ) internal view returns (uint256 newFeeBase, uint256 fee, uint256 deposit) {
        (newFeeBase, ) = LibTokenomics.getTimeAdjustedFee({
            config: config,
            feeBase: LibTokenomics.fromSzabo(state.feeBaseSzabo),
            isProposal: true,
            tNow: uint64(block.timestamp),
            tLast: state.lastProposedAt,
            tAvg: state.avgBlockTime
        });
        fee = LibTokenomics.getSlotsAdjustedFee({
            state: state,
            config: config,
            isProposal: true,
            feeBase: newFeeBase
        });
        fee = LibTokenomics.getBootstrapDiscountedFee(state, config, fee);
        deposit = (fee * config.proposerDepositPctg) / 100;
    }

    function getProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (TaikoData.ProposedBlock storage) {
        if (id <= state.latestVerifiedId || id >= state.nextBlockId) {
            revert L1_ID();
        }
        return state.getProposedBlock(maxNumBlocks, id);
    }
}
