// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/IAddressResolver.sol";
import "../../libs/LibMath.sol";
import "../../verifiers/IVerifier.sol";
import "../tiers/ITierProvider.sol";
import "../TaikoData.sol";
import "./LibUtils.sol";

/// @title LibProving
/// @notice A library for handling block contestation and proving in the Taiko
/// protocol.
/// @custom:security-contact security@taiko.xyz
library LibProving {
    using LibMath for uint256;

    /// @notice Keccak hash of the string "RETURN_LIVENESS_BOND".
    bytes32 public constant RETURN_LIVENESS_BOND = keccak256("RETURN_LIVENESS_BOND");

    /// @notice The tier name for optimistic proofs.
    bytes32 public constant TIER_OP = bytes32("tier_optimistic");

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    /// @notice Emitted when a transition is proved.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param prover The prover's address.
    /// @param validityBond The validity bond amount.
    /// @param tier The tier of the proof.
    event TransitionProved(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address prover,
        uint96 validityBond,
        uint16 tier
    );

    /// @notice Emitted when a transition is contested.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param contester The contester's address.
    /// @param contestBond The contest bond amount.
    /// @param tier The tier of the proof.
    event TransitionContested(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address contester,
        uint96 contestBond,
        uint16 tier
    );

    /// @notice Emitted when proving is paused or unpaused.
    /// @param paused The pause status.
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
    error L1_MISSING_VERIFIER();
    error L1_NOT_ASSIGNED_PROVER();

    /// @notice Pauses or unpauses the proving process.
    /// @param _state Current TaikoData.State.
    /// @param _pause The pause status.
    function pauseProving(TaikoData.State storage _state, bool _pause) external {
        if (_state.slotB.provingPaused == _pause) revert L1_INVALID_PAUSE_STATUS();
        _state.slotB.provingPaused = _pause;

        if (!_pause) {
            _state.slotB.lastUnpausedAt = uint64(block.timestamp);
        }
        emit ProvingPaused(_pause);
    }

    /// @dev Proves or contests a block transition.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _meta The block's metadata.
    /// @param _tran The transition data.
    /// @param _proof The proof.
    /// @param maxBlocksToVerify_ The number of blocks to be verified with this transaction.
    function proveBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        TaikoData.BlockMetadata memory _meta,
        TaikoData.Transition memory _tran,
        TaikoData.TierProof memory _proof
    )
        internal
        returns (uint8 maxBlocksToVerify_)
    {
        // Make sure parentHash is not zero
        // To contest an existing transition, simply use any non-zero value as
        // the blockHash and stateRoot.
        if (_tran.parentHash == 0 || _tran.blockHash == 0 || _tran.stateRoot == 0) {
            revert L1_INVALID_TRANSITION();
        }

        // Check that the block has been proposed but has not yet been verified.
        TaikoData.SlotB memory b = _state.slotB;
        if (_meta.id <= b.lastVerifiedBlockId || _meta.id >= b.numBlocks) {
            revert L1_INVALID_BLOCK_ID();
        }

        uint64 slot = _meta.id % _config.blockRingBufferSize;
        TaikoData.Block storage blk = _state.blocks[slot];

        // Check the integrity of the block data. It's worth noting that in
        // theory, this check may be skipped, but it's included for added
        // caution.
        if (blk.blockId != _meta.id || blk.metaHash != keccak256(abi.encode(_meta))) {
            revert L1_BLOCK_MISMATCH();
        }

        // Each transition is uniquely identified by the parentHash, with the
        // blockHash and stateRoot open for later updates as higher-tier proofs
        // become available. In cases where a transition with the specified
        // parentHash does not exist, the transition ID (tid) will be set to 0.
        (uint32 tid, TaikoData.TransitionState storage ts) =
            _createTransition(_state, blk, _tran, slot);

        // The new proof must meet or exceed the minimum tier required by the
        // block or the previous proof; it cannot be on a lower tier.
        if (_proof.tier == 0 || _proof.tier < _meta.minTier || _proof.tier < ts.tier) {
            revert L1_INVALID_TIER();
        }

        // Retrieve the tier configurations. If the tier is not supported, the
        // subsequent action will result in a revert.
        ITierProvider.Tier memory tier =
            ITierProvider(_resolver.resolve("tier_provider", false)).getTier(_proof.tier);

        // Check if this prover is allowed to submit a proof for this block
        _checkProverPermission(_state, blk, ts, tid, tier);

        // We must verify the proof, and any failure in proof verification will
        // result in a revert.
        //
        // It's crucial to emphasize that the proof can be assessed in two
        // potential modes: "proving mode" and "contesting mode." However, the
        // precise verification logic is defined within each tier's IVerifier
        // contract implementation. We simply specify to the verifier contract
        // which mode it should utilize - if the new tier is higher than the
        // previous tier, we employ the proving mode; otherwise, we employ the
        // contesting mode (the new tier cannot be lower than the previous tier,
        // this has been checked above).
        //
        // It's obvious that proof verification is entirely decoupled from
        // Taiko's core protocol.
        {
            address verifier = _resolver.resolve(tier.verifierName, true);

            if (verifier != address(0)) {
                bool isContesting = _proof.tier == ts.tier && tier.contestBond != 0;

                IVerifier.Context memory ctx = IVerifier.Context({
                    metaHash: blk.metaHash,
                    blobHash: _meta.blobHash,
                    // Separate msgSender to allow the prover to be any address in the future.
                    prover: msg.sender,
                    msgSender: msg.sender,
                    blockId: blk.blockId,
                    isContesting: isContesting,
                    blobUsed: _meta.blobUsed
                });

                IVerifier(verifier).verifyProof(ctx, _tran, _proof);
            } else if (tier.verifierName != TIER_OP) {
                // The verifier can be address-zero, signifying that there are no
                // proof checks for the tier. In practice, this only applies to
                // optimistic proofs.
                revert L1_MISSING_VERIFIER();
            }
        }

        bool isTopTier = tier.contestBond == 0;
        IERC20 tko = IERC20(_resolver.resolve("taiko_token", false));

        if (isTopTier) {
            // A special return value from the top tier prover can signal this
            // contract to return all liveness bond.
            bool returnLivenessBond = blk.livenessBond > 0 && _proof.data.length == 32
                && bytes32(_proof.data) == RETURN_LIVENESS_BOND;

            if (returnLivenessBond) {
                tko.transfer(blk.assignedProver, blk.livenessBond);
                blk.livenessBond = 0;
            }
        }

        bool sameTransition = _tran.blockHash == ts.blockHash && _tran.stateRoot == ts.stateRoot;

        if (_proof.tier > ts.tier) {
            // Handles the case when an incoming tier is higher than the current transition's tier.
            // Reverts when the incoming proof tries to prove the same transition
            // (L1_ALREADY_PROVED).
            _overrideWithHigherProof(ts, _tran, _proof, tier, tko, sameTransition);

            emit TransitionProved({
                blockId: blk.blockId,
                tran: _tran,
                prover: msg.sender,
                validityBond: tier.validityBond,
                tier: _proof.tier
            });
        } else {
            // New transition and old transition on the same tier - and if this transaction tries to
            // prove the same, it reverts
            if (sameTransition) revert L1_ALREADY_PROVED();

            if (isTopTier) {
                // The top tier prover re-proves.
                assert(tier.validityBond == 0);
                assert(ts.validityBond == 0 && ts.contestBond == 0 && ts.contester == address(0));

                ts.prover = msg.sender;
                ts.blockHash = _tran.blockHash;
                ts.stateRoot = _tran.stateRoot;

                emit TransitionProved({
                    blockId: blk.blockId,
                    tran: _tran,
                    prover: msg.sender,
                    validityBond: 0,
                    tier: _proof.tier
                });
            } else {
                // Contesting but not on the highest tier
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
                ts.contestations += 1;

                emit TransitionContested({
                    blockId: blk.blockId,
                    tran: _tran,
                    contester: msg.sender,
                    contestBond: tier.contestBond,
                    tier: _proof.tier
                });
            }
        }

        ts.timestamp = uint64(block.timestamp);
        return tier.maxBlocksToVerifyPerProof;
    }

    /// @dev Handle the transition initialization logic
    function _createTransition(
        TaikoData.State storage _state,
        TaikoData.Block storage _blk,
        TaikoData.Transition memory _tran,
        uint64 slot
    )
        private
        returns (uint32 tid_, TaikoData.TransitionState storage ts_)
    {
        tid_ = LibUtils.getTransitionId(_state, _blk, slot, _tran.parentHash);

        if (tid_ == 0) {
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
                tid_ = _blk.nextTransitionId++;
            }

            // Keep in mind that state.transitions are also reusable storage
            // slots, so it's necessary to reinitialize all transition fields
            // below.
            ts_ = _state.transitions[slot][tid_];
            ts_.blockHash = 0;
            ts_.stateRoot = 0;
            ts_.validityBond = 0;
            ts_.contester = address(0);
            ts_.contestBond = 1; // to save gas
            ts_.timestamp = _blk.proposedAt;
            ts_.tier = 0;
            ts_.contestations = 0;

            if (tid_ == 1) {
                // This approach serves as a cost-saving technique for the
                // majority of blocks, where the first transition is expected to
                // be the correct one. Writing to `tran` is more economical
                // since it resides in the ring buffer, whereas writing to
                // `transitionIds` is not as cost-effective.
                ts_.key = _tran.parentHash;

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
                ts_.prover = _blk.assignedProver;
            } else {
                // In scenarios where this transition is not the first one, we
                // straightforwardly reset the transition prover to address
                // zero.
                ts_.prover = address(0);

                // Furthermore, we index the transition for future retrieval.
                // It's worth emphasizing that this mapping for indexing is not
                // reusable. However, given that the majority of blocks will
                // only possess one transition — the correct one — we don't need
                // to be concerned about the cost in this case.
                _state.transitionIds[_blk.blockId][_tran.parentHash] = tid_;

                // There is no need to initialize ts.key here because it's only used when tid == 1
            }
        } else {
            // A transition with the provided parentHash has been located.
            ts_ = _state.transitions[slot][tid_];
        }
    }

    /// @dev Handles what happens when there is a higher proof incoming
    function _overrideWithHigherProof(
        TaikoData.TransitionState storage _ts,
        TaikoData.Transition memory _tran,
        TaikoData.TierProof memory _proof,
        ITierProvider.Tier memory _tier,
        IERC20 _tko,
        bool _sameTransition
    )
        private
    {
        // Higher tier proof overwriting lower tier proof
        uint256 reward;

        if (_ts.contester != address(0)) {
            if (_sameTransition) {
                // The contested transition is proven to be valid, contestor loses the game
                reward = _ts.contestBond >> 2;
                _tko.transfer(_ts.prover, _ts.validityBond + reward);
            } else {
                // The contested transition is proven to be invalid, contestor wins the game
                reward = _ts.validityBond >> 2;
                _tko.transfer(_ts.contester, _ts.contestBond + reward);
            }
        } else {
            if (_sameTransition) revert L1_ALREADY_PROVED();
            // Contest the existing transition and prove it to be invalid
            reward = _ts.validityBond >> 1;
            _ts.contestations += 1;
        }

        unchecked {
            if (reward > _tier.validityBond) {
                _tko.transfer(msg.sender, reward - _tier.validityBond);
            } else {
                _tko.transferFrom(msg.sender, address(this), _tier.validityBond - reward);
            }
        }

        _ts.validityBond = _tier.validityBond;
        _ts.contestBond = 1; // to save gas
        _ts.contester = address(0);
        _ts.prover = msg.sender;
        _ts.tier = _proof.tier;

        if (!_sameTransition) {
            _ts.blockHash = _tran.blockHash;
            _ts.stateRoot = _tran.stateRoot;
        }
    }

    /// @dev Check the msg.sender (the new prover) against the block's assigned prover.
    function _checkProverPermission(
        TaikoData.State storage _state,
        TaikoData.Block storage _blk,
        TaikoData.TransitionState storage _ts,
        uint32 _tid,
        ITierProvider.Tier memory _tier
    )
        private
        view
    {
        // The highest tier proof can always submit new proofs
        if (_tier.contestBond == 0) return;

        bool inProvingWindow = uint256(_ts.timestamp).max(_state.slotB.lastUnpausedAt)
            + _tier.provingWindow * 60 >= block.timestamp;
        bool isAssignedPover = msg.sender == _blk.assignedProver;

        // The assigned prover can only submit the very first transition.
        if (_tid == 1 && _ts.tier == 0 && inProvingWindow) {
            if (!isAssignedPover) revert L1_NOT_ASSIGNED_PROVER();
        } else {
            // Disallow the same address to prove the block so that we can detect that the
            // assigned prover should not receive his liveness bond back
            if (isAssignedPover) revert L1_ASSIGNED_PROVER_NOT_ALLOWED();
        }
    }
}
