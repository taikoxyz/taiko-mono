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
        address prover;
        uint64 feeInGwei;
        uint64 bondedAmount;
        uint48 activatedAt;
        uint48 firstProposalId;
        uint48 lastProposalId;
    }

    /// @notice Top-level market state shared across epochs.
    struct MarketState {
        uint48 activeEpochId;
        uint48 pendingEpochId;
        uint48 lastFinalizedProposalId;
        uint48 nextEpochId;
        bool permissionlessMode;
        bool activeEpochExiting;
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

    /// @dev Exclusive proving window in seconds before permissionless proving opens.
    uint48 internal immutable _provingWindow;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Shared market state.
    MarketState public marketState;

    /// @notice All epochs indexed by epoch id.
    mapping(uint48 epochId => Epoch) public epochs;

    /// @notice Bond balances tracked by account in gwei.
    mapping(address account => uint64 bondBalance) public bondBalances;

    /// @notice Accrued prover fees tracked by account in wei.
    mapping(address account => uint256 feeBalance) public feeBalances;

    /// @dev Displaced epochs awaiting bond release after finalization.
    uint48[] internal _displacedEpochIds;

    /// @notice Slashed bond retained in-market and paid out to future rescue provers.
    uint64 public rescueRewardPool;

    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bid is placed or updated.
    event BidPlaced(uint48 indexed epochId, address indexed prover, uint64 feeInGwei);

    /// @notice Emitted when a pending epoch becomes active.
    event EpochActivated(uint48 indexed epochId, uint48 firstProposalId);

    /// @notice Emitted when a prover exits their position.
    event EpochExited(uint48 indexed epochId);

    /// @notice Emitted when bond is deposited.
    event BondDeposited(address indexed account, uint64 amount);

    /// @notice Emitted when bond is withdrawn.
    event BondWithdrawn(address indexed account, uint64 amount);

    /// @notice Emitted when locked bond is released back to prover after finalization.
    event BondReleased(uint48 indexed epochId, address indexed prover, uint64 amount);

    /// @notice Emitted when a prover fee is charged from proposer ETH.
    event FeeCharged(uint48 indexed proposalId, address indexed proposer, uint64 feeInGwei);

    /// @notice Emitted when accrued prover fees are withdrawn.
    event FeesWithdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when emergency permissionless mode changes.
    event PermissionlessModeUpdated(bool enabled);

    /// @notice Emitted when a prover misses the exclusive proving window and is slashed.
    event EpochSlashed(
        uint48 indexed epochId,
        address indexed prover,
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
    /// @param _provingWindowSeconds The exclusive proving window in seconds.
    constructor(
        address _inboxAddr,
        address _bondTokenAddr,
        uint64 _minBondGwei,
        uint48 _permissionlessProvingDelaySeconds,
        uint48 _provingWindowSeconds
    )
        nonZeroAddr(_inboxAddr)
        nonZeroAddr(_bondTokenAddr)
        nonZeroValue(_minBondGwei)
        nonZeroValue(_permissionlessProvingDelaySeconds)
        nonZeroValue(_provingWindowSeconds)
    {
        require(
            _permissionlessProvingDelaySeconds > _provingWindowSeconds, PermissionlessDelayTooSmall()
        );

        _inbox = IInbox(_inboxAddr);
        _bondToken = IERC20(_bondTokenAddr);
        _minBond = _minBondGwei;
        _permissionlessProvingDelay = _permissionlessProvingDelaySeconds;
        _provingWindow = _provingWindowSeconds;
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
    function depositBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        _bondToken.safeTransferFrom(msg.sender, address(this), uint256(_amount) * 1 gwei);
        bondBalances[msg.sender] += _amount;
        emit BondDeposited(msg.sender, _amount);
    }

    /// @inheritdoc IProverMarket
    function withdrawBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        require(bondBalances[msg.sender] >= _amount, InsufficientBond());
        bondBalances[msg.sender] -= _amount;
        _bondToken.safeTransfer(msg.sender, uint256(_amount) * 1 gwei);
        emit BondWithdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverMarket
    function withdrawFees(uint256 _amount) external nonReentrant nonZeroValue(_amount) {
        require(feeBalances[msg.sender] >= _amount, InsufficientFees());
        feeBalances[msg.sender] -= _amount;
        msg.sender.sendEtherAndVerify(_amount);
        emit FeesWithdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverMarket
    function bid(uint64 _feeInGwei) external nonReentrant whenNotPaused {
        require(bondBalances[msg.sender] >= _minBond, InsufficientBond());

        MarketState memory state = marketState;

        // Must undercut the active epoch fee to become the new pending prover.
        if (state.activeEpochId != 0) {
            require(_feeInGwei < epochs[state.activeEpochId].feeInGwei, BidFeeTooHigh());
        }

        // If there is an existing pending epoch from a different prover, must also undercut it.
        // Refund the displaced pending prover's bond.
        if (state.pendingEpochId != 0) {
            Epoch storage pending = epochs[state.pendingEpochId];
            if (pending.prover != msg.sender) {
                require(_feeInGwei < pending.feeInGwei, BidFeeTooHigh());
                bondBalances[pending.prover] += pending.bondedAmount;
            } else {
                // Same prover re-bidding: refund old bond before locking fresh.
                bondBalances[msg.sender] += pending.bondedAmount;
            }
        }

        // Lock bond and create new pending epoch.
        bondBalances[msg.sender] -= _minBond;
        uint48 newEpochId = ++state.nextEpochId;

        epochs[newEpochId] = Epoch({
            prover: msg.sender,
            feeInGwei: _feeInGwei,
            bondedAmount: _minBond,
            activatedAt: 0,
            firstProposalId: 0,
            lastProposalId: 0
        });

        state.pendingEpochId = newEpochId;
        marketState = state;

        emit BidPlaced(newEpochId, msg.sender, _feeInGwei);
    }

    /// @inheritdoc IProverMarket
    function exit() external {
        MarketState memory state = marketState;

        // Check pending first (can fully clear it).
        if (state.pendingEpochId != 0 && epochs[state.pendingEpochId].prover == msg.sender) {
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
        if (state.activeEpochId != 0 && epochs[state.activeEpochId].prover == msg.sender) {
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
        payable
        onlyFrom(address(_inbox))
    {
        MarketState memory state = marketState;
        uint256 feeConsumed;
        bool stateChanged;

        if (!state.permissionlessMode) {
            // Retire the active epoch if it is exiting or being displaced by a pending bid.
            if (state.activeEpochId != 0 && (state.activeEpochExiting || state.pendingEpochId != 0))
            {
                _retireActiveEpoch(state);
                stateChanged = true;
            }

            // Activate the pending epoch if there is no active epoch.
            if (state.activeEpochId == 0 && state.pendingEpochId != 0) {
                _activatePendingEpoch(state, _proposalId, _proposalTimestamp);
                stateChanged = true;
            }

            // Assign proposal to the active epoch and charge fee.
            uint48 activeId = state.activeEpochId;
            if (activeId != 0) {
                epochs[activeId].lastProposalId = _proposalId;

                uint256 feeWei = uint256(epochs[activeId].feeInGwei) * 1 gwei;
                if (feeWei > 0) {
                    require(msg.value >= feeWei, InsufficientFee());
                    feeBalances[epochs[activeId].prover] += feeWei;
                    feeConsumed = feeWei;
                    emit FeeCharged(_proposalId, _proposer, epochs[activeId].feeInGwei);
                }
            }
        }

        if (stateChanged) marketState = state;

        // Refund excess ETH to proposer (CEI: state writes above, external call below).
        uint256 excess = msg.value - feeConsumed;
        if (excess > 0) {
            _proposer.sendEtherAndVerify(excess);
        }
    }

    /// @inheritdoc IProverMarket
    function canSubmitProof(
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        public
        view
        returns (bool)
    {
        // Permissionless mode: anyone can prove.
        if (marketState.permissionlessMode) return true;

        // After the permissionless delay, anyone can prove.
        if (_proposalAge >= uint256(_permissionlessProvingDelay)) return true;

        // Look up which epoch owns this proposal by range.
        uint48 epochId = _findEpochForProposal(_firstNewProposalId);

        // No epoch assigned (proposal accepted without active market): permissionless.
        if (epochId == 0) return true;

        // During the exclusive window, only the epoch prover may prove.
        return _caller == epochs[epochId].prover;
    }

    /// @inheritdoc IProverMarket
    function onProofAccepted(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint256 _proposalAge
    )
        external
        onlyFrom(address(_inbox))
    {
        MarketState memory state = marketState;
        state.lastFinalizedProposalId = _lastProposalId;

        _checkAndSlash(state, _caller, _firstNewProposalId, _proposalAge);

        // Release bonds for displaced epochs whose proposals are now fully finalized.
        _releaseDisplacedBonds(_lastProposalId);

        marketState = state;
    }

    /// @inheritdoc IProverMarket
    function forcePermissionlessMode(bool _enabled) external onlyOwner {
        marketState.permissionlessMode = _enabled;
        emit PermissionlessModeUpdated(_enabled);
    }

    /// @inheritdoc IProverMarket
    function bondToken() external view returns (address) {
        return address(_bondToken);
    }

    /// @inheritdoc IProverMarket
    function provingWindow() external view returns (uint48) {
        return _provingWindow;
    }

    /// @inheritdoc IProverMarket
    function activeFeeInGwei() external view returns (uint64) {
        MarketState memory state = marketState;
        if (state.permissionlessMode) return 0;

        // Simulate the epoch transition that would happen on next proposal.
        if (state.activeEpochId != 0 && (state.activeEpochExiting || state.pendingEpochId != 0)) {
            // Active will be retired; pending (if any) will activate.
            if (state.pendingEpochId != 0) return epochs[state.pendingEpochId].feeInGwei;
            return 0;
        }
        if (state.activeEpochId == 0 && state.pendingEpochId != 0) {
            return epochs[state.pendingEpochId].feeInGwei;
        }
        if (state.activeEpochId != 0) return epochs[state.activeEpochId].feeInGwei;
        return 0;
    }

    /// @inheritdoc IProverMarket
    function minBond() external view returns (uint64) {
        return _minBond;
    }

    /// @inheritdoc IProverMarket
    function permissionlessProvingDelay() external view returns (uint48) {
        return _permissionlessProvingDelay;
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

    /// @dev Enforces prover authorization and slashes the owning epoch when the proof arrives
    ///      after the permissionless proving delay.
    function _checkAndSlash(
        MarketState memory _state,
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        private
    {
        // Permissionless mode: anyone can prove, no slashing.
        if (_state.permissionlessMode) return;

        uint48 epochId = _findEpochForProposal(_firstNewProposalId);

        // Within the exclusive window: only the epoch prover may prove.
        if (_proposalAge < uint256(_permissionlessProvingDelay)) {
            if (epochId != 0) {
                require(_caller == epochs[epochId].prover, NotAuthorizedProver());
            }
            return;
        }

        // Past the permissionless delay: anyone can prove, slash the epoch.
        if (epochId == 0) return;

        Epoch storage epoch = epochs[epochId];
        uint64 slashedAmount = epoch.bondedAmount;
        if (slashedAmount == 0) return;

        epoch.bondedAmount = 0;

        uint64 rewardAmount;
        if (_caller == epoch.prover) {
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

        emit EpochSlashed(epochId, epoch.prover, _caller, slashedAmount, rewardAmount);
    }

    /// @dev Finds which epoch owns a proposal by checking active and displaced epoch ranges.
    /// @return epochId_ The epoch that owns the proposal, or 0 if none.
    function _findEpochForProposal(uint48 _proposalId) private view returns (uint48 epochId_) {
        // Check active epoch.
        uint48 activeId = marketState.activeEpochId;
        if (activeId != 0) {
            Epoch storage e = epochs[activeId];
            if (_proposalId >= e.firstProposalId && _proposalId <= e.lastProposalId) {
                return activeId;
            }
        }

        // Check displaced epochs.
        uint256 n = _displacedEpochIds.length;
        for (uint256 i; i < n; ++i) {
            uint48 eid = _displacedEpochIds[i];
            Epoch storage e = epochs[eid];
            if (_proposalId >= e.firstProposalId && _proposalId <= e.lastProposalId) {
                return eid;
            }
        }
    }

    /// @dev Adds an epoch to the displaced tracking array for future bond release.
    function _addDisplacedEpoch(uint48 _epochId) private {
        _displacedEpochIds.push(_epochId);
    }

    /// @dev Releases bonds for displaced epochs whose proposals are all finalized.
    function _releaseDisplacedBonds(uint48 _lastFinalizedProposalId) private {
        uint256 n = _displacedEpochIds.length;
        uint256 remaining;
        for (uint256 i; i < n; ++i) {
            uint48 eid = _displacedEpochIds[i];
            Epoch storage e = epochs[eid];
            if (e.lastProposalId <= _lastFinalizedProposalId) {
                if (e.bondedAmount > 0) {
                    bondBalances[e.prover] += e.bondedAmount;
                    emit BondReleased(eid, e.prover, e.bondedAmount);
                    e.bondedAmount = 0;
                }
            } else {
                _displacedEpochIds[remaining++] = eid;
            }
        }
        // Trim released entries from the end using cached length.
        for (uint256 j = remaining; j < n; ++j) {
            _displacedEpochIds.pop();
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error PermissionlessDelayTooSmall();
    error InsufficientBond();
    error InsufficientFee();
    error InsufficientFees();
    error NoBidToExit();
    error BidFeeTooHigh();
    error NotAuthorizedProver();
}
