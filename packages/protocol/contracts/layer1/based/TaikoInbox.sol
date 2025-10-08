// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/libs/LibNames.sol";
import "src/shared/signal/ISignalService.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./libs/LibProverAuth.sol";
import "./libs/LibVerification.sol";
import "./ITaikoInbox.sol";
import "./IProposeBatch.sol";

/// @title TaikoInbox
/// @notice Acts as the inbox for the Taiko Alethia protocol, a simplified version of the
/// original Taiko-Based Contestable Rollup (BCR) but with the tier-based proof system and
/// contestation mechanisms removed.
///
/// Key assumptions of this protocol:
/// - Block proposals and proofs are asynchronous. Proofs are not available at proposal time,
///   unlike Taiko Gwyneth, which assumes synchronous composability.
/// - Proofs are presumed error-free and thoroughly validated, with subproofs/multiproofs management
/// delegated to IVerifier contracts.
///
/// @dev Registered in the address resolver as "taiko".
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoInbox is EssentialContract, ITaikoInbox, IProposeBatch {
    using LibMath for uint256;
    using LibVerification for ITaikoInbox.State;
    using SafeERC20 for IERC20;

    address public immutable inboxWrapper;
    address public immutable verifier;
    address internal immutable bondToken;
    ISignalService public immutable signalService;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // External functions ------------------------------------------------------------------------

    constructor(
        address _inboxWrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        nonZeroAddr(_verifier)
        nonZeroAddr(_signalService)
    {
        inboxWrapper = _inboxWrapper;
        verifier = _verifier;
        bondToken = _bondToken;
        signalService = ISignalService(_signalService);
    }

    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    /// @notice Proposes a batch of blocks.
    /// @param _params ABI-encoded BlockParams.
    /// @param _txList Transaction list in calldata. If the txList is empty, blob will be used for
    /// data availability.
    /// @return info_ Information of the proposed batch, which is used for constructing blocks
    /// offchain.
    /// @return meta_ Metadata of the proposed batch, which is used for proving the batch.
    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata /*_additionalData*/
    )
        public
        override(ITaikoInbox, IProposeBatch)
        nonReentrant
        returns (BatchInfo memory info_, BatchMetadata memory meta_)
    {
        Stats2 memory stats2 = state.stats2;
        Config memory config = _getConfig();

        unchecked {
            require(
                stats2.numBatches <= stats2.lastVerifiedBatchId + config.maxUnverifiedBatches,
                TooManyBatches()
            );

            BatchParams memory params = abi.decode(_params, (BatchParams));

            {
                if (inboxWrapper == address(0)) {
                    if (params.proposer == address(0)) {
                        params.proposer = msg.sender;
                    } else {
                        require(params.proposer == msg.sender, CustomProposerNotAllowed());
                    }

                    // blob hashes are only accepted if the caller is trusted.
                    require(params.blobParams.blobHashes.length == 0, InvalidBlobParams());
                    require(params.blobParams.createdIn == 0, InvalidBlobCreatedIn());
                    require(params.isForcedInclusion == false, InvalidForcedInclusion());
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
            Batch memory lastBatch =
                state.batches[(stats2.numBatches - 1) % config.batchRingBufferSize];

            (uint64 anchorBlockId, uint64 lastBlockTimestamp) = _validateBatchParams(
                params, config.maxAnchorHeightOffset, config.maxBlocksPerBatch, lastBatch
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
            {
                info_ = BatchInfo({
                    txsHash: bytes32(0), // to be initialised later
                    //
                    // Data to build L2 blocks
                    blocks: params.blocks,
                    blobHashes: new bytes32[](0), // to be initialised later
                    // The client must ensure that the lower 128 bits of the extraData field in the
                    // header of each block in this batch match the specified value.
                    // The upper 128 bits of the extraData field are validated using off-chain
                    // protocol logic.
                    extraData: bytes32(uint256(_encodeExtraDataLower128Bits(config, params))),
                    coinbase: params.coinbase,
                    proposer: params.proposer,
                    proposedIn: uint64(block.number),
                    blobCreatedIn: params.blobParams.createdIn,
                    blobByteOffset: params.blobParams.byteOffset,
                    blobByteSize: params.blobParams.byteSize,
                    gasLimit: config.blockMaxGasLimit,
                    lastBlockId: lastBatch.lastBlockId + uint64(params.blocks.length),
                    lastBlockTimestamp: lastBlockTimestamp,
                    // Data for the L2 anchor transaction, shared by all blocks in the batch
                    anchorBlockId: anchorBlockId,
                    anchorBlockHash: blockhash(anchorBlockId),
                    baseFeeConfig: config.baseFeeConfig
                });

                require(info_.anchorBlockHash != 0, ZeroAnchorBlockHash());

                bytes32 txListHash = keccak256(_txList);
                (info_.txsHash, info_.blobHashes) = _calculateTxsHash(txListHash, params.blobParams);

                meta_ = BatchMetadata({
                    infoHash: keccak256(abi.encode(info_)),
                    prover: info_.proposer,
                    batchId: stats2.numBatches,
                    proposedAt: uint64(block.timestamp),
                    firstBlockId: lastBatch.lastBlockId + 1
                });

                _checkBatchInForkRange(config, meta_.firstBlockId, info_.lastBlockId);

                if (params.proverAuth.length == 0) {
                    // proposer is the prover
                    _debitBond(meta_.prover, config.livenessBond);
                } else {
                    bytes memory proverAuth = params.proverAuth;
                    // Circular dependency so zero it out. (BatchParams has proverAuth but
                    // proverAuth has also batchParamsHash)
                    params.proverAuth = "";

                    // Outsource the prover authentication to the LibProverAuth library to reduce
                    // this contract's code size.
                    LibProverAuth.ProverAuth memory auth = LibProverAuth.validateProverAuth(
                        config.chainId,
                        stats2.numBatches,
                        keccak256(abi.encode(params)),
                        txListHash,
                        proverAuth
                    );

                    meta_.prover = auth.prover;

                    if (auth.feeToken == bondToken) {
                        // proposer pay the prover fee with bond tokens
                        _debitBond(info_.proposer, auth.fee);

                        // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                        // if not then add the diff to the bond balance
                        int256 bondDelta = int96(auth.fee) - int96(config.livenessBond);

                        if (bondDelta < 0) {
                            _debitBond(meta_.prover, uint256(-bondDelta));
                        } else {
                            state.creditBond(meta_.prover, uint256(bondDelta));
                        }
                    } else {
                        _debitBond(meta_.prover, config.livenessBond);

                        if (info_.proposer != meta_.prover) {
                            IERC20(auth.feeToken).safeTransferFrom(
                                info_.proposer, meta_.prover, auth.fee
                            );
                        }
                    }
                }
            }

            {
                Batch storage batch = state.batches[stats2.numBatches % config.batchRingBufferSize];

                // SSTORE #1
                batch.metaHash = keccak256(abi.encode(meta_));

                // SSTORE #2 {{
                batch.batchId = stats2.numBatches;
                batch.lastBlockTimestamp = lastBlockTimestamp;
                batch.anchorBlockId = anchorBlockId;
                batch.nextTransitionId = 1;
                batch.verifiedTransitionId = 0;
                batch.reserved4 = 0;
                // SSTORE }}

                // SSTORE #3 {{
                batch.lastBlockId = info_.lastBlockId;
                batch.reserved3 = 0;
                batch.livenessBond = config.livenessBond;
                // SSTORE }}
            }
            stats2.numBatches += 1;
            stats2.lastProposedIn = uint56(block.number);

            emit BatchProposed(info_, meta_, _txList);
        } // end-of-unchecked

        state.verifyBatches(config, stats2, signalService, 1);
    }

    /// @inheritdoc IProveBatches
    function v4ProveBatches(bytes calldata _params, bytes calldata _proof) external nonReentrant {
        (BatchMetadata[] memory metas, Transition[] memory trans) =
            abi.decode(_params, (BatchMetadata[], Transition[]));

        uint256 metasLength = metas.length;
        require(metasLength != 0, NoBlocksToProve());
        require(metasLength <= type(uint8).max, TooManyBatchesToProve());
        require(metasLength == trans.length, ArraySizesMismatch());

        Stats2 memory stats2 = state.stats2;
        require(!stats2.paused, ContractPaused());

        Config memory config = _getConfig();
        IVerifier.Context[] memory ctxs = new IVerifier.Context[](metasLength);

        bool hasConflictingProof;
        for (uint256 i; i < metasLength; ++i) {
            BatchMetadata memory meta = metas[i];

            // During batch proposal, we've ensured that its blocks won't cross fork boundaries.
            // Hence, we only need to verify the firstBlockId of the block in the following check.
            _checkBatchInForkRange(config, meta.firstBlockId, meta.firstBlockId);

            require(meta.batchId > stats2.lastVerifiedBatchId, BatchNotFound());
            require(meta.batchId < stats2.numBatches, BatchNotFound());

            Transition memory tran = trans[i];
            require(tran.parentHash != 0, InvalidTransitionParentHash());
            require(tran.blockHash != 0, InvalidTransitionBlockHash());
            require(tran.stateRoot != 0, InvalidTransitionStateRoot());

            ctxs[i].batchId = meta.batchId;
            ctxs[i].metaHash = keccak256(abi.encode(meta));
            ctxs[i].transition = tran;
            ctxs[i].prover = msg.sender;

            // Verify the batch's metadata.
            uint256 slot = meta.batchId % config.batchRingBufferSize;
            Batch storage batch = state.batches[slot];
            require(ctxs[i].metaHash == batch.metaHash, MetaHashMismatch());

            // Finds out if this transition is overwriting an existing one (with the same parent
            // hash) or is a new one.
            uint24 tid;
            uint24 nextTransitionId = batch.nextTransitionId;
            if (nextTransitionId > 1) {
                // This batch has at least one transition.
                if (state.transitions[slot][1].parentHash == tran.parentHash) {
                    // Overwrite the first transition.
                    tid = 1;
                } else if (nextTransitionId > 2) {
                    // Retrieve the transition ID using the parent hash from the mapping. If the ID
                    // is 0, it indicates a new transition; otherwise, it's an overwrite of an
                    // existing transition.
                    tid = state.transitionIds[meta.batchId][tran.parentHash];
                }
            }

            if (tid == 0) {
                // This transition is new, we need to use the next available ID.
                unchecked {
                    tid = batch.nextTransitionId++;
                }
            } else {
                TransitionState memory _ts = state.transitions[slot][tid];
                if (_ts.blockHash == 0) {
                    // This transition has been invalidated due to a conflicting proof.
                    // So we can reuse the transition ID.
                } else {
                    bool isSameTransition = _ts.blockHash == tran.blockHash
                        && (_ts.stateRoot == 0 || _ts.stateRoot == tran.stateRoot);

                    if (isSameTransition) {
                        // Re-approving the same transition is allowed, but we will not change the
                        // existing one.
                    } else {
                        // A conflict is detected with the new transition. Pause the contract and
                        // invalidate the existing transition by setting its blockHash to 0.
                        hasConflictingProof = true;
                        state.transitions[slot][tid].blockHash = 0;
                        emit ConflictingProof(meta.batchId, _ts, tran);
                    }

                    // Proceed with other transitions.
                    continue;
                }
            }

            TransitionState storage ts = state.transitions[slot][tid];

            ts.blockHash = tran.blockHash;
            ts.stateRoot =
                meta.batchId % config.stateRootSyncInternal == 0 ? tran.stateRoot : bytes32(0);

            bool inProvingWindow;
            unchecked {
                inProvingWindow = block.timestamp
                    <= uint256(meta.proposedAt).max(stats2.lastUnpausedAt) + config.provingWindow;
            }

            ts.inProvingWindow = inProvingWindow;
            ts.prover = inProvingWindow ? meta.prover : msg.sender;
            ts.createdAt = uint48(block.timestamp);

            if (tid == 1) {
                ts.parentHash = tran.parentHash;
            } else {
                state.transitionIds[meta.batchId][tran.parentHash] = tid;
            }
        }

        IVerifier(verifier).verifyProof(ctxs, _proof);

        // Emit the event
        {
            uint64[] memory batchIds = new uint64[](metasLength);
            for (uint256 i; i < metasLength; ++i) {
                batchIds[i] = metas[i].batchId;
            }

            emit BatchesProved(verifier, batchIds, trans);
        }

        if (hasConflictingProof) {
            _pause();
            emit Paused(verifier);
        } else {
            state.verifyBatches(config, stats2, signalService, uint8(metasLength));
        }
    }

    /// @inheritdoc ITaikoInbox
    function v4VerifyBatches(uint8 _length)
        external
        nonZeroValue(_length)
        nonReentrant
        whenNotPaused
    {
        state.verifyBatches(_getConfig(), state.stats2, signalService, _length);
    }

    /// @inheritdoc IBondManager
    function v4DepositBond(uint256 _amount) external payable whenNotPaused {
        state.bondBalance[msg.sender] += _handleDeposit(msg.sender, _amount);
    }

    /// @inheritdoc IBondManager
    function v4WithdrawBond(uint256 _amount) external whenNotPaused {
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

    /// @inheritdoc IBondManager
    function v4BondToken() external view returns (address) {
        return bondToken;
    }

    /// @inheritdoc ITaikoInbox
    function v4GetStats1() external view returns (Stats1 memory) {
        return state.stats1;
    }

    /// @inheritdoc ITaikoInbox
    function v4GetStats2() external view returns (Stats2 memory) {
        return state.stats2;
    }

    /// @inheritdoc ITaikoInbox
    function v4GetTransitionById(
        uint64 _batchId,
        uint24 _tid
    )
        external
        view
        returns (TransitionState memory)
    {
        uint256 slot = _batchId % _getConfig().batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());
        require(_tid != 0, TransitionNotFound());
        require(_tid < batch.nextTransitionId, TransitionNotFound());
        return state.transitions[slot][_tid];
    }

    /// @inheritdoc ITaikoInbox
    function v4GetTransitionByParentHash(
        uint64 _batchId,
        bytes32 _parentHash
    )
        external
        view
        returns (TransitionState memory)
    {
        uint256 slot = _batchId % _getConfig().batchRingBufferSize;
        Batch storage batch = state.batches[slot];
        require(batch.batchId == _batchId, BatchNotFound());

        uint24 tid;
        if (batch.nextTransitionId > 1) {
            // This batch has at least one transition.
            if (state.transitions[slot][1].parentHash == _parentHash) {
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
        return state.transitions[slot][tid];
    }

    /// @inheritdoc ITaikoInbox
    function v4GetLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        batchId_ = state.stats2.lastVerifiedBatchId;

        ITaikoInbox.Config memory config = _getConfig();
        require(batchId_ >= config.forkHeights.pacaya, BatchNotFound());

        blockId_ = state.getBatch(config, batchId_).lastBlockId;
        ts_ = state.getBatchVerifyingTransition(config, batchId_);
    }

    /// @inheritdoc ITaikoInbox
    function v4GetLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        batchId_ = state.stats1.lastSyncedBatchId;
        ITaikoInbox.Config memory config = _getConfig();
        blockId_ = state.getBatch(config, batchId_).lastBlockId;
        ts_ = state.getBatchVerifyingTransition(config, batchId_);
    }

    /// @inheritdoc IBondManager
    function v4BondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    // Public functions -------------------------------------------------------------------------

    /// @inheritdoc EssentialContract
    function paused() public view override returns (bool) {
        return state.stats2.paused;
    }

    /// @inheritdoc ITaikoInbox
    function v4GetBatch(uint64 _batchId) external view returns (Batch memory) {
        return state.getBatch(_getConfig(), _batchId);
    }

    /// @inheritdoc ITaikoInbox
    function v4GetBatchVerifyingTransition(uint64 _batchId)
        external
        view
        returns (TransitionState memory)
    {
        return state.getBatchVerifyingTransition(_getConfig(), _batchId);
    }

    /// @inheritdoc ITaikoInbox
    function v4GetConfig() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);

        require(_genesisBlockHash != 0, InvalidGenesisBlockHash());
        state.transitions[0][1].blockHash = _genesisBlockHash;

        Batch storage batch = state.batches[0];
        batch.metaHash = bytes32(uint256(1));
        batch.lastBlockTimestamp = uint64(block.timestamp);
        batch.anchorBlockId = uint64(block.number);
        batch.nextTransitionId = 2;
        batch.verifiedTransitionId = 1;

        state.stats1.genesisHeight = uint64(block.number);

        state.stats2.lastProposedIn = uint56(block.number);
        state.stats2.numBatches = 1;

        emit BatchesVerified(0, _genesisBlockHash);
    }

    function _unpause() internal override {
        state.stats2.lastUnpausedAt = uint64(block.timestamp);
        state.stats2.paused = false;
    }

    function _pause() internal override {
        state.stats2.paused = true;
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

    function _getConfig() internal view virtual returns (Config memory);

    // Private functions -----------------------------------------------------------------------

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
        uint16 _maxBlocksPerBatch,
        Batch memory _lastBatch
    )
        private
        view
        returns (uint64 anchorBlockId_, uint64 lastBlockTimestamp_)
    {
        uint256 nBlocks = _params.blocks.length;
        require(nBlocks != 0, BlockNotFound());
        require(nBlocks <= _maxBlocksPerBatch, TooManyBlocks());

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

            for (uint256 i; i < nBlocks; ++i) {
                BlockParams memory blockParams = _params.blocks[i];
                totalShift += blockParams.timeShift;

                uint256 numSignals = blockParams.signalSlots.length;
                require(numSignals == 0, TooManySignals());
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

    /// @dev The function _encodeExtraDataLower128Bits encodes certain information into a uint128
    /// - bits 0-7: used to store _config.baseFeeConfig.sharingPctg.
    /// - bit 8: used to store _batchParams.isForcedInclusion.
    function _encodeExtraDataLower128Bits(
        Config memory _config,
        BatchParams memory _batchParams
    )
        private
        pure
        returns (uint128 encoded_)
    {
        encoded_ |= _config.baseFeeConfig.sharingPctg; // bits 0-7
        encoded_ |= _batchParams.isForcedInclusion ? 1 << 8 : 0; // bit 8
    }

    /// @dev Check this batch is between current fork height (inclusive) and next fork height
    /// (exclusive)
    function _checkBatchInForkRange(
        Config memory _config,
        uint64 _firstBlockId,
        uint64 _lastBlockId
    )
        private
        pure
    {
        require(_firstBlockId >= _config.forkHeights.shasta, ForkNotActivated());
        require(
            _config.forkHeights.unzen == 0 || _lastBlockId < _config.forkHeights.unzen,
            BeyondCurrentFork()
        );
    }
}
