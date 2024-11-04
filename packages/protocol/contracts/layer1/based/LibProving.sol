// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../verifiers/IVerifier.sol";
import "./LibBonds.sol";
import "./LibData.sol";
import "./LibUtils.sol";
import "./LibVerifying.sol";

/// @title LibProving
/// @notice A library that offers helper functions for proving and contesting block transitions.
/// @custom:security-contact security@taiko.xyz
library LibProving {
    using LibMath for uint256;

    // A struct to get around stack too deep issue and to cache state variables for multiple reads.
    struct Local {
        TaikoData.SlotB b;
        ITierProvider.Tier tier;
        ITierProvider.Tier minTier;
        TaikoData.BlockMetadataV2 meta;
        TaikoData.TierProof proof;
        bytes32 metaHash;
        uint64 slot;
        uint64 blockId;
        uint24 tid;
        bool lastUnpausedAt;
        bool isTopTier;
        bool inProvingWindow;
        bool sameTransition;
    }

    /// @dev Emitted when a transition is proved.
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

    /// @dev Emitted when a transition is contested.
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

    /// @dev Emitted when proving is paused or unpaused.
    /// @param paused The pause status.
    event ProvingPaused(bool paused);

    error L1_ALREADY_CONTESTED();
    error L1_ALREADY_PROVED();
    error L1_BLOCK_MISMATCH();
    error L1_CANNOT_CONTEST();
    error L1_DIFF_VERIFIER();
    error L1_INVALID_BLOCK_ID();
    error L1_INVALID_PARAMS();
    error L1_INVALID_PAUSE_STATUS();
    error L1_INVALID_TIER();
    error L1_INVALID_TRANSITION();
    error L1_NOT_ASSIGNED_PROVER();
    error L1_PROVING_PAUSED();

    /// @dev Pauses or unpauses the proving process.
    /// @param _state Pointer to the protocol's storage.
    /// @param _pause The pause status.
    function pauseProving(TaikoData.State storage _state, bool _pause) public {
        require(_state.slotB.provingPaused != _pause, L1_INVALID_PAUSE_STATUS());
        _state.slotB.provingPaused = _pause;

        if (!_pause) {
            _state.slotB.lastUnpausedAt = uint64(block.timestamp);
        }
        emit ProvingPaused(_pause);
    }

    /// @dev Proves or contests multiple Taiko L2 blocks.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _resolver The address resolver.
    /// @param _blockIds The index of the block to prove. This is also used to select the right
    /// implementation version.
    /// @param _inputs A list of abi-encoded (TaikoData.BlockMetadataV2, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    /// @param _batchProof A list of abi-encoded TaikoData.TierProof that contains the
    /// batch/aggregated proof for the given blocks.
    function proveBlocks(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64[] calldata _blockIds,
        bytes[] calldata _inputs,
        bytes calldata _batchProof
    )
        public // Will reach contract size limit if changed to `internal`
    {
        require(_blockIds.length != 0, L1_INVALID_PARAMS());
        require(_blockIds.length == _inputs.length, L1_INVALID_PARAMS());

        TaikoData.TierProof memory batchProof;
        if (_batchProof.length != 0) {
            batchProof = abi.decode(_batchProof, (TaikoData.TierProof));
            require(batchProof.tier != 0, L1_INVALID_TIER());
        }

        IVerifier.ContextV2[] memory ctxs = new IVerifier.ContextV2[](_blockIds.length);
        bytes32 batchVerifierName;
        bool batchVerifierNameSet;

        // This loop iterates over each block ID in the _blockIds array. For each block ID, it calls
        // the _proveBlock function to get the context and verifier.
        for (uint256 i; i < _blockIds.length; ++i) {
            bytes32 _verifierName;
            (ctxs[i], _verifierName) =
                _proveBlock(_state, _config, _resolver, _blockIds[i], _inputs[i], batchProof);

            // Verify that if batchProof is used, the verifier is the same for all blocks.
            if (batchProof.tier != 0) {
                if (!batchVerifierNameSet) {
                    batchVerifierNameSet = true;
                    batchVerifierName = _verifierName;
                } else {
                    require(batchVerifierName == _verifierName, L1_DIFF_VERIFIER());
                }
            }
        }

        // If batch verifier name is not empty, verify the batch proof.
        if (batchVerifierName != LibStrings.B_TIER_OPTIMISTIC) {
            IVerifier(_resolver.resolve(batchVerifierName, false)).verifyBatchProof(
                ctxs, batchProof
            );
        }
    }

    /// @dev Proves or contests a single Taiko L2 block.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _resolver The address resolver.
    /// @param _blockId The index of the block to prove. This is also used to select the right
    /// implementation version.
    /// @param _input An abi-encoded (TaikoData.BlockMetadataV2, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    function proveBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _blockId,
        bytes calldata _input
    )
        public // Will reach contract size limit if changed to `internal`
    {
        TaikoData.TierProof memory noBatchProof;
        _proveBlock(_state, _config, _resolver, _blockId, _input, noBatchProof);
    }

    /// @dev Proves or contests a single Taiko L2 block.
    /// @param _state Pointer to the protocol's storage.
    /// @param _config The protocol's configuration.
    /// @param _resolver The address resolver.
    /// @param _blockId The index of the block to prove. This is also used to select the right
    /// implementation version.
    /// @param _input An abi-encoded (TaikoData.BlockMetadataV2, TaikoData.Transition,
    /// TaikoData.TierProof) tuple.
    /// @param _batchProof An abi-encoded TaikoData.TierProof that contains the batch/aggregated
    /// proof for the given blocks.
    /// @return ctx_ The context of the verifier.
    /// @return verifierName_ The name of the verifier.
    function _proveBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        uint64 _blockId,
        bytes calldata _input,
        TaikoData.TierProof memory _batchProof
    )
        private
        returns (IVerifier.ContextV2 memory ctx_, bytes32 verifierName_)
    {
        Local memory local;
        local.b = _state.slotB;
        local.blockId = _blockId;

        if (_batchProof.tier == 0) {
            // No batch proof is available, each transition is proving using a separate proof.
            (local.meta, ctx_.tran, local.proof) = abi.decode(
                _input, (TaikoData.BlockMetadataV2, TaikoData.Transition, TaikoData.TierProof)
            );
        } else {
            // All transitions are proving using the batch proof.
            (local.meta, ctx_.tran) =
                abi.decode(_input, (TaikoData.BlockMetadataV2, TaikoData.Transition));
            local.proof = _batchProof;
        }

        require(ctx_.tran.parentHash != 0, L1_INVALID_TRANSITION());
        require(ctx_.tran.blockHash != 0, L1_INVALID_TRANSITION());
        require(ctx_.tran.stateRoot != 0, L1_INVALID_TRANSITION());

        // Check that the block has been proposed but has not yet been verified.
        require(_blockId == local.meta.id, L1_INVALID_BLOCK_ID());
        require(local.meta.id > local.b.lastVerifiedBlockId, L1_INVALID_BLOCK_ID());
        require(local.meta.id < local.b.numBlocks, L1_INVALID_BLOCK_ID());

        local.slot = local.meta.id % _config.blockRingBufferSize;
        TaikoData.BlockV2 storage blk = _state.blocks[local.slot];

        local.metaHash = blk.metaHash;

        // Check the integrity of the block data. It's worth noting that in theory, this check may
        // be skipped, but it's included for added caution.
        require(local.metaHash == keccak256(abi.encode(local.meta)), L1_BLOCK_MISMATCH());

        // Each transition is uniquely identified by the parentHash, with the blockHash and
        // stateRoot open for later updates as higher-tier proofs become available. In cases where a
        // transition with the specified parentHash does not exist, a new transition will be
        // created.
        TaikoData.TransitionState memory ts;
        (local.tid, ts) = _fetchOrCreateTransition(_state, blk, ctx_.tran, local);

        // Reset a deprecated field.
        ts.__reserved1 = 0;

        // The new proof must meet or exceed the minimum tier required by the block or the previous
        // proof; it cannot be on a lower tier.
        require(local.proof.tier != 0, L1_INVALID_TIER());
        require(local.proof.tier >= local.meta.minTier, L1_INVALID_TIER());
        require(local.proof.tier >= ts.tier, L1_INVALID_TIER());

        // Retrieve the tier configurations. If the tier is not supported, the subsequent action
        // will result in a revert.
        {
            ITierRouter tierRouter = ITierRouter(_resolver.resolve(LibStrings.B_TIER_ROUTER, false));
            ITierProvider tierProvider = ITierProvider(tierRouter.getProvider(local.blockId));

            local.tier = tierProvider.getTier(local.proof.tier);
            local.minTier = tierProvider.getTier(local.meta.minTier);
            local.isTopTier = local.tier.contestBond == 0;
        }

        local.inProvingWindow = !LibUtils.isPostDeadline({
            _tsTimestamp: ts.timestamp,
            _lastUnpausedAt: local.b.lastUnpausedAt,
            _windowMinutes: local.minTier.provingWindow
        });

        // Checks if only the assigned prover is permissioned to prove the block. The assigned
        // prover is granted exclusive permission to prove only the first transition.
        if (
            !local.isTopTier && ts.contester == address(0) && local.tid == 1 && ts.tier == 0
                && local.inProvingWindow
        ) {
            require(msg.sender == local.meta.proposer, L1_NOT_ASSIGNED_PROVER());
        }
        // We must verify the proof, and any failure in proof verification will result in a revert.
        // It's crucial to emphasize that the proof can be assessed in two potential modes: "proving
        // mode" and "contesting mode." However, the precise verification logic is defined within
        // each tier's IVerifier contract implementation. We simply specify to the verifier contract
        // which mode it should utilize - if the new tier is higher than the previous tier, we
        // employ the proving mode; otherwise, we employ the contesting mode (the new tier cannot be
        // lower than the previous tier, this has been checked above). It's obvious that proof
        // verification is entirely decoupled from Taiko's core protocol.
        if (local.tier.verifierName != "") {
            ctx_ = IVerifier.ContextV2({
                metaHash: local.metaHash,
                blobHash: local.meta.blobHash,
                // Separate msgSender to allow the prover to be any address in the future.
                prover: msg.sender,
                msgSender: msg.sender,
                blockId: local.blockId,
                isContesting: local.proof.tier == ts.tier && !local.isTopTier,
                blobUsed: local.meta.blobUsed,
                tran: ctx_.tran
            });

            verifierName_ = local.tier.verifierName;

            if (_batchProof.tier == 0) {
                // In the case of per-transition proof, we verify the proof.
                IVerifier(_resolver.resolve(local.tier.verifierName, false)).verifyProof(
                    LibData.verifierContextV2ToV1(ctx_), ctx_.tran, local.proof
                );
            }
        }

        if (LibUtils.isSyncBlock(_config.stateRootSyncInternal, local.blockId)) {
            local.sameTransition =
                ctx_.tran.blockHash == ts.blockHash && ctx_.tran.stateRoot == ts.stateRoot;
        } else {
            local.sameTransition = ctx_.tran.blockHash == ts.blockHash;

            // For non sync-block, we set the stateRoot to 0 before emitting it in events
            ctx_.tran.stateRoot = 0;
        }

        if (local.proof.tier > ts.tier) {
            // Handles the case when an incoming tier is higher than the current transition's tier.
            // Reverts when the incoming proof tries to prove the same transition
            // (L1_ALREADY_PROVED).
            _overrideWithHigherProof(_state, _resolver, blk, ts, ctx_.tran, local.proof, local);

            emit TransitionProvedV2({
                blockId: local.blockId,
                tran: ctx_.tran,
                prover: msg.sender,
                validityBond: local.tier.validityBond,
                tier: local.proof.tier,
                proposedIn: local.meta.proposedIn
            });
        } else {
            // New transition and old transition on the same tier - and if this transaction tries to
            // prove the same, it reverts
            require(!local.sameTransition, L1_ALREADY_PROVED());

            if (local.isTopTier) {
                // The top tier prover re-proves.
                assert(local.tier.validityBond == 0);
                assert(ts.validityBond == 0 && ts.contester == address(0));

                ts.prover = msg.sender;
                ts.blockHash = ctx_.tran.blockHash;
                ts.stateRoot = ctx_.tran.stateRoot;

                emit TransitionProvedV2({
                    blockId: local.blockId,
                    tran: ctx_.tran,
                    prover: msg.sender,
                    validityBond: 0,
                    tier: local.proof.tier,
                    proposedIn: local.meta.proposedIn
                });
            } else {
                // Contesting but not on the highest tier
                require(ts.contester == address(0), L1_ALREADY_CONTESTED());

                // Making it a non-sliding window, relative when ts.timestamp was registered (or to
                // lastUnpaused if that one is bigger)
                require(
                    !LibUtils.isPostDeadline(
                        ts.timestamp, local.b.lastUnpausedAt, local.tier.cooldownWindow
                    ),
                    L1_CANNOT_CONTEST()
                );

                // Burn the contest bond from the prover.
                LibBonds.debitBond(
                    _state, _resolver, msg.sender, local.blockId, local.tier.contestBond
                );

                // We retain the contest bond within the transition, just in case this configuration
                // is altered to a different value before the contest is resolved. It's worth noting
                // that the previous value of ts.contestBond doesn't have any significance.
                ts.contestBond = local.tier.contestBond;
                ts.contester = msg.sender;

                emit TransitionContestedV2({
                    blockId: local.blockId,
                    tran: ctx_.tran,
                    contester: msg.sender,
                    contestBond: local.tier.contestBond,
                    tier: local.proof.tier,
                    proposedIn: local.meta.proposedIn
                });
            }
        }

        ts.timestamp = uint64(block.timestamp);
        _state.transitions[local.slot][local.tid] = ts;

        if (
            !_state.slotB.provingPaused && LibUtils.shouldVerifyBlocks(_config, local.meta.id, true)
        ) {
            LibVerifying.verifyBlocks(_state, _config, _resolver, _config.maxBlocksToVerify);
        }
    }

    /// @dev Handle the transition initialization logic.
    /// @param _state Pointer to the protocol's storage.
    /// @param _blk Current TaikoData.BlockV2.
    /// @param _tran Current TaikoData.Transition.
    /// @param _local Current Local struct.
    /// @return tid_ The transition ID.
    /// @return ts_ The transition state.
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
            // viewed as a special transition on tier-0. Subsequently, we transform this tier-0
            // transition into a non-zero-tier transition with a proof. This approach ensures that
            // the same logic is applicable for both 0-to-non-zero transition updates and
            // non-zero-to-non-zero transition updates.
            unchecked {
                // Unchecked is safe: Not realistic 2**32 different fork choice per block will be
                // proven and none of them is valid
                tid_ = _blk.nextTransitionId++;
            }

            // Keep in mind that state.transitions are also reusable storage slots, so it's
            // necessary to reinitialize all transition fields below.
            ts_.timestamp = _local.meta.proposedAt;

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
                // While alternative implementations are possible, introducing such changes would
                // require additional if-else logic.
                ts_.prover = _local.meta.proposer;
            } else {
                // Furthermore, we index the transition for future retrieval. It's worth emphasizing
                // that this mapping for indexing is not reusable. However, given that the majority
                // of blocks will only possess one transition — the correct one — we don't need
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
    /// higher tier proof incoming.
    /// @param _state Pointer to the protocol's storage.
    /// @param _resolver The address resolver.
    /// @param _blk Current TaikoData.BlockV2.
    /// @param _ts Current TaikoData.TransitionState.
    /// @param _tran Current TaikoData.Transition.
    /// @param _proof Current TaikoData.TierProof.
    /// @param _local Current Local struct.
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
                // The contested transition is proven to be valid, contester loses the game
                reward = _rewardAfterFriction(_ts.contestBond);

                // We return the validity bond back, but the original prover doesn't get any reward.
                LibBonds.creditBond(_state, _ts.prover, _local.blockId, _ts.validityBond);
            } else {
                // The contested transition is proven to be invalid, contester wins the game.
                // Contester gets 3/4 of reward, the new prover gets 1/4.
                reward = _rewardAfterFriction(_ts.validityBond) >> 2;
                unchecked {
                    LibBonds.creditBond(
                        _state, _ts.contester, _local.blockId, _ts.contestBond + reward * 3
                    );
                }
            }
        } else {
            require(!_local.sameTransition, L1_ALREADY_PROVED());

            // The code below will be executed if 1) the transition is proved for the first time
            // or 2) the transition is contested.
            reward = _rewardAfterFriction(_ts.validityBond);

            if (!_blk.livenessBondReturned) {
                _blk.livenessBondReturned = true;

                if (_returnLivenessBond(_local, _proof.data)) {
                    if (_local.meta.proposer == msg.sender) {
                        unchecked {
                            reward += _local.meta.livenessBond;
                        }
                    } else {
                        LibBonds.creditBond(
                            _state, _local.meta.proposer, _local.blockId, _local.meta.livenessBond
                        );
                    }
                } else {
                    // Reward a majority of liveness bond to the actual prover
                    unchecked {
                        reward += _rewardAfterFriction(_local.meta.livenessBond);
                    }
                }
            }
        }

        unchecked {
            if (reward > _local.tier.validityBond) {
                LibBonds.creditBond(
                    _state, msg.sender, _local.blockId, reward - _local.tier.validityBond
                );
            } else if (reward < _local.tier.validityBond) {
                LibBonds.debitBond(
                    _state, _resolver, msg.sender, _local.blockId, _local.tier.validityBond - reward
                );
            }
        }

        _ts.validityBond = _local.tier.validityBond;
        _ts.contester = address(0);
        _ts.prover = msg.sender;
        _ts.tier = _proof.tier;

        if (!_local.sameTransition) {
            _ts.blockHash = _tran.blockHash;
            _ts.stateRoot = _tran.stateRoot;
        }
    }

    /// @dev Returns the reward after applying 12.5% friction.
    /// @param _amount The amount to apply friction to.
    /// @return The reward after applying friction.
    function _rewardAfterFriction(uint256 _amount) private pure returns (uint256) {
        return (_amount * 7) >> 3;
    }

    /// @dev Returns if the liveness bond shall be returned.
    /// @param _local Current Local struct.
    /// @param _proofData The proof data.
    /// @return True if the liveness bond shall be returned, false otherwise.
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
