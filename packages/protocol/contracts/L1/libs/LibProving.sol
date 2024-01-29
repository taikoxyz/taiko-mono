// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../common/AddressResolver.sol";
import "../tiers/ITierProvider.sol";
import "../verifiers/IVerifier.sol";
import "../TaikoData.sol";
import "./LibUtils.sol";

/// @title LibProving
/// @notice A library for handling block contestation and proving in the Taiko
/// protocol.
library LibProving {
    bytes32 public constant RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");
    // Warning: Any events defined here must also be defined in TaikoEvents.sol.

    event TransitionProved(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address prover,
        uint96 validityBond,
        uint16 tier
    );

    event TransitionContested(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    event ProvingPaused(bool paused);

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_ALREADY_CONTESTED();
    error L1_ALREADY_PROVED();
    error L1_ASSIGNED_PROVER_NOT_ALLOWED();
    error L1_BLOCK_MISMATCH();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_PAUSE_STATUS();
    error L1_INVALID_TIER();
    error L1_INVALID_TRANSITION();
    error L1_NOT_ASSIGNED_PROVER();
    error L1_MISSING_VERIFIER();
    error L1_UNEXPECTED_TRANSITION_TIER();

    function pauseProving(TaikoData.State storage state, bool pause) external {
        if (state.slotB.provingPaused == pause) revert L1_INVALID_PAUSE_STATUS();

        state.slotB.provingPaused = pause;
        emit ProvingPaused(pause);
    }

    /// @dev Proves or contests a block transition.
    function proveBlock(
        TaikoData.State storage state,
        TaikoData.Config memory config,
        AddressResolver resolver,
        TaikoData.BlockMetadata memory meta,
        TaikoData.Transition memory tran,
        TaikoData.TierProof memory proof
    )
        external
        returns (uint8 maxBlocksToVerify)
    {
        // Make sure parentHash is not zero
        if (tran.parentHash == 0 || tran.blockHash == 0 || tran.signalRoot == 0) {
            revert L1_INVALID_TRANSITION();
        }

        // Check that the block has been proposed but has not yet been verified.
        TaikoData.SlotB memory b = state.slotB;
        if (meta.id <= b.lastVerifiedBlockId || meta.id >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = meta.id % config.blockRingBufferSize;
        TaikoData.Block storage blk = state.blocks[slot];

        // Check the integrity of the block data.
        if (blk.blockId != meta.id || blk.metaHash != keccak256(abi.encode(meta))) {
            revert L1_BLOCK_MISMATCH();
        }

        // Each transition is uniquely identified by the parentHash, with the
        // blockHash and signalRoot open for later updates as higher-tier proofs
        // become available. In cases where a transition with the specified
        // parentHash does not exist, the transition ID (tid) will be set to 0.
        uint32 tid = LibUtils.getTransitionId(state, blk, slot, tran.parentHash);
        TaikoData.TransitionState storage ts;

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
            ts = state.transitions[slot][tid];
            ts.blockHash = 0;
            ts.signalRoot = 0;
            ts.validityBond = 0;
            ts.contester = address(0);
            ts.contestBond = 1; // see below (the value does't matter)
            ts.timestamp = blk.proposedAt;
            ts.tier = 0;
            ts.contestations = 0;

            if (tid == 1) {
                // This approach serves as a cost-saving technique for the
                // majority of blocks, where the first transition is expected to
                // be the correct one. Writing to `tran` is more economical
                // since it resides in the ring buffer, whereas writing to
                // `transitionIds` is not as cost-effective.
                ts.key = tran.parentHash;

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
                ts.prover = blk.assignedProver;
            } else {
                // In scenarios where this transition is not the first one, we
                // straightforwardly reset the transition prover to address
                // zero.
                ts.prover = address(0);

                // Furthermore, we index the transition for future retrieval.
                // It's worth emphasizing that this mapping for indexing is not
                // reusable. However, given that the majority of blocks will
                // only possess one transition — the correct one — we don't need
                // to be concerned about the cost in this case.
                state.transitionIds[blk.blockId][tran.parentHash] = tid;
            }
        } else {
            // A transition with the provided parentHash has been located.
            ts = state.transitions[slot][tid];
            if (ts.tier < meta.minTier) {
                revert L1_UNEXPECTED_TRANSITION_TIER();
            }
        }

        // The new proof must meet or exceed the minimum tier required by the
        // block or the previous proof; it cannot be on a lower tier.
        if (proof.tier == 0 || proof.tier < ts.tier) {
            revert L1_INVALID_TIER();
        }

        // Retrieve the tier configurations. If the tier is not supported, the
        // subsequent action will result in a revert.
        ITierProvider.Tier memory tier =
            ITierProvider(resolver.resolve("tier_provider", false)).getTier(proof.tier);

        maxBlocksToVerify = tier.maxBlocksToVerifyWithTier;

        // We must verify the proof, and any failure in proof verification will
        // result in a revert.
        //
        // It's crucial to emphasize that the proof can be assessed in two
        // potential modes: "proving mode" and "contesting mode." However, the
        // precise verification logic is defined within each tier'IVerifier
        // contract implementation. We simply specify to the verifier contract
        // which mode it should utilize - if the new tier is higher than the
        // previous tier, we employ the proving mode; otherwise, we employ the
        // contesting mode (the new tier cannot be lower than the previous tier,
        // this has been checked above).
        //
        // It's obvious that proof verification is entirely decoupled from
        // Taiko's core protocol.
        {
            address verifier = resolver.resolve(tier.verifierName, true);
            // The verifier can be address-zero, signifying that there are no
            // proof checks for the tier. In practice, this only applies to
            // optimistic proofs.
            if (
                verifier == address(0)
                    && keccak256(abi.encodePacked(tier.verifierName))
                        != keccak256(abi.encodePacked("tier_optimistic"))
            ) {
                revert L1_MISSING_VERIFIER();
            }
            if (verifier != address(0)) {
                bool isContesting = proof.tier == ts.tier && tier.contestBond != 0;

                IVerifier.Context memory ctx = IVerifier.Context({
                    metaHash: blk.metaHash,
                    blobHash: meta.blobHash,
                    prover: msg.sender,
                    blockId: blk.blockId,
                    isContesting: isContesting,
                    blobUsed: meta.blobUsed
                });

                IVerifier(verifier).verifyProof(ctx, tran, proof);
            }
        }

        IERC20 tko = IERC20(resolver.resolve("taiko_token", false));

        if (tier.contestBond == 0) {
            assert(tier.validityBond == 0);

            // It means prover is right (not the contester)
            bool sameTransition = tran.blockHash == ts.blockHash && tran.signalRoot == ts.signalRoot;

            // A special return value from the top tier prover can signal this
            // contract to return all liveness bond.
            if (
                blk.livenessBond > 0 && proof.data.length == 32
                    && bytes32(proof.data) == RETURN_LIVENESS_BOND
            ) {
                tko.transfer(blk.assignedProver, blk.livenessBond);
                blk.livenessBond = 0;
            }

            ts.blockHash = tran.blockHash;
            ts.signalRoot = tran.signalRoot;
            ts.prover = msg.sender;

            if (ts.contester != address(0)) {
                if (!sameTransition) {
                    // At this point we know that the contester was right
                    tko.transfer(ts.contester, ts.validityBond >> 2 + ts.contestBond);
                }
                ts.contester = address(0);
                ts.validityBond = 0;
            }

            ts.timestamp = uint64(block.timestamp);
            ts.tier = proof.tier;

            emit TransitionProved({
                blockId: blk.blockId,
                tran: tran,
                prover: msg.sender,
                validityBond: 0,
                tier: proof.tier
            });
        } else if (proof.tier == ts.tier) {
            // Contesting an existing transition requires either the blockHash
            // or signalRoot to be different. This precaution is necessary
            // because this `proveBlock` transaction might aim to prove a
            // transition but could potentially be front-run by another prover
            // attempting to prove the same transition.
            if (tran.blockHash == ts.blockHash && tran.signalRoot == ts.signalRoot) {
                revert L1_ALREADY_PROVED();
            }

            // The new tier is the same as the previous tier, we are in the
            // contesting mode.
            //
            // It's important to note that tran.blockHash and
            // tran.signalRoot are not permanently stored, so their
            // specific values are inconsequential. They only need to differ
            // from the existing values to signify a contest. Therefore, a
            // contester can conveniently utilize the value 1 for these two
            // parameters.

            // The existing transiton must not have been contested.
            if (ts.contester != address(0)) revert L1_ALREADY_CONTESTED();

            // Burn the contest bond from the prover.
            tko.transferFrom(msg.sender, address(this), tier.contestBond);

            // We retain the contest bond within the transition, just in
            // case this configuration is altered to a different value
            // before the contest is resolved.
            //
            // It's worth noting that the previous value of ts.contestBond
            // doesn't have any significance.
            ts.contestBond = tier.contestBond;
            ts.contester = msg.sender;
            ts.timestamp = uint64(block.timestamp);
            ts.contestations += 1;

            emit TransitionContested({
                blockId: blk.blockId,
                tran: tran,
                contester: msg.sender,
                contestBond: tier.contestBond,
                tier: proof.tier
            });
        } else {
            assert(proof.tier > ts.tier);
            // The new tier is higher than the previous tier, we are in the
            // proving mode. This works even if this transition's contester is
            // address zero, see more info below.

            // The ability to prove a transition is granted under the following
            // two circumstances:
            //
            // 1. When the transition has been contested, indicated by
            // ts.contester not being address zero.
            //
            // 2. When the transition's blockHash and/or signalRoot differs. In
            // this case, the new prover essentially contests the previous proof
            // but immediately validates it, obviating the requirement to set a
            // contester, burn the contest bond, and other associated actions.
            // This streamlined process is applied to 0-to-non-zero transition
            // updates.
            if (
                ts.contester == address(0) && ts.blockHash == tran.blockHash
                    && ts.signalRoot == tran.signalRoot
            ) {
                // Alternatively, it can be understood that a transition cannot
                // be re-approved by higher-tier proofs without undergoing
                // contestation.
                revert L1_ALREADY_PROVED();
            }

            if (tid == 1 && ts.tier == 0 && block.timestamp <= ts.timestamp + tier.provingWindow) {
                // For the first transition, (1) if the previous prover is
                // still the assigned prover, we exclusively grant permission to
                // the assigned approver to re-prove the block, (2) unless the
                // proof window has elapsed.
                if (msg.sender != blk.assignedProver) revert L1_NOT_ASSIGNED_PROVER();
            } else if (msg.sender == blk.assignedProver) {
                // However, if the previous prover of the first transition is
                // not the block's assigned prover, or for any other
                // transitions, the assigned prover is not permitted to prove
                // such transitions.
                revert L1_ASSIGNED_PROVER_NOT_ALLOWED();
            }

            unchecked {
                // This is the amount of Taiko tokens to send to the new prover
                // and the winner of the contest (same amount to both parties).
                uint256 reward;
                if (ts.blockHash == tran.blockHash && ts.signalRoot == tran.signalRoot) {
                    assert(ts.contester != address(0));
                    // In the event that the previous prover emerges as the
                    // winner, half of the contest bond is designated as the
                    // reward, to be divided equally between the new prover and
                    // the previous prover -- 1/4 each
                    reward = ts.contestBond >> 2;

                    // Mint the reward and the validity bond and return it to
                    // the previous prover.
                    tko.transfer(ts.prover, reward + ts.validityBond);
                } else {
                    // In the event that the contester is the winner, half of
                    // the validity bond is designated as the reward, to be
                    // divided equally between the new prover and the contester.
                    reward = ts.validityBond >> 2;

                    // It's important to note that the contester is set to zero
                    // for the tier-0 transition. Consequently, we only grant a
                    // reward to the contester if it is not a zero-address.
                    if (ts.contester != address(0)) {
                        tko.transfer(ts.contester, reward + ts.contestBond);
                    } else {
                        // The prover is also the contester, so the reward is
                        // sent to him.
                        tko.transfer(msg.sender, reward);
                    }

                    // Given that the contester emerges as the winner, the
                    // previous blockHash and signalRoot are considered
                    // incorrect, and we must replace them with the correct
                    // values.
                    ts.blockHash = tran.blockHash;
                    ts.signalRoot = tran.signalRoot;
                }

                // Reward this prover.
                // In theory, the reward can also be zero for certain tiers if
                // their validity bonds are set to zero.
                tko.transfer(msg.sender, reward);
            }

            // Burn the validity bond from the prover.
            tko.transferFrom(msg.sender, address(this), tier.validityBond);

            // Regardless of whether the previous prover or the contester
            // emerges as the winner, we consistently erase the contest history
            // to make this transition appear entirely new.
            ts.prover = msg.sender;
            ts.validityBond = tier.validityBond;
            ts.contester = address(0);
            ts.contestBond = 1; // to save gas
            ts.timestamp = uint64(block.timestamp);
            ts.tier = proof.tier;

            emit TransitionProved({
                blockId: blk.blockId,
                tran: tran,
                prover: msg.sender,
                validityBond: tier.validityBond,
                tier: proof.tier
            });
        }
    }
}
