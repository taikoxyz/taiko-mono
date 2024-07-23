// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/IVerifier.sol";
import "./LibBonds.sol";
import "./LibData.sol";
import "./LibUtils.sol";

/// @title LibProving
/// @notice A library for handling block contestation and proving in the Taiko
/// protocol.
/// @custom:security-contact security@taiko.xyz
library LibProving {
    using LibMath for uint256;

    // A struct to get around stack too deep issue and to cache state variables for multiple reads.
    struct Local {
        TaikoData.SlotB b;
        ITierProvider.Tier tier;
        ITierProvider.Tier minTier;
        bytes32 metaHash;
        address assignedProver;
        bytes32 stateRoot;
        uint96 livenessBond;
        uint64 slot;
        uint64 blockId;
        uint24 tid;
        bool lastUnpausedAt;
        bool isTopTier;
        bool inProvingWindow;
        bool sameTransition;
        bool postFork;
        uint64 proposedAt;
    }

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

    /// @notice Emitted when a transition is proved.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param prover The prover's address.
    /// @param validityBond The validity bond amount.
    /// @param tier The tier of the proof.
    /// @param proposedIn The L1 block in which a transition is proved.
    event TransitionProvedV2(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address prover,
        uint96 validityBond,
        uint16 tier,
        uint64 proposedIn
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

    /// @notice Emitted when a transition is contested.
    /// @param blockId The block ID.
    /// @param tran The transition data.
    /// @param contester The contester's address.
    /// @param contestBond The contest bond amount.
    /// @param tier The tier of the proof.
    /// @param proposedIn The L1 block in which this L2 block is proposed.
    event TransitionContestedV2(
        uint256 indexed blockId,
        TaikoData.Transition tran,
        address contester,
        uint96 contestBond,
        uint16 tier,
        uint64 proposedIn
    );

    /// @notice Emitted when proving is paused or unpaused.
    /// @param paused The pause status.
    event ProvingPaused(bool paused);

    error L1_ALREADY_CONTESTED();
    error L1_ALREADY_PROVED();
    error L1_BLOCK_MISMATCH();
    error L1_CANNOT_CONTEST();
    error L1_INVALID_PAUSE_STATUS();
    error L1_INVALID_TIER();
    error L1_INVALID_TRANSITION();
    error L1_NOT_ASSIGNED_PROVER();
    error L1_PROVING_PAUSED();

    /// @notice Pauses or unpauses the proving process.
    /// @param _state Current TaikoData.State.
    /// @param _pause The pause status.
    function pauseProving(TaikoData.State storage _state, bool _pause) internal {
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
    /// @param _blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param _input An abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    function proveBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _blockId,
        bytes calldata _input
    )
        internal
    {
        Local memory local;

        local.b = _state.slotB;
        local.blockId = _blockId;
        local.postFork = _blockId >= _config.ontakeForkHeight;

        TaikoData.BlockMetadataV2 memory meta;
        TaikoData.Transition memory tran;
        TaikoData.TierProof memory proof;

        if (local.postFork) {
            uint256 offset;
            (meta, offset) = LibData.decodeMetadataPacked(_input);
            (tran, proof) = abi.decode(_input[offset:], (TaikoData.Transition, TaikoData.TierProof));
        } else {
            TaikoData.BlockMetadata memory meta1;

            (meta1, tran, proof) = abi.decode(
                _input, (TaikoData.BlockMetadata, TaikoData.Transition, TaikoData.TierProof)
            );
            // Below, the liveness bond parameter must be 0 to force reading from block storage.
            meta = LibData.metadataV1toV2(meta1, 0);
        }

        if (_blockId != meta.id) revert LibUtils.L1_INVALID_BLOCK_ID();

        // Make sure parentHash is not zero
        // To contest an existing transition, simply use any non-zero value as
        // the blockHash and stateRoot.
        if (tran.parentHash == 0 || tran.blockHash == 0 || tran.stateRoot == 0) {
            revert L1_INVALID_TRANSITION();
        }

        // Check that the block has been proposed but has not yet been verified.
        if (meta.id <= local.b.lastVerifiedBlockId || meta.id >= local.b.numBlocks) {
            revert LibUtils.L1_INVALID_BLOCK_ID();
        }

        local.slot = meta.id % _config.blockRingBufferSize;
        TaikoData.Block storage blk = _state.blocks[local.slot];

        local.proposedAt = local.postFork ? meta.proposedAt : blk.proposedAt;

        if (LibUtils.shouldSyncStateRoot(_config.stateRootSyncInternal, local.blockId)) {
            local.stateRoot = tran.stateRoot;
        }

        local.assignedProver = blk.assignedProver;
        if (local.assignedProver == address(0)) {
            local.assignedProver = meta.proposer;
        }

        if (!blk.livenessBondReturned) {
            local.livenessBond = meta.livenessBond == 0 ? blk.livenessBond : meta.livenessBond;
        }
        local.metaHash = blk.metaHash;

        // Check the integrity of the block data. It's worth noting that in
        // theory, this check may be skipped, but it's included for added
        // caution.
        if (local.metaHash != LibData.hashMetadata(local.postFork, meta)) {
            revert L1_BLOCK_MISMATCH();
        }

        // Each transition is uniquely identified by the parentHash, with the
        // blockHash and stateRoot open for later updates as higher-tier proofs
        // become available. In cases where a transition with the specified
        // parentHash does not exist, the transition ID (tid) will be set to 0.
        TaikoData.TransitionState memory ts;
        (local.tid, ts) = _fetchOrCreateTransition(_state, blk, tran, local);

        // The new proof must meet or exceed the minimum tier required by the
        // block or the previous proof; it cannot be on a lower tier.
        if (proof.tier == 0 || proof.tier < meta.minTier || proof.tier < ts.tier) {
            revert L1_INVALID_TIER();
        }

        // Retrieve the tier configurations. If the tier is not supported, the
        // subsequent action will result in a revert.
        {
            ITierRouter tierRouter = ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER, false));
            ITierProvider tierProvider = ITierProvider(tierRouter.getProvider(local.blockId));

            local.tier = tierProvider.getTier(proof.tier);
            local.minTier = tierProvider.getTier(meta.minTier);
        }

        local.inProvingWindow = !LibUtils.isPostDeadline({
            _tsTimestamp: ts.timestamp,
            _lastUnpausedAt: local.b.lastUnpausedAt,
            _windowMinutes: local.minTier.provingWindow
        });

        // Checks if only the assigned prover is permissioned to prove the block.
        // The assigned prover is granted exclusive permission to prove only the first
        // transition.
        if (
            local.tier.contestBond != 0 && ts.contester == address(0) && local.tid == 1
                && ts.tier == 0 && local.inProvingWindow
        ) {
            if (msg.sender != local.assignedProver) revert L1_NOT_ASSIGNED_PROVER();
        }
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
        if (local.tier.verifierName != "") {
            address verifier = _resolver.resolve(local.tier.verifierName, false);
            bool isContesting = proof.tier == ts.tier && local.tier.contestBond != 0;

            IVerifier.Context memory ctx = IVerifier.Context({
                metaHash: local.metaHash,
                blobHash: meta.blobHash,
                // Separate msgSender to allow the prover to be any address in the future.
                prover: msg.sender,
                msgSender: msg.sender,
                blockId: local.blockId,
                isContesting: isContesting,
                blobUsed: meta.blobUsed
            });

            IVerifier(verifier).verifyProof(ctx, tran, proof);
        }

        local.isTopTier = local.tier.contestBond == 0;

        local.sameTransition = tran.blockHash == ts.blockHash && local.stateRoot == ts.stateRoot;

        if (proof.tier > ts.tier) {
            // Handles the case when an incoming tier is higher than the current transition's tier.
            // Reverts when the incoming proof tries to prove the same transition
            // (L1_ALREADY_PROVED).
            _overrideWithHigherProof(_state, _resolver, blk, ts, tran, proof, local);

            if (local.postFork) {
                emit TransitionProvedV2({
                    blockId: local.blockId,
                    tran: tran,
                    prover: msg.sender,
                    validityBond: local.tier.validityBond,
                    tier: proof.tier,
                    proposedIn: meta.proposedIn
                });
            } else {
                emit TransitionProved({
                    blockId: local.blockId,
                    tran: tran,
                    prover: msg.sender,
                    validityBond: local.tier.validityBond,
                    tier: proof.tier
                });
            }
        } else {
            // New transition and old transition on the same tier - and if this transaction tries to
            // prove the same, it reverts
            if (local.sameTransition) revert L1_ALREADY_PROVED();

            if (local.isTopTier) {
                // The top tier prover re-proves.
                assert(local.tier.validityBond == 0);
                assert(ts.validityBond == 0 && ts.contester == address(0));

                ts.prover = msg.sender;
                ts.blockHash = tran.blockHash;
                ts.stateRoot = local.stateRoot;

                if (local.postFork) {
                    emit TransitionProvedV2({
                        blockId: local.blockId,
                        tran: tran,
                        prover: msg.sender,
                        validityBond: 0,
                        tier: proof.tier,
                        proposedIn: meta.proposedIn
                    });
                } else {
                    emit TransitionProved({
                        blockId: local.blockId,
                        tran: tran,
                        prover: msg.sender,
                        validityBond: 0,
                        tier: proof.tier
                    });
                }
            } else {
                // Contesting but not on the highest tier
                if (ts.contester != address(0)) revert L1_ALREADY_CONTESTED();

                // Making it a non-sliding window, relative when ts.timestamp was registered (or to
                // lastUnpaused if that one is bigger)
                if (
                    LibUtils.isPostDeadline(
                        ts.timestamp, local.b.lastUnpausedAt, local.tier.cooldownWindow
                    )
                ) {
                    revert L1_CANNOT_CONTEST();
                }

                // _checkIfContestable(/*_state,*/ tier.cooldownWindow, ts.timestamp);
                // Burn the contest bond from the prover.
                LibBonds.debitBond(_state, _resolver, msg.sender, local.tier.contestBond);

                // We retain the contest bond within the transition, just in
                // case this configuration is altered to a different value
                // before the contest is resolved.
                //
                // It's worth noting that the previous value of ts.contestBond
                // doesn't have any significance.
                ts.contestBond = local.tier.contestBond;
                ts.contester = msg.sender;

                if (local.postFork) {
                    emit TransitionContestedV2({
                        blockId: local.blockId,
                        tran: tran,
                        contester: msg.sender,
                        contestBond: local.tier.contestBond,
                        tier: proof.tier,
                        proposedIn: meta.proposedIn
                    });
                } else {
                    emit TransitionContested({
                        blockId: local.blockId,
                        tran: tran,
                        contester: msg.sender,
                        contestBond: local.tier.contestBond,
                        tier: proof.tier
                    });
                }
            }
        }

        ts.timestamp = uint64(block.timestamp);
        _state.transitions[local.slot][local.tid] = ts;
    }

    /// @dev Handle the transition initialization logic
    function _fetchOrCreateTransition(
        TaikoData.State storage _state,
        TaikoData.Block storage _blk,
        TaikoData.Transition memory _tran,
        Local memory _local
    )
        private
        returns (uint24 tid_, TaikoData.TransitionState memory ts_)
    {
        tid_ = LibUtils.getTransitionId(_state, _blk, _local.slot, _tran.parentHash);

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
            ts_.timestamp = _local.proposedAt;

            if (tid_ == 1) {
                // This approach serves as a cost-saving technique for the
                // majority of blocks, where the first transition is expected to
                // be the correct one. Writing to `transitions` is more economical
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
                ts_.prover = _local.assignedProver;
            } else {
                // Furthermore, we index the transition for future retrieval.
                // It's worth emphasizing that this mapping for indexing is not
                // reusable. However, given that the majority of blocks will
                // only possess one transition — the correct one — we don't need
                // to be concerned about the cost in this case.

                // There is no need to initialize ts.key here because it's only used when tid == 1
                _state.transitionIds[_local.blockId][_tran.parentHash] = tid_;
            }
        } else {
            // A transition with the provided parentHash has been located.
            ts_ = _state.transitions[_local.slot][tid_];
        }
    }

    /// @dev Handles what happens when either the first transition is being proven or there is a
    /// higher tier proof incoming
    ///
    /// Assume Alice is the initial prover, Bob is the contester, and Cindy is the subsequent
    /// prover. The validity bond `V` is set at 100, and the contestation bond `C` at 500. If Bob
    /// successfully contests, he receives a reward of 65.625, calculated as 3/4 of 7/8 of 100. Cindy
    /// receives 21.875, which is 1/4 of 7/8 of 100, while the protocol retains 12.5 as friction.
    /// Bob's Return on Investment (ROI) is 13.125%, calculated from 65.625 divided by 500.
    // To establish the expected ROI `r` for valid contestations, where the contestation bond `C` to
    // validity bond `V` ratio is `C/V = 21/(32*r)`, and if `r` set at 10%, the C/V ratio will be
    // 6.5625.
    function _overrideWithHigherProof(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        TaikoData.Block storage _blk,
        TaikoData.TransitionState memory _ts,
        TaikoData.Transition memory _tran,
        TaikoData.TierProof memory _proof,
        Local memory _local
    )
        private
    {
        // Higher tier proof overwriting lower tier proof
        uint256 reward; // reward to the new (current) prover

        if (_ts.contester != address(0)) {
            if (_local.sameTransition) {
                // The contested transition is proven to be valid, contester loses the game
                reward = _rewardAfterFriction(_ts.contestBond);

                // We return the validity bond back, but the original prover doesn't get any reward.
                LibBonds.creditBond(_state, _ts.prover, _ts.validityBond);
            } else {
                // The contested transition is proven to be invalid, contester wins the game.
                // Contester gets 3/4 of reward, the new prover gets 1/4.
                reward = _rewardAfterFriction(_ts.validityBond) >> 2;

                LibBonds.creditBond(_state, _ts.contester, _ts.contestBond + reward * 3);
            }
        } else {
            if (_local.sameTransition) revert L1_ALREADY_PROVED();

            // The code below will be executed if
            // - 1) the transition is proved for the fist time, or
            // - 2) the transition is contested.
            reward = _rewardAfterFriction(_ts.validityBond);

            if (_local.livenessBond != 0) {
                // After the first proof, the block's liveness bond will always be reset to 0.
                // This means liveness bond will be handled only once for any given block.
                _blk.livenessBond = 0;
                _blk.livenessBondReturned = true;

                if (_returnLivenessBond(_local, _proof.data)) {
                    if (_local.assignedProver == msg.sender) {
                        reward += _local.livenessBond;
                    } else {
                        LibBonds.creditBond(_state, _local.assignedProver, _local.livenessBond);
                    }
                }
            }
        }

        unchecked {
            if (reward > _local.tier.validityBond) {
                LibBonds.creditBond(_state, msg.sender, reward - _local.tier.validityBond);
            } else if (reward < _local.tier.validityBond) {
                LibBonds.debitBond(_state, _resolver, msg.sender, _local.tier.validityBond - reward);
            }
        }

        _ts.validityBond = _local.tier.validityBond;
        _ts.contester = address(0);
        _ts.prover = msg.sender;
        _ts.tier = _proof.tier;

        if (!_local.sameTransition) {
            _ts.blockHash = _tran.blockHash;
            _ts.stateRoot = _local.stateRoot;
        }
    }

    /// @dev Returns the reward after applying 12.5% friction.
    function _rewardAfterFriction(uint256 _amount) private pure returns (uint256) {
        return _amount == 0 ? 0 : (_amount * 7) >> 3;
    }

    /// @dev Returns if the liveness bond shall be returned.
    function _returnLivenessBond(
        Local memory _local,
        bytes memory _proofData
    )
        private
        pure
        returns (bool)
    {
        return _local.inProvingWindow && _local.tid == 1
            || _local.isTopTier && _proofData.length == 32
                && bytes32(_proofData) == LibStrings.H_RETURN_LIVENESS_BOND;
    }
}
