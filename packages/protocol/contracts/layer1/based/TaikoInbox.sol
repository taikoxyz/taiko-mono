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
// Surge: import new libraries
import "./LibVerifying.sol";
import "./LibProposing.sol";
import "./LibProving.sol";
import "./LibBonds.sol";

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

    /// @inheritdoc ITaikoInbox
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        public
        override(ITaikoInbox, IProposeBatch)
        nonReentrant
        returns (BatchInfo memory info_, BatchMetadata memory meta_)
    {
        require(!state.stats2.proposeWithProofMode, ProposeWithProofModeEnabled());

        BatchParams memory params = abi.decode(_params, (BatchParams));
        Stats2 memory stats2;
        Config memory config = pacayaConfig();

        // Surge: Extract proposing logic into LibProposing
        LibProposing.LibProposeBatchParams memory proposeBatchParams = LibProposing
            .LibProposeBatchParams({
            config: config,
            params: params,
            bondToken: bondToken,
            signalService: signalService,
            inboxWrapper: inboxWrapper
        });

        (info_, meta_, stats2) = LibProposing.proposeBatches(state, proposeBatchParams, _txList);
        LibVerifying.verifyBatches(state, config, stats2, 1, dao, verifier, signalService);
    }

    /// @inheritdoc ITaikoInbox
    function proveBatches(bytes calldata _params, bytes calldata _proof) external nonReentrant {
        require(!state.stats2.proposeWithProofMode, ProposeWithProofModeEnabled());

        (LibProofType.ProofType proofType, BatchMetadata[] memory metas, Transition[] memory trans)
        = abi.decode(_params, (LibProofType.ProofType, BatchMetadata[], Transition[]));

        Stats2 memory stats2;
        Config memory config = pacayaConfig();

        LibProving.ProveBatchesParams memory proveParams =
            LibProving.ProveBatchesParams({ proofType: proofType, metas: metas, trans: trans });

        // Surge: Extract proving logic into LibProving
        stats2 = LibProving.proveBatches(state, config, proveParams, _proof, verifier);
        LibVerifying.verifyBatches(
            state, config, stats2, metas.length, dao, verifier, signalService
        );
    }

    /// @inheritdoc ITaikoInbox
    function proposeWithProof(
        bytes calldata _proposeParams,
        bytes calldata _txList,
        bytes calldata _proveParams,
        bytes calldata _proof
    )
        external
        nonReentrant
        returns (BatchInfo memory info_, BatchMetadata memory meta_)
    {
        Stats2 memory stats2;
        Config memory config = pacayaConfig();

        {
            // Decode propose params
            BatchParams memory proposeParams = abi.decode(_proposeParams, (BatchParams));

            LibProposing.LibProposeBatchParams memory proposeBatchParams = LibProposing
                .LibProposeBatchParams({
                config: config,
                params: proposeParams,
                bondToken: bondToken,
                signalService: signalService,
                inboxWrapper: inboxWrapper
            });

            // Propose the batch
            (info_, meta_, stats2) = LibProposing.proposeBatches(state, proposeBatchParams, _txList);
        }

        // Ensure we're proving the same batch that was just proposed
        BatchMetadata[] memory metas = new BatchMetadata[](1);
        metas[0] = meta_;

        {
            // Decode prove params
            (LibProofType.ProofType proofType,, Transition[] memory trans) =
                abi.decode(_proveParams, (LibProofType.ProofType, BatchMetadata[], Transition[]));
            require(trans.length == 1, InvalidParams());

            // Prove the batch
            LibProving.ProveBatchesParams memory proveParams =
                LibProving.ProveBatchesParams({ proofType: proofType, metas: metas, trans: trans });

            stats2 = LibProving.proveBatches(state, config, proveParams, _proof, verifier);
        }

        // Single verification call for both propose and prove
        LibVerifying.verifyBatches(state, config, stats2, 1, dao, verifier, signalService);
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
        state.bondBalance[msg.sender] += LibBonds.handleDeposit(msg.sender, _amount, bondToken);
    }

    /// @inheritdoc ITaikoInbox
    function withdrawBond(uint256 _amount) external {
        uint256 balance = state.bondBalance[msg.sender];
        require(balance >= _amount, InsufficientBond());

        state.bondBalance[msg.sender] -= _amount;
        LibBonds.handleWithdrawal(msg.sender, _amount, bondToken);
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
            // Enable propose-with-proof mode after rollback
            state.stats2.proposeWithProofMode = true;
            emit Stats2Updated(state.stats2);
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

    // Surge: protection against prover killer blocks
    /// @inheritdoc ITaikoInbox
    function setProposeWithProofMode(bool _enabled) external onlyOwner {
        state.stats2.proposeWithProofMode = _enabled;
        emit Stats2Updated(state.stats2);
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

    // Private functions -----------------------------------------------------------------------

    // Surge: _verifyBatches has been extracted away to LibVerifying.sol in order to reduce the
    // code size of TaikoInbox.sol
    // Surge: _proposeBatches has been extracted away to LibProposing.sol
    // Surge: _proveBatches has been extracted away to LibProving.sol

    // Surge: _debitBond and _handleDeposit have been moved to LibBonds.sol
    // Surge: _validateBatchParams has been moved to LibProposing.sol
}
