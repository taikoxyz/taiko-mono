// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "./AbstractInbox.sol";
import "./libs/LibBonds.sol";
import "./libs/LibState.sol";
import "./codec/LibCodecBatchContext.sol";
import "./codec/LibCodecTransitionMeta.sol";
import "./codec/LibCodecSummary.sol";
import "./codec/LibCodecProposeBatchesInputs.sol";
import "./codec/LibCodecProverAuth.sol";
import "./codec/LibCodecBatchProveInput.sol";
import "./IBondManager2.sol";

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
abstract contract TaikoInbox is AbstractInbox, IBondManager2 {
    using LibBonds for I.State;
    using LibState for I.State;
    using SafeERC20 for IERC20;

    /// @notice Protocol state storage
    /// @dev Storage layout must match Ontake fork for upgrade compatibility
    State public $;
    /// @notice Reserved storage slots for future upgrades
    uint256[50] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() AbstractInbox() { }

    // -------------------------------------------------------------------------
    // Bond Management Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the bond balance for a user
    /// @param _user The user address
    /// @return The bond balance
    function balanceOf4(address _user) external view returns (uint256) {
        return $.bondBalance[_user];
    }

    /// @notice Deposits bond for the sender
    /// @param _amount The amount to deposit
    function deposit4(uint256 _amount) external payable {
        $.bondBalance[msg.sender] +=
            LibBonds.depositBond(_getConfig().bondToken, msg.sender, _amount);
    }

    /// @notice Withdraws bond for the sender
    /// @param _amount The amount to withdraw
    function withdraw4(uint256 _amount) external {
        $.withdrawBond(_getConfig().bondToken, _amount);
    }

    /// @notice Gets the bond token address
    /// @return The bond token address
    function bondToken4() external view returns (address) {
        return _getConfig().bondToken;
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @inheritdoc AbstractInbox
    function _getBlobHash(uint256 _blobIdx) internal view override returns (bytes32) {
        return blobhash(_blobIdx);
    }

    /// @inheritdoc AbstractInbox
    function _getBlockHash(uint256 _blockNumber) internal view override returns (bytes32) {
        return blockhash(_blockNumber);
    }

    /// @inheritdoc AbstractInbox
    function _isSignalSent(
        I.Config memory _conf,
        bytes32 _signalSlot
    )
        internal
        view
        override
        returns (bool)
    {
        return ISignalService(_conf.signalService).isSignalSent(_signalSlot);
    }

    /// @inheritdoc AbstractInbox
    function _syncChainData(
        I.Config memory _conf,
        uint64 _blockId,
        bytes32 _stateRoot
    )
        internal
        override
    {
        ISignalService(_conf.signalService).syncChainData(
            _conf.chainId, LibSignals.STATE_ROOT, _blockId, _stateRoot
        );
    }

    /// @inheritdoc AbstractInbox
    function _transferFee(
        address _feeToken,
        address _from,
        address _to,
        uint256 _amount
    )
        internal
        override
    {
        IERC20(_feeToken).safeTransferFrom(_from, _to, _amount);
    }

    /// @inheritdoc AbstractInbox
    function _debitBond(I.Config memory _conf, address _user, uint256 _amount) internal override {
        LibBonds.debitBond($, _conf.bondToken, _user, _amount);
    }

    /// @inheritdoc AbstractInbox
    function _creditBond(address _user, uint256 _amount) internal override {
        LibBonds.creditBond($, _user, _amount);
    }

    /// @inheritdoc AbstractInbox
    function _loadSummaryHash() internal view override returns (bytes32) {
        return $.loadSummaryHash();
    }

    /// @inheritdoc AbstractInbox
    function _saveSummaryHash(bytes32 _summaryHash) internal override {
        $.saveSummaryHash(_summaryHash);
    }

    /// @inheritdoc AbstractInbox
    function _loadTransitionMetaHash(
        I.Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        override
        returns (bytes32 metaHash_, bool isFirstTransition_)
    {
        return $.loadTransitionMetaHash(_conf, _lastVerifiedBlockHash, _batchId);
    }

    /// @inheritdoc AbstractInbox
    function _saveTransition(
        I.Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        override
        returns (bool isFirstTransition_)
    {
        return $.saveTransition(_conf, _batchId, _parentHash, _tranMetahash);
    }

    /// @inheritdoc AbstractInbox
    function _loadBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId
    )
        internal
        view
        override
        returns (bytes32)
    {
        return $.loadBatchMetaHash(_conf, _batchId);
    }

    /// @inheritdoc AbstractInbox
    function _saveBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
        override
    {
        return $.saveBatchMetaHash(_conf, _batchId, _metaHash);
    }

    /// @inheritdoc AbstractInbox
    function _encodeBatchContext(I.BatchContext memory _context)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibCodecBatchContext.encode(_context);
    }

    /// @inheritdoc AbstractInbox
    function _encodeTransitionMetas(I.TransitionMeta[] memory _transitionMetas)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibCodecTransitionMeta.encode(_transitionMetas);
    }

    /// @inheritdoc AbstractInbox
    function _encodeSummary(I.Summary memory _summary)
        internal
        pure
        override
        returns (bytes memory)
    {
        return LibCodecSummary.encode(_summary);
    }

    /// @inheritdoc AbstractInbox
    function _decodeProposeBatchesInputs(bytes memory _data)
        internal
        pure
        override
        returns (
            I.Summary memory,
            I.Batch[] memory,
            I.BatchProposeMetadataEvidence memory,
            I.TransitionMeta[] memory
        )
    {
        return LibCodecProposeBatchesInputs.decode(_data);
    }

    /// @inheritdoc AbstractInbox
    function _decodeProverAuth(bytes memory _data)
        internal
        pure
        override
        returns (I.ProverAuth memory)
    {
        return LibCodecProverAuth.decode(_data);
    }

    /// @inheritdoc AbstractInbox
    function _decodeSummary(bytes memory _data) internal pure override returns (I.Summary memory) {
        return LibCodecSummary.decode(_data);
    }

    /// @inheritdoc AbstractInbox
    function _decodeProveBatchesInputs(bytes memory _data)
        internal
        pure
        override
        returns (I.BatchProveInput[] memory)
    {
        return LibCodecBatchProveInput.decode(_data);
    }
}
