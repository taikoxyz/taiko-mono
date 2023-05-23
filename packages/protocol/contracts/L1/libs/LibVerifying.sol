// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {ISignalService} from "../../signal/ISignalService.sol";
import {LibUtils} from "./LibUtils.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {TaikoData} from "../../L1/TaikoData.sol";

library LibVerifying {
    using SafeCastUpgradeable for uint256;
    using LibUtils for TaikoData.State;

    event BlockVerified(uint256 indexed id, bytes32 blockHash);

    event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot);

    error L1_INVALID_CONFIG();

    function init(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        bytes32 genesisBlockHash
    ) internal {
        if (
            config.chainId <= 1 || config.maxNumProposedBlocks == 1
                || config.ringBufferSize <= config.maxNumProposedBlocks + 1
                || config.blockMaxGasLimit == 0 || config.maxTransactionsPerBlock == 0
                || config.maxBytesPerTxList == 0
            // EIP-4844 blob size up to 128K
            || config.maxBytesPerTxList > 128 * 1024 || config.maxEthDepositsPerBlock == 0
                || config.maxEthDepositsPerBlock < config.minEthDepositsPerBlock
            // EIP-4844 blob deleted after 30 days
            || config.txListCacheExpiry > 30 * 24 hours || config.ethDepositGas == 0
                || config.ethDepositMaxFee == 0 || config.ethDepositMaxFee >= type(uint96).max
                || config.adjustmentQuotient == 0
        ) revert L1_INVALID_CONFIG();

        uint64 timeNow = uint64(block.timestamp);
        state.genesisHeight = uint64(block.number);
        state.genesisTimestamp = timeNow;

        state.numBlocks = 1;

        TaikoData.Block storage blk = state.blocks[0];
        blk.proposedAt = timeNow;
        blk.nextForkChoiceId = 2;
        blk.verifiedForkChoiceId = 1;

        TaikoData.ForkChoice storage fc = state.blocks[0].forkChoices[1];
        fc.blockHash = genesisBlockHash;
        fc.provenAt = timeNow;

        emit BlockVerified(0, genesisBlockHash);
    }

    function verifyBlocks(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint256 maxBlocks
    ) internal returns (TaikoData.VerifiedBlock[] memory verifiedBlocks) {
        verifiedBlocks = new TaikoData.VerifiedBlock[](config.maxVerificationsPerTx);

        uint256 i = state.lastVerifiedBlockId;
        TaikoData.Block storage blk = state.blocks[i % config.ringBufferSize];

        uint256 fcId = blk.verifiedForkChoiceId;
        assert(fcId > 0);
        bytes32 blockHash = blk.forkChoices[fcId].blockHash;
        uint32 gasUsed = blk.forkChoices[fcId].gasUsed;
        bytes32 signalRoot;

        uint64 processed;
        unchecked {
            ++i;
        }

        address callback = resolver.resolve("callback", true);
        while (i < state.numBlocks && processed < maxBlocks) {
            blk = state.blocks[i % config.ringBufferSize];
            assert(blk.blockId == i);

            fcId = LibUtils.getForkChoiceId(state, blk, blockHash, gasUsed);

            if (fcId == 0) break;

            TaikoData.ForkChoice storage fc = blk.forkChoices[fcId];

            if (fc.prover == address(0)) break;

            uint256 proofCooldownPeriod = fc.prover == address(1)
                ? config.systemProofCooldownPeriod
                : config.proofCooldownPeriod;

            if (block.timestamp < fc.provenAt + proofCooldownPeriod) break;

            blockHash = fc.blockHash;
            gasUsed = fc.gasUsed;
            signalRoot = fc.signalRoot;

            blk.nextForkChoiceId = 1;
            blk.verifiedForkChoiceId = uint24(fcId);

            emit BlockVerified(blk.blockId, fc.blockHash);

            verifiedBlocks[processed] = TaikoData.VerifiedBlock({
                prover: fc.prover,
                proposedAt: blk.proposedAt,
                provenAt: fc.provenAt
            });

            unchecked {
                ++i;
                ++processed;
            }
        }

        assembly {
            mstore(verifiedBlocks, processed)
        }

        if (processed > 0) {
            unchecked {
                state.lastVerifiedBlockId += processed;
            }

            if (config.relaySignalRoot) {
                // Send the L2's signal root to the signal service so other TaikoL1
                // deployments, if they share the same signal service, can relay the
                // signal to their corresponding TaikoL2 contract.
                ISignalService(resolver.resolve("signal_service", false)) //
                    .sendSignal(signalRoot);
            }
            emit CrossChainSynced(state.lastVerifiedBlockId, blockHash, signalRoot);
        }
    }
}
