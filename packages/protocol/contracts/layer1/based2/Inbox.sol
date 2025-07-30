// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
import "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import "src/layer1/forced-inclusion/IForcedInclusionStore.sol";
import "./AbstractInbox.sol";
import "./state/LibBonds.sol";
import "./state/LibState.sol";
import "./state/IStorage.sol";
import "./IBondManager2.sol";

/// @title Inbox
/// @dev This contract extends AbstractInbox with L1-specific implementations for blob hash
/// retrieval,
/// block hash access, signal service integration, and fee transfers. It also implements the
/// IBondManager2 interface to handle user bond management with deposit and withdrawal capabilities.
/// The contract uses LibBonds for bond accounting and LibState for protocol state management.
/// @custom:security-contact security@taiko.xyz
abstract contract Inbox is AbstractInbox, IBondManager2, IStorage {
    using LibBonds for State;
    using LibState for State;
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
        Config memory _conf,
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
        Config memory _conf,
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
    function _debitBond(Config memory _conf, address _user, uint256 _amount) internal override {
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
        Config memory _conf,
        bytes32 _lastVerifiedBlockHash,
        uint256 _batchId
    )
        internal
        view
        override
        returns (bytes32 metaHash_)
    {
        return $.loadTransitionMetaHash(_conf, _lastVerifiedBlockHash, _batchId);
    }

    /// @inheritdoc AbstractInbox
    function _saveTransition(
        Config memory _conf,
        uint48 _batchId,
        bytes32 _parentHash,
        bytes32 _tranMetahash
    )
        internal
        override
    {
        return $.saveTransition(_conf, _batchId, _parentHash, _tranMetahash);
    }

    /// @inheritdoc AbstractInbox
    function _loadBatchMetaHash(
        Config memory _conf,
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
        Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
        override
    {
        return $.saveBatchMetaHash(_conf, _batchId, _metaHash);
    }

    /// @inheritdoc AbstractInbox
    function _getCurrentPreconfer() internal view override returns (address) {
        IPreconfWhitelist preconfWhitelist = IPreconfWhitelist(_getConfig().preconfWhitelist);
        address preconfer = preconfWhitelist.getOperatorForCurrentEpoch();

        if (preconfer != address(0)) {
            return preconfer;
        }

        return preconfWhitelist.getFallbackPreconfer();
    }

    /// @inheritdoc AbstractInbox
    function _isForcedInclusionDue(uint48 _batchId) internal view override returns (bool) {
        return IForcedInclusionStore(_getConfig().forcedInclusionStore).isOldestForcedInclusionDue(
            _batchId
        );
    }

    /// @inheritdoc AbstractInbox
    function _consumeForcedInclusion(
        address _feeRecipient,
        uint64 _nextBatchId
    )
        internal
        override
        returns (IForcedInclusionStore.ForcedInclusion memory)
    {
        return IForcedInclusionStore(_getConfig().forcedInclusionStore).consumeOldestForcedInclusion(
            _feeRecipient, _nextBatchId
        );
    }
}
