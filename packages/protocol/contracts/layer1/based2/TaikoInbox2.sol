// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./libs/LibBonds2.sol";
// import "./libs/LibInit2.sol";
import "./libs/LibPropose2.sol";
import "./libs/LibProve2.sol";
// import "./libs/LibRead2.sol";
import "./libs/LibVerify2.sol";
import "./ITaikoInbox2.sol";
import "./IProposeBatch2.sol";
import "./libs/LibTransition.sol";

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
    using LibTransition for ITaikoInbox2.State;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // External functions ------------------------------------------------------------------------

    constructor() EssentialContract() { }

    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    function v4ProposeBatches(
        I.Summary memory _summary,
        I.Batch[] memory _batch,
        I.BatchProposeMetadataEvidence memory _evidence,
        I.TransitionMeta[] calldata _trans
    )
        public
        // override(ITaikoInbox2, IProposeBatch2)
        nonReentrant
        returns (I.Summary memory)
    {
        require(state.summaryHash == keccak256(abi.encode(_summary)), SummaryMismatch());
        I.Config memory conf = _getConfig();

        LibParams.ReadWrite memory rw1 = LibParams.ReadWrite({
            // reads
            getBatchMetaHash: _getBatchMetaHash,
            isSignalSent: _isSignalSent,
            loadTransitionMetaHash: _loadTransitionMetaHash,
            getBlobHash: _getBlobHash,
            // writes
            saveBatchMetaHash: _saveBatchMetaHash,
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            validateProverAuth: LibAuth2.validateProverAuth
        });
        _summary = LibPropose2.proposeBatches(conf, rw1, _summary, _batch, _evidence);

        LibVerify2.ReadWrite memory rw2 = LibVerify2.ReadWrite({
            // reads
            getBatchMetaHash: _getBatchMetaHash,
            loadTransitionMetaHash: _loadTransitionMetaHash,
            // writes
            creditBond: _creditBond,
            syncChainData: _syncChainData
        });
        _summary = LibVerify2.verifyBatches(conf, rw2, _summary, _trans);

        state.summaryHash = keccak256(abi.encode(_summary));
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
        require(state.summaryHash == keccak256(abi.encode(_summary)), SummaryMismatch());

        I.Config memory conf = _getConfig();
        LibProve2.ReadWrite memory rw = LibProve2.ReadWrite({
            // reads
            blockTimestamp: uint48(block.timestamp),
            blockNumber: uint48(block.number),
            getBatchMetaHash: _getBatchMetaHash,
            // writes
            creditBond: _creditBond,
            debitBond: _debitBond,
            saveTransition: _saveTransition
        });

        bytes32 aggregatedBatchHash;
        (_summary, aggregatedBatchHash) = LibProve2.proveBatches(conf, rw, _summary, _inputs);

        IVerifier2(conf.verifier).verifyProof(aggregatedBatchHash, _proof);

        state.summaryHash = keccak256(abi.encode(_summary));
        return _summary;
    }

    function v4DepositBond(uint256 _amount) external payable {
        I.Config memory conf = _getConfig();
        state.bondBalance[msg.sender] += LibBonds2.depositBond(conf.bondToken, msg.sender, _amount);
    }

    function v4WithdrawBond(uint256 _amount) external {
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

    function v4GetConfig() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // Internal functions ----------------------------------------------------------------------

    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);
        LibInit2.init(state, _genesisBlockHash);
    }

    function _getConfig() internal view virtual returns (Config memory);

    // Internal Binding functions ----------------------------------------------------------------

    function _getBlobHash(uint256 _blockNumber) private view returns (bytes32) {
        return blockhash(_blockNumber);
    }

    function _saveBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        private
    {
        state.batches[_batchId % _conf.batchRingBufferSize] = _metaHash;
    }

    function _getBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId
    )
        private
        view
        returns (bytes32)
    {
        return state.batches[_batchId % _conf.batchRingBufferSize];
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
        return state.loadTransitionMetaHash(_conf, _lastVerifiedBlockHash, _batchId);
    }

    function _saveTransition(
        I.Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        returns (bool isFirstTransition_)
    {
        return state.saveTransition(_conf, _batchId, _parentHash, _tranMetahash);
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

    function _syncChainData(I.Config memory _conf, uint64 _blockId, bytes32 _stateRoot) private {
        ISignalService(_conf.signalService).syncChainData(
            _conf.chainId, LibSignals.STATE_ROOT, _blockId, _stateRoot
        );
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

    // --- ERRORs --------------------------------------------------------------------------------
    error SummaryMismatch();
}
