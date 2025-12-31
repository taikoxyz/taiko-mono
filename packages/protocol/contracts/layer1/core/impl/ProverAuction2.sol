// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProverAuction } from "../iface/IProverAuction.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

import "./ProverAuction2_Layout.sol"; // DO NOT DELETE

/// @title ProverAuction2
/// @notice Multi-prover reverse auction with weighted random selection and bounded fee spread.
///
/// @dev Design Objectives:
///      1. BOUNDED PROVER POOL: Maintains a small pool of active provers (maxActiveProvers).
///         New provers must undercut the worst (highest-fee) prover to join when pool is full.
///
///      2. WEIGHTED RANDOM SELECTION: Provers are selected per-block using a fee-weighted lottery.
///         Lower fees = higher selection probability. Weight = (maxFee - proverFee) + 1.
///         This incentivizes competitive fees while avoiding winner-take-all dynamics.
///
///      3. FEE SPREAD CONTROL: When a new prover joins with fee X, existing provers with
///         fee >= X * maxFeeSpreadPctg / 100 are evicted. This bounds the fee range in the
///         pool, preventing stale high-fee provers from lingering.
///
///      4. ANTI-MANIPULATION: Self-bid rate limiting (MIN_SELF_BID_INTERVAL) prevents provers
///         from gaming the moving average. Exponential fee increase when pool is empty
///         encourages timely re-entry.
///
///      5. BOND-BASED ACCOUNTABILITY: Provers must maintain sufficient bond. Slashing reduces
///         bond and triggers ejection when below threshold. Withdrawal delay prevents
///         hit-and-run attacks.
///
/// @custom:security-contact security@taiko.xyz
contract ProverAuction2 is EssentialContract, IProverAuction {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Minimum time between self-bids to prevent moving average manipulation
    uint48 public constant MIN_SELF_BID_INTERVAL = 1 hours;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Per-prover state for the active pool
    struct ProverInfo {
        uint32 feeInGwei;
        uint16 index;
        uint8 active; // 1 = active, 0 = inactive
    }

    /// @notice Bond balance and withdrawal state for a prover
    struct BondInfo {
        uint128 balance; // Current bond balance
        uint48 withdrawableAt; // Timestamp when withdrawal is allowed (0 = no delay set)
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a prover deposits bond tokens
    /// @param prover The prover who deposited
    /// @param amount The amount deposited
    event Deposited(address indexed prover, uint128 amount);

    /// @notice Emitted when a prover withdraws bond tokens
    /// @param prover The prover who withdrew
    /// @param amount The amount withdrawn
    event Withdrawn(address indexed prover, uint128 amount);

    /// @notice Emitted when a prover places or updates a bid
    /// @param newProver The prover placing the bid
    /// @param feeInGwei The fee in Gwei
    /// @param oldProver The previous prover being outbid (address(0) if none)
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);

    /// @notice Emitted when a prover requests to exit the auction
    /// @param prover The prover requesting exit
    /// @param withdrawableAt Timestamp when withdrawal is allowed
    event ExitRequested(address indexed prover, uint48 withdrawableAt);

    /// @notice Emitted when a prover is ejected (low bond, fee spread eviction, or pool replacement)
    /// @param prover The prover ejected
    event ProverEjected(address indexed prover);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The Inbox contract address (only caller for slashProver/checkBondDeferWithdrawal)
    address public immutable inbox;

    /// @notice The ERC20 token used for bonds (TAIKO token)
    IERC20 public immutable bondToken;

    /// @notice Multiplier for livenessBond to calculate required/threshold bond amounts
    uint16 public immutable bondMultiplier;

    /// @notice Minimum fee reduction in basis points to outbid (e.g., 500 = 5%)
    uint16 public immutable minFeeReductionBps;

    /// @notice Reward percentage in basis points for slashing (e.g., 6000 = 60%)
    uint16 public immutable rewardBps;

    /// @notice Time after exit before bond withdrawal is allowed
    uint48 public immutable bondWithdrawalDelay;

    /// @notice Time period for fee doubling when pool is empty
    uint48 public immutable feeDoublingPeriod;

    /// @notice Time window for moving average smoothing
    uint48 public immutable movingAverageWindow;

    /// @notice Maximum number of fee doublings allowed (e.g., 8 = 256x cap)
    uint8 public immutable maxFeeDoublings;

    /// @notice Initial maximum fee for first-ever bid (in Gwei)
    uint32 public immutable initialMaxFee;

    /// @notice Multiplier for moving average fee to calculate floor (e.g., 2 = 2x moving average)
    uint8 public immutable movingAverageMultiplier;

    /// @notice Maximum number of active provers
    uint16 public immutable maxActiveProvers;

    /// @notice Maximum fee spread as percentage (e.g., 200 = new prover's fee * 2 is the max allowed)
    /// @dev When a new prover joins with fee X, existing provers with fee >= X * maxFeeSpreadPctg / 100
    ///      are evicted to keep the fee range bounded.
    uint16 public immutable maxFeeSpreadPctg;

    /// @notice Bond amount slashed per failed proof
    uint96 private immutable _livenessBond;

    /// @notice Pre-computed required bond amount (livenessBond * bondMultiplier * 2)
    uint128 private immutable _requiredBond;

    /// @notice Pre-computed ejection threshold (livenessBond * bondMultiplier)
    uint128 private immutable _ejectionThreshold;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Bond information per address
    mapping(address account => BondInfo info) internal _bonds;

    /// @dev Active prover info per address
    mapping(address prover => ProverInfo info) internal _proverInfo;

    /// @dev Active provers in insertion order
    address[] internal _activeProvers;

    /// @dev Exponential moving average of winning fees (in Gwei)
    uint32 internal _movingAverageFee;

    /// @dev Total accumulated (slashed - rewarded), locked forever in contract
    uint128 internal _totalSlashedAmount;

    /// @dev Contract creation timestamp for initial fee timing
    uint48 internal _contractCreationTime;

    /// @dev Timestamp of the last moving average update
    uint48 internal _lastAvgUpdate;

    /// @dev Timestamp when the active pool became empty (0 when non-empty)
    uint48 internal _poolEmptySince;

    /// @dev Last fee recorded when pool became empty
    uint32 internal _lastPoolFee;

    /// @dev Reserved storage gap for future upgrades
    uint256[43] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the ProverAuction2 contract with immutable parameters
    /// @param _inbox The Inbox contract address
    /// @param _bondToken The ERC20 token used for bonds
    /// @param _livenessBondAmount Bond amount slashed per failed proof
    /// @param _bondMultiplier Multiplier for livenessBond to calculate bond requirements
    /// @param _minFeeReductionBps Minimum fee reduction to outbid (basis points)
    /// @param _rewardBps Reward percentage in basis points for slashing
    /// @param _bondWithdrawalDelay Time after exit before withdrawal allowed
    /// @param _feeDoublingPeriod Time period for fee doubling when pool is empty
    /// @param _movingAverageWindow Time window for moving average smoothing
    /// @param _maxFeeDoublings Maximum number of fee doublings
    /// @param _initialMaxFee Initial maximum fee for first-ever bid (in Gwei)
    /// @param _movingAverageMultiplier Multiplier for moving average fee floor
    /// @param _maxActiveProvers Maximum number of active provers
    /// @param _maxFeeSpreadPctg Maximum fee spread percentage (e.g., 200 = 2x)
    constructor(
        address _inbox,
        address _bondToken,
        uint96 _livenessBondAmount,
        uint16 _bondMultiplier,
        uint16 _minFeeReductionBps,
        uint16 _rewardBps,
        uint48 _bondWithdrawalDelay,
        uint48 _feeDoublingPeriod,
        uint48 _movingAverageWindow,
        uint8 _maxFeeDoublings,
        uint32 _initialMaxFee,
        uint8 _movingAverageMultiplier,
        uint16 _maxActiveProvers,
        uint16 _maxFeeSpreadPctg
    ) {
        require(_inbox != address(0), ZeroAddress());
        require(_bondToken != address(0), ZeroAddress());
        require(_livenessBondAmount > 0, ZeroValue());
        require(_bondMultiplier > 0, ZeroValue());
        require(_minFeeReductionBps <= 10_000, InvalidBps());
        require(_rewardBps <= 10_000, InvalidBps());
        require(_feeDoublingPeriod > 0, ZeroValue());
        require(_movingAverageWindow > 0, ZeroValue());
        require(_maxFeeDoublings <= 64, InvalidMaxFeeDoublings());
        require(_initialMaxFee > 0, ZeroValue());
        require(_movingAverageMultiplier > 0, ZeroValue());
        require(_maxActiveProvers > 0, ZeroValue());
        require(_maxFeeSpreadPctg >= 100, InvalidFeeSpread());

        inbox = _inbox;
        bondToken = IERC20(_bondToken);
        _livenessBond = _livenessBondAmount;
        bondMultiplier = _bondMultiplier;
        minFeeReductionBps = _minFeeReductionBps;
        rewardBps = _rewardBps;
        bondWithdrawalDelay = _bondWithdrawalDelay;
        feeDoublingPeriod = _feeDoublingPeriod;
        movingAverageWindow = _movingAverageWindow;
        maxFeeDoublings = _maxFeeDoublings;
        initialMaxFee = _initialMaxFee;
        movingAverageMultiplier = _movingAverageMultiplier;
        maxActiveProvers = _maxActiveProvers;
        maxFeeSpreadPctg = _maxFeeSpreadPctg;

        unchecked {
            uint128 ejectionThreshold = uint128(_livenessBondAmount) * _bondMultiplier;
            _ejectionThreshold = ejectionThreshold;
            _requiredBond = ejectionThreshold * 2;
        }
    }

    // ---------------------------------------------------------------
    // Initializer Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract (for upgradeable proxy pattern)
    /// @param _owner The owner of this contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        _contractCreationTime = uint48(block.timestamp);
        _poolEmptySince = _contractCreationTime;
    }

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Deposit bond tokens into the contract
    /// @param _amount The amount of tokens to deposit
    function deposit(uint128 _amount) external nonReentrant {
        bondToken.safeTransferFrom(msg.sender, address(this), _amount);
        _bonds[msg.sender].balance += _amount;
        emit Deposited(msg.sender, _amount);
    }

    /// @notice Withdraw bond tokens from the contract
    /// @param _amount The amount of tokens to withdraw
    function withdraw(uint128 _amount) external nonReentrant {
        BondInfo storage info = _bonds[msg.sender];

        if (_proverInfo[msg.sender].active == 1) {
            revert CurrentProverCannotWithdraw();
        }

        if (info.withdrawableAt != 0) {
            require(block.timestamp >= info.withdrawableAt, WithdrawalDelayNotPassed());
        }

        require(info.balance >= _amount, InsufficientBond());

        unchecked {
            info.balance -= _amount;
        }
        bondToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    /// @notice Place a bid to join the active prover pool
    /// @param _feeInGwei The fee per proposal in Gwei
    function bid(uint32 _feeInGwei) external nonReentrant {
        BondInfo storage bidderBond = _bonds[msg.sender];
        require(bidderBond.balance >= getRequiredBond(), InsufficientBond());

        ProverInfo storage info = _proverInfo[msg.sender];
        bool isActive = info.active == 1;

        if (isActive) {
            require(block.timestamp >= _lastAvgUpdate + MIN_SELF_BID_INTERVAL, SelfBidTooFrequent());
            require(_feeInGwei < info.feeInGwei, FeeMustBeLower());
            info.feeInGwei = _feeInGwei;
            _updateMovingAverage(_feeInGwei);
            emit BidPlaced(msg.sender, _feeInGwei, msg.sender);
            return;
        }

        uint256 count = _activeProvers.length;
        uint32 maxFee;
        address evicted = address(0);

        if (count == 0) {
            maxFee = _getVacantMaxBidFee();
        } else if (count < maxActiveProvers) {
            (, maxFee,) = _findWorstProver();
        } else {
            (address worst, uint32 worstFee, uint16 worstIndex) = _findWorstProver();
            require(_feeInGwei < worstFee, FeeMustBeLower());
            unchecked {
                maxFee = uint32(uint256(worstFee) * (10_000 - minFeeReductionBps) / 10_000);
            }
            require(_feeInGwei <= maxFee, FeeTooHigh());
            _removeActiveProver(worst, worstIndex);
            _deferWithdraw(worst);
            evicted = worst;
        }

        if (count == 0 || count < maxActiveProvers) {
            require(_feeInGwei <= maxFee, FeeTooHigh());
        }

        if (bidderBond.withdrawableAt != 0) {
            bidderBond.withdrawableAt = 0;
        }

        _addActiveProver(msg.sender, _feeInGwei);
        if (_activeProvers.length == 1) {
            _poolEmptySince = 0;
        }

        // Evict provers whose fees exceed the new prover's fee * maxFeeSpreadPctg / 100
        _evictHighFeeProvers(_feeInGwei);

        _updateMovingAverage(_feeInGwei);
        emit BidPlaced(msg.sender, _feeInGwei, evicted);
    }

    /// @notice Request to exit the active pool and start the withdrawal delay
    function requestExit() external {
        ProverInfo storage info = _proverInfo[msg.sender];
        require(info.active == 1, NotCurrentProver());

        _removeActiveProver(msg.sender, info.index);
        uint48 withdrawableAt = _deferWithdraw(msg.sender);
        emit ExitRequested(msg.sender, withdrawableAt);
    }

    /// @inheritdoc IProverAuction
    function slashProver(address _proverAddr, address _recipient) external nonReentrant {
        require(msg.sender == inbox, OnlyInbox());

        BondInfo storage bond = _bonds[_proverAddr];

        uint128 actualSlash = uint128(LibMath.min(_livenessBond, bond.balance));
        uint128 actualReward = 0;
        if (_recipient != address(0)) {
            actualReward = uint128(uint256(actualSlash) * rewardBps / 10_000);
        }

        unchecked {
            bond.balance -= actualSlash;
            _totalSlashedAmount += actualSlash - actualReward;
        }

        if (actualReward > 0) {
            bondToken.safeTransfer(_recipient, actualReward);
        }

        emit ProverSlashed(_proverAddr, actualSlash, _recipient, actualReward);

        if (bond.balance < _ejectionThreshold) {
            ProverInfo storage info = _proverInfo[_proverAddr];
            if (info.active == 1) {
                _removeActiveProver(_proverAddr, info.index);
                _deferWithdraw(_proverAddr);
                emit ProverEjected(_proverAddr);
            }
        }
    }

    /// @inheritdoc IProverAuction
    function checkBondDeferWithdrawal(address _proverAddr) external returns (bool success_) {
        require(msg.sender == inbox, OnlyInbox());

        BondInfo storage bond = _bonds[_proverAddr];
        if (bond.balance < _ejectionThreshold) {
            return false;
        }

        ProverInfo storage info = _proverInfo[_proverAddr];
        if (info.active != 1 || bond.withdrawableAt != 0) {
            unchecked {
                bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
            }
        }

        return true;
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function getCurrentProver() external view returns (address prover_, uint32 feeInGwei_) {
        uint256 count = _activeProvers.length;
        if (count == 0) {
            return (address(0), 0);
        }

        uint32 maxFee = 0;
        for (uint256 i = 0; i < count; i++) {
            uint32 fee = _proverInfo[_activeProvers[i]].feeInGwei;
            if (fee > maxFee) maxFee = fee;
        }

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < count; i++) {
            uint32 fee = _proverInfo[_activeProvers[i]].feeInGwei;
            totalWeight += uint256(maxFee - fee) + 1;
        }

        uint256 rand = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.number, address(this)))
        );
        uint256 target = rand % totalWeight;

        for (uint256 i = 0; i < count; i++) {
            address prover = _activeProvers[i];
            uint32 fee = _proverInfo[prover].feeInGwei;
            uint256 weight = uint256(maxFee - fee) + 1;
            if (target < weight) {
                return (prover, fee);
            }
            target -= weight;
        }

        address lastProver = _activeProvers[count - 1];
        return (lastProver, _proverInfo[lastProver].feeInGwei);
    }

    /// @inheritdoc IProverAuction
    function isCurrentProver(address _proverAddr)
        external
        view
        returns (bool isActive_, uint32 feeInGwei_)
    {
        ProverInfo storage info = _proverInfo[_proverAddr];
        if (info.active == 1) {
            return (true, info.feeInGwei);
        }
        return (false, 0);
    }

    /// @notice Get the maximum fee that can be bid currently
    /// @return maxFee_ The maximum fee in Gwei
    function getMaxBidFee() public view returns (uint32 maxFee_) {
        uint256 count = _activeProvers.length;
        if (count == 0) {
            return _getVacantMaxBidFee();
        }

        (, uint32 worstFee,) = _findWorstProver();
        if (count < maxActiveProvers) {
            return worstFee;
        }

        unchecked {
            return uint32(uint256(worstFee) * (10_000 - minFeeReductionBps) / 10_000);
        }
    }

    /// @notice Get the active prover addresses in insertion order.
    /// @return provers_ The active prover list.
    function getActiveProvers() external view returns (address[] memory provers_) {
        return _activeProvers;
    }

    /// @notice Get a prover's current fee and active status.
    /// @param _prover The prover address to query.
    /// @return feeInGwei_ The prover's fee in Gwei (0 if inactive).
    /// @return active_ True if the prover is in the active pool.
    function getProverStatus(address _prover) external view returns (uint32 feeInGwei_, bool active_) {
        ProverInfo storage info = _proverInfo[_prover];
        return (info.feeInGwei, info.active == 1);
    }

    /// @notice Get the maximum number of active provers.
    /// @return maxActiveProvers_ The pool capacity.
    function getMaxActiveProvers() external view returns (uint16 maxActiveProvers_) {
        return maxActiveProvers;
    }

    /// @notice Get the bond information for an account
    /// @param _account The account to query
    /// @return bondInfo_ The bond info struct
    function getBondInfo(address _account) external view returns (BondInfo memory bondInfo_) {
        return _bonds[_account];
    }

    /// @notice Get the required bond amount to participate
    /// @return requiredBond_ The required bond in tokens
    function getRequiredBond() public view returns (uint128 requiredBond_) {
        return _requiredBond;
    }

    /// @notice Get the liveness bond amount slashed per failed proof
    /// @return livenessBond_ The liveness bond in tokens
    function getLivenessBond() external view returns (uint96 livenessBond_) {
        return _livenessBond;
    }

    /// @notice Get the ejection threshold below which a prover is ejected
    /// @return threshold_ The ejection threshold in tokens
    function getEjectionThreshold() public view returns (uint128 threshold_) {
        return _ejectionThreshold;
    }

    /// @notice Get the current moving average fee
    /// @return avgFee_ The moving average fee in Gwei
    function getMovingAverageFee() external view returns (uint32 avgFee_) {
        return _movingAverageFee;
    }

    /// @notice Get the total amount slashed and locked in the contract
    /// @return totalSlashedAmount_ The total slashed amount in tokens
    function getTotalSlashedAmount() external view returns (uint128 totalSlashedAmount_) {
        return _totalSlashedAmount;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Adds a prover to the active pool.
    function _addActiveProver(address _proverAddr, uint32 _feeInGwei) internal {
        ProverInfo storage info = _proverInfo[_proverAddr];
        info.feeInGwei = _feeInGwei;
        info.active = 1;
        info.index = uint16(_activeProvers.length);
        _activeProvers.push(_proverAddr);
    }

    /// @dev Removes a prover from the active pool.
    function _removeActiveProver(address _proverAddr, uint16 _index) internal {
        uint256 lastIndex = _activeProvers.length - 1;
        if (_index != lastIndex) {
            address lastProver = _activeProvers[lastIndex];
            _activeProvers[_index] = lastProver;
            _proverInfo[lastProver].index = _index;
        }
        _activeProvers.pop();

        uint32 removedFee = _proverInfo[_proverAddr].feeInGwei;
        _proverInfo[_proverAddr].feeInGwei = 0;
        _proverInfo[_proverAddr].active = 0;
        _proverInfo[_proverAddr].index = 0;

        if (_activeProvers.length == 0) {
            _poolEmptySince = uint48(block.timestamp);
            _lastPoolFee = removedFee;
        }
    }

    /// @dev Sets the withdrawal delay timer and returns the timestamp.
    function _deferWithdraw(address _proverAddr) internal returns (uint48 withdrawableAt_) {
        unchecked {
            withdrawableAt_ = uint48(block.timestamp) + bondWithdrawalDelay;
        }
        _bonds[_proverAddr].withdrawableAt = withdrawableAt_;
    }

    /// @dev Finds the highest-fee prover in the active pool.
    function _findWorstProver() internal view returns (address worst_, uint32 worstFee_, uint16 index_) {
        uint256 count = _activeProvers.length;
        worst_ = _activeProvers[0];
        worstFee_ = _proverInfo[worst_].feeInGwei;
        index_ = 0;

        for (uint256 i = 1; i < count; i++) {
            address prover = _activeProvers[i];
            uint32 fee = _proverInfo[prover].feeInGwei;
            if (fee > worstFee_) {
                worstFee_ = fee;
                worst_ = prover;
                index_ = uint16(i);
            }
        }
    }

    /// @dev Evicts provers whose fees exceed the threshold based on the new prover's fee.
    /// @param _newFee The fee of the newly joined prover
    function _evictHighFeeProvers(uint32 _newFee) internal {
        // Calculate the maximum allowed fee: newFee * maxFeeSpreadPctg / 100
        // Provers with fee >= threshold will be evicted
        uint256 threshold = uint256(_newFee) * maxFeeSpreadPctg / 100;
        if (threshold > type(uint32).max) {
            threshold = type(uint32).max;
        }

        // Iterate backwards to safely remove elements
        // Note: _activeProvers.length changes during iteration
        uint256 i = _activeProvers.length;
        while (i > 0) {
            i--;
            address prover = _activeProvers[i];
            uint32 fee = _proverInfo[prover].feeInGwei;
            if (fee >= threshold) {
                _removeActiveProver(prover, uint16(i));
                _deferWithdraw(prover);
                emit ProverEjected(prover);
            }
        }
    }

    /// @dev Computes the maximum bid fee when the pool is empty.
    function _getVacantMaxBidFee() internal view returns (uint32 maxFee_) {
        uint32 feeFloor;
        unchecked {
            uint256 movingAvgFee = uint256(_movingAverageFee) * movingAverageMultiplier;
            uint256 cappedMovingAvg = LibMath.min(movingAvgFee, type(uint32).max);
            feeFloor = uint32(LibMath.max(initialMaxFee, cappedMovingAvg));
        }

        uint32 baseFee = uint32(LibMath.max(_lastPoolFee, feeFloor));
        uint48 startTime = _poolEmptySince == 0 ? _contractCreationTime : _poolEmptySince;

        uint256 elapsed = block.timestamp - startTime;
        uint256 periods = elapsed / feeDoublingPeriod;
        periods = LibMath.min(periods, uint256(maxFeeDoublings));

        uint256 maxFee = uint256(baseFee) << periods;
        return uint32(LibMath.min(maxFee, type(uint32).max));
    }

    /// @dev Updates the time-weighted moving average of fees.
    function _updateMovingAverage(uint32 _newFee) internal {
        uint48 nowTs = uint48(block.timestamp);
        uint32 currentAvg = _movingAverageFee;

        if (currentAvg == 0) {
            _movingAverageFee = _newFee;
            _lastAvgUpdate = nowTs;
            return;
        }

        uint48 lastUpdate = _lastAvgUpdate == 0 ? nowTs : _lastAvgUpdate;

        unchecked {
            uint48 elapsed = nowTs - lastUpdate;
            uint48 window = movingAverageWindow;
            uint256 weightNew = elapsed >= window ? window : elapsed;
            if (weightNew == 0) {
                weightNew = 1;
            }
            uint256 weightOld = window - weightNew;

            uint256 weightedAvg =
                (uint256(currentAvg) * weightOld + uint256(_newFee) * weightNew) / window;
            _movingAverageFee = uint32(weightedAvg);
            _lastAvgUpdate = nowTs;
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error CurrentProverCannotWithdraw();
    error FeeMustBeLower();
    error FeeTooHigh();
    error SelfBidTooFrequent();
    error InsufficientBond();
    error InvalidMaxFeeDoublings();
    error InvalidBps();
    error InvalidFeeSpread();
    error NotCurrentProver();
    error OnlyInbox();
    error WithdrawalDelayNotPassed();
    error ZeroAddress();
    error ZeroValue();
}
