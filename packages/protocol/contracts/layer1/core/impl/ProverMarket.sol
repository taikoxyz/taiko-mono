// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "../iface/IInbox.sol";
import { IProverMarket } from "../iface/IProverMarket.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @title ProverMarket
/// @notice Perpetual reverse-auction prover market. Provers bid to win exclusive proving rights
/// for epochs of proposals. Lower fee bids displace the current winner. The market handles
/// authorization, fee accounting, and bond management for proving obligations.
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;
    using LibAddress for address;

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
        uint48 nextEpochId;
        bool permissionlessMode;
        bool activeEpochExiting;
        bool degradedMode;
    }

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev Inbox that owns proposal acceptance and proof finalization.
    IInbox internal immutable _inbox;

    /// @dev Bond token that backs prover obligations.
    IERC20 internal immutable _bondToken;

    /// @dev Minimum bond in gwei required to place a bid.
    uint64 internal immutable _minBond;

    /// @dev Seconds after which proving becomes permissionless for a proposal.
    uint48 internal immutable _permissionlessProvingDelay;

    /// @dev Maximum displaced epochs tracked for bond release.
    uint8 internal constant MAX_DISPLACED_EPOCHS = 8;

    /// @dev Enter degraded mode before the displaced queue is full so one slot remains reserved.
    uint8 internal constant ENTER_DEGRADED_AT = MAX_DISPLACED_EPOCHS - 1;

    /// @dev Exit degraded mode only after the displaced backlog is fully drained.
    uint8 internal constant EXIT_DEGRADED_AT = 0;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Shared market state.
    MarketState public marketState;

    /// @notice All epochs indexed by epoch id.
    mapping(uint48 epochId => Epoch) public epochs;

    /// @notice Bond balances tracked by account in gwei.
    mapping(address account => uint64 bondBalance) public bondBalances;

    /// @notice Deposited proposer credits and accrued prover fees tracked by account in wei.
    mapping(address account => uint256 feeCreditBalance) public feeCreditBalances;

    /// @notice Maps proposal id to the epoch that owns it.
    mapping(uint48 proposalId => uint48 epochId) public proposalEpochs;

    /// @dev Displaced epochs awaiting bond release after finalization.
    uint48[8] internal _displacedEpochIds;
    uint8 internal _numDisplacedEpochs;

    /// @notice Slashed bond retained in-market and paid out to future rescue provers.
    uint64 public rescueRewardPool;

    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bid is placed or updated.
    event BidPlaced(
        uint48 indexed epochId, address indexed operator, address feeRecipient, uint64 feeInGwei
    );

    /// @notice Emitted when a pending epoch becomes active.
    event EpochActivated(uint48 indexed epochId, uint48 firstProposalId);

    /// @notice Emitted when an operator exits their position.
    event EpochExited(uint48 indexed epochId);

    /// @notice Emitted when bond is deposited.
    event BondDeposited(address indexed account, uint64 amount);

    /// @notice Emitted when bond is withdrawn.
    event BondWithdrawn(address indexed account, uint64 amount);

    /// @notice Emitted when locked bond is released back to operator after finalization.
    event BondReleased(uint48 indexed epochId, address indexed operator, uint64 amount);

    /// @notice Emitted when fee credit is deposited.
    event FeeCreditDeposited(address indexed account, uint256 amount);

    /// @notice Emitted when fee credit is withdrawn.
    event FeeCreditWithdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when a prover fee is reserved from proposer credit.
    event FeeReserved(uint48 indexed proposalId, address indexed proposer, uint64 feeInGwei);

    /// @notice Emitted when emergency permissionless mode changes.
    event PermissionlessModeUpdated(bool enabled);

    /// @notice Emitted when protocol churn safety disables or restores exclusive assignments.
    event DegradedModeUpdated(bool enabled);

    /// @notice Emitted when a prover misses the exclusive proving window and is slashed.
    event EpochSlashed(
        uint48 indexed epochId,
        address indexed operator,
        address indexed proofSubmitter,
        uint64 slashedAmount,
        uint64 rewardAmount
    );

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable contract dependencies.
    /// @param _inboxAddr The inbox address.
    /// @param _bondTokenAddr The bond token address.
    /// @param _minBondGwei The minimum bond in gwei required to bid.
    /// @param _permissionlessProvingDelaySeconds Seconds until proving becomes open.
    constructor(
        address _inboxAddr,
        address _bondTokenAddr,
        uint64 _minBondGwei,
        uint48 _permissionlessProvingDelaySeconds
    ) {
        require(_inboxAddr != address(0), ZeroAddress());
        require(_bondTokenAddr != address(0), ZeroAddress());
        require(_minBondGwei != 0, ZeroValue());

        _inbox = IInbox(_inboxAddr);
        _bondToken = IERC20(_bondTokenAddr);
        _minBond = _minBondGwei;
        _permissionlessProvingDelay = _permissionlessProvingDelaySeconds;
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
    function depositBond(uint64 _amount) external nonReentrant {
        require(_amount != 0, ZeroValue());
        _bondToken.safeTransferFrom(msg.sender, address(this), uint256(_amount) * 1 gwei);
        bondBalances[msg.sender] += _amount;
        emit BondDeposited(msg.sender, _amount);
    }

    /// @inheritdoc IProverMarket
    function withdrawBond(uint64 _amount) external nonReentrant {
        require(_amount != 0, ZeroValue());
        require(bondBalances[msg.sender] >= _amount, InsufficientBond());
        bondBalances[msg.sender] -= _amount;
        _bondToken.safeTransfer(msg.sender, uint256(_amount) * 1 gwei);
        emit BondWithdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverMarket
    function depositFeeCredit() external payable {
        require(msg.value != 0, ZeroValue());
        feeCreditBalances[msg.sender] += msg.value;
        emit FeeCreditDeposited(msg.sender, msg.value);
    }

    /// @inheritdoc IProverMarket
    function withdrawFeeCredit(uint256 _amount) external nonReentrant {
        require(_amount != 0, ZeroValue());
        require(feeCreditBalances[msg.sender] >= _amount, InsufficientFeeCredit());
        feeCreditBalances[msg.sender] -= _amount;
        msg.sender.sendEtherAndVerify(_amount);
        emit FeeCreditWithdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverMarket
    function bid(address _feeRecipient, uint64 _feeInGwei) external whenNotPaused {
        require(_feeRecipient != address(0), ZeroAddress());
        require(bondBalances[msg.sender] >= _minBond, InsufficientBond());

        MarketState memory state = marketState;

        // Must undercut the active epoch fee to become the new pending prover.
        if (state.activeEpochId != 0) {
            require(_feeInGwei < epochs[state.activeEpochId].feeInGwei, BidFeeTooHigh());
        }

        // If there is an existing pending epoch from a different operator, must also undercut it.
        // Refund the displaced pending operator's bond.
        if (state.pendingEpochId != 0) {
            Epoch storage pending = epochs[state.pendingEpochId];
            if (pending.operator != msg.sender) {
                require(_feeInGwei < pending.feeInGwei, BidFeeTooHigh());
                bondBalances[pending.operator] += pending.bondedAmount;
            } else {
                // Same operator re-bidding: refund old bond before locking fresh.
                bondBalances[msg.sender] += pending.bondedAmount;
            }
        }

        // Lock bond and create new pending epoch.
        bondBalances[msg.sender] -= _minBond;
        uint48 newEpochId = ++state.nextEpochId;

        epochs[newEpochId] = Epoch({
            operator: msg.sender,
            feeRecipient: _feeRecipient,
            feeInGwei: _feeInGwei,
            bondedAmount: _minBond,
            activatedAt: 0,
            firstProposalId: 0,
            lastAssignedProposalId: 0
        });

        state.pendingEpochId = newEpochId;
        marketState = state;

        emit BidPlaced(newEpochId, msg.sender, _feeRecipient, _feeInGwei);
    }

    /// @inheritdoc IProverMarket
    function exit() external {
        MarketState memory state = marketState;

        // Check pending first (can fully clear it).
        if (state.pendingEpochId != 0 && epochs[state.pendingEpochId].operator == msg.sender) {
            Epoch storage pending = epochs[state.pendingEpochId];
            bondBalances[msg.sender] += pending.bondedAmount;
            pending.bondedAmount = 0;
            uint48 exitedId = state.pendingEpochId;
            state.pendingEpochId = 0;
            marketState = state;
            emit EpochExited(exitedId);
            return;
        }

        // Check active (mark as exiting, stays liable for assigned proposals).
        if (state.activeEpochId != 0 && epochs[state.activeEpochId].operator == msg.sender) {
            require(!state.activeEpochExiting, NoBidToExit());
            state.activeEpochExiting = true;
            marketState = state;
            emit EpochExited(state.activeEpochId);
            return;
        }

        revert NoBidToExit();
    }

    /// @inheritdoc IProverMarket
    function onProposalAccepted(
        uint48 _proposalId,
        address _proposer,
        uint48 _proposalTimestamp
    )
        external
        onlyFrom(address(_inbox))
    {
        MarketState memory state = marketState;

        if (!state.permissionlessMode && !state.degradedMode) {
            if (state.activeEpochId == 0) {
                if (state.pendingEpochId != 0) {
                    if (_numDisplacedEpochs >= ENTER_DEGRADED_AT) {
                        state.degradedMode = true;
                        emit DegradedModeUpdated(true);
                    } else {
                        _activatePendingEpoch(state, _proposalId, _proposalTimestamp);
                    }
                }
            } else if (state.activeEpochExiting) {
                if (state.pendingEpochId != 0 && _numDisplacedEpochs >= ENTER_DEGRADED_AT) {
                    _retireActiveEpoch(state);
                    state.degradedMode = true;
                    emit DegradedModeUpdated(true);
                } else {
                    _retireActiveEpoch(state);
                    if (state.pendingEpochId != 0) {
                        _activatePendingEpoch(state, _proposalId, _proposalTimestamp);
                    }
                }
            } else if (state.pendingEpochId != 0) {
                if (_numDisplacedEpochs >= ENTER_DEGRADED_AT) {
                    _retireActiveEpoch(state);
                    state.degradedMode = true;
                    emit DegradedModeUpdated(true);
                } else {
                    _retireActiveEpoch(state);
                    _activatePendingEpoch(state, _proposalId, _proposalTimestamp);
                }
            }
        }

        // Assign proposal to the active epoch.
        uint48 activeId = state.activeEpochId;
        if (activeId != 0 && !state.permissionlessMode && !state.degradedMode) {
            epochs[activeId].lastAssignedProposalId = _proposalId;
            proposalEpochs[_proposalId] = activeId;

            // Reserve fee from proposer's credit balance.
            uint256 feeWei = uint256(epochs[activeId].feeInGwei) * 1 gwei;
            if (feeWei > 0 && feeCreditBalances[_proposer] >= feeWei) {
                feeCreditBalances[_proposer] -= feeWei;
                feeCreditBalances[epochs[activeId].feeRecipient] += feeWei;
                emit FeeReserved(_proposalId, _proposer, epochs[activeId].feeInGwei);
            }
        }

        marketState = state;
    }

    /// @inheritdoc IProverMarket
    function beforeProofSubmission(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _proposalTimestamp,
        uint256 _proposalAge
    )
        external
        onlyFrom(address(_inbox))
        view
    {
        _proposalTimestamp; // unused but part of interface

        // Permissionless mode: anyone can prove.
        if (marketState.permissionlessMode) return;

        // After the permissionless delay, anyone can prove.
        if (_proposalAge >= uint256(_permissionlessProvingDelay)) return;

        // Look up which epoch owns this proposal.
        uint48 epochId = proposalEpochs[_firstNewProposalId];

        // No epoch assigned (proposal accepted without active market): permissionless.
        if (epochId == 0) return;

        // During the exclusive window, only the epoch operator may prove.
        require(_caller == epochs[epochId].operator, NotAuthorizedProver());
    }

    /// @inheritdoc IProverMarket
    function onProofAccepted(
        address _caller,
        address _actualProver,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint256 _proposalAge,
        uint48 _finalizedAt
    )
        external
        onlyFrom(address(_inbox))
    {
        _actualProver; // unused but part of interface
        _finalizedAt; // unused but part of interface

        MarketState memory state = marketState;
        state.lastFinalizedProposalId = _lastProposalId;

        _maybeSlashLateProof(state, _caller, _firstNewProposalId, _proposalAge);

        // Release bonds for displaced epochs whose proposals are now fully finalized.
        _releaseDisplacedBonds(_lastProposalId);

        if (state.degradedMode && _numDisplacedEpochs <= EXIT_DEGRADED_AT) {
            state.degradedMode = false;
            emit DegradedModeUpdated(false);
        }

        marketState = state;
    }

    /// @inheritdoc IProverMarket
    function forcePermissionlessMode(bool _enabled) external onlyOwner {
        marketState.permissionlessMode = _enabled;
        emit PermissionlessModeUpdated(_enabled);
    }

    /// @inheritdoc IProverMarket
    function creditMigratedBond(
        address _account,
        uint64 _amount
    )
        external
        onlyFrom(address(_inbox))
    {
        bondBalances[_account] += _amount;
        emit BondDeposited(_account, _amount);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Activates the current pending epoch for new assignments.
    function _activatePendingEpoch(
        MarketState memory _state,
        uint48 _proposalId,
        uint48 _proposalTimestamp
    )
        private
    {
        uint48 pendingId = _state.pendingEpochId;
        epochs[pendingId].activatedAt = _proposalTimestamp;
        epochs[pendingId].firstProposalId = _proposalId;

        _state.activeEpochId = pendingId;
        _state.pendingEpochId = 0;
        _state.activeEpochExiting = false;

        emit EpochActivated(pendingId, _proposalId);
    }

    /// @dev Retires the active epoch so already-assigned proposals remain tracked but new ones do
    ///      not attach to it.
    function _retireActiveEpoch(MarketState memory _state) private {
        _addDisplacedEpoch(_state.activeEpochId);
        _state.activeEpochId = 0;
        _state.activeEpochExiting = false;
    }

    /// @dev Slashes the owning epoch if the first newly finalized proposal aged into the
    ///      permissionless window before proof submission.
    function _maybeSlashLateProof(
        MarketState memory _state,
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        private
    {
        if (_state.permissionlessMode || _proposalAge < uint256(_permissionlessProvingDelay)) {
            return;
        }

        uint48 epochId = proposalEpochs[_firstNewProposalId];
        if (epochId == 0) return;

        Epoch storage epoch = epochs[epochId];
        uint64 slashedAmount = epoch.bondedAmount;
        if (slashedAmount == 0) return;

        epoch.bondedAmount = 0;

        uint64 rewardAmount;
        if (_caller == epoch.operator) {
            rescueRewardPool += slashedAmount;
        } else {
            rewardAmount = rescueRewardPool + slashedAmount;
            rescueRewardPool = 0;
            bondBalances[_caller] += rewardAmount;
        }

        if (_state.activeEpochId == epochId) {
            _state.activeEpochId = 0;
            _state.activeEpochExiting = false;
        }

        emit EpochSlashed(epochId, epoch.operator, _caller, slashedAmount, rewardAmount);
    }

    /// @dev Adds an epoch to the displaced tracking array for future bond release.
    function _addDisplacedEpoch(uint48 _epochId) private {
        uint8 n = _numDisplacedEpochs;
        require(n < MAX_DISPLACED_EPOCHS, TooManyDisplacedEpochs());
        _displacedEpochIds[n] = _epochId;
        _numDisplacedEpochs = n + 1;
    }

    /// @dev Releases bonds for displaced epochs whose proposals are all finalized.
    function _releaseDisplacedBonds(uint48 _lastFinalizedProposalId) private {
        uint8 n = _numDisplacedEpochs;
        uint8 remaining;
        for (uint8 i; i < n; ++i) {
            uint48 eid = _displacedEpochIds[i];
            Epoch storage e = epochs[eid];
            if (e.lastAssignedProposalId <= _lastFinalizedProposalId) {
                if (e.bondedAmount > 0) {
                    bondBalances[e.operator] += e.bondedAmount;
                    emit BondReleased(eid, e.operator, e.bondedAmount);
                    e.bondedAmount = 0;
                }
            } else {
                _displacedEpochIds[remaining] = eid;
                ++remaining;
            }
        }
        _numDisplacedEpochs = remaining;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ZeroAddress();
    error ZeroValue();
    error InsufficientBond();
    error InsufficientFeeCredit();
    error NoBidToExit();
    error BidFeeTooHigh();
    error NotAuthorizedProver();
    error TooManyDisplacedEpochs();
}
