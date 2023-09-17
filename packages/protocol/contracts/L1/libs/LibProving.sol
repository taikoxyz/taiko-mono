// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IEvidenceVerifier } from "../verifiers/IEvidenceVerifier.sol";
import { LibMath } from "../../libs/LibMath.sol";
import { LibTiers } from "./LibTiers.sol";
import { LibUtils } from "./LibUtils.sol";
import { TaikoData } from "../TaikoData.sol";
import { TaikoToken } from ".././TaikoToken.sol";

library LibProving {
    using LibMath for uint256;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    event Proved(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address prover,
        uint96 proofBond,
        uint16 tier
    );

    event Contested(
        uint256 indexed blockId,
        bytes32 parentHash,
        bytes32 blockHash,
        bytes32 signalRoot,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_ALREADY_CONTESTED();
    error L1_ALREADY_PROVED();
    error L1_ASSIGNED_PROVER_NOT_ALLOWED();
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_EVIDENCE();
    error L1_INVALID_TIER();
    error L1_NOT_ASSIGNED_PROVER();
    error L1_NOT_CONTESTABLE();

    /// @dev Proves or contests a block transition.
    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        uint64 blockId,
        TaikoData.BlockEvidence memory evidence
    )
        internal
    {
        // Make sure parentHash is not zero
        if (evidence.parentHash == 0) revert L1_INVALID_EVIDENCE();

        // Check that the block has been proposed but has not yet been verified.
        TaikoData.SlotB memory b = state.slotB;
        if (blockId <= b.lastVerifiedBlockId || blockId >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = blockId % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];

        // Check the integrity of the block data. It's worth noting that in
        // theory, this check may be skipped, but it's included for added
        // caution.
        if (blk.blockId != blockId || blk.metaHash != evidence.metaHash) {
            revert L1_BLOCK_MISMATCH();
        }

        // Each transition is uniquely identified by the parentHash, with the
        // blockHash and signalRoot open for later updates as higher-tier proofs
        // become available. In cases where a transition with the specified
        // parentHash does not exist, the transition ID (tid) will be set to 0.
        uint32 tid =
            LibUtils.getTransitionId(state, blk, slot, evidence.parentHash);
        TaikoData.Transition storage tran;

        if (tid == 0) {
            // In cases where a transition with the provided parentHash is not
            // found, we must essentially "create" one and set it to its initial
            // state. This initial state can be viewed as a special transition
            // on tier-0.
            //
            // Subsequently, we transform this tier-0 transition into a
            // non-zero-tier transition with a proof. This approach ensures that
            // the same logic is applicable for both 0-to-non-zero transition
            // updates and non-zero-to-non-zero transition updates.
            unchecked {
                // Unchecked is safe:  Not realistic 2**32 different fork choice
                // per block will be proven and none of them is valid
                tid = blk.nextTransitionId++;
            }

            // Keep in mind that state.transitions are also reusable storage
            // slots, so it's necessary to reinitialize all transition fields
            // below.
            tran = state.transitions[slot][tid];
            tran.blockHash = 0;
            tran.signalRoot = 0;
            tran.proofBond = 0;
            tran.contester = address(0);
            tran.contestBond = 0;
            tran.timestamp = uint64(block.timestamp);
            tran.tier = 0;

            if (tid == 1) {
                // This approach serves as a cost-saving technique for the
                // majority of blocks, where the first transition is expected to
                // be the correct one. Writing to `tran` is more economical
                // since it resides in the ring buffer, whereas writing to
                // `transitionIds` is not as cost-effective.
                tran.key = evidence.parentHash;

                // In the case of this first transition, the block's assigned
                // prover has the privilege to re-prove it, but only when the
                // assigned prover matches the previous prover. To ensure this,
                // we establish the transition's prover as the block's assigned
                // prover. Consequently, when we carry out a 0-to-non-zero
                // transition update, the previous prover will consistently be
                // the block's assigned prover.
                //
                // While alternative implementations are possible, introducing
                // such changes would require additional if-else logic.
                tran.prover = blk.assignedProver;
            } else {
                // In scenarios where this transition is not the first one, the
                // block's assigned prover is treated no differently than any
                // other provers. Consequently, we straightforwardly reset the
                // transition prover to address zero.
                tran.prover = address(0);

                // Furthermore, we index the transition for future retrieval.
                // It's worth emphasizing that this mapping for indexing is not
                // reusable. However, given that the majority of blocks will
                // only possess one transition — the correct one — we don't need
                // to be concerned about the cost in this case.
                state.transitionIds[blk.blockId][evidence.parentHash] = tid;
            }
        } else {
            // A transition with the provided parentHash has been located.
            tran = state.transitions[slot][tid];
            assert(tran.tier >= blk.minTier);
        }

        // The new proof must meet or exceed the minimum tier required by the
        // block or the previous proof; it cannot be on a lower tier.
        if (evidence.tier < blk.minTier || evidence.tier < tran.tier) {
            revert L1_INVALID_TIER();
        }

        // Retrieve the tier configurations. If the tier is not supported, the
        // subsequent action will result in a revert.
        TaikoData.TierConfig memory tier = LibTiers.getTierConfig(evidence.tier);

        // We must verify the proof, and any failure in proof verification will
        // result in a revert of the following code.
        //
        // It's crucial to emphasize that the proof can be assessed in two
        // potential modes: "proof mode" and "contest mode." However, the
        // precise verification logic is defined within each tier's
        // IEvidenceVerifier contract implementation. We simply specify to the
        // verifier contract which mode it should utilize - if the new tier
        // is higher than the previous tier, we employ the proof mode;
        // otherwise, we employ the contest mode (the new tier cannot be lower
        // than the previous tier, this has been checked above).
        //
        // It's obvious that proof verification is entirely decoupled from
        // Taiko's core protocol.
        {
            address verifier = resolver.resolve(tier.verifierName, true);

            // The verifier can be address-zero, signifying that there are no
            // proof checks for the tier. In practice, this only applies to
            // optimistic proofs.
            if (verifier != address(0)) {
                IEvidenceVerifier(verifier).verifyProof({
                    blockId: blk.blockId,
                    prover: msg.sender,
                    isContesting: evidence.tier == tran.tier,
                    evidence: evidence
                });
            }
        }

        // Prepare to burn either the proof bond or the contest bond below.
        TaikoToken tt = TaikoToken(resolver.resolve("taiko_token", false));

        if (evidence.tier == tran.tier) {
            // To contest the existing transition
            // The block hash or signal root must be different
            if (
                evidence.blockHash == tran.blockHash
                    && evidence.signalRoot == tran.signalRoot
            ) {
                revert L1_ALREADY_PROVED();
            }

            // The existing transiton must not have been contested
            if (tran.contester != address(0)) revert L1_ALREADY_CONTESTED();

            // Contest bond being zero means this tier is not contestable.
            if (tier.contestBond == 0) {
                revert L1_NOT_CONTESTABLE();
            }

            // Burn the contest bond
            tt.burn(msg.sender, tier.contestBond);

            tran.contester = msg.sender;
            tran.contestBond = tier.contestBond;
            tran.timestamp = uint64(block.timestamp);

            emit Contested(
                blk.blockId,
                evidence.parentHash,
                tran.blockHash,
                tran.signalRoot,
                msg.sender,
                tier.contestBond,
                evidence.tier
            );
        } else {
            // To prove or re-approve the transition

            if (evidence.blockHash == 0 || evidence.signalRoot == 0) {
                revert L1_INVALID_EVIDENCE();
            }

            if (
                tran.contester == address(0)
                    && tran.blockHash == evidence.blockHash
                    && tran.signalRoot == evidence.signalRoot
            ) {
                revert L1_ALREADY_PROVED();
            }

            if (tid == 1) {
                // Special handing for the first transition, if the current
                // prover is the assigned prover, we only allow the assigned
                // approve to aprove within the proof window.
                if (
                    tran.prover == blk.assignedProver
                        && msg.sender != blk.assignedProver
                        && block.timestamp <= tran.timestamp + tier.provingWindow
                ) {
                    revert L1_NOT_ASSIGNED_PROVER();
                }
            } else {
                // The assigned prover cannot prove transitions other than the
                // first one.
                if (msg.sender == blk.assignedProver) {
                    revert L1_ASSIGNED_PROVER_NOT_ALLOWED();
                }
            }

            tt.burn(msg.sender, tier.proofBond);

            unchecked {
                uint256 reward;
                if (
                    tran.blockHash == evidence.blockHash
                        && tran.signalRoot == evidence.signalRoot
                ) {
                    // Challenger lost
                    reward = tran.contestBond / 4;
                    tt.mint(tran.prover, reward + tran.proofBond);
                } else {
                    // Challenger won
                    reward = tran.proofBond / 4;
                    if (
                        tran.contester != address(0)
                            && tran.contester != LibUtils.PLACEHOLDER_ADDR
                    ) {
                        tt.mint(tran.contester, reward + tran.contestBond);
                    }
                    tran.blockHash = evidence.blockHash;
                    tran.signalRoot = evidence.signalRoot;
                }

                if (reward != 0) {
                    tt.mint(msg.sender, reward);
                }
            }

            tran.prover = msg.sender;
            tran.proofBond = tier.proofBond;
            tran.contester = address(0);
            tran.contestBond = 1; // non-zero to save gas
            tran.timestamp = uint64(block.timestamp);
            tran.tier = evidence.tier;

            emit Proved(
                blk.blockId,
                evidence.parentHash,
                evidence.blockHash,
                evidence.signalRoot,
                msg.sender,
                tier.proofBond,
                evidence.tier
            );
        }
    }
}
