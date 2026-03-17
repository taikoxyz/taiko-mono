// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "../iface/IInbox.sol";
import { IProverMarket } from "../iface/IProverMarket.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title ProverMarket
/// @notice Skeleton contract for the prover market integration review
/// @dev This contract intentionally exposes the planned market surface without implementing the
/// economic logic yet. It exists so the `Inbox` integration and contract boundary can be reviewed
/// before the market behavior is finalized.
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Market-owned liability interval for a prover epoch.
    struct Epoch {
        address operator;
        address feeRecipient;
        uint64 feeInGwei;
        uint64 bondedAmount;
        uint48 activatedAt;
        uint48 firstProposalId;
        uint48 lastAssignedProposalId;
    }

    /// @notice Top-level market state shared across epochs.
    struct MarketState {
        uint48 activeEpochId;
        uint48 pendingEpochId;
        uint48 lastFinalizedProposalId;
        bool permissionlessMode;
    }

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev Inbox that owns proposal acceptance and proof finalization.
    IInbox internal immutable _inbox;

    /// @dev Bond token that backs prover obligations.
    IERC20 internal immutable _bondToken;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The currently active epoch.
    Epoch public activeEpoch;

    /// @notice The next epoch selected by bidding but not yet activated.
    Epoch public pendingEpoch;

    /// @notice Shared market state.
    MarketState public marketState;

    /// @notice Bond balances tracked by account in gwei.
    mapping(address account => uint64 bondBalance) public bondBalances;

    /// @notice Fee credits tracked by account in wei.
    mapping(address account => uint256 feeCreditBalance) public feeCreditBalances;

    uint256[45] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when emergency permissionless mode changes.
    /// @param enabled True if permissionless mode is forced, false otherwise.
    event PermissionlessModeUpdated(bool enabled);

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable contract dependencies.
    /// @param _inboxAddr The inbox address.
    /// @param _bondTokenAddr The bond token address.
    constructor(address _inboxAddr, address _bondTokenAddr) {
        require(_inboxAddr != address(0), ZeroAddress());
        require(_bondTokenAddr != address(0), ZeroAddress());

        _inbox = IInbox(_inboxAddr);
        _bondToken = IERC20(_bondTokenAddr);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract owner.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProverMarket
    function bid(address _feeRecipient, uint64 _feeInGwei) external {
        _feeRecipient;
        _feeInGwei;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function exit() external {
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function depositBond(uint64 _amount) external {
        _amount;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function withdrawBond(uint64 _amount) external {
        _amount;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function depositFeeCredit() external payable {
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function withdrawFeeCredit(uint256 _amount) external {
        _amount;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function beforeProofSubmission(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _proposalTimestamp,
        uint256 _proposalAge
    )
        external
    {
        _caller;
        _firstNewProposalId;
        _proposalTimestamp;
        _proposalAge;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function onProposalAccepted(
        uint48 _proposalId,
        address _proposer,
        uint48 _proposalTimestamp
    )
        external
    {
        _proposalId;
        _proposer;
        _proposalTimestamp;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function onProofAccepted(
        address _caller,
        address _actualProver,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint48 _finalizedAt
    )
        external
    {
        _caller;
        _actualProver;
        _firstNewProposalId;
        _lastProposalId;
        _finalizedAt;
        revert NotImplemented();
    }

    /// @inheritdoc IProverMarket
    function forcePermissionlessMode(bool _enabled) external onlyOwner {
        _enabled;
        revert NotImplemented();
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error NotImplemented();
    error ZeroAddress();
}
