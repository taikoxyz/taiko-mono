// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "../../libs/LibTxDecoder.sol";
import "../TkoToken.sol";
import "./LibUtils.sol";

/// @author dantaik <dan@taiko.xyz>
library LibProposing {
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.BlockMetadata;
    using LibUtils for TaikoData.State;

    event BlockCommitted(
        uint64 commitSlot,
        uint64 commitHeight,
        bytes32 commitHash
    );
    event BlockProposed(uint256 indexed id, TaikoData.BlockMetadata meta);

    function commitBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 commitSlot,
        bytes32 commitHash
    ) public {
        assert(config.commitConfirmations > 0);
        // It's OK to allow committing block when the system is halt.
        // By not checking the halt status, this method will be cheaper.
        //
        // assert(!LibUtils.isHalted(state));

        bytes32 hash = _aggregateCommitHash(block.number, commitHash);

        require(state.commits[msg.sender][commitSlot] != hash, "L1:committed");
        state.commits[msg.sender][commitSlot] = hash;

        emit BlockCommitted({
            commitSlot: commitSlot,
            commitHeight: uint64(block.number),
            commitHash: commitHash
        });
    }

    function proposeBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        bytes[] calldata inputs
    ) public {
        // For alpha-2 testnet, the network only allows an special address
        // to propose but anyone to prove. This is the first step of testing
        // the tokenomics.

        // TODO(daniel): remove this special address.
        address soloProposer = resolver.resolve("solo_proposer", true);
        require(
            soloProposer == address(0) || soloProposer == msg.sender,
            "L1:soloProposer"
        );

        assert(!LibUtils.isHalted(state));

        require(inputs.length == 2, "L1:inputs:size");
        TaikoData.BlockMetadata memory meta = abi.decode(
            inputs[0],
            (TaikoData.BlockMetadata)
        );
        _verifyBlockCommit({
            state: state,
            commitConfirmations: config.commitConfirmations,
            meta: meta
        });
        _validateMetadata(config, meta);

        {
            bytes calldata txList = inputs[1];
            // perform validation and populate some fields
            require(
                txList.length >= 0 &&
                    txList.length <= config.maxBytesPerTxList &&
                    meta.txListHash == txList.hashTxList(),
                "L1:txList"
            );

            require(
                state.nextBlockId <
                    state.latestVerifiedId + config.maxNumBlocks,
                "L1:tooMany"
            );

            meta.id = state.nextBlockId;
            meta.l1Height = block.number - 1;
            meta.l1Hash = blockhash(block.number - 1);
            meta.timestamp = uint64(block.timestamp);

            // if multiple L2 blocks included in the same L1 block,
            // their block.mixHash fields for randomness will be the same.
            meta.mixHash = bytes32(block.difficulty);
        }

        uint256 deposit;
        if (config.enableTokenomics) {
            uint256 newFeeBase;
            {
                uint256 fee;
                (newFeeBase, fee, deposit) = getBlockFee(state, config);
                TkoToken(resolver.resolve("tko_token", false)).burn(
                    msg.sender,
                    fee + deposit
                );
            }
            // Update feeBase and avgBlockTime
            state.feeBase = LibUtils.movingAverage({
                maValue: state.feeBase,
                newValue: newFeeBase,
                maf: config.feeBaseMAF
            });
        }

        _saveProposedBlock(
            state,
            config.maxNumBlocks,
            state.nextBlockId,
            TaikoData.ProposedBlock({
                metaHash: meta.hashMetadata(),
                deposit: deposit,
                proposer: msg.sender,
                proposedAt: meta.timestamp
            })
        );

        state.avgBlockTime = LibUtils
            .movingAverage({
                maValue: state.avgBlockTime,
                newValue: meta.timestamp - state.lastProposedAt,
                maf: config.blockTimeMAF
            })
            .toUint64();

        state.lastProposedAt = meta.timestamp;

        emit BlockProposed(state.nextBlockId++, meta);
    }

    function getBlockFee(
        TaikoData.State storage state,
        TaikoData.Config memory config
    ) public view returns (uint256 newFeeBase, uint256 fee, uint256 deposit) {
        (newFeeBase, ) = LibUtils.getTimeAdjustedFee({
            state: state,
            config: config,
            isProposal: true,
            tNow: uint64(block.timestamp),
            tLast: state.lastProposedAt,
            tAvg: state.avgBlockTime
        });
        fee = LibUtils.getSlotsAdjustedFee({
            state: state,
            config: config,
            isProposal: true,
            feeBase: newFeeBase
        });
        fee = LibUtils.getBootstrapDiscountedFee(state, config, fee);
        deposit = (fee * config.proposerDepositPctg) / 100;
    }

    function isCommitValid(
        TaikoData.State storage state,
        uint256 commitConfirmations,
        uint256 commitSlot,
        uint256 commitHeight,
        bytes32 commitHash
    ) public view returns (bool) {
        assert(commitConfirmations > 0);
        bytes32 hash = _aggregateCommitHash(commitHeight, commitHash);
        return
            state.commits[msg.sender][commitSlot] == hash &&
            block.number >= commitHeight + commitConfirmations;
    }

    function getProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (TaikoData.ProposedBlock storage) {
        require(id > state.latestVerifiedId && id < state.nextBlockId, "L1:id");
        return state.getProposedBlock(maxNumBlocks, id);
    }

    function _saveProposedBlock(
        TaikoData.State storage state,
        uint256 maxNumBlocks,
        uint256 id,
        TaikoData.ProposedBlock memory blk
    ) private {
        state.proposedBlocks[id % maxNumBlocks] = blk;
    }

    function _verifyBlockCommit(
        TaikoData.State storage state,
        uint256 commitConfirmations,
        TaikoData.BlockMetadata memory meta
    ) private {
        if (commitConfirmations == 0) {
            return;
        }
        bytes32 commitHash = _calculateCommitHash(
            meta.beneficiary,
            meta.txListHash
        );

        require(
            isCommitValid({
                state: state,
                commitConfirmations: commitConfirmations,
                commitSlot: meta.commitSlot,
                commitHeight: meta.commitHeight,
                commitHash: commitHash
            }),
            "L1:notCommitted"
        );

        if (meta.commitSlot == 0) {
            // Special handling of slot 0 for refund; non-zero slots
            // are supposed to managed by node software for reuse.
            delete state.commits[msg.sender][meta.commitSlot];
        }
    }

    function _validateMetadata(
        TaikoData.Config memory config,
        TaikoData.BlockMetadata memory meta
    ) private pure {
        require(
            meta.id == 0 &&
                meta.l1Height == 0 &&
                meta.l1Hash == 0 &&
                meta.mixHash == 0 &&
                meta.timestamp == 0 &&
                meta.beneficiary != address(0) &&
                meta.txListHash != 0,
            "L1:placeholder"
        );

        require(meta.gasLimit <= config.blockMaxGasLimit, "L1:gasLimit");
        require(meta.extraData.length <= 32, "L1:extraData");
    }

    function _calculateCommitHash(
        address beneficiary,
        bytes32 txListHash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(beneficiary, txListHash));
    }

    function _aggregateCommitHash(
        uint256 commitHeight,
        bytes32 commitHash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(commitHash, commitHeight));
    }
}
