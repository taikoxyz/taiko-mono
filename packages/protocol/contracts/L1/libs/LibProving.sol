// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../verifiers/IVerifier.sol";
import "./LibBonds.sol";
import "./LibUtils.sol";
import "./LibVerifying.sol";

/// @title LibProving
/// @notice A library for handling block contestation and proving in the Taiko protocol.
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
        uint64 proposedAt;
    }

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
    error L1_INVALID_PARAMS();
    error L1_INVALID_PAUSE_STATUS();
    error L1_INVALID_TIER();
    error L1_INVALID_TRANSITION();
    error L1_MULTIPLE_VERIFIERS();
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

    function proveBlocks(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _proof
    )
        public
    {
        if (_blockIds.length == 0 || _blockIds.length != _inputs.length) {
            revert L1_INVALID_PARAMS();
        }

        IVerifier.Context[] memory ctxs = new IVerifier.Context[](_blockIds.length);

        address onlyVerifier;
        uint256 count;

        TaikoData.TierProof memory proof = abi.decode(_proof, (TaikoData.TierProof));

        for (uint256 i; i < _blockIds.length; ++i) {
            (address verifier, IVerifier.Context memory ctx) =
                _proveBlock(_state, _config, _resolver, _blockIds[i], _inputs[i], proof.tier);

            if (verifier == address(0)) continue;

            if (onlyVerifier == address(0)) {
                onlyVerifier = verifier;
            } else if (onlyVerifier != verifier) {
                revert L1_MULTIPLE_VERIFIERS();
            }

            unchecked {
                ctxs[count++] = ctx;
            }
        }

        if (onlyVerifier != address(0) && count != 0) {
            assembly {
                mstore(ctxs, count)
            }
            IVerifier(onlyVerifier).verifyProof(ctxs, proof);
        }
        for (uint256 i; i < _blockIds.length; ++i) {
            if (LibUtils.shouldVerifyBlocks(_config, _blockIds[i], false)) {
                LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
            }
        }
    }

    /// @notice Proves or contests a block transition.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _blockId The index of the block to prove. This is also used to select the right
    /// implementation version.
    /// @param _input An abi-encoded (TaikoData.BlockMetadata, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    function _proveBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _blockId,
        bytes calldata _input,
        uint16 _proofTier
    )
        private
        returns (address verifier_, IVerifier.Context memory ctx_)
    {
        Local memory local;

        local.b = _state.slotB;
        local.blockId = _blockId;

        TaikoData.BlockMetadataV2 memory meta;
        TaikoData.Transition memory tran;
        TaikoData.TierProof memory proof;

        // TODO(daniel)
        (meta, tran,) = abi.decode(
            _input, (TaikoData.BlockMetadataV2, TaikoData.Transition, TaikoData.TierProof)
        );

        if (_blockId != meta.id) revert LibUtils.L1_INVALID_BLOCK_ID();

        // Make sure parentHash is not zero
        // To contest an existing transition, simply use any non-zero value as the blockHash and
        // stateRoot.
        if (tran.parentHash == 0 || tran.blockHash == 0 || tran.stateRoot == 0) {
            revert L1_INVALID_TRANSITION();
        }

        // Check that the block has been proposed but has not yet been verified.
        if (meta.id <= local.b.lastVerifiedBlockId || meta.id >= local.b.numBlocks) {
            revert LibUtils.L1_INVALID_BLOCK_ID();
        }

        local.slot = meta.id % _config.blockRingBufferSize;
        TaikoData.BlockV2 storage blk = _state.blocks[local.slot];

        local.proposedAt = meta.proposedAt;

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

        // Check the integrity of the block data. It's worth noting that in theory, this check may
        // be skipped, but it's included for added caution.
        if (local.metaHash != keccak256(abi.encode(meta))) revert L1_BLOCK_MISMATCH();

        // Each transition is uniquely identified by the parentHash, with the blockHash and
        // stateRoot open for later updates as higher-tier proofs become available. In cases where a
        // transition with the specified parentHash does not exist, the transition ID (tid) will be
        // set to 0.
        TaikoData.TransitionState memory ts;
        (local.tid, ts) = _fetchOrCreateTransition(_state, blk, tran, local);

        // The new proof must meet or exceed the minimum tier required by the block or the previous
        // proof; it cannot be on a lower tier.
        if (_proofTier == 0 || _proofTier < meta.minTier || _proofTier < ts.tier) {
            revert L1_INVALID_TIER();
        }

        // Retrieve the tier configurations. If the tier is not supported, the subsequent action
        // will result in a revert.
        {
            ITierRouter tierRouter = ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER, false));
            ITierProvider tierProvider = ITierProvider(tierRouter.getProvider(local.blockId));

            local.tier = tierProvider.getTier(_proofTier);
            local.minTier = tierProvider.getTier(meta.minTier);
        }

        local.inProvingWindow = !LibUtils.isPostDeadline({
            _tsTimestamp: ts.timestamp,
            _lastUnpausedAt: local.b.lastUnpausedAt,
            _windowMinutes: local.minTier.provingWindow
        });

        // Checks if only the assigned prover is permissioned to prove the block. The assigned
        // prover is granted exclusive permission to prove only the first transition.
        if (
            local.tier.contestBond != 0 && ts.contester == address(0) && local.tid == 1
                && ts.tier == 0 && local.inProvingWindow
        ) {
            if (msg.sender != local.assignedProver) revert L1_NOT_ASSIGNED_PROVER();
        }
        // We must verify the proof, and any failure in proof verification will result in a revert.
        //
        // It's crucial to emphasize that the proof can be assessed in two potential modes: "proving
        // mode" and "contesting mode." However, the precise verification logic is defined within
        // each tier's IVerifier contract implementation. We simply specify to the verifier contract
        // which mode it should utilize - if the new tier is higher than the previous tier, we
        // employ the proving mode; otherwise, we employ the contesting mode (the new tier cannot be
        // lower than the previous tier, this has been checked above).
        //
        // It's obvious that proof verification is entirely decoupled from Taiko's core protocol.
        if (local.tier.verifierName != "") {
            verifier_ = _resolver.resolve(local.tier.verifierName, false);
            bool isContesting = _proofTier == ts.tier && local.tier.contestBond != 0;

            ctx_ = IVerifier.Context({
                metaHash: local.metaHash,
                blobHash: meta.blobHash,
                // Separate msgSender to allow the prover to be any address in the future.
                prover: msg.sender,
                msgSender: msg.sender,
                blockId: local.blockId,
                isContesting: isContesting,
                blobUsed: meta.blobUsed,
                transition: tran
            });
        }

        local.isTopTier = local.tier.contestBond == 0;

        local.sameTransition = tran.blockHash == ts.blockHash && local.stateRoot == ts.stateRoot;

        if (_proofTier > ts.tier) {
            // Handles the case when an incoming tier is higher than the current transition's tier.
            // Reverts when the incoming proof tries to prove the same transition
            // (L1_ALREADY_PROVED).
            _overrideWithHigherProof(_state, _resolver, blk, ts, tran, proof, local);

            emit TransitionProvedV2({
                blockId: local.blockId,
                tran: tran,
                prover: msg.sender,
                validityBond: local.tier.validityBond,
                tier: proof.tier,
                proposedIn: meta.proposedIn
            });
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

                emit TransitionProvedV2({
                    blockId: local.blockId,
                    tran: tran,
                    prover: msg.sender,
                    validityBond: 0,
                    tier: proof.tier,
                    proposedIn: meta.proposedIn
                });
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

                // Burn the contest bond from the prover.
                LibBonds.debitBond(_state, _resolver, msg.sender, local.tier.contestBond);

                // We retain the contest bond within the transition, just in case this configuration
                // is altered to a different value before the contest is resolved.
                //
                // It's worth noting that the previous value of ts.contestBond doesn't have any
                // significance.
                ts.contestBond = local.tier.contestBond;
                ts.contester = msg.sender;

                emit TransitionContestedV2({
                    blockId: local.blockId,
                    tran: tran,
                    contester: msg.sender,
                    contestBond: local.tier.contestBond,
                    tier: proof.tier,
                    proposedIn: meta.proposedIn
                });
            }
        }

        ts.timestamp = uint64(block.timestamp);
        _state.transitions[local.slot][local.tid] = ts;
    }

    /// @dev Handle the transition initialization logic.
    /// @param _state Current TaikoData.State.
    /// @param _blk Current TaikoData.Block.
    /// @param _tran Current TaikoData.Transition.
    /// @param _local Local state variables.
    /// @return tid_ Transition ID.
    /// @return ts_ Transition state.
    function _fetchOrCreateTransition(
        TaikoData.State storage _state,
        TaikoData.BlockV2 storage _blk,
        TaikoData.Transition memory _tran,
        Local memory _local
    )
        private
        returns (uint24 tid_, TaikoData.TransitionState memory ts_)
    {
        tid_ = LibUtils.getTransitionId(_state, _blk, _local.slot, _tran.parentHash);

        if (tid_ == 0) {
            // In cases where a transition with the provided parentHash is not found, we must
            // essentially "create" one and set it to its initial state. This initial state can be
            // viewed as a special transition on tier-0.
            //
            // Subsequently, we transform this tier-0 transition into a non-zero-tier transition
            // with a proof. This approach ensures that the same logic is applicable for both
            // 0-to-non-zero transition updates and non-zero-to-non-zero transition updates.
            unchecked {
                // Unchecked is safe: Not realistic 2**32 different fork choice per block will be
                // proven and none of them is valid.
                tid_ = _blk.nextTransitionId++;
            }

            // Keep in mind that state.transitions are also reusable storage slots, so it's
            // necessary to reinitialize all transition fields below.
            ts_.timestamp = _local.proposedAt;

            if (tid_ == 1) {
                // This approach serves as a cost-saving technique for the majority of blocks, where
                // the first transition is expected to be the correct one. Writing to `transitions`
                // is more economical since it resides in the ring buffer, whereas writing to
                // `transitionIds` is not as cost-effective.
                ts_.key = _tran.parentHash;

                // In the case of this first transition, the block's assigned prover has the
                // privilege to re-prove it, but only when the assigned prover matches the previous
                // prover. To ensure this, we establish the transition's prover as the block's
                // assigned prover. Consequently, when we carry out a 0-to-non-zero transition
                // update, the previous prover will consistently be the block's assigned prover.
                //
                // While alternative implementations are possible, introducing such changes would
                // require additional if-else logic.
                ts_.prover = _local.assignedProver;
            } else {
                // Furthermore, we index the transition for future retrieval. It's worth emphasizing
                // that this mapping for indexing is not reusable. However, given that the majority
                // of blocks will only possess one transition — the correct one — we don't need
                // to be concerned about the cost in this case.

                // There is no need to initialize ts.key here because it's only used when tid == 1.
                _state.transitionIds[_local.blockId][_tran.parentHash] = tid_;
            }
        } else {
            // A transition with the provided parentHash has been located.
            ts_ = _state.transitions[_local.slot][tid_];
        }
    }

    /// @dev Handles what happens when either the first transition is being proven or there is a
    /// higher tier proof incoming.
    /// @param _state Current TaikoData.State.
    /// @param _resolver Address resolver interface.
    /// @param _blk Current TaikoData.Block.
    /// @param _ts Current TaikoData.TransitionState.
    /// @param _tran Current TaikoData.Transition.
    /// @param _proof Current TaikoData.TierProof.
    /// @param _local Local state variables.
    function _overrideWithHigherProof(
        TaikoData.State storage _state,
        IAddressResolver _resolver,
        TaikoData.BlockV2 storage _blk,
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
                // The contested transition is proven to be valid, contester loses the game.
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
            // - 1) the transition is proved for the first time, or
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

    /// @dev Calculates the reward after applying a 12.5% friction.
    /// @param _amount The initial amount before applying friction.
    /// @return The amount after applying 12.5% friction.
    function _rewardAfterFriction(uint256 _amount) private pure returns (uint256) {
        return _amount == 0 ? 0 : (_amount * 7) >> 3;
    }

    /// @dev Determines if the liveness bond should be returned.
    /// @param _local The local state containing various parameters.
    /// @param _proofData The proof data to be checked.
    /// @return True if the liveness bond should be returned, false otherwise.
    function _returnLivenessBond(
        Local memory _local,
        bytes memory _proofData
    )
        private
        pure
        returns (bool)
    {
        return (_local.inProvingWindow && _local.tid == 1)
            || (
                _local.isTopTier && _proofData.length == 32
                    && bytes32(_proofData) == LibStrings.H_RETURN_LIVENESS_BOND
            );
    }
}
