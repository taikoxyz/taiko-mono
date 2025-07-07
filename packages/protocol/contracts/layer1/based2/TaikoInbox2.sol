// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/signal/LibSignals.sol";
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
abstract contract TaikoInbox2 is TaikoInboxBase, IBondManager2 {
    using LibBonds for I.State;
    using LibState for I.State;
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
    // Internal Functions
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
        return state.loadSummaryHash();
    }

    function _saveSummaryHash(bytes32 _summaryHash) internal override {
        state.saveSummaryHash(_summaryHash);
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
        return state.loadTransitionMetaHash(_conf, _lastVerifiedBlockHash, _batchId);
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
        return state.saveTransition(_conf, _batchId, _parentHash, _tranMetahash);
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
        return state.loadBatchMetaHash(_conf, _batchId);
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
        return state.saveBatchMetaHash(_conf, _batchId, _metaHash);
    }
}
