// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProverAuction } from "../iface/IProverAuction.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

import "./ProverAuction_Layout.sol"; // DO NOT DELETE

/// @title ProverAuction
/// @notice A continuous reverse auction contract for prover services in the Taiko protocol.
/// Provers compete by offering the lowest proving fee per proposal. The winner becomes the
/// designated prover for all proposals until outbid, exited, or ejected due to low bond.
/// @dev Key features:
///      - Single prover slot with 1 SLOAD for getProver()
///      - Time-based fee cap when slot is vacant (doubles every feeDoublingPeriod)
///      - Decoupled bond management (deposit/withdraw separate from bidding)
///      - Best-effort slashing with automatic ejection on low bond
///      - Moving average fee tracking to prevent manipulation
///      - Entry points remain callable while paused (see tests for rationale)
/// @custom:security-contact security@taiko.xyz
contract ProverAuction is EssentialContract, IProverAuction {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Minimum time between self-bids to prevent moving average manipulation
    uint48 public constant MIN_SELF_BID_INTERVAL = 2 minutes;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Packed into 32 bytes (1 storage slot) for gas-efficient getProver()
    struct Prover {
        address addr; // 20 bytes - prover address
        uint32 feeInGwei; // 4 bytes - fee per proposal in Gwei (max ~4.29 ETH)
        uint48 exitTimestamp; // 6 bytes - when exit was triggered (0 = active)
    }

    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------


    /// @notice Emitted when a new bid is placed or current prover lowers their fee.
    /// @param newProver The address of the new prover.
    /// @param feeInGwei The new fee per proposal in Gwei.
    /// @param oldProver The address of the previous prover (address(0) if none).
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);


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

    /// @notice Time period for fee doubling when slot is vacant
    uint48 public immutable feeDoublingPeriod;

    /// @notice Time window for moving average smoothing
    uint48 public immutable movingAverageWindow;

    /// @notice Maximum number of fee doublings allowed (e.g., 8 = 256x cap)
    uint8 public immutable maxFeeDoublings;

    /// @notice Initial maximum fee for first-ever bid (in Gwei)
    uint32 public immutable initialMaxFee;

    /// @notice Multiplier for moving average fee to calculate floor (e.g., 2 = 2x moving average)
    uint8 public immutable movingAverageMultiplier;

    /// @notice Bond amount slashed per failed proof
    uint96 private immutable _livenessBond;

    /// @notice Pre-computed required bond amount (livenessBond * bondMultiplier * 2)
    uint128 private immutable _requiredBond;

    /// @notice Pre-computed ejection threshold (livenessBond * bondMultiplier)
    uint128 private immutable _ejectionThreshold;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Current prover packed into single slot for 1 SLOAD in getProver()
    Prover internal _prover;

    /// @dev Bond information per address
    mapping(address account => BondInfo info) internal _bonds;

    /// @dev Exponential moving average of winning fees (in Gwei)
    uint32 internal _movingAverageFee;

    /// @dev Total accumulated (slashed - rewarded), locked forever in contract
    uint128 internal _totalSlashedAmount;

    /// @dev Contract creation timestamp for initial fee timing
    uint48 internal _contractCreationTime;

    /// @dev Timestamp of the last moving average update
    uint48 internal _lastAvgUpdate;

    /// @dev Reserved storage gap for future upgrades
    uint256[45] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the ProverAuction contract with immutable parameters
    /// @param _inbox The Inbox contract address
    /// @param _bondToken The ERC20 token used for bonds
    /// @param _livenessBondAmount Bond amount slashed per failed proof
    /// @param _bondMultiplier Multiplier for livenessBond to calculate bond requirements
    /// @param _minFeeReductionBps Minimum fee reduction to outbid (basis points)
    /// @param _rewardBps Reward percentage in basis points for slashing
    /// @param _bondWithdrawalDelay Time after exit before withdrawal allowed
    /// @param _feeDoublingPeriod Time period for fee doubling when vacant
    /// @param _movingAverageWindow Time window for moving average smoothing
    /// @param _maxFeeDoublings Maximum number of fee doublings
    /// @param _initialMaxFee Initial maximum fee for first-ever bid (in Gwei)
    /// @param _movingAverageMultiplier Multiplier for moving average fee floor
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
        uint8 _movingAverageMultiplier
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

        // Pre-compute bond thresholds to save gas on every bid/slash
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
    }

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Deposit bond tokens to caller's balance.
    /// @param _amount Amount of bond tokens to deposit.
    /// @dev Tokens are transferred from msg.sender to this contract.
    function deposit(uint128 _amount) external nonReentrant {
        bondToken.safeTransferFrom(msg.sender, address(this), _amount);
        _bonds[msg.sender].balance += _amount;
        emit Deposited(msg.sender, _amount);
    }

    /// @notice Withdraw bond tokens from caller's balance.
    /// @param _amount Amount to withdraw.
    /// @dev Reverts if caller is active prover or withdrawal delay not passed.
    function withdraw(uint128 _amount) external nonReentrant {
        BondInfo storage info = _bonds[msg.sender];

        // Check withdrawal delay if set
        if (info.withdrawableAt == 0) {
            // No delay set - must check if caller is active prover (only SLOAD when needed)
            Prover memory p = _prover;
            require(p.addr != msg.sender || p.exitTimestamp > 0, CurrentProverCannotWithdraw());
        } else {
            // Delay is set - caller was outbid/exited, just check timing
            require(block.timestamp >= info.withdrawableAt, WithdrawalDelayNotPassed());
        }

        // Check sufficient balance
        require(info.balance >= _amount, InsufficientBond());

        unchecked {
            info.balance -= _amount;
        }
        bondToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverAuction
    function bid(uint32 _feeInGwei) external nonReentrant {
        BondInfo storage bidderBond = _bonds[msg.sender];

        // 1. Validate bond
        require(bidderBond.balance >= getRequiredBond(), InsufficientBond());

        // 2. Load current prover
        Prover memory current = _prover;

        // 3. Validate fee based on caller
        bool isVacant = current.addr == address(0) || current.exitTimestamp > 0;
        // Must be active current prover (not exited) to apply self-bid rules.
        bool isSelfBid = current.addr == msg.sender && !isVacant;

        if (isSelfBid) {
            // Current prover lowering their own fee - just needs to be lower
            // Enforce minimum interval between self-bids to prevent MA manipulation
            require(block.timestamp >= _lastAvgUpdate + MIN_SELF_BID_INTERVAL, SelfBidTooFrequent());
            require(_feeInGwei < current.feeInGwei, FeeMustBeLower());
        } else if (isVacant) {
            // Vacant slot: time-based cap
            require(_feeInGwei <= getMaxBidFee(), FeeTooHigh());
        } else {
            // Outbidding another prover: reduction required
            require(_feeInGwei < current.feeInGwei, FeeMustBeLower());
            uint32 maxAllowedFee;
            unchecked {
                // Safe: uint32 * uint16 / 10000 fits in uint32
                maxAllowedFee =
                    uint32(uint256(current.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
            }
            require(_feeInGwei <= maxAllowedFee, FeeTooHigh());
        }

        // 4. Clear bidder's exit status if re-entering (conditional to save gas)
        if (bidderBond.withdrawableAt != 0) {
            bidderBond.withdrawableAt = 0;
        }

        // 5. Handle outbid prover (only if different address)
        if (current.addr != address(0) && current.addr != msg.sender && current.exitTimestamp == 0)
        {
            unchecked {
                // Safe: uint48 + uint48 won't overflow for ~8900 years
                _bonds[current.addr].withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
            }
        }

        // 6. Set new prover
        _prover = Prover({ addr: msg.sender, feeInGwei: _feeInGwei, exitTimestamp: 0 });

        // 7. Update moving average
        _updateMovingAverage(_feeInGwei);

        emit BidPlaced(msg.sender, _feeInGwei, current.addr);
    }

    /// @inheritdoc IProverAuction
    function requestExit() external {
        Prover storage p = _prover;

        require(p.addr == msg.sender, NotCurrentProver());
        require(p.exitTimestamp == 0, AlreadyExited());

        // Mark as exited
        p.exitTimestamp = uint48(block.timestamp);

        // Set withdrawal timer (cache value to avoid redundant SLOAD in emit)
        uint48 withdrawableAt;
        unchecked {
            // Safe: uint48 + uint48 won't overflow for ~8900 years
            withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        }
        _bonds[msg.sender].withdrawableAt = withdrawableAt;

        emit ExitRequested(msg.sender, withdrawableAt);
    }

    /// @inheritdoc IProverAuction
    function slashProver(address _proverAddr, address _recipient) external nonReentrant {
        require(msg.sender == inbox, OnlyInbox());

        BondInfo storage bond = _bonds[_proverAddr];

        // Best-effort slash using the configured liveness bond
        uint128 actualSlash = uint128(LibMath.min(_livenessBond, bond.balance));
        // Reward recipient based on the actual slashed amount
        uint128 actualReward = 0;
        if (_recipient != address(0)) {
            actualReward = uint128(uint256(actualSlash) * rewardBps / 10_000);
        }

        unchecked {
            // Safe: actualSlash <= bond.balance by construction above
            bond.balance -= actualSlash;
            // Safe: actualReward <= actualSlash by construction above
            _totalSlashedAmount += actualSlash - actualReward;
        }

        if (actualReward > 0) {
            bondToken.safeTransfer(_recipient, actualReward);
        }

        emit ProverSlashed(_proverAddr, actualSlash, _recipient, actualReward);

        // Eject if below threshold AND is current prover AND not already exited
        // Check balance threshold first to avoid SLOAD when not needed
        if (bond.balance < _ejectionThreshold) {
            Prover storage current = _prover;
            if (_proverAddr == current.addr && current.exitTimestamp == 0) {
                current.exitTimestamp = uint48(block.timestamp);
                unchecked {
                    // Safe: uint48 + uint48 won't overflow for ~8900 years
                    bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
                }
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

        Prover memory current = _prover;
        bool isCurrent = _proverAddr == current.addr && current.exitTimestamp == 0;

        if (!isCurrent || bond.withdrawableAt != 0) {
            unchecked {
                // Safe: uint48 + uint48 won't overflow for ~8900 years
                bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
            }
        }

        return true;
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @notice Get the current active prover and their fee.
    /// @return prover_ Current prover address (address(0) if none or exited).
    /// @return feeInGwei_ Fee per proposal in Gwei.
    /// @dev Optimized for 1 SLOAD - called on every proposal by Inbox.
    function getProver() external view returns (address prover_, uint32 feeInGwei_) {
        Prover memory p = _prover; // 1 SLOAD

        // Return empty if no prover or prover has exited
        if (p.addr == address(0) || p.exitTimestamp > 0) {
            return (address(0), 0);
        }

        return (p.addr, p.feeInGwei);
    }

    /// @notice Get the maximum allowed bid fee at the current time.
    /// @return maxFee_ Maximum fee in Gwei that a bid can specify.
    /// @dev If active prover exists: returns fee * (10000 - minFeeReductionBps) / 10000.
    /// @dev If slot is vacant: returns time-based cap (doubles every feeDoublingPeriod).
    function getMaxBidFee() public view returns (uint32 maxFee_) {
        Prover memory current = _prover;

        // Active prover: must undercut by minFeeReductionBps
        if (current.addr != address(0) && current.exitTimestamp == 0) {
            unchecked {
                // Safe: uint32 * uint16 / 10000 fits in uint32
                return uint32(uint256(current.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
            }
        }

        // Vacant slot: time-based doubling
        // Use max of initialMaxFee and movingAverage * multiplier to prevent manipulation
        uint32 feeFloor;
        unchecked {
            // Safe: uint32 * uint8 fits in uint256, result capped to uint32.max
            uint256 movingAvgFee = uint256(_movingAverageFee) * movingAverageMultiplier;
            uint256 cappedMovingAvg = LibMath.min(movingAvgFee, type(uint32).max);
            feeFloor = uint32(LibMath.max(initialMaxFee, cappedMovingAvg));
        }

        uint32 baseFee;
        uint48 startTime;

        if (current.addr == address(0)) {
            // Never had a prover - use fee floor
            baseFee = feeFloor;
            startTime = _contractCreationTime;
        } else {
            // Previous prover exited - use max of their fee and fee floor
            baseFee = uint32(LibMath.max(current.feeInGwei, feeFloor));
            startTime = current.exitTimestamp;
        }

        uint256 elapsed;
        uint256 periods;
        unchecked {
            // Safe: block.timestamp >= startTime always
            elapsed = block.timestamp - startTime;
            periods = elapsed / feeDoublingPeriod;

            periods = LibMath.min(periods, uint256(maxFeeDoublings));
        }

        // Safe: baseFee (uint32) << periods (capped at maxFeeDoublings, a uint8) fits in uint256
        uint256 maxFee = uint256(baseFee) << periods;

        return uint32(LibMath.min(maxFee, type(uint32).max));
    }

    /// @notice Get bond information for an account.
    /// @param _account The account to query.
    /// @return bondInfo_ The bond information struct.
    function getBondInfo(address _account) external view returns (BondInfo memory bondInfo_)
    {
        return _bonds[_account];
    }

    /// @inheritdoc IProverAuction
    function getRequiredBond() public view returns (uint128 requiredBond_) {
        return _requiredBond;
    }

    /// @inheritdoc IProverAuction
    function getLivenessBond() external view returns (uint96 livenessBond_) {
        return _livenessBond;
    }

    /// @inheritdoc IProverAuction
    function getEjectionThreshold() public view returns (uint128 threshold_) {
        return _ejectionThreshold;
    }

    /// @notice Get the current moving average fee.
    /// @return avgFee_ The exponential moving average of winning fees in Gwei.
    function getMovingAverageFee() external view returns (uint32 avgFee_) {
        return _movingAverageFee;
    }

    /// @inheritdoc IProverAuction
    function getTotalSlashedAmount() external view returns (uint128 totalSlashedAmount_) {
        return _totalSlashedAmount;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Updates the time-weighted moving average of fees.
    ///      The weight of the new fee increases linearly with elapsed time since
    ///      the last update, capped at feeDoublingPeriod. A minimum weight of 1
    ///      is applied to avoid no-op updates in the same block.
    /// @param _newFee The new fee to incorporate into the average
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

    error AlreadyExited();
    error CurrentProverCannotWithdraw();
    error FeeMustBeLower();
    error FeeTooHigh();
    error SelfBidTooFrequent();
    error InsufficientBond();
    error InvalidMaxFeeDoublings();
    error InvalidBps();
    error NotCurrentProver();
    error OnlyInbox();
    error WithdrawalDelayNotPassed();
    error ZeroAddress();
    error ZeroValue();
}
