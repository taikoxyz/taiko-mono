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

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // Define errors locally
    error ContractPaused();

    // External functions ------------------------------------------------------------------------

    constructor() EssentialContract() { }

    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    function v4ProposeBatches(
        I.Summary memory _summary,
        I.Batch[] memory _batch,
        I.BatchProposeMetadataEvidence calldata _parentProposeMetaEvidence,
        I.TransitionMeta[] calldata _trans
    )
        public
        // override(ITaikoInbox2, IProposeBatch2)
        nonReentrant
        returns (I.Summary memory)
    {
        bool _paused = state.validateSummary(_summary);
        require(!_paused, ContractPaused());

        I.Config memory conf = _getConfig();
        LibPropose2.Environment memory env = LibPropose2.Environment({
            // reads
            sender: msg.sender,
            blockTimestamp: uint48(block.timestamp),
            blockNumber: uint48(block.number),
            encodeBatchMetadata: LibData2.encodeBatchMetadata,
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

        _summary =
            LibPropose2.proposeBatches(conf, env, _summary, _batch, _parentProposeMetaEvidence);
        _summary = LibVerify2.verifyBatches(conf, env, _summary, _trans);

        state.updateSummary(_summary, _paused);
        return _summary;
    }

    function v4ProveBatches(
        I.Summary memory _summary,
        I.BatchProveInput[] calldata _inputs,
        bytes calldata _proof
    )
        external
        nonReentrant
        returns (I.Summary memory)
    {
        bool _paused = state.validateSummary(_summary);
        require(!_paused, ContractPaused());

        I.Config memory conf = _getConfig();
        LibProve2.Environment memory env = LibProve2.Environment({
            // reads
            sender: msg.sender,
            blockTimestamp: uint48(block.timestamp),
            blockNumber: uint48(block.number),
            // writes
            debitBond: _debitBond,
            creditBond: _creditBond,
            saveTransition: _saveTransition
        });

        bytes32 aggregatedBatchHash;
        (_summary, aggregatedBatchHash) = state.proveBatches(conf, env, _summary, _inputs);

        state.updateSummary(_summary, _paused);

        IVerifier2(conf.verifier).verifyProof(aggregatedBatchHash, _proof);
        return _summary;
    }

    function v4DepositBond(uint256 _amount) external payable whenNotPaused {
        I.Config memory conf = _getConfig();
        state.bondBalance[msg.sender] += LibBonds2.depositBond(conf.bondToken, msg.sender, _amount);
    }

    function v4WithdrawBond(uint256 _amount) external whenNotPaused {
        I.Config memory conf = _getConfig();
        state.withdrawBond(conf.bondToken, _amount);
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
        returns (bytes32 metaHash_, bool isFirstTransition_)
    {
        uint256 slot = _batchId % _conf.batchRingBufferSize;

        (uint48 embededBatchId, bytes32 partialParentHash) =
            LibData2.loadBatchIdAndPartialParentHash(state, slot); // 1 SLOAD

        if (embededBatchId != _batchId) return (0, false);

        if (partialParentHash == _lastVerifiedBlockHash >> 48) {
            return (state.transitions[slot][1].metaHash, true);
        } else {
            return (state.transitionMetaHashes[_batchId][_lastVerifiedBlockHash], false);
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

    function _isSignalSent(
        I.Config memory _conf,
        bytes32 _signalSlot
    )
        private
        view
        returns (bool)
    {
        return ISignalService(_conf.signalService).isSignalSent(_signalSlot);
    }

    function _debitBond(I.Config memory _conf, address _user, uint256 _amount) private {
        LibBonds2.debitBond(state, _conf.bondToken, _user, _amount);
    }

    function _creditBond(address _user, uint256 _amount) private {
        LibBonds2.creditBond(state, _user, _amount);
    }

    function _transferFee(address _feeToken, address _from, address _to, uint256 _amount) private {
        IERC20(_feeToken).safeTransferFrom(_from, _to, _amount);
    }

    function _syncChainData(I.Config memory _conf, uint64 _blockId, bytes32 _stateRoot) private {
        ISignalService(_conf.signalService).syncChainData(
            _conf.chainId, LibSignals.STATE_ROOT, _blockId, _stateRoot
        );
    }
}
