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
import {TaikoData} from "../../L1/TaikoData.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    error L1_INVALID_CONFIG();

    event BlockVerified(uint256 indexed id, bytes32 blockHash);
    event XchainSynced(
        uint256 indexed srcHeight,
        bytes32 blockHash,
        bytes32 signalRoot
    );

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
        state.numBlocks = 1;

        state.verifiedBlocks[0].blockHash = genesisBlockHash;

        emit BlockVerified(0, genesisBlockHash);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint256 maxBlocks
    ) internal {
        bytes32 blockHash = state
            .verifiedBlocks[
                state.lastVerifiedBlockId % config.maxNumVerifiedBlocks
            ]
            .blockHash;

        bytes32 signalRoot;
        uint64 processed;
        uint256 i;
        unchecked {
            i = state.lastVerifiedBlockId + 1;
        }

        while (i < state.numBlocks && processed < maxBlocks) {
            TaikoData.ProposedBlock storage blk = state.proposedBlocks[
                i % config.maxNumProposedBlocks
            ];

            uint256 fcId = state.forkChoiceIds[i][blockHash];

            if (fcId == 0) {
                break;
            }

            TaikoData.ForkChoice storage fc = blk.forkChoices[fcId];

            if (fc.prover == address(0)) {
                break;
            }

            (blockHash, signalRoot) = _markBlockVerified({
                state: state,
                config: config,
                fc: fc,
                blk: blk
            });

            emit BlockVerified(i, blockHash);

            unchecked {
                ++i;
                ++processed;
            }
        }

        if (processed > 0) {
            unchecked {
                state.lastVerifiedBlockId += processed;
            }

            // Note: Not all L2 hashes are stored on L1, only the last
            // verified one in a batch. This is sufficient because the last
            // verified hash is the only one needed checking the existence
            // of a cross-chain message with a merkle proof.
            state.verifiedBlocks[
                state.lastVerifiedBlockId % config.maxNumVerifiedBlocks
            ] = TaikoData.VerifiedBlock(
                state.lastVerifiedBlockId,
                blockHash,
                signalRoot
            );

            emit XchainSynced(state.lastVerifiedBlockId, blockHash, signalRoot);
        }
    }

    function _markBlockVerified(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        TaikoData.ForkChoice storage fc,
        TaikoData.ProposedBlock storage blk
    ) private returns (bytes32 blockHash, bytes32 signalRoot) {
        if (config.enableTokenomics) {
            (
                uint256 newFeeBase,
                uint256 amount,
                uint256 premiumRate
            ) = LibTokenomics.getProofReward({
                    state: state,
                    config: config,
                    provenAt: fc.provenAt,
                    proposedAt: blk.proposedAt
                });

            // reward the prover
            _addToBalance(state, fc.prover, amount);

            unchecked {
                // premiumRate in [0-10000]
                amount = (blk.deposit * (10000 - premiumRate)) / 10000;
            }
            _addToBalance(state, blk.proposer, amount);

            // Update feeBase and avgProofTime
            state.feeBaseTwei = LibUtils
                .movingAverage({
                    maValue: state.feeBaseTwei,
                    newValue: LibTokenomics.toTwei(newFeeBase),
                    maf: config.feeBaseMAF
                })
                .toUint64();
        }

        uint256 proofTime;
        unchecked {
            proofTime = (fc.provenAt - blk.proposedAt) * 1000;
        }
        state.avgProofTime = LibUtils
            .movingAverage({
                maValue: state.avgProofTime,
                newValue: proofTime,
                maf: config.provingConfig.avgTimeMAF
            })
            .toUint64();

        blockHash = fc.blockHash;
        signalRoot = fc.signalRoot;

        blk.nextForkChoiceId = 1;

        // Clean up the fork choice but keep non-zeros if possible to be
        // reused.
        fc.blockHash = bytes32(uint256(1)); // none-zero placeholder
        fc.signalRoot = bytes32(uint256(1)); // none-zero placeholder
        fc.provenAt = 1; // none-zero placeholder
        fc.prover = address(0);
    }

    function _addToBalance(
        TaikoData.State storage state,
        address account,
        uint256 amount
    ) private {
        if (amount == 0) return;
        if (state.balances[account] == 0) {
            // Reduce refund to 1 wei as a penalty if the proposer
            // has 0 TKO outstanding balance.
            state.balances[account] = 1;
        } else {
            state.balances[account] += amount;
        }
    }

    function _checkConfig(TaikoData.Config memory config) private pure {
        if (
            config.chainId <= 1 ||
            config.maxNumProposedBlocks <= 1 ||
            config.maxNumVerifiedBlocks == 0 ||
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
        if (feeConfig.avgTimeMAF <= 1 || feeConfig.startBips > 10000)
            revert L1_INVALID_CONFIG();
    }
}
