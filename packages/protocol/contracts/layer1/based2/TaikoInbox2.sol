// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./libs/LibBonds2.sol";
// import "./libs/LibInit2.sol";
import "./libs/LibPropose2.sol";
import "./libs/LibProve2.sol";
// import "./libs/LibRead2.sol";
import "./libs/LibVerify2.sol";
import "./ITaikoInbox2.sol";
import "./IProposeBatch2.sol";

/// @title TaikoInbox2
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
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoInbox2 is
    EssentialContract,
    ITaikoInbox2,
    IProposeBatch2,
    IBondManager2,
    ITaiko
{
    using SafeERC20 for IERC20;
    using LibBonds2 for ITaikoInbox2.State;
    using LibData2 for ITaikoInbox2.State;
    using LibPropose2 for ITaikoInbox2.State;
    using LibProve2 for ITaikoInbox2.State;
    using LibVerify2 for ITaikoInbox2.State;

    address public immutable inboxWrapper;
    address public immutable verifier;
    address internal immutable bondToken;
    address public immutable signalService;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // Define errors locally
    error ContractPaused();

    // External functions ------------------------------------------------------------------------

    constructor(
        address _inboxWrapper,
        address _verifier,
        address _signalService
    )
        nonZeroAddr(_verifier)
        nonZeroAddr(_signalService)
        EssentialContract()
    {
        inboxWrapper = _inboxWrapper;
        verifier = _verifier;
        signalService = _signalService;
    }

    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    function v4ProposeBatch(
        I.Summary memory _summary,
        I.BatchParams memory _params,
        I.BatchProposeMetadataEvidence calldata _parentProposeMetaEvidence,
        I.TransitionMeta[] calldata _trans
    )
        public
        // override(ITaikoInbox2, IProposeBatch2)
        nonReentrant
        returns (I.BatchMetadata memory meta_)
    {
        bool _paused = state.validateSummary(_summary);
        require(!_paused, ContractPaused());

        I.Config memory conf = _getConfig();
        LibPropose2.Environment memory env = LibPropose2.Environment({
            // reads
            conf: conf,
            inboxWrapper: inboxWrapper,
            sender: msg.sender,
            blockTimestamp: uint48(block.timestamp),
            blockNumber: uint48(block.number),
            parentBatchMetaHash: state.batches[(_summary.numBatches - 1) % conf.batchRingBufferSize],
            isSignalSent: _isSignalSent,
            loadTransitionMetaHash: _loadTransitionMetaHash,
            getBlobHash: _getBlobHash,
            // writes
            saveBatchMetaHash: _saveBatchMetaHash,
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            syncChainData: _syncChainData,
            validateProverAuth: LibAuth2.validateProverAuth
        });

        (meta_, _summary) = LibPropose2.proposeBatch(
            env, _summary, _params, _parentProposeMetaEvidence 
        );

        emit I.BatchProposed(_summary.numBatches, meta_);

        _summary = LibVerify2.verifyBatches(env, _summary, _trans);

        state.updateSummary(_summary, _paused);
    }

    function v4ProveBatches(
        I.Summary memory _summary,
        I.BatchProveInput[] calldata _inputs,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        bool _paused = state.validateSummary(_summary);
        require(!_paused, ContractPaused());

        LibProve2.Environment memory env = LibProve2.Environment({
            // reads
            conf: _getConfig(),
            sender: msg.sender,
            blockTimestamp: uint48(block.timestamp),
            blockNumber: uint48(block.number),
            verifier: verifier,
            // writes
            debitBond: _debitBond,
            creditBond: _creditBond,
            saveTransition: _saveTransition
        });

        bytes32 aggregatedBatchHash;
        (_summary, aggregatedBatchHash) = state.proveBatches(env, _summary, _inputs);

        state.updateSummary(_summary, _paused);

        IVerifier2(verifier).verifyProof(aggregatedBatchHash, _proof);
    }

    function v4DepositBond(uint256 _amount) external payable whenNotPaused {
        state.bondBalance[msg.sender] += LibBonds2.depositBond(bondToken, msg.sender, _amount);
    }

    function v4WithdrawBond(uint256 _amount) external whenNotPaused {
        state.withdrawBond(bondToken, _amount);
    }

    function v4BondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    function v4IsInbox() external pure override returns (bool) {
        return true;
    }

    // Public functions -------------------------------------------------------------------------

    function paused() public view override returns (bool) {
        return state.summaryHash & bytes32(uint256(1)) != 0;
    }

    function v4GetConfig() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);
        // state.init(_genesisBlockHash); // TODO
    }

    function _unpause() internal override {
        // TODO
        // state.stats2.lastUnpausedAt = uint64(block.timestamp);
        // state.stats2.paused = false;
    }

    function _pause() internal override {
        // TODO
        // state.stats2.paused = true;
    }

    function _getConfig() internal view virtual returns (Config memory);

    function _saveBatchMetaHash(
        I.Config memory _config,
        uint256 _batchId,
        bytes32 _metaHash
    )
        private
    {
        state.batches[_batchId % _config.batchRingBufferSize] = _metaHash;
    }

    function _loadTransitionMetaHash(
        I.Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        private
        view
        returns (bytes32)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;

        (uint48 embededBatchId, bytes32 partialParentHash) =
            LibData2.loadBatchIdAndPartialParentHash(state, slot); // 1 SLOAD

        if (embededBatchId != _batchId) return 0;

        if (partialParentHash == _lastVerifiedBlockHash >> 48) {
            return state.transitions[slot][1].metaHash;
        } else {
            return state.transitionMetaHashes[_batchId][_lastVerifiedBlockHash];
        }
    }

    function _saveTransition(
        I.Config memory _conf,
        uint256 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        returns (bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;

        // In the next code section, we always use `$.transitions[slot][1]` to reuse a previously
        // declared state variable -- note that the second mapping key is always 1.
        // Tip: the reuse of the first transition slot can save 3900 gas per batch.
        (uint48 embededBatchId, bytes32 partialParentHash) =
            LibData2.loadBatchIdAndPartialParentHash(state, slot);

        isFirstTransition_ = embededBatchId != _batchId;

        if (isFirstTransition_) {
            // This is the very first transition of the batch, or a transition with the same parent
            // hash. We can reuse the transition state slot to reduce gas cost.
            state.transitions[slot][1].batchIdAndPartialParentHash =
                LibData2.encodeBatchIdAndPartialParentHash(uint48(_batchId), _parentHash); // 1
                // SSTORE
            state.transitions[slot][1].metaHash = _tranMetahash; // 1 SSTORE
        } else if (partialParentHash == _parentHash >> 48) {
            // Overwrite the first proof
            state.transitions[slot][1].metaHash = _tranMetahash; // 1 SSTORE
        } else {
            // This is not the very first transition of the batch, or a transition with the same
            // parent hash. Use a mapping to store the meta hash of the transition. The mapping
            // slots are not reusable.
            state.transitionMetaHashes[_batchId][_parentHash] = _tranMetahash; // 1 SSTORE
        }
    }

    function _getBlobHash(uint256 _blockNumber) private view returns (bytes32) {
        return blockhash(_blockNumber);
    }

    function _isSignalSent(bytes32 _signalSlot) private view returns (bool) {
        return ISignalService(signalService).isSignalSent(_signalSlot);
    }

    function _debitBond(address _bondToken, address _user, uint256 _amount) private {
        LibBonds2.debitBond(state, _bondToken, _user, _amount);
    }

    function _creditBond(address _user, uint256 _amount) private {
        LibBonds2.creditBond(state, _user, _amount);
    }

    function _transferFee(address _feeToken, address _from, address _to, uint256 _amount) private {
        IERC20(_feeToken).safeTransferFrom(_from, _to, _amount);
    }

    function _syncChainData(I.Config memory _config, uint64 _blockId, bytes32 _stateRoot) private {
        ISignalService(signalService).syncChainData(
            _config.chainId, LibSignals.STATE_ROOT, _blockId, _stateRoot
        );
    }
}
