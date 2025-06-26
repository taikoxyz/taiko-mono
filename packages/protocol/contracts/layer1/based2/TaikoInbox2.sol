// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
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
        I.Summary calldata _summary,
        I.BatchProposeMetadataEvidence calldata _parentProposeMetaEvidence,
        I.BatchParams calldata _params,
        bytes calldata _txList,
        bytes calldata _additionalData,
        I.TransitionMeta[] calldata _trans
    )
        public
        // override(ITaikoInbox2, IProposeBatch2)
        nonReentrant
        returns (I.BatchMetadata memory meta_, I.Summary memory summary_)
    {
        bool _paused = state.validateSummary(_summary);
        require(!_paused, I.ContractPaused());

        I.Config memory conf = _getConfig();
        LibPropose2.Environment memory env = LibPropose2.Environment({
            conf: conf,
            inboxWrapper: inboxWrapper,
            sender: msg.sender,
            blockTimestamp: uint48(block.timestamp),
            blockNumber: uint48(block.number),
            parentBatchMetaHash: state.batches[(_summary.numBatches - 1) % conf.batchRingBufferSize],
            getBlobHash: _getBlobHash,
            isSignalSent: _isSignalSent,
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            syncChainData: _syncChainData,
            validateProverAuth: LibAuth2.validateProverAuth
        });

        (meta_, summary_) = state.proposeBatch(
            env, _summary, _parentProposeMetaEvidence, _params, _txList, _additionalData
        );

        emit I.BatchProposed(summary_.numBatches, meta_);

        summary_ = state.verifyBatches(env, summary_, _trans);

        state.updateSummary(summary_, _paused);
    }

    function v4ProveBatches(
        I.Summary calldata _summary,
        I.BatchProveInput[] calldata _inputs,
        bytes calldata _proof
    )
        external
        nonReentrant
    {
        LibData2.Env memory env = _loadEnv();
        state.proveBatches(env, _summary, _inputs, _proof);
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

    function _loadEnv() private view returns (LibData2.Env memory) {
        return LibData2.Env({
            config: _getConfig(),
            bondToken: bondToken,
            verifier: verifier,
            inboxWrapper: inboxWrapper,
            signalService: signalService,
            prevSummaryHash: state.summaryHash
        });
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
