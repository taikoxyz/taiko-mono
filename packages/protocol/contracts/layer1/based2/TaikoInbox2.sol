// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/layer1/verifiers/IVerifier.sol";
import "./libs/LibBondManagement.sol";
import "./libs/LibInitialization.sol";
import "./libs/LibBatchProposal.sol";
import "./libs/LibBatchProving.sol";
import "./libs/LibBatchVerification.sol";
import "./ITaikoInbox2.sol";
import "./IProposeBatch2.sol";
import "./libs/LibTransitionStorage.sol";

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
    using LibBondManagement for ITaikoInbox2.State;
    using LibTransitionStorage for ITaikoInbox2.State;
    using LibInitialization for ITaikoInbox2.State;

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

        LibReadWrite.RW memory rw = _getReadWrite();
        _summary = LibBatchProposal.proposeBatches(conf, rw, _summary, _batch, _evidence);
        _summary = LibBatchVerification.verifyBatches(conf, rw, _summary, _trans);

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
        LibReadWrite.RW memory rw = _getReadWrite();
        bytes32 aggregatedBatchHash;
        (_summary, aggregatedBatchHash) = LibBatchProving.proveBatches(conf, rw, _summary, _inputs);

        IVerifier2(conf.verifier).verifyProof(aggregatedBatchHash, _proof);

        state.summaryHash = keccak256(abi.encode(_summary));
        return _summary;
    }

    function v4DepositBond(uint256 _amount) external payable {
        state.bondBalance[msg.sender] +=
            LibBondManagement.depositBond(_getConfig().bondToken, msg.sender, _amount);
    }

    function v4WithdrawBond(uint256 _amount) external {
        state.withdrawBond(_getConfig().bondToken, _amount);
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
        state.init(_genesisBlockHash);
    }

    function _getConfig() internal view virtual returns (Config memory);

    // Internal Binding functions ----------------------------------------------------------------

    function _getReadWrite() internal pure virtual returns (LibReadWrite.RW memory) {
        return LibReadWrite.RW({
            // reads
            loadBatchMetaHash: _loadBatchMetaHash,
            isSignalSent: _isSignalSent,
            loadTransitionMetaHash: _loadTransitionMetaHash,
            getBlobHash: _getBlobHash,
            // writes
            saveBatchMetaHash: _saveBatchMetaHash,
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            saveTransition: _saveTransition,
            syncChainData: _syncChainData
        });
    }

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

    function _loadBatchMetaHash(
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
        LibBondManagement.debitBond(state, _conf.bondToken, _user, _amount);
    }

    function _creditBond(address _user, uint256 _amount) private {
        LibBondManagement.creditBond(state, _user, _amount);
    }

    function _transferFee(address _feeToken, address _from, address _to, uint256 _amount) private {
        IERC20(_feeToken).safeTransferFrom(_from, _to, _amount);
    }

    // --- ERRORs --------------------------------------------------------------------------------

    error SummaryMismatch();
}
