// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProverAuction } from "../iface/IProverAuction.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title ProverAuction
/// @notice A continuous reverse auction contract for prover services in the Taiko protocol.
/// Provers compete by offering the lowest proving fee per proposal. The winner becomes the
/// designated prover for all proposals until outbid, exited, or forced out due to low bond.
/// @dev Key features:
///      - Single prover slot with 1 SLOAD for getCurrentProver()
///      - Time-based fee cap when slot is vacant (doubles every feeDoublingPeriod)
///      - Decoupled bond management (deposit/withdraw separate from bidding)
///      - Best-effort slashing with automatic force-exit on low bond
///      - Moving average fee tracking to prevent manipulation
/// @custom:security-contact security@taiko.xyz
contract ProverAuction is EssentialContract, IProverAuction {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev Packed into 32 bytes (1 storage slot) for gas-efficient getCurrentProver()
    struct Prover {
        address addr; // 20 bytes - prover address
        uint48 feeInGwei; // 6 bytes - fee per proposal in Gwei
        uint48 exitTimestamp; // 6 bytes - when exit was triggered (0 = active)
    }

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The Inbox contract address (only caller for slashBond)
    address public immutable inbox;

    /// @notice The ERC20 token used for bonds (TAIKO token)
    IERC20 public immutable bondToken;

    /// @notice Bond amount slashed per failed proof
    uint96 public immutable livenessBond;

    /// @notice Maximum number of unproven proposals at any time
    uint16 public immutable maxPendingProposals;

    /// @notice Minimum fee reduction in basis points to outbid (e.g., 500 = 5%)
    uint16 public immutable minFeeReductionBps;

    /// @notice Time after exit before bond withdrawal is allowed
    uint48 public immutable bondWithdrawalDelay;

    /// @notice Time period for fee doubling when slot is vacant
    uint48 public immutable feeDoublingPeriod;

    /// @notice Maximum number of fee doublings allowed (e.g., 8 = 256x cap)
    uint8 public immutable maxFeeDoublings;

    /// @notice Initial maximum fee for first-ever bid (in Gwei)
    uint48 public immutable initialMaxFee;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Current prover packed into single slot for 1 SLOAD in getCurrentProver()
    Prover internal _prover;

    /// @dev Bond information per address
    mapping(address account => BondInfo info) internal _bonds;

    /// @dev Exponential moving average of winning fees (in Gwei)
    uint48 internal _movingAverageFee;

    /// @dev Total accumulated (slashed - rewarded), locked forever in contract
    uint128 internal _totalSlashDiff;

    /// @dev Contract creation timestamp for initial fee timing
    uint48 internal _contractCreationTime;

    /// @dev Reserved storage gap for future upgrades
    uint256[45] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes the ProverAuction contract with immutable parameters
    /// @param _inbox The Inbox contract address
    /// @param _bondToken The ERC20 token used for bonds
    /// @param _livenessBond Bond amount slashed per failed proof
    /// @param _maxPendingProposals Maximum unproven proposals at any time
    /// @param _minFeeReductionBps Minimum fee reduction to outbid (basis points)
    /// @param _bondWithdrawalDelay Time after exit before withdrawal allowed
    /// @param _feeDoublingPeriod Time period for fee doubling when vacant
    /// @param _maxFeeDoublings Maximum number of fee doublings
    /// @param _initialMaxFee Initial maximum fee for first-ever bid (in Gwei)
    constructor(
        address _inbox,
        address _bondToken,
        uint96 _livenessBond,
        uint16 _maxPendingProposals,
        uint16 _minFeeReductionBps,
        uint48 _bondWithdrawalDelay,
        uint48 _feeDoublingPeriod,
        uint8 _maxFeeDoublings,
        uint48 _initialMaxFee
    ) {
        require(_initialMaxFee > 0, InitialMaxFeeCannotBeZero());

        inbox = _inbox;
        bondToken = IERC20(_bondToken);
        livenessBond = _livenessBond;
        maxPendingProposals = _maxPendingProposals;
        minFeeReductionBps = _minFeeReductionBps;
        bondWithdrawalDelay = _bondWithdrawalDelay;
        feeDoublingPeriod = _feeDoublingPeriod;
        maxFeeDoublings = _maxFeeDoublings;
        initialMaxFee = _initialMaxFee;
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
    // Bond Management
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function deposit(uint128 _amount) external nonReentrant {
        bondToken.safeTransferFrom(msg.sender, address(this), _amount);
        unchecked {
            _bonds[msg.sender].balance += _amount;
        }
        emit Deposited(msg.sender, _amount);
    }

    /// @inheritdoc IProverAuction
    function withdraw(uint128 _amount) external nonReentrant {
        // Current prover cannot withdraw
        require(_prover.addr != msg.sender, CurrentProverCannotWithdraw());

        BondInfo storage info = _bonds[msg.sender];

        // Check withdrawal delay if set
        require(
            info.withdrawableAt == 0 || block.timestamp >= info.withdrawableAt,
            WithdrawalDelayNotPassed()
        );

        // Check sufficient balance
        require(info.balance >= _amount, InsufficientBond());

        unchecked {
            info.balance -= _amount;
        }
        bondToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    // ---------------------------------------------------------------
    // Auction Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function getCurrentProver() external view returns (address prover_, uint48 feeInGwei_) {
        Prover memory p = _prover; // 1 SLOAD

        // Return empty if no prover or prover has exited
        if (p.addr == address(0) || p.exitTimestamp > 0) {
            return (address(0), 0);
        }

        return (p.addr, p.feeInGwei);
    }

    /// @inheritdoc IProverAuction
    function getMaxBidFee() public view returns (uint48 maxFee_) {
        Prover memory current = _prover;

        // Active prover: must undercut by minFeeReductionBps
        if (current.addr != address(0) && current.exitTimestamp == 0) {
            unchecked {
                // Safe: uint48 * uint16 / 10000 fits in uint48
                return uint48(uint256(current.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
            }
        }

        // Vacant slot: time-based doubling
        uint48 baseFee;
        uint48 startTime;

        if (current.addr == address(0)) {
            // Never had a prover
            baseFee = initialMaxFee;
            startTime = _contractCreationTime;
        } else {
            // Previous prover exited - use their fee, but fall back to initialMaxFee if 0
            // This prevents the slot from being permanently stuck at 0 fee
            baseFee = current.feeInGwei > 0 ? current.feeInGwei : initialMaxFee;
            startTime = current.exitTimestamp;
        }

        uint256 elapsed;
        uint256 periods;
        unchecked {
            // Safe: block.timestamp >= startTime always
            elapsed = block.timestamp - startTime;
            periods = elapsed / feeDoublingPeriod;

            if (periods > maxFeeDoublings) {
                periods = maxFeeDoublings;
            }
        }

        uint256 maxFee = uint256(baseFee) << periods; // baseFee * 2^periods

        if (maxFee > type(uint48).max) {
            return type(uint48).max;
        }

        return uint48(maxFee);
    }

    /// @inheritdoc IProverAuction
    function bid(uint48 _feeInGwei) external nonReentrant {
        BondInfo storage bidderBond = _bonds[msg.sender];

        // 1. Validate bond
        require(bidderBond.balance >= getRequiredBond(), InsufficientBond());

        // 2. Load current prover
        Prover memory current = _prover;

        // 3. Validate fee based on caller
        bool isVacant = current.addr == address(0) || current.exitTimestamp > 0;
        bool isSelfBid = current.addr == msg.sender && !isVacant;

        if (isSelfBid) {
            // Current prover lowering their own fee - just needs to be lower
            require(_feeInGwei < current.feeInGwei, FeeMustBeLower());
        } else if (isVacant) {
            // Vacant slot: time-based cap
            require(_feeInGwei <= getMaxBidFee(), FeeTooHigh());
        } else {
            // Outbidding another prover: reduction required
            uint48 maxAllowedFee;
            unchecked {
                // Safe: uint48 * uint16 / 10000 fits in uint48
                maxAllowedFee =
                    uint48(uint256(current.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
            }
            require(_feeInGwei <= maxAllowedFee, FeeTooHigh());
        }

        // 4. Clear bidder's exit status if re-entering
        bidderBond.withdrawableAt = 0;

        // 5. Handle outbid prover (only if different address)
        if (current.addr != address(0) && current.addr != msg.sender) {
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

    // ---------------------------------------------------------------
    // Slashing (Inbox Only)
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function slashBond(
        address _proverAddr,
        uint128 _slashAmount,
        address _recipient,
        uint128 _rewardAmount
    )
        external
        nonReentrant
    {
        require(msg.sender == inbox, OnlyInbox());

        BondInfo storage bond = _bonds[_proverAddr];

        // Best-effort slash
        uint128 actualSlash = _slashAmount > bond.balance ? bond.balance : _slashAmount;
        // Reward recipient (capped by what was actually slashed)
        uint128 actualReward = _rewardAmount > actualSlash ? actualSlash : _rewardAmount;

        unchecked {
            // Safe: actualSlash <= bond.balance by construction above
            bond.balance -= actualSlash;
            // Safe: actualReward <= actualSlash by construction above
            _totalSlashDiff += actualSlash - actualReward;
        }

        if (actualReward > 0 && _recipient != address(0)) {
            bondToken.safeTransfer(_recipient, actualReward);
        }

        emit BondSlashed(_proverAddr, actualSlash, _recipient, actualReward);

        // Force out if below threshold AND is current prover AND not already exited
        Prover storage currentProver = _prover;
        if (
            _proverAddr == currentProver.addr && currentProver.exitTimestamp == 0
                && bond.balance < getForceExitThreshold()
        ) {
            currentProver.exitTimestamp = uint48(block.timestamp);
            unchecked {
                // Safe: uint48 + uint48 won't overflow for ~8900 years
                bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
            }
            emit ProverForcedOut(_proverAddr);
        }
    }

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function getBondInfo(address _account) external view returns (BondInfo memory bondInfo_) {
        return _bonds[_account];
    }

    /// @inheritdoc IProverAuction
    function getRequiredBond() public view returns (uint128 requiredBond_) {
        unchecked {
            // Safe: uint96 * uint16 * 2 fits in uint128
            return uint128(livenessBond) * maxPendingProposals * 2;
        }
    }

    /// @inheritdoc IProverAuction
    function getForceExitThreshold() public view returns (uint128 threshold_) {
        unchecked {
            // Safe: uint96 * uint16 / 2 fits in uint128
            return uint128(livenessBond) * maxPendingProposals / 2;
        }
    }

    /// @inheritdoc IProverAuction
    function getMovingAverageFee() external view returns (uint48 avgFee_) {
        return _movingAverageFee;
    }

    /// @inheritdoc IProverAuction
    function getTotalSlashDiff() external view returns (uint128 totalSlashDiff_) {
        return _totalSlashDiff;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Updates the exponential moving average of fees
    /// @param _newFee The new fee to incorporate into the average
    function _updateMovingAverage(uint48 _newFee) internal {
        uint48 currentAvg = _movingAverageFee;

        if (currentAvg == 0) {
            // First bid sets the baseline
            _movingAverageFee = _newFee;
        } else {
            unchecked {
                // Safe: uint48 * 9 + uint48 fits in uint256, result / 10 fits in uint48
                _movingAverageFee = uint48((uint256(currentAvg) * 9 + uint256(_newFee)) / 10);
            }
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error AlreadyExited();
    error CurrentProverCannotWithdraw();
    error FeeMustBeLower();
    error FeeTooHigh();
    error InitialMaxFeeCannotBeZero();
    error InsufficientBond();
    error NotCurrentProver();
    error OnlyInbox();
    error WithdrawalDelayNotPassed();
}
