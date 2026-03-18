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
    uint64 internal immutable _minBondGwei;

    /// @dev Exclusive proving window in seconds. Within this window only the assigned prover may
    /// prove; after it anyone may prove and the assigned prover is slashed.
    uint48 internal immutable _provingWindow;

    /// @dev Minimum fee discount in basis points a new bid must undercut by (e.g. 1000 = 10%).
    uint16 internal immutable _bidDiscountBps;

    /// @dev Bond in gwei reserved per assigned proposal. Released when proven.
    uint64 internal immutable _bondPerProposalGwei;

    /// @dev Fixed slash amount in gwei per late proof submission.
    uint64 internal immutable _slashPerProofGwei;

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

    /// @notice Maps proposal id to the epoch that owns it.
    mapping(uint48 proposalId => uint48 epochId) public proposalEpochs;

    /// @notice Bond reserved for unproven proposals, tracked by prover in gwei.
    mapping(address account => uint64 reserved) public reservedBondGwei;

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

    /// @notice Emitted when a prover fee is charged from proposer ETH.
    event FeeCharged(uint48 indexed proposalId, address indexed proposer, uint64 feeInGwei);

    /// @notice Emitted when accrued prover fees are withdrawn.
    event FeesWithdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when emergency permissionless mode changes.
    event PermissionlessModeUpdated(bool enabled);

    /// @notice Emitted when a prover is slashed for missing the proving window.
    event ProverSlashed(
        address indexed prover, address indexed proofSubmitter, uint64 slashedAmount
    );

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable contract dependencies.
    /// @param _inboxAddr The inbox address.
    /// @param _bondTokenAddr The bond token address.
    /// @param _minBond The minimum bond in gwei required to bid.
    /// @param _provingWindowSeconds The exclusive proving window in seconds.
    /// @param _bidDiscountBasisPoints Minimum fee discount in basis points for new bids (e.g. 1000
    /// = 10%).
    /// @param _bondPerProposal Bond in gwei reserved per assigned proposal.
    /// @param _slashPerProof Fixed slash amount in gwei per late proof submission.
    constructor(
        address _inboxAddr,
        address _bondTokenAddr,
        uint64 _minBond,
        uint48 _provingWindowSeconds,
        uint16 _bidDiscountBasisPoints,
        uint64 _bondPerProposal,
        uint64 _slashPerProof
    )
        nonZeroAddr(_inboxAddr)
        nonZeroAddr(_bondTokenAddr)
        nonZeroValue(_minBond)
        nonZeroValue(_provingWindowSeconds)
        nonZeroValue(_bidDiscountBasisPoints)
        nonZeroValue(_bondPerProposal)
        nonZeroValue(_slashPerProof)
    {
        _inbox = IInbox(_inboxAddr);
        _bondToken = IERC20(_bondTokenAddr);
        _minBondGwei = _minBond;
        _provingWindow = _provingWindowSeconds;
        _bidDiscountBps = _bidDiscountBasisPoints;
        _bondPerProposalGwei = _bondPerProposal;
        _slashPerProofGwei = _slashPerProof;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract owner.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Deposits bond used to back proving obligations.
    /// @param _amount The bond amount in gwei.
    function depositBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        _bondToken.safeTransferFrom(msg.sender, address(this), uint256(_amount) * 1 gwei);
        bondBalances[msg.sender] += _amount;
        emit BondDeposited(msg.sender, _amount);
    }

    /// @notice Withdraws previously deposited bond.
    /// @param _amount The bond amount in gwei.
    function withdrawBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        require(
            bondBalances[msg.sender] - reservedBondGwei[msg.sender] >= _amount, InsufficientBond()
        );
        bondBalances[msg.sender] -= _amount;
        _bondToken.safeTransfer(msg.sender, uint256(_amount) * 1 gwei);
        emit BondWithdrawn(msg.sender, _amount);
    }

    /// @notice Withdraws accrued prover fees.
    /// @param _amount The amount in wei to withdraw.
    function withdrawFees(uint256 _amount) external nonReentrant nonZeroValue(_amount) {
        require(feeBalances[msg.sender] >= _amount, InsufficientFees());
        feeBalances[msg.sender] -= _amount;
        msg.sender.sendEtherAndVerify(_amount);
        emit FeesWithdrawn(msg.sender, _amount);
    }

    /// @notice Places or updates a bid for a future proving epoch.
    /// @param _feeInGwei The fee quote in gwei for each assigned proposal.
    function bid(uint64 _feeInGwei) external nonReentrant whenNotPaused {
        require(bondBalances[msg.sender] >= _minBondGwei, InsufficientBond());

        MarketState memory state = marketState;

        if (state.activeEpochId != 0) {
            require(
                _feeInGwei * 10_000
                    <= uint256(epochs[state.activeEpochId].feeInGwei) * (10_000 - _bidDiscountBps),
                BidFeeTooHigh()
            );
        }

        if (state.pendingEpochId != 0 && epochs[state.pendingEpochId].prover != msg.sender) {
            require(
                _feeInGwei * 10_000
                    <= uint256(epochs[state.pendingEpochId].feeInGwei) * (10_000 - _bidDiscountBps),
                BidFeeTooHigh()
            );
        }

        uint48 newEpochId = ++state.nextEpochId;

        epochs[newEpochId] = Epoch({
            prover: msg.sender,
            feeInGwei: _feeInGwei,
            activatedAt: 0,
            firstProposalId: 0,
            lastProposalId: 0
        });

        state.pendingEpochId = newEpochId;
        marketState = state;

        emit BidPlaced(newEpochId, msg.sender, _feeInGwei);
    }

    /// @notice Requests exit from the market for the caller's active or pending position.
    function exit() external {
        MarketState memory state = marketState;

        if (state.pendingEpochId != 0 && epochs[state.pendingEpochId].prover == msg.sender) {
            uint48 exitedId = state.pendingEpochId;
            state.pendingEpochId = 0;
            marketState = state;
            emit EpochExited(exitedId);
            return;
        }

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
            if (state.activeEpochId != 0) {
                bool shouldRetire = state.activeEpochExiting || state.pendingEpochId != 0;
                if (!shouldRetire) {
                    address prv = epochs[state.activeEpochId].prover;
                    shouldRetire = bondBalances[prv] < reservedBondGwei[prv] + _bondPerProposalGwei;
                }
                if (shouldRetire) {
                    state.activeEpochId = 0;
                    state.activeEpochExiting = false;
                    stateChanged = true;
                }
            }

            if (state.activeEpochId == 0 && state.pendingEpochId != 0) {
                _activatePendingEpoch(state, _proposalId, _proposalTimestamp);
                stateChanged = true;
            }

            uint48 activeId = state.activeEpochId;
            if (activeId != 0) {
                address prv = epochs[activeId].prover;
                reservedBondGwei[prv] += _bondPerProposalGwei;
                proposalEpochs[_proposalId] = activeId;
                epochs[activeId].lastProposalId = _proposalId;

                uint256 feeWei = uint256(epochs[activeId].feeInGwei) * 1 gwei;
                if (feeWei > 0) {
                    require(msg.value >= feeWei, InsufficientFee());
                    feeBalances[prv] += feeWei;
                    feeConsumed = feeWei;
                    emit FeeCharged(_proposalId, _proposer, epochs[activeId].feeInGwei);
                }
            }
        }

        if (stateChanged) marketState = state;

        uint256 excess = msg.value - feeConsumed;
        if (excess > 0) {
            _proposer.sendEtherAndVerify(excess);
        }
    }

    /// @notice Checks whether a caller is authorized to submit a proof for a given proposal.
    /// @param _caller The account that would submit the proof.
    /// @param _firstNewProposalId The first proposal id that would be newly finalized.
    /// @param _proposalAge The age in seconds of the first newly finalized proposal.
    /// @return True if the caller is authorized to prove.
    function canSubmitProof(
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        public
        view
        returns (bool)
    {
        if (marketState.permissionlessMode) return true;

        if (_proposalAge >= uint256(_provingWindow)) return true;

        uint48 epochId = _findEpochForProposal(_firstNewProposalId);

        if (epochId == 0) return true;

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

        if (!state.permissionlessMode) {
            _releaseReservedBond(_firstNewProposalId, _lastProposalId);
            _checkAndSlash(state, _caller, _firstNewProposalId, _proposalAge);
        }

        marketState = state;
    }

    /// @notice Enables or disables emergency permissionless proving mode.
    /// @param _enabled True to force permissionless proving, false to restore market enforcement.
    function forcePermissionlessMode(bool _enabled) external onlyOwner {
        marketState.permissionlessMode = _enabled;
        emit PermissionlessModeUpdated(_enabled);
    }

    /// @inheritdoc IProverMarket
    function bondToken() external view returns (address) {
        return address(_bondToken);
    }

    /// @notice Returns the exclusive proving window in seconds.
    function provingWindow() external view returns (uint48) {
        return _provingWindow;
    }

    /// @notice Returns the fee in gwei that the next proposal will be charged.
    function activeFeeInGwei() external view returns (uint64) {
        MarketState memory state = marketState;
        if (state.permissionlessMode) return 0;

        if (state.activeEpochId != 0) {
            bool wouldRetire = state.activeEpochExiting || state.pendingEpochId != 0;
            if (!wouldRetire) {
                address prv = epochs[state.activeEpochId].prover;
                wouldRetire = bondBalances[prv] < reservedBondGwei[prv] + _bondPerProposalGwei;
            }
            if (wouldRetire) {
                if (state.pendingEpochId != 0) return epochs[state.pendingEpochId].feeInGwei;
                return 0;
            }
            return epochs[state.activeEpochId].feeInGwei;
        }
        if (state.pendingEpochId != 0) {
            return epochs[state.pendingEpochId].feeInGwei;
        }
        return 0;
    }

    /// @notice Returns the minimum bond in gwei required to place a bid.
    function minBond() external view returns (uint64) {
        return _minBondGwei;
    }

    /// @notice Returns the minimum bid discount in basis points (e.g. 1000 = 10%).
    function bidDiscountBps() external view returns (uint16) {
        return _bidDiscountBps;
    }

    /// @notice Returns the bond in gwei reserved per assigned proposal.
    function bondPerProposal() external view returns (uint64) {
        return _bondPerProposalGwei;
    }

    /// @notice Returns the slash amount in gwei per late proof.
    function slashPerProof() external view returns (uint64) {
        return _slashPerProofGwei;
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

    /// @dev Activates the current pending epoch for new assignments. Skips activation if the
    ///      pending prover lacks sufficient bond.
    function _activatePendingEpoch(
        MarketState memory _state,
        uint48 _proposalId,
        uint48 _proposalTimestamp
    )
        private
    {
        uint48 pendingId = _state.pendingEpochId;
        address prv = epochs[pendingId].prover;

        if (bondBalances[prv] < reservedBondGwei[prv] + _bondPerProposalGwei) {
            _state.pendingEpochId = 0;
            return;
        }

        epochs[pendingId].activatedAt = _proposalTimestamp;
        epochs[pendingId].firstProposalId = _proposalId;

        _state.activeEpochId = pendingId;
        _state.pendingEpochId = 0;
        _state.activeEpochExiting = false;

        emit EpochActivated(pendingId, _proposalId);
    }

    /// @dev Enforces prover authorization and slashes the owning epoch when the proof arrives
    ///      after the exclusive proving window.
    function _checkAndSlash(
        MarketState memory _state,
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        private
    {
        uint48 epochId = _findEpochForProposal(_firstNewProposalId);

        if (_proposalAge < uint256(_provingWindow)) {
            if (epochId != 0) {
                require(_caller == epochs[epochId].prover, NotAuthorizedProver());
            }
            return;
        }

        if (epochId == 0) return;

        address prv = epochs[epochId].prover;

        uint64 slashAmount =
            _slashPerProofGwei < bondBalances[prv] ? _slashPerProofGwei : bondBalances[prv];

        if (slashAmount > 0) {
            bondBalances[prv] -= slashAmount;
            if (_caller != prv) {
                bondBalances[_caller] += slashAmount;
            }
            emit ProverSlashed(prv, _caller, slashAmount);
        }

        if (bondBalances[prv] < reservedBondGwei[prv]) {
            if (_state.activeEpochId == epochId) {
                _state.activeEpochId = 0;
                _state.activeEpochExiting = false;
            }
        }
    }

    /// @dev Releases reserved bond for proposals in the given range.
    function _releaseReservedBond(uint48 _firstProposalId, uint48 _lastProposalId) private {
        uint48 current = _firstProposalId;
        while (current <= _lastProposalId) {
            uint48 epochId = proposalEpochs[current];
            if (epochId == 0) {
                ++current;
                continue;
            }

            uint48 start = current;
            while (current <= _lastProposalId && proposalEpochs[current] == epochId) {
                ++current;
            }

            uint64 count = uint64(current - start);
            uint64 releaseAmount = count * _bondPerProposalGwei;
            address prv = epochs[epochId].prover;

            if (releaseAmount > reservedBondGwei[prv]) {
                releaseAmount = reservedBondGwei[prv];
            }
            reservedBondGwei[prv] -= releaseAmount;
        }
    }

    /// @dev Looks up which epoch owns a proposal via the proposalEpochs mapping.
    /// @return The epoch id that owns the proposal, or 0 if none.
    function _findEpochForProposal(uint48 _proposalId) private view returns (uint48) {
        return proposalEpochs[_proposalId];
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientBond();
    error InsufficientFee();
    error InsufficientFees();
    error NoBidToExit();
    error BidFeeTooHigh();
    error NotAuthorizedProver();
}
