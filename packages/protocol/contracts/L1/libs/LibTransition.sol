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

    event BondReceived(address indexed from, uint64 blockId, uint256 bond);

    error L1_TIER_INVALID();
    error L1_TRANSITION_NOT_FOUND();
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_ALREADY_PROVEN();
    error L1_ALREADY_CHALLANGED();
    error L1_NOT_CHALLANGED();
    error L1_INVALID_ORACLE_PROVER();
    error L1_NOT_PROVEABLE();
    error L1_TRANSITION_NOT_CHALLENGABLE();

    uint16 public constant TIER_OPTIMISTIC = 10;
    uint16 public constant TIER_PSE_ZKEVM = 30;
    uint16 public constant TIER_ORACLE = 100;

    uint8 public constant TIER_ID_OPTIMISTIC = 1;
    uint8 public constant TIER_ID_PSE_ZKEVM = 2;
    uint8 public constant TIER_ID_ORACLE = 3;

    event TransitionProven(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        address prover,
        uint96 proverbond,
        uint16 tier
    );

    event TransitionChallenged(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        address challenger,
        uint96 challengerBond,
        uint16 tier
    );

    function applyEvidence(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.Transition storage tran,
        TaikoData.BlockEvidence memory evidence
    )
        internal
        returns (bool isProving)
    {
        uint96 newBond;

        if (tran.tier == 0) {
            // This is the first transition for this parentHash
            isProving = true;
            (newBond,) = getTierBonds(evidence.tier);

            tran.prover = evidence.prover;
            tran.proverBond = newBond;
            tran.challenger = address(0); // keep challengerBond as is
            tran.provenAt = uint64(block.timestamp);
            tran.challengedAt = 0;
            tran.tier = evidence.tier;
        } else if (evidence.tier == tran.tier) {
            if (
                evidence.blockHash == tran.blockHash
                    && evidence.signalRoot == tran.signalRoot
            ) {
                revert L1_ALREADY_PROVEN();
            }

            if (tran.challenger != address(0)) revert L1_ALREADY_CHALLANGED();

            (, newBond) = getTierBonds(tran.tier);

            if (newBond == 0) revert L1_TRANSITION_NOT_CHALLENGABLE();

            tran.challenger = evidence.prover;
            tran.challengerBond = newBond;
            tran.provenAt = 0;
            tran.challengedAt = uint64(block.timestamp);
        } else if (
            evidence.blockHash == tran.blockHash
                && evidence.signalRoot == tran.signalRoot
        ) {
            if (tran.challenger == address(0)) revert L1_NOT_CHALLANGED();

            isProving = true;
            (newBond,) = getTierBonds(evidence.tier);

            uint96 reward = tran.challengerBond / 4;

            // proving the tran.prover is right
            state.taikoTokenBalances[tran.prover] += tran.proverBond + reward;

            tran.prover = evidence.prover;
            tran.proverBond = newBond + reward;

            tran.challenger = address(0); // keep challengerBond as is

            tran.tier = evidence.tier;
        } else {
            isProving = true;
            (newBond,) = getTierBonds(evidence.tier);

            uint96 reward;
            if (tran.challenger != address(0)) {
                // proving the tran.challenger is right
                reward = tran.proverBond / 4;
                state.taikoTokenBalances[tran.challenger] +=
                    tran.challengerBond + reward;
            } else {
                // prove evidence.prover is right
                reward = tran.proverBond;
            }

            tran.prover = evidence.prover;
            tran.proverBond = reward + newBond;
            tran.challenger = address(0); // keep challengerBond as is
            tran.challengedAt = tran.provenAt;
            tran.tier = evidence.tier;
        }

        if (isProving) {
            tran.blockHash = evidence.blockHash;
            tran.signalRoot = evidence.signalRoot;
            tran.provenAt = uint64(block.timestamp);

            emit TransitionProven(
                blk.blockId,
                evidence.parentHash,
                evidence.blockHash,
                evidence.prover,
                newBond,
                evidence.tier
            );
        } else {
            emit TransitionChallenged(
                blk.blockId,
                evidence.parentHash,
                tran.blockHash,
                evidence.prover,
                newBond,
                evidence.tier
            );
        }

        if (newBond != 0) {
            state.receiveTaikoToken(resolver, evidence.prover, newBond);
            emit BondReceived(evidence.prover, blk.blockId, newBond);
        }
    }


    function challange(
        TaikoData.State storage state,
        AddressResolver resolver,
        TaikoData.Block storage blk,
        TaikoData.Transition storage tran,
        TaikoData.BlockEvidence memory evidence
    )
        internal
    {
        if (tran.challenger != address(0)) revert L1_ALREADY_CHALLANGED();

        (, uint96 newBond) = getTierBonds(evidence.tier);

        if (newBond == 0) revert L1_TRANSITION_NOT_CHALLENGABLE();

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
            emit BondReceived(evidence.prover, blk.blockId, newBond);
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

    function isTransitionRegisteredAlready(
        TaikoData.State storage state,
        uint64 slot,
        bytes32 blockHash,
        bytes32 signalRoot
    )
        internal
        view
        returns (bool registered)
    {
        TaikoData.Block memory blk = state.blocks[slot];

        // Todo: Most probably we cannot go with it - best to have a separate mapping
        // checking this but for now is OK.
        for(uint32 i; i < blk.nextTransitionId; i++) {
            if (state.transitions[slot][i].blockHash == blockHash &&
            state.transitions[slot][i].signalRoot == signalRoot) {
                registered = true;
            }
        }
    }

    function getTierBonds(uint16 tier)
        internal
        pure
        returns (uint96 provingBond, uint96 challangingBond)
    {
        if (tier == TIER_ID_OPTIMISTIC) return (10_000 ether, 10_000 ether);
        if (tier == TIER_ID_PSE_ZKEVM) return (0, 20_000 ether);
        if (tier == TIER_ID_ORACLE) return (0, 0 /* note allowed */ );
        revert L1_TIER_INVALID();
    }

    function getTierCooldownPeriod(uint16 tier)
        internal
        pure
        returns (uint256)
    {
        if (tier == TIER_ID_OPTIMISTIC) return 4 hours;
        if (tier == TIER_ID_PSE_ZKEVM) return 30 minutes;
        if (tier == TIER_ID_ORACLE) return 15 minutes;
        revert L1_TIER_INVALID();
    }

    function getTierMinMax()
        internal
        pure
        returns (uint16 currentTier, uint16 maxTier)
    {
        return (TIER_ID_OPTIMISTIC, TIER_ID_ORACLE);
    }

    function getBlockDefaultTier(uint256 rand) internal pure returns (uint16) {
        if (rand % 100 == 0) return TIER_ID_PSE_ZKEVM; // 1%
        return TIER_ID_OPTIMISTIC; // 99%
    }
}
