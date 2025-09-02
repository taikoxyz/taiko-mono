// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/signal/ISignalService.sol";
// Surge: import surge verifier related files
import "src/layer1/surge/verifiers/ISurgeVerifier.sol";
import "src/layer1/surge/verifiers/LibProofType.sol";
import "./ITaikoInbox.sol";
import "./IProposeBatch.sol";
import "./LibVerifying.sol";

/// @title TaikoInbox
/// @notice Acts as the inbox for the Taiko Alethia protocol, a simplified version of the
/// original Taiko-Based Contestable Rollup (BCR). The tier-based proof system and
/// contestation mechanisms have been removed.
///
/// Key assumptions of this protocol:
/// - Block proposals and proofs are asynchronous. Proofs are not available at proposal time,
///   unlike Taiko Gwyneth, which assumes synchronous composability.
/// - Proofs are presumed error-free and thoroughly validated, with subproofs/multiproofs management
/// delegated to IVerifier contracts.
///
/// @dev Registered in the address resolver as "taiko".
/// @custom:security-contact security@nethermind.io
abstract contract TaikoInbox is EssentialContract, ITaikoInbox, IProposeBatch, ITaiko {
    using LibMath for uint256;
    using SafeERC20 for IERC20;
    using LibProofType for LibProofType.ProofType;

    address public immutable inboxWrapper;
    address public immutable dao;
    address public immutable verifier;
    address public immutable bondToken;
    ISignalService public immutable signalService;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // External functions ------------------------------------------------------------------------

    constructor(
        address _inboxWrapper,
        address _dao,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        nonZeroAddr(_dao)
        nonZeroAddr(_signalService)
        EssentialContract(address(0))
    {
        inboxWrapper = _inboxWrapper;
        dao = _dao;
        verifier = _verifier;
        bondToken = _bondToken;
        signalService = ISignalService(_signalService);
    }

    function init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    /// @notice Proposes a batch of blocks.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList Transaction list in calldata. If the txList is empty, blob will be used for
    /// data availability.
    /// @return info_ Information of the proposed batch, which is used for constructing blocks
    /// offchain.
    /// @return meta_ Metadata of the proposed batch, which is used for proving the batch.
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        public
        override(ITaikoInbox, IProposeBatch)
        nonReentrant
        returns (BatchInfo memory info_, BatchMetadata memory meta_)
    {
        Stats2 memory stats2 = state.stats2;
        Config memory config = pacayaConfig();
        require(stats2.numBatches >= config.forkHeights.pacaya, ForkNotActivated());

        unchecked {
            require(
                stats2.numBatches <= stats2.lastVerifiedBatchId + config.maxUnverifiedBatches,
                TooManyBatches()
            );

            BatchParams memory params = abi.decode(_params, (BatchParams));

            {
                if (inboxWrapper == address(0)) {
                    require(params.proposer == address(0), CustomProposerNotAllowed());
                    params.proposer = msg.sender;

                    // blob hashes are only accepted if the caller is trusted.
                    require(params.blobParams.blobHashes.length == 0, InvalidBlobParams());
                    require(params.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                } else {
                    require(params.proposer != address(0), CustomProposerMissing());
                    require(msg.sender == inboxWrapper, NotInboxWrapper());
                }

                // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
                // preconfer address. This will allow us to implement preconfirmation features in L2
                // anchor transactions.
                if (params.coinbase == address(0)) {
                    params.coinbase = params.proposer;
                }

                if (params.revertIfNotFirstProposal) {
                    require(state.stats2.lastProposedIn != block.number, NotFirstProposal());
                }
            }

            bool calldataUsed = _txList.length != 0;

            if (calldataUsed) {
                // calldata is used for data availability
                require(params.blobParams.firstBlobIndex == 0, InvalidBlobParams());
                require(params.blobParams.numBlobs == 0, InvalidBlobParams());
                require(params.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                require(params.blobParams.blobHashes.length == 0, InvalidBlobParams());
            } else if (params.blobParams.blobHashes.length == 0) {
                // this is a normal batch, blobs are created and used in the current batches.
                // firstBlobIndex can be non-zero.
                require(params.blobParams.numBlobs != 0, BlobNotSpecified());
                require(params.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                params.blobParams.createdIn = uint64(block.number);
            } else {
                // this is a forced-inclusion batch, blobs were created in early blocks and are used
                // in the current batches
                require(params.blobParams.createdIn != 0, InvalidBlobCreatedIn());
                require(params.blobParams.numBlobs == 0, InvalidBlobParams());
                require(params.blobParams.firstBlobIndex == 0, InvalidBlobParams());
            }

            // Keep track of last batch's information.
            Batch storage lastBatch =
                state.batches[(stats2.numBatches - 1) % config.batchRingBufferSize];

            (uint64 anchorBlockId, uint64 lastBlockTimestamp) = _validateBatchParams(
                params,
                config.maxAnchorHeightOffset,
                config.maxSignalsToReceive,
                config.maxBlocksPerBatch,
                lastBatch
            );

            // This section constructs the metadata for the proposed batch, which is crucial for
            // nodes/clients to process the batch. The metadata itself is not stored on-chain;
            // instead, only its hash is kept.
            // The metadata must be supplied as calldata prior to proving the batch, enabling the
            // computation and verification of its integrity through the comparison of the metahash.
            //
            // Note that `difficulty` has been removed from the metadata. The client and prover must
            // use
            // the following approach to calculate a block's difficulty:
            //  `keccak256(abi.encode("TAIKO_DIFFICULTY", block.number))`
            info_ = BatchInfo({
                txsHash: bytes32(0), // to be initialised later
                //
                // Data to build L2 blocks
                blocks: params.blocks,
                blobHashes: new bytes32[](0), // to be initialised later
                extraData: bytes32(uint256(config.baseFeeConfig.sharingPctg)),
                coinbase: params.coinbase,
                proposedIn: uint64(block.number),
                blobCreatedIn: params.blobParams.createdIn,
                blobByteOffset: params.blobParams.byteOffset,
                blobByteSize: params.blobParams.byteSize,
                gasLimit: config.blockMaxGasLimit,
                // Surge: custom L2 basefee set by the proposer
                baseFee: params.baseFee,
                lastBlockId: 0, // to be initialised later
                lastBlockTimestamp: lastBlockTimestamp,
                //
                // Data for the L2 anchor transaction, shared by all blocks in the batch
                anchorBlockId: anchorBlockId,
                anchorBlockHash: blockhash(anchorBlockId),
                baseFeeConfig: config.baseFeeConfig
            });

            require(info_.anchorBlockHash != 0, ZeroAnchorBlockHash());

            info_.lastBlockId = stats2.numBatches == config.forkHeights.pacaya
                ? stats2.numBatches + uint64(params.blocks.length) - 1
                : lastBatch.lastBlockId + uint64(params.blocks.length);

            (info_.txsHash, info_.blobHashes) =
                _calculateTxsHash(keccak256(_txList), params.blobParams);

            meta_ = BatchMetadata({
                infoHash: keccak256(abi.encode(info_)),
                proposer: params.proposer,
                batchId: stats2.numBatches,
                proposedAt: uint64(block.timestamp)
            });

            Batch storage batch = state.batches[stats2.numBatches % config.batchRingBufferSize];

            // SSTORE #1
            batch.metaHash = keccak256(abi.encode(meta_));

            // SSTORE #2 {{
            batch.batchId = stats2.numBatches;
            batch.lastBlockTimestamp = lastBlockTimestamp;
            batch.anchorBlockId = anchorBlockId;
            batch.nextTransitionId = 1;
            batch.verifiedTransitionId = 0;
            batch.finalisingTransitionIndex = 0;
            // SSTORE }}

            _debitBond(params.proposer, config.livenessBondBase);

            // SSTORE #3 {{
            batch.lastBlockId = info_.lastBlockId;
            batch.reserved3 = 0;
            batch.livenessBond = config.livenessBondBase;
            // SSTORE }}

            stats2.numBatches += 1;
            require(
                config.forkHeights.shasta == 0 || stats2.numBatches < config.forkHeights.shasta,
                BeyondCurrentFork()
            );
            stats2.lastProposedIn = uint56(block.number);

            emit BatchProposed(info_, meta_, _txList);
        } // end-of-unchecked

        LibVerifying.verifyBatches(state, config, stats2, 1, dao, verifier, signalService);
    }

    /// @notice Proves multiple batches with a single aggregated proof.
    /// @param _params ABI-encoded parameter containing:
    /// - proofType: Type of proof to be used.
    /// - metas: Array of metadata for each batch being proved.
    /// - transitions: Array of batch transitions to be proved.
    /// @param _proof The aggregated cryptographic proof proving the batches transitions.
    function proveBatches(bytes calldata _params, bytes calldata _proof) external nonReentrant {
        // Surge: Add proof type to the parameters
        (LibProofType.ProofType proofType, BatchMetadata[] memory metas, Transition[] memory trans)
        = abi.decode(_params, (LibProofType.ProofType, BatchMetadata[], Transition[]));

        require(metas.length != 0, NoBlocksToProve());
        require(metas.length == trans.length, ArraySizesMismatch());

        Stats2 memory stats2 = state.stats2;

        Config memory config = pacayaConfig();
        IVerifier.Context[] memory ctxs = new IVerifier.Context[](metas.length);

        // Surge: Remove `hasConflictingProof` variable

        for (uint256 i; i < metas.length; ++i) {
            BatchMetadata memory meta = metas[i];

            require(meta.batchId >= config.forkHeights.pacaya, ForkNotActivated());
            require(
                config.forkHeights.shasta == 0 || meta.batchId < config.forkHeights.shasta,
                BeyondCurrentFork()
            );

            require(meta.batchId > stats2.lastVerifiedBatchId, BatchNotFound());
            require(meta.batchId < stats2.numBatches, BatchNotFound());

            Transition memory tran = trans[i];
            require(tran.parentHash != 0, InvalidTransitionParentHash());
            require(tran.blockHash != 0, InvalidTransitionBlockHash());
            require(tran.stateRoot != 0, InvalidTransitionStateRoot());

            ctxs[i].batchId = meta.batchId;
            ctxs[i].metaHash = keccak256(abi.encode(meta));
            ctxs[i].transition = tran;

            // Verify the batch's metadata.
            uint256 slot = meta.batchId % config.batchRingBufferSize;
            Batch storage batch = state.batches[slot];
            require(ctxs[i].metaHash == batch.metaHash, MetaHashMismatch());

            // Finds out if this transition is overwriting an existing one (with the same parent
            // hash) or is a new one.
            uint24 tid;

            // Surge: block to avoid stack too deep
            {
                uint24 nextTransitionId = batch.nextTransitionId;
                if (nextTransitionId > 1) {
                    // This batch has at least one transition.
                    // Surge: get the first transition
                    if (state.transitions[slot][1][0].parentHash == tran.parentHash) {
                        // Overwrite the first transition.
                        tid = 1;
                    } else if (nextTransitionId > 2) {
                        // Retrieve the transition ID using the parent hash from the mapping. If the
                        // ID
                        // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                        // existing transition.
                        tid = state.transitionIds[meta.batchId][tran.parentHash];
                    }
                }
            }

            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                unchecked {
                    tid = batch.nextTransitionId++;
                }
            } else {
                TransitionState[] storage transitions = state.transitions[slot][tid];

                // Surge: `mti` is the matching transition index
                uint256 mti = type(uint256).max;
                {
                    // Surge: Try to find a matching transition
                    uint256 numTransitions = transitions.length;
                    for (uint256 j; j < numTransitions; ++j) {
                        bytes32 _blockHash = transitions[j].blockHash;
                        bytes32 _stateRoot = transitions[j].stateRoot;
                        if (
                            _blockHash == tran.blockHash
                                && (_stateRoot == 0 || _stateRoot == tran.stateRoot)
                        ) {
                            mti = j;
                            break;
                        }
                    }
                }

                // Surge: Remove the notion of reusing invalidated transitions since we no longer
                // invalidate on conflicting proofs

                // Surge: Modify the logic of checking for matching transitions based on the
                // new finality gadget

                // A matching transition was found
                if (mti != type(uint256).max) {
                    // Existing proof type of the matching transition
                    LibProofType.ProofType _proofType = transitions[mti].proofType;

                    // Take action depending upon existing proof type
                    if (
                        _proofType.isZkTeeProof()
                            || (_proofType.isZkProof() && proofType.isZkProof())
                            || (_proofType.isTeeProof() && proofType.isTeeProof())
                    ) {
                        // We skip the transition if the existing proof type is ZK + TEE or if the
                        // existing proof type is same as the newly submitted proof type
                        continue;
                    }

                    // At this point, the transition would be both ZK + TEE proven
                    transitions[mti].proofType = _proofType.combine(proofType);
                    // The sender of the latest set of proofs becomes the bond receiver
                    transitions[mti].bondReceiver = msg.sender;
                } else {
                    TransitionState memory _ts;

                    // Add the conflicting transition
                    _ts.blockHash = tran.blockHash;
                    _ts.stateRoot = meta.batchId % config.stateRootSyncInternal == 0
                        ? tran.stateRoot
                        : bytes32(0);
                    _ts.proofType = proofType;

                    // If the conflicting transition is finalising, the sender of the proof becomes
                    // the bond receiver
                    if (proofType.isZkTeeProof()) {
                        _ts.bondReceiver = msg.sender;
                    }

                    // _ts.createdAt may not be set since it is irrelevant for conflicting
                    // transitions

                    transitions.push(_ts);

                    emit ConflictingProof(meta.batchId, _ts, tran);
                }

                // Surge: remove transition state and shift it to the conditionals above

                // Proceed with other transitions.
                continue;
            }

            // Surge: prepare the transition state in memory instead of storage
            TransitionState memory __ts;

            if (tid == 1) {
                __ts.parentHash = tran.parentHash;
            } else {
                state.transitionIds[meta.batchId][tran.parentHash] = tid;
            }

            __ts.blockHash = tran.blockHash;
            __ts.stateRoot =
                meta.batchId % config.stateRootSyncInternal == 0 ? tran.stateRoot : bytes32(0);
            __ts.proofType = proofType;

            bool inProvingWindow;
            unchecked {
                inProvingWindow = block.timestamp <= uint256(meta.proposedAt) + config.provingWindow;
            }

            // Surge: Set the bond receiver based on the proving window and received proof type
            if (proofType.isZkTeeProof()) {
                __ts.bondReceiver = inProvingWindow ? meta.proposer : msg.sender;
            }

            // Surge: Remove initialising `ts.provingWindow` and `ts.prover`

            __ts.createdAt = uint48(block.timestamp);

            // Surge: add the transition to the transitions array in storage
            state.transitions[slot][tid].push(__ts);
        }

        // Surge: We use the ISurgeVerifier interface
        LibProofType.ProofType __proofType = ISurgeVerifier(verifier).verifyProof(ctxs, _proof);
        // Surge: check that proof type sent in the parameters matches the
        // proof type returned by the verifier
        require(__proofType.equals(proofType), InvalidProofType());

        // Emit the event
        {
            uint64[] memory batchIds = new uint64[](metas.length);
            for (uint256 i; i < metas.length; ++i) {
                batchIds[i] = metas[i].batchId;
            }

            emit BatchesProved(verifier, batchIds, trans);
        }

        LibVerifying.verifyBatches(
            state, config, stats2, metas.length, dao, verifier, signalService
        );
    }

    /// @notice Verify batches by providing the length of the batches to verify.
    /// @dev This function is necessary to upgrade from this fork to the next one.
    /// @param _length Specifis how many batches to verify. The max number of batches to verify is
    /// `pacayaConfig().maxBatchesToVerify * _length`.
    function verifyBatches(uint64 _length) external nonZeroValue(_length) nonReentrant {
        LibVerifying.verifyBatches(
            state, pacayaConfig(), state.stats2, _length, dao, verifier, signalService
        );
    }

    /// @inheritdoc ITaikoInbox
    function depositBond(uint256 _amount) external payable {
        state.bondBalance[msg.sender] += _handleDeposit(msg.sender, _amount);
    }

    /// @inheritdoc ITaikoInbox
    function withdrawBond(uint256 _amount) external {
        uint256 balance = state.bondBalance[msg.sender];
        require(balance >= _amount, InsufficientBond());

        emit BondWithdrawn(msg.sender, _amount);

        state.bondBalance[msg.sender] -= _amount;

        if (bondToken != address(0)) {
            IERC20(bondToken).safeTransfer(msg.sender, _amount);
        } else {
            LibAddress.sendEtherAndVerify(msg.sender, _amount);
        }
    }

    // Surge: enables permissionless rolling back of incase of a prover bug.
    /// @inheritdoc ITaikoInbox
    function rollbackBatches() external {
        Config memory config = pacayaConfig();

        uint64 startId = state.stats2.lastVerifiedBatchId + 1;
        uint64 endId = state.stats2.numBatches - 1;

        // If the verification streak has been broken, likely due to a prover bug, we rollback to
        // the last verified batch.
        if (
            block.timestamp
                - state.batches[state.stats2.lastVerifiedBatchId % config.batchRingBufferSize]
                    .lastBlockTimestamp > config.maxVerificationDelay
        ) {
            state.stats2.numBatches = startId;
        } else {
            revert RollbackNotAllowed();
        }

        emit BatchesRollbacked(startId, endId);
    }

    // View functions --------------------------------------------------------------------------

    /// @inheritdoc ITaikoInbox
    function getStats1() external view returns (Stats1 memory) {
        return state.stats1;
    }

    /// @inheritdoc ITaikoInbox
    function getStats2() external view returns (Stats2 memory) {
        return state.stats2;
    }

    /// @inheritdoc ITaikoInbox
    function getTransitionsById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        returns (TransitionState[] memory)
    {
        Config memory config = pacayaConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());
        require(_tid != 0, TransitionNotFound());
        require(_tid < batch.nextTransitionId, TransitionNotFound());

        // Surge: get the transitions array
        TransitionState[] storage transitions = state.transitions[slot][_tid];
        uint256 numTransitions = transitions.length;

        // Surge: return the transitions array instead of a single transition
        TransitionState[] memory _transitions = new TransitionState[](numTransitions);
        for (uint256 i; i < numTransitions; ++i) {
            _transitions[i] = transitions[i];
        }

        return _transitions;
    }

    /// @inheritdoc ITaikoInbox
    function getTransitionsByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (TransitionState[] memory)
    {
        Config memory config = pacayaConfig();
        uint256 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        uint24 tid;
        if (batch.nextTransitionId > 1) {
            // This batch has at least one transition.
            // Surge: get the first transition
            if (state.transitions[slot][1][0].parentHash == _parentHash) {
                // Overwrite the first transition.
                tid = 1;
            } else if (batch.nextTransitionId > 2) {
                // Retrieve the transition ID using the parent hash from the mapping. If the ID
                // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                // existing transition.
                tid = state.transitionIds[_batchId][_parentHash];
            }
        }

        require(tid != 0 && tid < batch.nextTransitionId, TransitionNotFound());

        // Surge: get the transitions array
        TransitionState[] storage transitions = state.transitions[slot][tid];
        uint256 numTransitions = transitions.length;

        // Surge: return the transitions array instead of a single transition
        TransitionState[] memory _transitions = new TransitionState[](numTransitions);
        for (uint256 i; i < numTransitions; ++i) {
            _transitions[i] = transitions[i];
        }

        return _transitions;
    }

    /// @inheritdoc ITaikoInbox
    function getLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        batchId_ = state.stats2.lastVerifiedBatchId;
        require(batchId_ >= pacayaConfig().forkHeights.pacaya, BatchNotFound());
        blockId_ = getBatch(batchId_).lastBlockId;
        ts_ = getBatchVerifyingTransition(batchId_);
    }

    /// @inheritdoc ITaikoInbox
    function getLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        batchId_ = state.stats1.lastSyncedBatchId;
        blockId_ = getBatch(batchId_).lastBlockId;
        ts_ = getBatchVerifyingTransition(batchId_);
    }

    // Surge: This function is required for stage-2
    /// @inheritdoc ITaikoInbox
    function getVerificationStreakStartedAt() external view returns (uint256) {
        Config memory config = pacayaConfig();

        // Surge: If the verification streak has been broken, we return the current timestamp,
        // otherwise we return the last recorded timestamp when the streak started.
        if (
            block.timestamp
                - state.batches[state.stats2.lastVerifiedBatchId % config.batchRingBufferSize]
                    .lastBlockTimestamp > config.maxVerificationDelay
        ) {
            return block.timestamp;
        } else {
            return state.stats1.verificationStreakStartedAt;
        }
    }

    /// @inheritdoc ITaikoInbox
    function bondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    /// @notice Determines the operational layer of the contract, whether it is on Layer 1 (L1) or
    /// Layer 2 (L2).
    /// @return True if the contract is operating on L1, false if on L2.
    function isOnL1() external pure override returns (bool) {
        return true;
    }

    // Public functions -------------------------------------------------------------------------

    /// @inheritdoc ITaikoInbox
    function getBatch(uint64 _batchId) public view returns (Batch memory batch_) {
        Config memory config = pacayaConfig();

        batch_ = state.batches[_batchId % config.batchRingBufferSize];
        require(batch_.batchId == _batchId, BatchNotFound());
    }

    /// @inheritdoc ITaikoInbox
    function getBatchVerifyingTransition(uint64 _batchId)
        public
        view
        returns (TransitionState memory ts_)
    {
        Config memory config = pacayaConfig();

        uint64 slot = _batchId % config.batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        if (batch.verifiedTransitionId != 0) {
            ts_ =
                state.transitions[slot][batch.verifiedTransitionId][batch.finalisingTransitionIndex];
        }
    }

    /// @inheritdoc ITaikoInbox
    function pacayaConfig() public view virtual returns (Config memory);

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);

        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());

        // Surge: Initialize the first transition in the array of transitions
        TransitionState memory _ts;
        _ts.blockHash = _genesisBlockHash;
        state.transitions[0][1].push(_ts);

        Batch storage batch = state.batches[0];
        batch.metaHash = bytes32(uint256(1));
        batch.lastBlockTimestamp = uint64(block.timestamp);
        batch.anchorBlockId = uint64(block.number);
        batch.nextTransitionId = 2;
        // Surge: Initialize the finalising transition index
        batch.finalisingTransitionIndex = 0;
        batch.verifiedTransitionId = 1;

        state.stats1.genesisHeight = uint64(block.number);

        state.stats2.lastProposedIn = uint56(block.number);
        state.stats2.numBatches = 1;

        // Surge: Initialize the verification streak started at timestamp
        state.stats1.verificationStreakStartedAt = uint64(block.timestamp);

        emit BatchesVerified(0, _genesisBlockHash);
    }

    function _calculateTxsHash(
        bytes32 _txListHash,
        BlobParams memory _blobParams
    )
        internal
        view
        virtual
        returns (bytes32 hash_, bytes32[] memory blobHashes_)
    {
        if (_blobParams.blobHashes.length != 0) {
            blobHashes_ = _blobParams.blobHashes;
        } else {
            uint256 numBlobs = _blobParams.numBlobs;
            blobHashes_ = new bytes32[](numBlobs);
            for (uint256 i; i < numBlobs; ++i) {
                unchecked {
                    blobHashes_[i] = blobhash(_blobParams.firstBlobIndex + i);
                }
            }
        }

        uint256 bloblHashesLength = blobHashes_.length;
        for (uint256 i; i < bloblHashesLength; ++i) {
            require(blobHashes_[i] != 0, BlobNotFound());
        }
        hash_ = keccak256(abi.encode(_txListHash, blobHashes_));
    }

    // Private functions -----------------------------------------------------------------------

    // Surge: _verifyBatches has been extracted away to LibVerifying.sol in order to reduce the
    // code size of TaikoInbox.sol

    function _debitBond(address _user, uint256 _amount) private {
        if (_amount == 0) return;

        uint256 balance = state.bondBalance[_user];
        if (balance >= _amount) {
            unchecked {
                state.bondBalance[_user] = balance - _amount;
            }
        } else if (bondToken != address(0)) {
            uint256 amountDeposited = _handleDeposit(_user, _amount);
            require(amountDeposited == _amount, InsufficientBond());
        } else {
            // Ether as bond must be deposited before proposing a batch
            revert InsufficientBond();
        }
        emit BondDebited(_user, _amount);
    }

    // Surge: remove _creditBond since it is directly handled in the finality gadget library

    function _handleDeposit(
        address _user,
        uint256 _amount
    )
        private
        returns (uint256 amountDeposited_)
    {
        if (bondToken != address(0)) {
            require(msg.value == 0, MsgValueNotZero());

            uint256 balance = IERC20(bondToken).balanceOf(address(this));
            IERC20(bondToken).safeTransferFrom(_user, address(this), _amount);
            amountDeposited_ = IERC20(bondToken).balanceOf(address(this)) - balance;
        } else {
            require(msg.value == _amount, EtherNotPaidAsBond());
            amountDeposited_ = _amount;
        }
        emit BondDeposited(_user, amountDeposited_);
    }

    function _validateBatchParams(
        BatchParams memory _params,
        uint64 _maxAnchorHeightOffset,
        uint8 _maxSignalsToReceive,
        uint16 _maxBlocksPerBatch,
        Batch memory _lastBatch
    )
        private
        view
        returns (uint64 anchorBlockId_, uint64 lastBlockTimestamp_)
    {
        uint256 blocksLength = _params.blocks.length;
        require(blocksLength != 0, BlockNotFound());
        require(blocksLength <= _maxBlocksPerBatch, TooManyBlocks());

        unchecked {
            if (_params.anchorBlockId == 0) {
                anchorBlockId_ = uint64(block.number - 1);
            } else {
                require(
                    _params.anchorBlockId + _maxAnchorHeightOffset >= block.number,
                    AnchorBlockIdTooSmall()
                );
                require(_params.anchorBlockId < block.number, AnchorBlockIdTooLarge());
                require(
                    _params.anchorBlockId >= _lastBatch.anchorBlockId,
                    AnchorBlockIdSmallerThanParent()
                );
                anchorBlockId_ = _params.anchorBlockId;
            }

            lastBlockTimestamp_ = _params.lastBlockTimestamp == 0
                ? uint64(block.timestamp)
                : _params.lastBlockTimestamp;

            require(lastBlockTimestamp_ <= block.timestamp, TimestampTooLarge());
            require(_params.blocks[0].timeShift == 0, FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < blocksLength; ++i) {
                totalShift += _params.blocks[i].timeShift;

                uint256 numSignals = _params.blocks[i].signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _maxSignalsToReceive, TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(
                        signalService.isSignalSent(_params.blocks[i].signalSlots[j]),
                        SignalNotSent()
                    );
                }
            }

            require(lastBlockTimestamp_ >= totalShift, TimestampTooSmall());

            uint64 firstBlockTimestamp = lastBlockTimestamp_ - totalShift;

            require(
                firstBlockTimestamp + _maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
                TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _lastBatch.lastBlockTimestamp, TimestampSmallerThanParent()
            );

            // make sure the batch builds on the expected latest chain state.
            require(
                _params.parentMetaHash == 0 || _params.parentMetaHash == _lastBatch.metaHash,
                ParentMetaHashMismatch()
            );
        }
    }
}
