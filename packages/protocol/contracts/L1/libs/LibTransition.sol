// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IPseProofVerifier } from "../PseProofVerifier.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibTaikoToken } from "./LibTaikoToken.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../../L1/TaikoData.sol";

library LibTransition {
    using LibTaikoToken for TaikoData.State;

    event ProverBondReceived(
        address indexed from, uint64 blockId, uint256 bond
    );
    event ChallengerBondReceived(
        address indexed from, uint64 blockId, uint256 bond
    );

    error L1_INVALID_TIER();
    error L1_TIER_MISMATCH();
    error L1_TRANSITION_NOT_FOUND();
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_ALREADY_PROVEN();
    error L1_ALREADY_CHALLANGED();
    error L1_NOT_CHALLANGED();
    error L1_INVALID_ORACLE_PROVER();
    error L1_NOT_PROVEABLE();
    error L1_TRANSITION_NOT_CHALLENGABLE();

    uint8 public constant TIER_ID_NONE = 0;
    uint8 public constant TIER_ID_1 = 1; // Currently OP
    uint8 public constant TIER_ID_2 = 2; // Currently ZK
    uint8 public constant TIER_ID_GUARDIAN = 3; // Oracle (in the previous
        // naming)

    event TransitionProven(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        address prover,
        uint96 proverbond,
        uint8 tier
    );

    event TransitionChallenged(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        address challenger,
        uint96 challengerBond,
        uint16 tier
    );

    function challenge(
        TaikoData.State storage state,
        TaikoData.TierConfig memory tierConfig,
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.Transition storage tran,
        TaikoData.BlockEvidence memory evidence
    )
        internal
    {
        if (
            evidence.blockHash == tran.blockHash
                && evidence.signalRoot == tran.signalRoot
        ) {
            revert L1_ALREADY_PROVEN();
        }
        // Check if challenged already
        if (tran.challenger != address(0)) revert L1_ALREADY_CHALLANGED();

        // Query the challenging bond
        (, uint96 newBond) = getTierBonds(tierConfig, evidence.tier);

        // If we are at "TIER_ID_GUARDIAN" then not challengeable
        // newBond is 0 if we are at TIER_ID_GUARDIAN
        if (newBond == 0) revert L1_TRANSITION_NOT_CHALLENGABLE();

        // Raise the current tier of the given transition
        if (tran.tier == TIER_ID_GUARDIAN - 1) {
            revert L1_TRANSITION_NOT_CHALLENGABLE();
        }
        tran.tier++;

        tran.challenger = evidence.prover;
        tran.challengerBond = newBond;
        tran.provenAt = 0;
        tran.challengedAt = uint64(block.timestamp);

        emit TransitionChallenged(
            blk.blockId,
            evidence.parentHash,
            tran.blockHash,
            evidence.prover,
            newBond,
            evidence.tier
        );

        if (newBond != 0) {
            state.receiveTaikoToken(resolver, evidence.prover, newBond);
            emit ChallengerBondReceived(evidence.prover, blk.blockId, newBond);
        }
    }

    function proveChallenged(
        TaikoData.State storage state,
        TaikoData.TierConfig memory tierConfig,
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.Transition storage tran,
        TaikoData.BlockEvidence memory evidence
    )
        internal
    {
        if (tran.challenger == address(0)) revert L1_NOT_CHALLANGED();

        if (tran.tier == evidence.tier) revert L1_TIER_MISMATCH();

        // Query the proverBond
        (uint96 newProverBond,) = getTierBonds(tierConfig, evidence.tier);
        uint96 reward = tran.proverBond / 4;
        // We have 2 scenario:
        // 1.: new proof confirms transition
        // 2.: denies the previous transition
        if (
            evidence.blockHash == tran.blockHash
                && evidence.signalRoot == tran.signalRoot
        ) {
            // proving the tran.prover is right
            state.taikoTokenBalances[tran.prover] += tran.proverBond + reward;
        } else {
            // proving the tran.challenger is right
            state.taikoTokenBalances[tran.challenger] +=
                tran.challengerBond + reward;
        }

        // Set respective values. Rest (like signalRoot, blockHash set in the
        // LibProving.sol)
        tran.proverBond = reward + newProverBond;
        tran.challenger = address(0); // keep challengerBond as is
        tran.challengedAt = 0;
        tran.tier = evidence.tier;

        emit TransitionProven(
            blk.blockId,
            evidence.parentHash,
            evidence.blockHash,
            evidence.prover,
            newProverBond,
            evidence.tier
        );

        if (newProverBond != 0) {
            state.receiveTaikoToken(resolver, evidence.prover, newProverBond);
            emit ProverBondReceived(evidence.prover, blk.blockId, newProverBond);
        }
    }

    function getTransition(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        uint64 blockId,
        bytes32 parentHash
    )
        internal
        view
        returns (TaikoData.Transition storage tran)
    {
        TaikoData.SlotB memory b = state.slotB;
        if (blockId < b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];
        if (blk.blockId != blockId) revert L1_BLOCK_MISMATCH();

        uint32 tid = LibUtils.getTransitionId(state, blk, slot, parentHash);
        if (tid == 0) revert L1_TRANSITION_NOT_FOUND();

        tran = state.transitions[slot][tid];
    }

    function getTierBonds(
        TaikoData.TierConfig memory tierConfig,
        uint8 tier
    )
        internal
        pure
        returns (uint96 provingBond, uint96 challangingBond)
    {
        if (tier > TIER_ID_GUARDIAN) {
            revert L1_INVALID_TIER();
        }
        return (
            tierConfig.tierData[tier].proverBond,
            tierConfig.tierData[tier].challengerBond
        );
    }

    function getTierCooldownPeriod(
        TaikoData.TierConfig memory tierConfig,
        uint8 tier
    )
        internal
        pure
        returns (uint256, uint256)
    {
        if (tier > TIER_ID_GUARDIAN) {
            revert L1_INVALID_TIER();
        }
        return (
            tierConfig.tierData[tier].proofRegularCooldown,
            tierConfig.tierData[tier].proofOracleCooldown
        );
    }

    function getTierMinMax() internal pure returns (uint8, uint8) {
        return (TIER_ID_1, TIER_ID_GUARDIAN);
    }

    // Todo: This has to be properly tunable with tier configs (see PR desc.) -
    // fine as is now.
    function getBlockDefaultTierStatus(uint256 rand)
        internal
        pure
        returns (uint8)
    {
        if (rand % 100 == 0) {
            return TIER_ID_2;
        } // 1%
        return TIER_ID_1; // 99%
    }
}
