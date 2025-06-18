// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/based/ITaiko.sol";
import "./libs/LibBonds.sol";
import "./libs/LibInit.sol";
import "./libs/LibPropose.sol";
import "./libs/LibProve.sol";
import "./libs/LibRead.sol";
import "./libs/LibVerify.sol";
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
/// @custom:security-contact security@taiko.xyz
abstract contract TaikoInbox is EssentialContract, ITaikoInbox, IProposeBatch, ITaiko {
    using LibBonds for ITaikoInbox.State;
    using LibInit for ITaikoInbox.State;
    using LibPropose for ITaikoInbox.State;
    using LibProve for ITaikoInbox.State;
    using LibRead for ITaikoInbox.State;
    using LibVerify for ITaikoInbox.State;

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
        address _bondToken,
        address _signalService
    )
        nonZeroAddr(_verifier)
        nonZeroAddr(_signalService)
        EssentialContract()
    {
        inboxWrapper = _inboxWrapper;
        verifier = _verifier;
        bondToken = _bondToken;
        signalService = _signalService;
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
        bytes calldata _additionalData
    )
        public
        override(ITaikoInbox, IProposeBatch)
        nonReentrant
        returns (BatchInfo memory, BatchMetadata memory)
    {
        LibPropose.Input memory input =
            LibPropose.Input(_getConfig(), bondToken, inboxWrapper, signalService);

        LibPropose.Output memory output =
            state.proposeBatch(input, _params, _txList, _additionalData);

        state.verifyBatches(input.config, output.stats2, signalService, 1);

        return (output.info, output.meta);
    }

    /// @inheritdoc IProveBatches
    function v4ProveBatches(bytes calldata _params, bytes calldata _proof) external nonReentrant {
        LibProve.Input memory input = LibProve.Input(_getConfig(), bondToken, verifier);
        LibProve.Output memory output = state.proveBatches(input, _params, _proof);

        if (output.hasConflictingProof) {
            _pause();
            emit Paused(verifier);
        } else {
            state.verifyBatches(
                input.config, output.stats2, signalService, uint8(output.metas.length)
            );
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
        state.bondBalance[msg.sender] += LibBonds.depositBond(bondToken, msg.sender, _amount);
    }

    /// @inheritdoc IBondManager
    function v4WithdrawBond(uint256 _amount) external whenNotPaused {
        state.withdrawBond(bondToken, _amount);
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
        return state.getTransitionById(_getConfig(), _batchId, _tid);
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
        return state.getTransitionByParentHash(_getConfig(), _batchId, _parentHash);
    }

    /// @inheritdoc ITaikoInbox
    function v4GetLastVerifiedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        return state.getLastVerifiedTransition(_getConfig());
    }

    /// @inheritdoc ITaikoInbox
    function v4GetLastSyncedTransition()
        external
        view
        returns (uint64 batchId_, uint64 blockId_, TransitionState memory ts_)
    {
        return state.getLastSyncedTransition(_getConfig());
    }

    /// @inheritdoc IBondManager
    function v4BondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    /// @inheritdoc ITaiko
    function v4IsInbox() external pure override returns (bool) {
        return true;
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
        state.init(_genesisBlockHash);
    }

    function _unpause() internal override {
        state.stats2.lastUnpausedAt = uint64(block.timestamp);
        state.stats2.paused = false;
    }

    function _pause() internal override {
        state.stats2.paused = true;
    }

    function _getConfig() internal view virtual returns (Config memory);
}
