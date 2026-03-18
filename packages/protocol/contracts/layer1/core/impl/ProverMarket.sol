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
/// for funded proposals. Lower fee bids displace the current winner. The market handles
/// authorization, fee-credit accounting, and bond management for proving obligations.
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;
    using LibAddress for address;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Term identity and funded proposal range.
    struct Term {
        address prover;
        uint48 startProposalId;
        uint48 endProposalId;
        uint64 feeInGwei;
        uint48 prevTermId;
        uint64 quoteBondGwei;
        uint48 assignedProposalCount;
    }

    /// @notice Top-level market state shared across terms.
    struct MarketState {
        uint48 activeTermId;
        uint48 pendingTermId;
        uint48 nextTermId;
        uint8 permissionlessReason;
        bool activeTermExiting;
        uint48 feeEwmaInGwei;
        uint48 lastRetiredTermId;
    }

    /// @notice Legacy degraded-mode state kept for storage compatibility.
    struct CapState {
        uint48 capFeeSnapshotGwei;
        uint48 capStartProposalId;
        uint48 capProposalCount;
        uint48 lastProvenProposalId;
        uint8 unprovenTermCount;
    }

    /// @notice Consolidated prover financial state packed into a single storage slot.
    struct ProverAccount {
        uint64 bondBalance;
        uint64 reservedBond;
    }

    /// @notice Stores explicit assignment data for a funded proposal.
    struct ProposalAssignment {
        uint48 termId;
        uint48 proposalTimestamp;
        uint64 reservedBondGwei;
    }

    /// @notice Constructor parameters bundled to avoid stack-too-deep.
    struct Params {
        address inboxAddr;
        address bondTokenAddr;
        uint64 minBond;
        uint48 provingWindowSeconds;
        uint16 bidDiscountBasisPoints;
        uint64 bondPerProposal;
        uint64 slashPerProof;
        uint8 maxBidMultiplier;
        uint64 maxFee;
        uint48 bidCooldownSeconds;
        uint48 provingGracePeriodSeconds;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    uint256 private constant _SEND_ETHER_GAS_LIMIT = 35_000;
    uint8 private constant _PERMISSIONLESS_FORCED = 1;
    uint8 private constant _PROPOSAL_NO_ACTIVE_TERM = 1;
    uint8 private constant _PROPOSAL_INSUFFICIENT_CREDIT = 2;
    uint8 private constant _PROPOSAL_INSUFFICIENT_BOND = 3;
    uint8 private constant _PROPOSAL_FORCED_PERMISSIONLESS = 4;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    IInbox internal immutable _inbox;
    IERC20 internal immutable _bondToken;
    uint64 internal immutable _minBondGwei;
    uint48 internal immutable _provingWindow;
    uint16 internal immutable _bidDiscountBps;
    uint64 internal immutable _bondPerProposalGwei;
    uint64 internal immutable _slashPerProofGwei;
    uint8 internal immutable _maxBidEwmaMultiplier;
    uint64 internal immutable _maxFeeInGwei;
    uint48 internal immutable _bidCooldown;
    uint48 internal immutable _provingGracePeriod;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Shared market state.
    MarketState public marketState;

    /// @notice All terms indexed by term id.
    mapping(uint48 termId => Term) public terms;

    /// @notice Consolidated prover account: bond balance and reserved bond.
    mapping(address account => ProverAccount) public proverAccounts;

    /// @notice Legacy degraded-mode state kept for storage compatibility.
    CapState public capState;

    /// @notice Explicit assignment data for funded proposals.
    mapping(uint48 proposalId => ProposalAssignment) public proposalAssignments;

    /// @notice ETH credits that proposers may spend on future proving fees.
    mapping(address account => uint256) public feeCredits;

    /// @notice Pull-based ETH balances claimable by provers and rescuers.
    mapping(address account => uint256) public claimableFees;

    /// @notice Earliest timestamp at which a prover may place a new bid after term retirement.
    mapping(address account => uint48) public bidCooldownUntil;

    uint256[42] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event BidPlaced(uint48 indexed termId, address indexed prover, uint64 feeInGwei);
    event TermActivated(uint48 indexed termId, uint48 firstProposalId, uint48 activatedAt);
    event TermExited(uint48 indexed termId);
    event BondDeposited(address indexed account, uint64 amount);
    event BondWithdrawn(address indexed account, uint64 amount);
    event FeeCharged(uint48 indexed proposalId, address indexed proposer, uint64 feeInGwei);
    event PermissionlessModeUpdated(bool enabled);
    event CapExceeded(uint48 proposalId);
    event CapRecovered(uint48 proposalId);
    event ProverSlashed(
        address indexed prover, address indexed proofSubmitter, uint64 slashedAmount
    );
    event FeeCreditDeposited(address indexed account, uint256 amount);
    event FeeCreditWithdrawn(address indexed account, uint256 amount);
    event FeesClaimed(address indexed account, uint256 amount);
    event ProposalAssignmentSkipped(
        uint48 indexed proposalId, address indexed proposer, uint8 reason
    );

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable contract dependencies.
    /// @param _p Bundled constructor parameters.
    constructor(Params memory _p)
        nonZeroAddr(_p.inboxAddr)
        nonZeroAddr(_p.bondTokenAddr)
        nonZeroValue(_p.minBond)
        nonZeroValue(_p.provingWindowSeconds)
        nonZeroValue(_p.bidDiscountBasisPoints)
        nonZeroValue(_p.bondPerProposal)
        nonZeroValue(_p.slashPerProof)
        nonZeroValue(_p.maxBidMultiplier)
        nonZeroValue(_p.maxFee)
    {
        _inbox = IInbox(_p.inboxAddr);
        _bondToken = IERC20(_p.bondTokenAddr);
        _minBondGwei = _p.minBond;
        _provingWindow = _p.provingWindowSeconds;
        _bidDiscountBps = _p.bidDiscountBasisPoints;
        _bondPerProposalGwei = _p.bondPerProposal;
        _slashPerProofGwei = _p.slashPerProof;
        _maxBidEwmaMultiplier = _p.maxBidMultiplier;
        _maxFeeInGwei = _p.maxFee;
        _bidCooldown = _p.bidCooldownSeconds;
        _provingGracePeriod = _p.provingGracePeriodSeconds;
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
        proverAccounts[msg.sender].bondBalance += _amount;
        emit BondDeposited(msg.sender, _amount);
    }

    /// @notice Withdraws previously deposited bond.
    /// @param _amount The bond amount in gwei.
    function withdrawBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        ProverAccount memory acct = proverAccounts[msg.sender];
        require(_availableBond(acct) >= _amount, InsufficientBond());
        acct.bondBalance -= _amount;
        proverAccounts[msg.sender] = acct;
        _bondToken.safeTransfer(msg.sender, uint256(_amount) * 1 gwei);
        emit BondWithdrawn(msg.sender, _amount);
    }

    /// @notice Deposits ETH fee credit for future proposal funding.
    function depositFeeCredit() external payable nonReentrant {
        require(msg.value != 0, ZERO_VALUE());
        feeCredits[msg.sender] += msg.value;
        emit FeeCreditDeposited(msg.sender, msg.value);
    }

    /// @notice Withdraws unused ETH fee credit.
    /// @param _amount The amount to withdraw in wei.
    function withdrawFeeCredit(uint256 _amount) external nonReentrant nonZeroValue(_amount) {
        uint256 credit = feeCredits[msg.sender];
        require(credit >= _amount, InsufficientFeeCredit());
        feeCredits[msg.sender] = credit - _amount;
        msg.sender.sendEtherAndVerify(_amount, _SEND_ETHER_GAS_LIMIT);
        emit FeeCreditWithdrawn(msg.sender, _amount);
    }

    /// @notice Withdraws earned proving fees.
    /// @param _amount The amount to withdraw in wei.
    function withdrawClaimableFees(uint256 _amount) external nonReentrant nonZeroValue(_amount) {
        uint256 claimable = claimableFees[msg.sender];
        require(claimable >= _amount, InsufficientClaimableFees());
        claimableFees[msg.sender] = claimable - _amount;
        msg.sender.sendEtherAndVerify(_amount, _SEND_ETHER_GAS_LIMIT);
        emit FeesClaimed(msg.sender, _amount);
    }

    /// @notice Places or updates a bid for a future proving term.
    /// @param _feeInGwei The fee quote in gwei for each funded assigned proposal.
    function bid(uint64 _feeInGwei) external nonReentrant whenNotPaused nonZeroValue(_feeInGwei) {
        require(_feeInGwei <= _maxFeeInGwei, BidFeeTooHigh());
        require(block.timestamp >= bidCooldownUntil[msg.sender], BidCooldownActive());

        MarketState memory state = marketState;

        if (state.activeTermId != 0) {
            Term memory activeTerm = terms[state.activeTermId];
            require(activeTerm.prover != msg.sender, ActiveProverCannotBid());
            require(
                _feeInGwei * 10_000 <= uint256(activeTerm.feeInGwei) * (10_000 - _bidDiscountBps),
                BidFeeTooHigh()
            );
        }

        if (state.pendingTermId != 0) {
            uint48 pendingTermId = state.pendingTermId;
            Term memory pendingTerm = terms[pendingTermId];

            if (pendingTerm.prover == msg.sender) {
                require(_feeInGwei < pendingTerm.feeInGwei, BidFeeTooHigh());
                terms[pendingTermId].feeInGwei = _feeInGwei;
                emit BidPlaced(pendingTermId, msg.sender, _feeInGwei);
                return;
            }

            require(
                _feeInGwei * 10_000 <= uint256(pendingTerm.feeInGwei) * (10_000 - _bidDiscountBps),
                BidFeeTooHigh()
            );
        } else if (state.activeTermId == 0 && state.feeEwmaInGwei != 0) {
            require(
                _feeInGwei <= uint256(_maxBidEwmaMultiplier) * state.feeEwmaInGwei, BidFeeTooHigh()
            );
        }

        ProverAccount memory acct = proverAccounts[msg.sender];
        require(_availableBond(acct) >= _minBondGwei, InsufficientBond());

        if (state.pendingTermId != 0) {
            uint48 pendingTermId = state.pendingTermId;
            Term memory pendingTerm = terms[pendingTermId];
            _releaseQuoteBond(pendingTerm.prover, terms[pendingTermId].quoteBondGwei);
            terms[pendingTermId].quoteBondGwei = 0;
        }

        acct.reservedBond += _minBondGwei;
        proverAccounts[msg.sender] = acct;

        uint48 newTermId = ++state.nextTermId;
        terms[newTermId] = Term({
            prover: msg.sender,
            startProposalId: 0,
            endProposalId: 0,
            feeInGwei: _feeInGwei,
            prevTermId: 0,
            quoteBondGwei: _minBondGwei,
            assignedProposalCount: 0
        });

        state.pendingTermId = newTermId;
        marketState = state;

        emit BidPlaced(newTermId, msg.sender, _feeInGwei);
    }

    /// @notice Exits a pending or active proving position.
    function exit() external {
        MarketState memory state = marketState;

        if (state.pendingTermId != 0 && terms[state.pendingTermId].prover == msg.sender) {
            uint48 exitedId = state.pendingTermId;
            _releaseQuoteBond(msg.sender, terms[exitedId].quoteBondGwei);
            terms[exitedId].quoteBondGwei = 0;
            state.pendingTermId = 0;
            marketState = state;
            emit TermExited(exitedId);
            return;
        }

        if (state.activeTermId != 0 && terms[state.activeTermId].prover == msg.sender) {
            require(!state.activeTermExiting, NoBidToExit());
            state.activeTermExiting = true;
            marketState = state;
            emit TermExited(state.activeTermId);
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
        nonReentrant
        onlyFrom(address(_inbox))
    {
        if (msg.value != 0) {
            feeCredits[_proposer] += msg.value;
            emit FeeCreditDeposited(_proposer, msg.value);
        }

        MarketState memory state = marketState;
        bool stateChanged;

        if (state.permissionlessReason == _PERMISSIONLESS_FORCED) {
            emit ProposalAssignmentSkipped(_proposalId, _proposer, _PROPOSAL_FORCED_PERMISSIONLESS);
            return;
        }

        if (state.activeTermId != 0 && _shouldRetireActiveTerm(state)) {
            _retireActiveTerm(state);
            stateChanged = true;
        }

        if (state.activeTermId == 0 && state.pendingTermId != 0) {
            stateChanged =
                _activatePendingTerm(state, _proposalId, _proposalTimestamp) || stateChanged;
        }

        uint48 activeTermId = state.activeTermId;
        if (activeTermId == 0) {
            if (stateChanged) marketState = state;
            emit ProposalAssignmentSkipped(_proposalId, _proposer, _PROPOSAL_NO_ACTIVE_TERM);
            return;
        }

        Term memory term = terms[activeTermId];
        ProverAccount memory acct = proverAccounts[term.prover];
        uint64 liabilityPerProposal = _liabilityPerProposal(term.feeInGwei);
        uint256 feeWei = uint256(term.feeInGwei) * 1 gwei;
        uint256 credit = feeCredits[_proposer];

        if (credit < feeWei) {
            if (stateChanged) marketState = state;
            emit ProposalAssignmentSkipped(_proposalId, _proposer, _PROPOSAL_INSUFFICIENT_CREDIT);
            return;
        }

        if (_availableBond(acct) < liabilityPerProposal) {
            _retireActiveTerm(state);
            marketState = state;
            emit ProposalAssignmentSkipped(_proposalId, _proposer, _PROPOSAL_INSUFFICIENT_BOND);
            return;
        }

        feeCredits[_proposer] = credit - feeWei;
        acct.reservedBond += liabilityPerProposal;
        proverAccounts[term.prover] = acct;

        ProposalAssignment storage assignment = proposalAssignments[_proposalId];
        assignment.termId = activeTermId;
        assignment.proposalTimestamp = _proposalTimestamp;
        assignment.reservedBondGwei = liabilityPerProposal;

        if (term.assignedProposalCount == 0) {
            terms[activeTermId].startProposalId = _proposalId;
        }
        terms[activeTermId].endProposalId = _proposalId;
        terms[activeTermId].assignedProposalCount = term.assignedProposalCount + 1;

        emit FeeCharged(_proposalId, _proposer, term.feeInGwei);

        if (stateChanged) marketState = state;
    }

    /// @notice Checks whether a caller is authorized to submit a proof for a proposal range.
    /// @param _caller The account that would submit the proof.
    /// @param _firstNewProposalId The first proposal id that would be newly finalized.
    /// @param _lastProposalId The last proposal id in the range.
    /// @return authorized_ True if the caller is authorized to prove the entire range.
    function canSubmitProof(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId
    )
        public
        view
        returns (bool authorized_)
    {
        if (marketState.permissionlessReason == _PERMISSIONLESS_FORCED) return true;

        for (uint48 proposalId = _firstNewProposalId; proposalId <= _lastProposalId; ++proposalId) {
            ProposalAssignment memory assignment = proposalAssignments[proposalId];
            if (assignment.termId == 0) continue;
            if (
                block.timestamp < uint256(assignment.proposalTimestamp) + uint256(_provingWindow)
                    && _caller != terms[assignment.termId].prover
            ) {
                return false;
            }
        }

        return true;
    }

    /// @inheritdoc IProverMarket
    function onProofAccepted(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId
    )
        external
        nonReentrant
        onlyFrom(address(_inbox))
    {
        MarketState memory state = marketState;
        bool forcedPermissionless = state.permissionlessReason == _PERMISSIONLESS_FORCED;
        uint256 rescueClaim;

        for (uint48 proposalId = _firstNewProposalId; proposalId <= _lastProposalId; ++proposalId) {
            rescueClaim += _authorizeAndSettleProposalAssignment(
                _caller, proposalId, forcedPermissionless
            );
        }

        if (rescueClaim != 0) {
            proverAccounts[_caller].bondBalance += uint64(rescueClaim);
        }

        if (state.activeTermId != 0) {
            Term memory activeTerm = terms[state.activeTermId];
            ProverAccount memory activeAcct = proverAccounts[activeTerm.prover];
            if (_availableBond(activeAcct) < _liabilityPerProposal(activeTerm.feeInGwei)) {
                _retireActiveTerm(state);
                marketState = state;
            }
        }
    }

    /// @notice Enables or disables emergency permissionless proving mode.
    /// @param _enabled True to force permissionless proving, false to restore market enforcement.
    function forcePermissionlessMode(bool _enabled) external onlyOwner {
        marketState.permissionlessReason = _enabled ? _PERMISSIONLESS_FORCED : 0;
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

    /// @notice Returns the fee in gwei that the next funded proposal will be charged.
    function activeFeeInGwei() external view returns (uint64) {
        MarketState memory state = marketState;
        if (state.permissionlessReason == _PERMISSIONLESS_FORCED) return 0;

        if (state.activeTermId != 0) {
            Term memory activeTerm = terms[state.activeTermId];
            bool wouldRetire = state.activeTermExiting || state.pendingTermId != 0;
            if (!wouldRetire) {
                ProverAccount memory acct = proverAccounts[activeTerm.prover];
                wouldRetire = _availableBond(acct) < _liabilityPerProposal(activeTerm.feeInGwei);
            }
            if (!wouldRetire) return activeTerm.feeInGwei;
            if (state.pendingTermId != 0) return terms[state.pendingTermId].feeInGwei;
            return 0;
        }

        if (state.pendingTermId != 0) {
            return terms[state.pendingTermId].feeInGwei;
        }

        return 0;
    }

    /// @notice Returns the minimum bond in gwei required to place a bid.
    function minBond() external view returns (uint64) {
        return _minBondGwei;
    }

    /// @notice Returns the minimum bid discount in basis points.
    function bidDiscountBps() external view returns (uint16) {
        return _bidDiscountBps;
    }

    /// @notice Returns the base bond in gwei reserved per funded proposal.
    function bondPerProposal() external view returns (uint64) {
        return _bondPerProposalGwei;
    }

    /// @notice Returns the minimum slash amount in gwei applied per late funded proposal.
    function slashPerProof() external view returns (uint64) {
        return _slashPerProofGwei;
    }

    /// @notice Returns the max bid multiplier applied to the fee EWMA.
    function maxBidEwmaMultiplier() external view returns (uint8) {
        return _maxBidEwmaMultiplier;
    }

    /// @notice Returns the absolute maximum fee in gwei that any bid may quote.
    function maxFee() external view returns (uint64) {
        return _maxFeeInGwei;
    }

    /// @notice Returns the bid cooldown period in seconds after term retirement.
    function bidCooldown() external view returns (uint48) {
        return _bidCooldown;
    }

    /// @notice Returns the grace period in seconds after the exclusive window before slashing.
    function provingGracePeriod() external view returns (uint48) {
        return _provingGracePeriod;
    }

    /// @notice Returns the exponentially weighted moving average of retired term fees.
    function feeEwma() external view returns (uint48) {
        return marketState.feeEwmaInGwei;
    }

    /// @inheritdoc IProverMarket
    function creditMigratedBond(
        address _account,
        uint64 _amount
    )
        external
        onlyFrom(address(_inbox))
    {
        proverAccounts[_account].bondBalance += _amount;
        emit BondDeposited(_account, _amount);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Activates the current pending term for new assignments if it has enough free bond.
    function _activatePendingTerm(
        MarketState memory _state,
        uint48 _proposalId,
        uint48 _proposalTimestamp
    )
        private
        returns (bool stateChanged_)
    {
        uint48 pendingId = _state.pendingTermId;
        Term memory pendingTerm = terms[pendingId];
        ProverAccount memory acct = proverAccounts[pendingTerm.prover];

        if (_availableBond(acct) < _liabilityPerProposal(pendingTerm.feeInGwei)) {
            _releaseQuoteBond(pendingTerm.prover, terms[pendingId].quoteBondGwei);
            terms[pendingId].quoteBondGwei = 0;
            _state.pendingTermId = 0;
            return true;
        }

        terms[pendingId].prevTermId = _state.lastRetiredTermId;
        _state.activeTermId = pendingId;
        _state.pendingTermId = 0;
        _state.activeTermExiting = false;

        emit TermActivated(pendingId, _proposalId, _proposalTimestamp);
        return true;
    }

    /// @dev Updates the fee EWMA using proposal-weighted blending.
    function _updateFeeEwma(
        MarketState memory _state,
        uint64 _fee,
        uint256 _proposalCount
    )
        private
        pure
    {
        if (_proposalCount == 0) return;
        uint48 ewma = _state.feeEwmaInGwei;
        if (ewma == 0) {
            uint256 raw = uint256(_fee);
            _state.feeEwmaInGwei = raw > type(uint48).max ? type(uint48).max : uint48(raw);
        } else {
            uint256 w = 1024;
            uint256 raw =
                (uint256(ewma) * w + uint256(_fee) * _proposalCount) / (w + _proposalCount);
            _state.feeEwmaInGwei = raw > type(uint48).max ? type(uint48).max : uint48(raw);
        }
    }

    /// @dev Returns true if the active term must retire before the next funded assignment.
    function _shouldRetireActiveTerm(MarketState memory _state) private view returns (bool) {
        if (_state.activeTermId == 0) return false;
        if (_state.activeTermExiting || _state.pendingTermId != 0) return true;

        Term memory activeTerm = terms[_state.activeTermId];
        ProverAccount memory acct = proverAccounts[activeTerm.prover];
        return _availableBond(acct) < _liabilityPerProposal(activeTerm.feeInGwei);
    }

    /// @dev Retires the current active term and releases its quote stake.
    function _retireActiveTerm(MarketState memory _state) private {
        uint48 activeTermId = _state.activeTermId;
        if (activeTermId == 0) return;

        Term memory activeTerm = terms[activeTermId];
        _updateFeeEwma(_state, activeTerm.feeInGwei, activeTerm.assignedProposalCount);
        _state.lastRetiredTermId = activeTermId;
        _state.activeTermId = 0;
        _state.activeTermExiting = false;

        if (_bidCooldown != 0) {
            bidCooldownUntil[activeTerm.prover] = uint48(block.timestamp) + _bidCooldown;
        }

        _releaseQuoteBond(activeTerm.prover, terms[activeTermId].quoteBondGwei);
        terms[activeTermId].quoteBondGwei = 0;
    }

    /// @dev Releases quote stake reserved for a pending or active term.
    function _releaseQuoteBond(address _prover, uint64 _amount) private {
        if (_amount == 0) return;
        ProverAccount memory acct = proverAccounts[_prover];
        if (_amount > acct.reservedBond) {
            _amount = acct.reservedBond;
        }
        acct.reservedBond -= _amount;
        proverAccounts[_prover] = acct;
    }

    /// @dev Returns the free bond available for new reservations.
    function _availableBond(ProverAccount memory _acct) private pure returns (uint64 available_) {
        if (_acct.bondBalance <= _acct.reservedBond) return 0;
        available_ = _acct.bondBalance - _acct.reservedBond;
    }

    /// @dev Validates authorization for a single funded proposal assignment and settles it.
    function _authorizeAndSettleProposalAssignment(
        address _caller,
        uint48 _proposalId,
        bool _forcedPermissionless
    )
        private
        returns (uint256 rescueClaim_)
    {
        ProposalAssignment memory assignment = proposalAssignments[_proposalId];
        if (assignment.termId == 0) return 0;

        Term memory term = terms[assignment.termId];
        address assignedProver = term.prover;
        uint256 deadline = uint256(assignment.proposalTimestamp) + uint256(_provingWindow);
        bool pastExclusiveWindow = block.timestamp >= deadline;
        bool late = block.timestamp >= deadline + uint256(_provingGracePeriod);

        if (!_forcedPermissionless && !pastExclusiveWindow && _caller != assignedProver) {
            revert NotAuthorizedProver();
        }

        ProverAccount memory acct = proverAccounts[assignedProver];
        uint64 releasedBond = assignment.reservedBondGwei;
        if (releasedBond > acct.reservedBond) {
            releasedBond = acct.reservedBond;
        }
        acct.reservedBond -= releasedBond;

        uint256 feeWei = uint256(term.feeInGwei) * 1 gwei;
        if (feeWei != 0) {
            address feeRecipient = assignedProver;
            if (_caller != assignedProver && (_forcedPermissionless || pastExclusiveWindow)) {
                feeRecipient = _caller;
            }
            claimableFees[feeRecipient] += feeWei;
        }

        if (late) {
            uint64 slashAmount = assignment.reservedBondGwei;
            if (slashAmount > acct.bondBalance) {
                slashAmount = acct.bondBalance;
            }

            if (slashAmount != 0) {
                acct.bondBalance -= slashAmount;
                if (_caller != assignedProver) {
                    rescueClaim_ = slashAmount;
                }
                emit ProverSlashed(assignedProver, _caller, slashAmount);
            }
        }

        proverAccounts[assignedProver] = acct;
        delete proposalAssignments[_proposalId];
    }

    /// @dev Computes the bond liability reserved and slashed per funded proposal.
    function _liabilityPerProposal(uint64 _feeInGwei) private view returns (uint64 liability_) {
        uint256 liability = uint256(_feeInGwei) * 2;
        if (liability < _bondPerProposalGwei) liability = _bondPerProposalGwei;
        if (liability < _slashPerProofGwei) liability = _slashPerProofGwei;
        if (liability > type(uint64).max) liability = type(uint64).max;
        liability_ = uint64(liability);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientBond();
    error InsufficientFee();
    error InsufficientFeeCredit();
    error InsufficientClaimableFees();
    error NoBidToExit();
    error BidFeeTooHigh();
    error NotAuthorizedProver();
    error ActiveProverCannotBid();
    error BidCooldownActive();
}
