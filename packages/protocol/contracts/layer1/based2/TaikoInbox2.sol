// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TaikoInboxBase.sol";
import "./libs/LibBonds.sol";
import "./IBondManager2.sol";

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
contract TaikoInbox2 is TaikoInboxBase, IBondManager2 {
    using LibBonds for I.State;
    using SafeERC20 for IERC20;

    State public state; // storage layout must match Ontake fork
    uint256[50] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() TaikoInboxBase() { }

    // -------------------------------------------------------------------------
    // Bond Management Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the bond balance for a user
    /// @param _user The user address
    /// @return The bond balance
    function balanceOf4(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    /// @notice Deposits bond for the sender
    /// @param _amount The amount to deposit
    function deposit4(uint256 _amount) external payable {
        state.bondBalance[msg.sender] +=
            LibBonds.depositBond(_getConfig().bondToken, msg.sender, _amount);
    }

    /// @notice Withdraws bond for the sender
    /// @param _amount The amount to withdraw
    function withdraw4(uint256 _amount) external {
        state.withdrawBond(_getConfig().bondToken, _amount);
    }

    function bondToken4() external view returns (address) {
        return _getConfig().bondToken;
    }

    // -------------------------------------------------------------------------
    // Internal  Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the blob hash for a block number
    /// @param _blockNumber The block number
    /// @return The blob hash
    function _getBlobHash(uint256 _blockNumber) internal view override returns (bytes32) {
        return blockhash(_blockNumber);
    }

    /// @notice Checks if a signal has been sent
    /// @param _conf The configuration
    /// @param _signalSlot The signal slot
    /// @return Whether the signal was sent
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

    /// @notice Syncs chain data to the signal service
    /// @param _conf The configuration
    /// @param _blockId The block ID
    /// @param _stateRoot The state root
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

    /// @notice Debits bond from a user
    /// @param _conf The configuration
    /// @param _user The user address
    /// @param _amount The amount to debit
    function _debitBond(I.Config memory _conf, address _user, uint256 _amount) internal override {
        LibBonds.debitBond(state, _conf.bondToken, _user, _amount);
    }

    /// @notice Credits bond to a user
    /// @param _user The user address
    /// @param _amount The amount to credit
    function _creditBond(address _user, uint256 _amount) internal override {
        LibBonds.creditBond(state, _user, _amount);
    }

    function _loadSummaryHash() internal view override returns (bytes32) {
        return state.summaryHash;
    }

    function _saveSummaryHash(bytes32 _summaryHash) internal override {
        state.summaryHash = _summaryHash;
    }

    /// @notice Transfers fee tokens between addresses
    /// @param _feeToken The fee token address
    /// @param _from The sender address
    /// @param _to The recipient address
    /// @param _amount The amount to transfer
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

    /// @notice Saves a transition to storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @param _parentHash The parent hash
    /// @param _tranMetahash The transition metadata hash
    /// @return isFirstTransition_ Whether this is the first transition
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
        uint256 slot = _batchId % _conf.batchRingBufferSize;

        // In the next code section, we always use `state.transitions[slot][1]` to reuse a
        // previously declared variable -- note that the second mapping key is always 1.
        // Tip: the reuse of the first transition slot can save 3900 gas per batch.
        (uint48 embeddedBatchId, bytes32 partialParentHash) = _loadBatchIdAndPartialParentHash(slot);

        isFirstTransition_ = embeddedBatchId != _batchId;

        if (isFirstTransition_) {
            // This is the very first transition of the batch.
            // We can reuse the transition slot to reduce gas cost.
            state.transitions[slot][1].batchIdAndPartialParentHash =
                (uint256(_parentHash) & ~type(uint48).max) | _batchId;
            state.transitions[slot][1].metaHash = _tranMetahash;
        } else if (partialParentHash == _parentHash >> 48) {
            // Same parent hash as stored, overwrite the existing transition
            state.transitions[slot][1].metaHash = _tranMetahash;
        } else {
            // Different parent hash, use separate mapping storage
            state.transitionMetaHashes[_batchId][_parentHash] = _tranMetahash;
        }
    }

    /// @notice Saves a batch metadata hash to storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @param _metaHash The metadata hash to save
    function _saveBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId,
        bytes32 _metaHash
    )
        internal
        override
    {
        state.batches[_batchId % _conf.batchRingBufferSize] = _metaHash;
    }

    /// @notice Loads a batch metadata hash from storage
    /// @param _conf The configuration
    /// @param _batchId The batch ID
    /// @return The batch metadata hash
    function _loadBatchMetaHash(
        I.Config memory _conf,
        uint256 _batchId
    )
        internal
        view
        override
        returns (bytes32)
    {
        return state.batches[_batchId % _conf.batchRingBufferSize];
    }

    /// @notice Loads a transition metadata hash from storage
    /// @param _conf The configuration
    /// @param _lastVerifiedBlockHash The last verified block hash
    /// @param _batchId The batch ID
    /// @return metaHash_ The transition metadata hash
    /// @return isFirstTransition_ Whether this is the first transition
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
        uint256 slot = _batchId % _conf.batchRingBufferSize;
        (uint48 embeddedBatchId, bytes32 partialParentHash) = _loadBatchIdAndPartialParentHash(slot);

        if (embeddedBatchId != _batchId) return (0, false);

        if (partialParentHash == _lastVerifiedBlockHash >> 48) {
            return (state.transitions[slot][1].metaHash, true);
        } else {
            return (state.transitionMetaHashes[_batchId][_lastVerifiedBlockHash], false);
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Loads batch ID and partial parent hash from storage
    /// @param _slot The storage slot
    /// @return embeddedBatchId_ The embedded batch ID
    /// @return partialParentHash_ The partial parent hash
    function _loadBatchIdAndPartialParentHash(uint256 _slot)
        private
        view
        returns (uint48 embeddedBatchId_, bytes32 partialParentHash_)
    {
        uint256 value = state.transitions[_slot][1].batchIdAndPartialParentHash;
        embeddedBatchId_ = uint48(value);
        partialParentHash_ = bytes32(value >> 48);
    }
}
