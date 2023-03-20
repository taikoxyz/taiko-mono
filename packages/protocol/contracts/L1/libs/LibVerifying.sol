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

    error L1_INVALID_CONFIG();

    event BlockVerified(uint256 indexed id, bytes32 blockHash);
    event XchainSynced(uint256 indexed srcHeight, ChainData chainData);

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash,
        uint64 feeBaseTwei
    ) internal {
        _checkConfig(config);

        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = uint64(block.timestamp);
        state.feeBaseTwei = feeBaseTwei;
        state.nextBlockId = 1;

        ChainData memory chainData = ChainData(genesisBlockHash, 0);
        state.l2ChainDatas[0] = chainData;

        emit BlockVerified(0, genesisBlockHash);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 maxBlocks
    ) internal {
        ChainData memory chainData = state.l2ChainDatas[
            state.lastBlockId % config.blockHashHistory
        ];

        uint64 processed;
        uint256 i;
        unchecked {
            i = state.lastBlockId + 1;
        }

        while (i < state.nextBlockId && processed < maxBlocks) {
            TaikoData.ProposedBlock storage proposal = state.proposedBlocks[
                i % config.maxNumBlocks
            ];

            uint256 fcId = state.forkChoiceIds[i][chainData.blockHash];

            if (proposal.nextForkChoiceId <= fcId) {
                break;
            }

            TaikoData.ForkChoice storage fc = state.forkChoices[
                i % config.maxNumBlocks
            ][fcId];

            if (fc.prover == address(0)) {
                break;
            }

            chainData = _markBlockVerified({
                state: state,
                config: config,
                fc: fc,
                proposal: proposal
            });

            emit BlockVerified(i, chainData.blockHash);

            unchecked {
                ++i;
                ++processed;
            }
        }

        if (processed > 0) {
            unchecked {
                state.lastBlockId += processed;
            }

            // Note: Not all L2 hashes are stored on L1, only the last
            // verified one in a batch. This is sufficient because the last
            // verified hash is the only one needed checking the existence
            // of a cross-chain message with a merkle proof.
            state.l2ChainDatas[
                state.lastBlockId % config.blockHashHistory
            ] = chainData;

            emit XchainSynced(state.lastBlockId, chainData);
        }
    }

    function _markBlockVerified(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.ForkChoice storage fc,
        TaikoData.ProposedBlock storage proposal
    ) private returns (ChainData memory chainData) {
        if (config.enableTokenomics) {
            (uint256 newFeeBase, uint256 amount, uint256 tRelBp) = LibTokenomics
                .getProofReward({
                    state: state,
                    config: config,
                    provenAt: fc.provenAt,
                    proposedAt: proposal.proposedAt
                });

            // reward the prover
            if (amount > 0) {
                if (state.balances[fc.prover] == 0) {
                    // Reduce reward to 1 wei as a penalty if the prover
                    // has 0 TKO outstanding balance.
                    state.balances[fc.prover] = 1;
                } else {
                    state.balances[fc.prover] += amount;
                }
            }

            // refund proposer deposit for valid blocks
            unchecked {
                // tRelBp in [0-10000]
                amount = (proposal.deposit * (10000 - tRelBp)) / 10000;
            }
            if (amount > 0) {
                if (state.balances[proposal.proposer] == 0) {
                    // Reduce refund to 1 wei as a penalty if the proposer
                    // has 0 TKO outstanding balance.
                    state.balances[proposal.proposer] = 1;
                } else {
                    state.balances[proposal.proposer] += amount;
                }
            }

            // Update feeBase and avgProofTime
            state.feeBaseTwei = LibUtils
                .movingAverage({
                    maValue: state.feeBaseTwei,
                    newValue: LibTokenomics.toTwei(newFeeBase),
                    maf: config.feeBaseMAF
                })
                .toUint64();
        }

        uint proofTime;
        unchecked {
            proofTime = (fc.provenAt - proposal.proposedAt) * 1000;
        }
        state.avgProofTime = LibUtils
            .movingAverage({
                maValue: state.avgProofTime,
                newValue: proofTime,
                maf: config.provingConfig.avgTimeMAF
            })
            .toUint64();

        chainData = fc.chainData;
        proposal.nextForkChoiceId = 1;

        // Clean up the fork choice but keep non-zeros if possible to be
        // reused.
        fc.chainData.blockHash = bytes32(uint256(1)); // none-zero placeholder
        fc.chainData.signalRoot = bytes32(uint256(1)); // none-zero placeholder
        fc.provenAt = 1; // none-zero placeholder
        fc.prover = address(0);
    }

    function _checkConfig(TaikoData.Config memory config) private pure {
        if (
            config.chainId <= 1 ||
            config.maxNumBlocks <= 1 ||
            config.blockHashHistory == 0 ||
            config.blockMaxGasLimit == 0 ||
            config.maxTransactionsPerBlock == 0 ||
            config.maxBytesPerTxList == 0 ||
            // EIP-4844 blob size up to 128K
            config.maxBytesPerTxList > 128 * 1024 ||
            config.minTxGasLimit == 0 ||
            config.slotSmoothingFactor == 0 ||
            config.anchorTxGasLimit == 0 ||
            // EIP-4844 blob deleted after 30 days
            config.txListCacheExpiry > 30 * 24 hours ||
            config.rewardBurnBips >= 10000
        ) revert L1_INVALID_CONFIG();

        _checkFeeConfig(config.proposingConfig);
        _checkFeeConfig(config.provingConfig);
    }

    function _checkFeeConfig(
        TaikoData.FeeConfig memory feeConfig
    ) private pure {
        if (
            feeConfig.avgTimeMAF <= 1 ||
            feeConfig.avgTimeCap == 0 ||
            feeConfig.gracePeriodPctg > feeConfig.maxPeriodPctg
        ) revert L1_INVALID_CONFIG();
    }
}
