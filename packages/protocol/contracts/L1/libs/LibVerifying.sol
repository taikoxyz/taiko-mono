// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {ChainData} from "../../common/IXchainSync.sol";
import {LibTokenomics} from "./LibTokenomics.sol";
import {LibUtils} from "./LibUtils.sol";
import {
    SafeCastUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockVerified(uint256 indexed id, ChainData chainData);
    event XchainSynced(uint256 indexed srcHeight, ChainData chainData);

    function init(
        TaikoData.State storage state,
        bytes32 genesisBlockHash,
        uint64 feeBaseSzabo
    ) internal {
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = uint64(block.timestamp);
        state.feeBaseSzabo = feeBaseSzabo;
        state.nextBlockId = 1;
        state.lastProposedAt = uint64(block.timestamp);

        ChainData memory chainData = ChainData(genesisBlockHash, 0);
        state.l2ChainDatas[0] = chainData;

        emit BlockVerified(0, chainData);
        emit XchainSynced(0, chainData);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 maxBlocks
    ) internal {
        uint64 latestL2Height = state.latestVerifiedHeight;
        ChainData memory latestL2ChainData = state.l2ChainDatas[
            latestL2Height % config.blockHashHistory
        ];

        uint64 processed;
        uint256 i;

        unchecked {
            i = state.latestVerifiedId + 1;
        }
        while (i < state.nextBlockId && processed < maxBlocks) {
            TaikoData.ProposedBlock storage proposal = state.proposedBlocks[
                i % config.maxNumBlocks
            ];

            uint256 fcId = state.forkChoiceIds[i][latestL2ChainData.blockHash];

            if (proposal.nextForkChoiceId <= fcId) {
                break;
            }

            TaikoData.ForkChoice storage fc = state.forkChoices[
                i % config.maxNumBlocks
            ][fcId];

            if (fc.prover == address(0)) {
                break;
            } else {
                (latestL2Height, latestL2ChainData) = _markBlockVerified({
                    state: state,
                    config: config,
                    fc: fc,
                    proposal: proposal,
                    latestL2Height: latestL2Height,
                    latestL2ChainData: latestL2ChainData
                });
                unchecked {
                    processed++;
                }
                emit BlockVerified(i, latestL2ChainData);
            }

            unchecked {
                ++i;
            }
        }

        if (processed > 0) {
            state.latestVerifiedId += processed;

            if (latestL2Height > state.latestVerifiedHeight) {
                state.latestVerifiedHeight = latestL2Height;

                // Note: Not all L2 hashes are stored on L1, only the last
                // verified one in a batch. This is sufficient because the last
                // verified hash is the only one needed checking the existence
                // of a cross-chain message with a merkle proof.
                state.l2ChainDatas[
                    latestL2Height % config.blockHashHistory
                ] = latestL2ChainData;

                emit XchainSynced(latestL2Height, latestL2ChainData);
            }
        }
    }

    function _markBlockVerified(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.ForkChoice storage fc,
        TaikoData.ProposedBlock storage proposal,
        uint64 latestL2Height,
        ChainData memory latestL2ChainData
    )
        private
        returns (uint64 _latestL2Height, ChainData memory _latestL2ChainData)
    {
        if (config.enableTokenomics) {
            uint256 newFeeBase;
            {
                // otherwise: stack too deep
                uint256 reward;
                uint256 tRelBp; // [0-10000], see the whitepaper
                (newFeeBase, reward, tRelBp) = LibTokenomics.getProofReward({
                    state: state,
                    config: config,
                    provenAt: fc.provenAt,
                    proposedAt: proposal.proposedAt
                });

                // reward the prover
                if (reward > 0) {
                    if (state.balances[fc.prover] == 0) {
                        // Reduce reward to 1 wei as a penalty if the prover
                        // has 0 TKO outstanding balance.
                        state.balances[fc.prover] = 1;
                    } else {
                        state.balances[fc.prover] += reward;
                    }
                }

                // refund proposer deposit for valid blocks
                uint256 refund = (proposal.deposit * (10000 - tRelBp)) / 10000;
                if (refund > 0) {
                    if (state.balances[proposal.proposer] == 0) {
                        // Reduce refund to 1 wei as a penalty if the proposer
                        // has 0 TKO outstanding balance.
                        state.balances[proposal.proposer] = 1;
                    } else {
                        state.balances[proposal.proposer] += refund;
                    }
                }
            }
            // Update feeBase and avgProofTime
            state.feeBaseSzabo = LibTokenomics.toSzabo(
                LibUtils.movingAverage({
                    maValue: LibTokenomics.fromSzabo(state.feeBaseSzabo),
                    newValue: newFeeBase,
                    maf: config.feeBaseMAF
                })
            );
        }

        state.avgProofTime = LibUtils
            .movingAverage({
                maValue: state.avgProofTime,
                newValue: fc.provenAt - proposal.proposedAt,
                maf: config.proofTimeMAF
            })
            .toUint64();

        if (fc.chainData.blockHash != latestL2ChainData.blockHash) {
            // valid block
            unchecked {
                _latestL2Height = latestL2Height + 1;
            }
            _latestL2ChainData = fc.chainData;
        }

        proposal.nextForkChoiceId = 1;

        // Clean up the fork choice but keep non-zeros if possible to be
        // reused.
        unchecked {
            fc.chainData.blockHash = bytes32(uint256(1)); // none-zero placeholder
            fc.chainData.signalRoot = bytes32(uint256(1)); // none-zero placeholder
            fc.provenAt = 1; // none-zero placeholder
            fc.prover = address(0);
        }
    }
}
