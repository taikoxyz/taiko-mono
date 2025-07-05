// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./TaikoInboxbase.sol";
import "./libs/LibStorage.sol";
import "./libs/LibBondManagement.sol";

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
abstract contract TaikoInbox2 is TaikoInboxbase, IBondManager2 {
    using LibBondManagement for ITaikoInbox2.State;
    using LibInitialization for ITaikoInbox2.State;
    using LibStorage for ITaikoInbox2.State;
    using SafeERC20 for IERC20;

    // State public state; // storage layout much match Ontake fork
    // uint256[50] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() TaikoInboxbase() { }
    /// @notice Gets the bond balance for a user
    /// @param _user The user address
    /// @return The bond balance

    function v4BondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    /// @notice Deposits bond for the sender
    /// @param _amount The amount to deposit
    function v4DepositBond(uint256 _amount) external payable {
        state.bondBalance[msg.sender] +=
            LibBondManagement.depositBond(_getConfig().bondToken, msg.sender, _amount);
    }

    /// @notice Withdraws bond for the sender
    /// @param _amount The amount to withdraw
    function v4WithdrawBond(uint256 _amount) external {
        state.withdrawBond(_getConfig().bondToken, _amount);
    }

    // -------------------------------------------------------------------------
    // Internal Binding Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the blob hash for a block number
    /// @param _blockNumber The block number
    /// @return The blob hash
    function _getBlobHash(uint256 _blockNumber) internal view virtual override returns (bytes32) {
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
        virtual
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
        virtual
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
    function _debitBond(
        I.Config memory _conf,
        address _user,
        uint256 _amount
    )
        internal
        virtual
        override
    {
        LibBondManagement.debitBond(state, _conf.bondToken, _user, _amount);
    }

    /// @notice Credits bond to a user
    /// @param _user The user address
    /// @param _amount The amount to credit
    function _creditBond(address _user, uint256 _amount) internal virtual override {
        LibBondManagement.creditBond(state, _user, _amount);
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
        virtual
        override
    {
        IERC20(_feeToken).safeTransferFrom(_from, _to, _amount);
    }

    function _loadSummaryHash() internal view override returns (bytes32) {
        return LibStorage.loadSummaryHash(state);
    }

    function _saveSummaryHash(bytes32 _summaryHash) internal override {
        LibStorage.saveSummaryHash(state, _summaryHash);
    }
}
