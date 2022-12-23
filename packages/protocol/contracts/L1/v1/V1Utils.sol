// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../../libs/LibMath.sol";
import "../LibData.sol";

/// @author dantaik <dan@taiko.xyz>
library V1Utils {
    using LibMath for uint256;

    uint64 public constant MASK_HALT = 1 << 0;

    bytes32 public constant BLOCK_DEADEND_HASH = bytes32(uint256(1));

    event WhitelistingEnabled(bool whitelistProposers, bool whitelistProvers);
    event ProposerWhitelisted(address indexed proposer, bool whitelisted);
    event ProverWhitelisted(address indexed prover, bool whitelisted);
    event Halted(bool halted);

    function saveProposedBlock(
        LibData.State storage state,
        uint256 maxNumBlocks,
        uint256 id,
        LibData.ProposedBlock memory blk
    ) internal {
        state.proposedBlocks[id % maxNumBlocks] = blk;
    }

    function enableWhitelisting(
        LibData.TentativeState storage tentative,
        bool whitelistProposers,
        bool whitelistProvers
    ) internal {
        tentative.whitelistProposers = whitelistProvers;
        tentative.whitelistProvers = whitelistProvers;
        emit WhitelistingEnabled(whitelistProposers, whitelistProvers);
    }

    function whitelistProposer(
        LibData.TentativeState storage tentative,
        address proposer,
        bool whitelisted
    ) internal {
        assert(tentative.whitelistProposers);
        require(
            proposer != address(0) &&
                tentative.proposers[proposer] != whitelisted,
            "L1:precondition"
        );

        tentative.proposers[proposer] = whitelisted;
        emit ProposerWhitelisted(proposer, whitelisted);
    }

    function whitelistProver(
        LibData.TentativeState storage tentative,
        address prover,
        bool whitelisted
    ) internal {
        assert(tentative.whitelistProvers);
        require(
            prover != address(0) && tentative.provers[prover] != whitelisted,
            "L1:precondition"
        );

        tentative.provers[prover] = whitelisted;
        emit ProverWhitelisted(prover, whitelisted);
    }

    function halt(LibData.State storage state, bool toHalt) internal {
        require(isHalted(state) != toHalt, "L1:precondition");
        setBit(state, MASK_HALT, toHalt);
        emit Halted(toHalt);
    }

    function getProposedBlock(
        LibData.State storage state,
        uint256 maxNumBlocks,
        uint256 id
    ) internal view returns (LibData.ProposedBlock storage) {
        return state.proposedBlocks[id % maxNumBlocks];
    }

    function getL2BlockHash(
        LibData.State storage state,
        uint256 number
    ) internal view returns (bytes32) {
        require(number <= state.latestVerifiedHeight, "L1:id");
        return state.l2Hashes[number];
    }

    function getStateVariables(
        LibData.State storage state
    )
        internal
        view
        returns (
            uint64 genesisHeight,
            uint64 latestVerifiedHeight,
            uint64 latestVerifiedId,
            uint64 nextBlockId
        )
    {
        genesisHeight = state.genesisHeight;
        latestVerifiedHeight = state.latestVerifiedHeight;
        latestVerifiedId = state.latestVerifiedId;
        nextBlockId = state.nextBlockId;
    }

    function isHalted(
        LibData.State storage state
    ) internal view returns (bool) {
        return isBitOne(state, MASK_HALT);
    }

    function isProposerWhitelisted(
        LibData.TentativeState storage tentative,
        address proposer
    ) internal view returns (bool) {
        assert(tentative.whitelistProposers);
        return tentative.proposers[proposer];
    }

    function isProverWhitelisted(
        LibData.TentativeState storage tentative,
        address prover
    ) internal view returns (bool) {
        assert(tentative.whitelistProvers);
        return tentative.provers[prover];
    }

    // Implement "Incentive Multipliers", see the whitepaper.
    function getTimeAdjustedFee(
        LibData.State storage state,
        LibData.Config memory config,
        bool isProposal,
        uint64 tNow,
        uint64 tLast,
        uint64 tAvg
    ) internal view returns (uint256 newFeeBase, uint256 tRelBp) {
        if (tAvg == 0) {
            newFeeBase = state.feeBase;
            tRelBp = 0;
        } else {
            uint256 _tAvg = tAvg > config.proofTimeCap
                ? config.proofTimeCap
                : tAvg;
            uint256 tGrace = (config.feeGracePeriodPctg * _tAvg) / 100;
            uint256 tMax = (config.feeMaxPeriodPctg * _tAvg) / 100;
            uint256 a = tLast + tGrace;
            uint256 b = tNow > a ? tNow - a : 0;
            tRelBp = (b.min(tMax) * 10000) / tMax; // [0 - 10000]
            uint256 alpha = 10000 +
                ((config.rewardMultiplierPctg - 100) * tRelBp) /
                100;
            if (isProposal) {
                newFeeBase = (state.feeBase * 10000) / alpha; // fee
            } else {
                newFeeBase = (state.feeBase * alpha) / 10000; // reward
            }
        }
    }

    // Implement "Slot-availability Multipliers", see the whitepaper.
    function getSlotsAdjustedFee(
        LibData.State storage state,
        LibData.Config memory config,
        bool isProposal,
        uint256 feeBase
    ) internal view returns (uint256) {
        // m is the `n'` in the whitepaper
        uint256 m = config.maxNumBlocks - 1 + config.feePremiumLamda;
        // n is the number of unverified blocks
        uint256 n = state.nextBlockId - state.latestVerifiedId - 1;
        // k is `m − n + 1` or `m − n - 1`in the whitepaper
        uint256 k = isProposal ? m - n - 1 : m - n + 1;
        return (feeBase * (m - 1) * m) / (m - n) / k;
    }

    // Implement "Bootstrap Discount Multipliers", see the whitepaper.
    function getBootstrapDiscountedFee(
        LibData.State storage state,
        LibData.Config memory config,
        uint256 feeBase
    ) internal view returns (uint256) {
        uint256 halves = uint256(block.timestamp - state.genesisTimestamp) /
            config.boostrapDiscountHalvingPeriod;
        uint256 gamma = 1024 - (1024 >> halves);
        return (feeBase * gamma) / 1024;
    }

    // Returns a deterministic deadline for uncle proof submission.
    function uncleProofDeadline(
        LibData.State storage state,
        LibData.Config memory config,
        LibData.ForkChoice storage fc,
        uint256 blockId
    ) internal view returns (uint64) {
        if (blockId <= 2 * config.maxNumBlocks) {
            return fc.provenAt + config.initialUncleDelay;
        } else {
            return fc.provenAt + state.avgProofTime;
        }
    }

    function hashMetadata(
        LibData.BlockMetadata memory meta
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(meta));
    }

    function movingAverage(
        uint256 maValue,
        uint256 newValue,
        uint256 maf
    ) internal pure returns (uint256) {
        if (maValue == 0) {
            return newValue;
        }
        uint256 _ma = (maValue * (maf - 1) + newValue) / maf;
        return _ma > 0 ? _ma : maValue;
    }

    function setBit(
        LibData.State storage state,
        uint64 mask,
        bool one
    ) private {
        state.statusBits = one
            ? state.statusBits | mask
            : state.statusBits & ~mask;
    }

    function isBitOne(
        LibData.State storage state,
        uint64 mask
    ) private view returns (bool) {
        return state.statusBits & mask != 0;
    }
}
