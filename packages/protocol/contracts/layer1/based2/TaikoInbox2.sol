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
import "./libs/LibStorage.sol";

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
    using LibBatchProposal for ITaikoInbox2.State;
    using LibBatchProving for ITaikoInbox2.State;
    using LibBatchVerification for ITaikoInbox2.State;
    using LibBondManagement for ITaikoInbox2.State;
    using LibInitialization for ITaikoInbox2.State;
    using LibStorage for ITaikoInbox2.State;
    using SafeERC20 for IERC20;

    State public state; // storage layout much match Ontake fork
    uint256[50] private __gap;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() EssentialContract() { }

    // -------------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the contract with owner and genesis block hash
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    function v4Init(address _owner, bytes32 _genesisBlockHash) external initializer {
        __Taiko_init(_owner, _genesisBlockHash);
    }

    /// @notice Proposes and verifies batches
    /// @param _summary The current summary
    /// @param _batch The batches to propose
    /// @param _evidence The batch proposal evidence
    /// @param _trans The transition metadata for verification
    /// @return The updated summary
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
        LibDataUtils.ReadWrite memory rw = _getReadWrite();

        // Propose batches
        _summary = state.proposeBatches(conf, rw, _summary, _batch, _evidence);

        // Verify batches
        _summary = state.verifyBatches(conf, rw, _summary, _trans);

        state.summaryHash = keccak256(abi.encode(_summary));
        return _summary;
    }

    /// @notice Proves batches with cryptographic proof
    /// @param _summary The current summary
    /// @param _inputs The batch prove inputs
    /// @param _proof The cryptographic proof
    /// @return The updated summary
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
        LibDataUtils.ReadWrite memory rw = _getReadWrite();

        // Prove batches and get aggregated hash
        bytes32 aggregatedBatchHash;
        (_summary, aggregatedBatchHash) = state.proveBatches(conf, rw, _summary, _inputs);

        // Verify the proof
        IVerifier2(conf.verifier).verifyProof(aggregatedBatchHash, _proof);

        state.summaryHash = keccak256(abi.encode(_summary));
        return _summary;
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

    /// @notice Gets the bond balance for a user
    /// @param _user The user address
    /// @return The bond balance
    function v4BondBalanceOf(address _user) external view returns (uint256) {
        return state.bondBalance[_user];
    }

    /// @notice Checks if this contract is an inbox
    /// @return Always returns true
    function v4IsInbox() external pure override returns (bool) {
        return true;
    }

    // -------------------------------------------------------------------------
    // Public Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the current configuration
    /// @return The configuration struct
    function v4GetConfig() external view virtual returns (Config memory) {
        return _getConfig();
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------------

    /// @notice Initializes the Taiko contract
    /// @param _owner The owner address
    /// @param _genesisBlockHash The genesis block hash
    function __Taiko_init(address _owner, bytes32 _genesisBlockHash) internal onlyInitializing {
        __Essential_init(_owner);
        state.init(_genesisBlockHash);
    }

    /// @notice Gets the configuration (must be implemented by derived contracts)
    /// @return The configuration struct
    function _getConfig() internal view virtual returns (Config memory);

    // -------------------------------------------------------------------------
    // Internal Binding Functions
    // -------------------------------------------------------------------------

    /// @notice Gets the blob hash for a block number
    /// @param _blockNumber The block number
    /// @return The blob hash
    function _getBlobHash(uint256 _blockNumber) internal view virtual returns (bytes32) {
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
    {
        ISignalService(_conf.signalService).syncChainData(
            _conf.chainId, LibSignals.STATE_ROOT, _blockId, _stateRoot
        );
    }

    /// @notice Debits bond from a user
    /// @param _conf The configuration
    /// @param _user The user address
    /// @param _amount The amount to debit
    function _debitBond(I.Config memory _conf, address _user, uint256 _amount) internal virtual {
        LibBondManagement.debitBond(state, _conf.bondToken, _user, _amount);
    }

    /// @notice Credits bond to a user
    /// @param _user The user address
    /// @param _amount The amount to credit
    function _creditBond(address _user, uint256 _amount) internal virtual {
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
    {
        IERC20(_feeToken).safeTransferFrom(_from, _to, _amount);
    }

    // -------------------------------------------------------------------------
    // Private Functions
    // -------------------------------------------------------------------------

    /// @notice Creates a ReadWrite struct with function pointers
    /// @return The ReadWrite struct with all required function pointers
    function _getReadWrite() private pure returns (LibDataUtils.ReadWrite memory) {
        return LibDataUtils.ReadWrite({
            // Read functions
            isSignalSent: _isSignalSent,
            getBlobHash: _getBlobHash,
            // Write functions
            debitBond: _debitBond,
            creditBond: _creditBond,
            transferFee: _transferFee,
            syncChainData: _syncChainData
        });
    }

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when the provided summary doesn't match the stored summary hash
    error SummaryMismatch();
}
