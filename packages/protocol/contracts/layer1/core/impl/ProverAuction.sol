// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProverAuction } from "../iface/IProverAuction.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

import "./ProverAuction_Layout.sol"; // DO NOT DELETE

/// @title ProverAuction
/// @notice Single-prover auction.
/// @custom:security-contact security@taiko.xyz
contract ProverAuction is EssentialContract, IProverAuction {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Minimum time between moving-average updates to limit rapid bid manipulation.
    uint256 public constant MIN_AVG_UPDATE_INTERVAL = LibPreconfConstants.SECONDS_IN_EPOCH;

    /// @notice Maximum number of provers in the pool (storage-only, single prover active).
    uint8 public constant MAX_POOL_SIZE = 16;

    /// @notice Slot table word count (storage-only, single prover active).
    uint8 internal constant SLOT_TABLE_WORDS = 8;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    struct PoolState {
        uint32 feeInGwei;
        uint8 poolSize;
        uint48 vacantSince;
        uint8 everHadPool;
    }

    struct PoolMember {
        uint8 index;
        uint8 joinOrder;
        uint16 weightBps;
        bool active;
    }

    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new bid is placed.
    /// @param newProver The address of the new prover.
    /// @param feeInGwei The new fee per proposal in Gwei.
    /// @param oldProver The address of the previous prover (address(0) if none).
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The Inbox contract address (only caller for slashProver/checkBondDeferWithdrawal).
    address public immutable inbox;

    /// @notice The ERC20 token used for bonds (TAIKO token).
    IERC20 public immutable bondToken;

    /// @notice Minimum fee reduction in basis points to outbid (e.g., 500 = 5%).
    uint16 public immutable minFeeReductionBps;

    /// @notice Reward percentage in basis points for slashing (e.g., 6000 = 60%).
    uint16 public immutable rewardBps;

    /// @notice Time after exit before bond withdrawal is allowed.
    uint48 public immutable bondWithdrawalDelay;

    /// @notice Time period for fee doubling when slot is vacant.
    uint48 public immutable feeDoublingPeriod;

    /// @notice Time window for moving average smoothing.
    uint48 public immutable movingAverageWindow;

    /// @notice Maximum number of fee doublings allowed (e.g., 8 = 256x cap).
    uint8 public immutable maxFeeDoublings;

    /// @notice Initial maximum fee for first-ever bid (in Gwei).
    uint32 public immutable initialMaxFee;

    /// @notice Multiplier for moving average fee to calculate floor (e.g., 2 = 2x moving average).
    uint8 public immutable movingAverageMultiplier;

    /// @notice Bond amount slashed per failed proof.
    uint96 private immutable _livenessBond;

    /// @notice Pre-computed required bond amount (ejectionThreshold * 2).
    uint128 private immutable _requiredBond;

    /// @notice Bond threshold that triggers ejection.
    uint128 private immutable _ejectionThreshold;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    PoolState internal _pool;

    address[MAX_POOL_SIZE] internal _activeProvers;
    uint256[SLOT_TABLE_WORDS] internal _slotTable;

    mapping(address account => PoolMember member) internal _members;
    mapping(address account => BondInfo info) internal _bonds;

    uint32 internal _movingAverageFee;
    uint128 internal _totalSlashedAmount;
    uint48 internal _contractCreationTime;
    uint48 internal _lastAvgUpdate;

    uint256[22] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(
        address _inbox,
        address _bondToken,
        uint96 _livenessBondAmount,
        uint128 _ejectionThresholdAmount,
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
        require(_ejectionThresholdAmount > _livenessBondAmount, InvalidEjectionThreshold());
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
        minFeeReductionBps = _minFeeReductionBps;
        rewardBps = _rewardBps;
        bondWithdrawalDelay = _bondWithdrawalDelay;
        feeDoublingPeriod = _feeDoublingPeriod;
        movingAverageWindow = _movingAverageWindow;
        maxFeeDoublings = _maxFeeDoublings;
        initialMaxFee = _initialMaxFee;
        movingAverageMultiplier = _movingAverageMultiplier;
        _ejectionThreshold = _ejectionThresholdAmount;
        _requiredBond = _ejectionThresholdAmount * 2;
    }

    // ---------------------------------------------------------------
    // Initializer Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract (for upgradeable proxy pattern).
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        _contractCreationTime = uint48(block.timestamp);
    }

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function deposit(uint128 _amount) external {
        _bonds[msg.sender].balance += _amount;
        bondToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(msg.sender, _amount);
    }

    /// @inheritdoc IProverAuction
    function withdraw(uint128 _amount) external {
        BondInfo storage info = _bonds[msg.sender];

        if (info.withdrawableAt == 0) {
            bool isCurrentProver =
                _pool.poolSize != 0 && _pool.vacantSince == 0 && _activeProvers[0] == msg.sender;
            require(!isCurrentProver, CurrentProverCannotWithdraw());
        } else {
            require(block.timestamp >= info.withdrawableAt, WithdrawalDelayNotPassed());
        }

        require(info.balance >= _amount, InsufficientBond());
        info.balance -= _amount;
        bondToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverAuction
    function bid(uint32 _feeInGwei) external {
        BondInfo storage bond = _bonds[msg.sender];
        PoolState memory pool = _pool;
        address oldProver = _activeProvers[0];
        bool isVacant = pool.poolSize == 0 || pool.vacantSince > 0;

        require(bond.balance >= getRequiredBond(), InsufficientBond());

        if (!isVacant && oldProver == msg.sender) {
            require(_feeInGwei < pool.feeInGwei, FeeMustBeLower());
            if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

            _setProver(msg.sender, _feeInGwei);
            _updateMovingAverage(_feeInGwei);
            emit BidPlaced(msg.sender, _feeInGwei, oldProver);
            return;
        }

        if (isVacant) {
            require(_feeInGwei <= getMaxBidFee(), FeeTooHigh());
            if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

            _setProver(msg.sender, _feeInGwei);
            _updateMovingAverage(_feeInGwei);
            emit BidPlaced(msg.sender, _feeInGwei, oldProver);
            return;
        }

        require(_feeInGwei < pool.feeInGwei, FeeMustBeLower());
        uint32 maxAllowedFee =
            uint32(uint256(pool.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
        require(_feeInGwei <= maxAllowedFee, FeeTooHigh());
        if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

        _bonds[oldProver].withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        _setProver(msg.sender, _feeInGwei);
        _updateMovingAverage(_feeInGwei);
        emit BidPlaced(msg.sender, _feeInGwei, oldProver);
    }

    /// @inheritdoc IProverAuction
    function requestExit() external {
        if (_pool.poolSize == 0 || _pool.vacantSince > 0 || _activeProvers[0] != msg.sender) {
            revert NotCurrentProver();
        }

        _bonds[msg.sender].withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        _vacateProver();

        emit ExitRequested(msg.sender, _bonds[msg.sender].withdrawableAt);
    }

    /// @inheritdoc IProverAuction
    function slashProver(address _proverAddr, address _recipient) external {
        require(msg.sender == inbox, OnlyInbox());

        BondInfo storage bond = _bonds[_proverAddr];

        uint128 actualSlash = uint128(LibMath.min(_livenessBond, bond.balance));
        uint128 actualReward;
        if (_recipient != address(0)) {
            actualReward = uint128(uint256(actualSlash) * rewardBps / 10_000);
        }

        bond.balance -= actualSlash;
        _totalSlashedAmount += actualSlash - actualReward;

        if (actualReward > 0) {
            bondToken.safeTransfer(_recipient, actualReward);
        }

        emit ProverSlashed(_proverAddr, actualSlash, _recipient, actualReward);

        if (bond.balance < _ejectionThreshold) {
            if (_pool.poolSize != 0 && _pool.vacantSince == 0 && _activeProvers[0] == _proverAddr) {
                _bonds[_proverAddr].withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
                _vacateProver();
                emit ProverEjected(_proverAddr);
            }
        }
    }

    /// @inheritdoc IProverAuction
    function checkBondDeferWithdrawal(address _prover) external returns (bool success_) {
        require(msg.sender == inbox, OnlyInbox());

        BondInfo storage bond = _bonds[_prover];
        if (bond.balance < _ejectionThreshold) {
            return false;
        }

        bool isCurrentProver =
            _pool.poolSize != 0 && _pool.vacantSince == 0 && _activeProvers[0] == _prover;
        if (!isCurrentProver || bond.withdrawableAt != 0) {
            bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        }

        return true;
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function getProver() external view returns (address prover_, uint32 feeInGwei_) {
        PoolState memory pool = _pool;
        if (pool.poolSize == 0 || pool.vacantSince > 0) {
            return (address(0), 0);
        }
        return (_activeProvers[0], pool.feeInGwei);
    }

    /// @notice Get the maximum allowed bid fee at the current time.
    /// @return maxFee_ Maximum fee in Gwei that a bid can specify.
    function getMaxBidFee() public view returns (uint32 maxFee_) {
        PoolState memory pool = _pool;

        if (pool.poolSize != 0 && pool.vacantSince == 0) {
            return uint32(uint256(pool.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
        }

        uint256 movingAvgFee = uint256(_movingAverageFee) * movingAverageMultiplier;
        uint256 cappedMovingAvg = LibMath.min(movingAvgFee, type(uint32).max);
        uint32 feeFloor = uint32(LibMath.max(initialMaxFee, cappedMovingAvg));

        uint32 baseFee;
        uint48 startTime;

        if (pool.everHadPool == 0) {
            baseFee = feeFloor;
            startTime = _contractCreationTime;
        } else {
            baseFee = uint32(LibMath.max(pool.feeInGwei, feeFloor));
            startTime = pool.vacantSince;
        }

        uint256 elapsed = block.timestamp - startTime;
        uint256 periods = elapsed / feeDoublingPeriod;
        if (periods > maxFeeDoublings) {
            periods = maxFeeDoublings;
        }

        uint256 maxFee = uint256(baseFee) << periods;
        return uint32(LibMath.min(maxFee, type(uint32).max));
    }

    /// @notice Get bond information for an account.
    /// @param _account The account to query.
    /// @return bondInfo_ The bond information struct.
    function getBondInfo(address _account) external view returns (BondInfo memory bondInfo_) {
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
    function getEjectionThreshold() external view returns (uint128 threshold_) {
        return _ejectionThreshold;
    }

    /// @notice Get the current moving average fee.
    /// @return avgFee_ The time-weighted moving average of winning fees in Gwei.
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

    /// @dev Sets the current prover and fee.
    /// @param prover The prover address.
    /// @param feeInGwei The fee per proposal in Gwei.
    function _setProver(address prover, uint32 feeInGwei) internal {
        _pool.feeInGwei = feeInGwei;
        _pool.poolSize = 1;
        _pool.vacantSince = 0;
        _pool.everHadPool = 1;
        _activeProvers[0] = prover;
    }

    /// @dev Vacates the current prover slot.
    function _vacateProver() internal {
        _activeProvers[0] = address(0);
        _pool.poolSize = 0;
        _pool.vacantSince = uint48(block.timestamp);
    }

    /// @dev Updates the time-weighted moving average of fees.
    /// @param _newFee The new fee to incorporate into the average.
    function _updateMovingAverage(uint32 _newFee) internal {
        uint48 nowTs = uint48(block.timestamp);
        uint32 currentAvg = _movingAverageFee;

        if (currentAvg == 0) {
            _movingAverageFee = _newFee;
            _lastAvgUpdate = nowTs;
            return;
        }

        uint48 lastUpdate = _lastAvgUpdate == 0 ? nowTs : _lastAvgUpdate;
        uint48 elapsed = nowTs - lastUpdate;
        if (elapsed < MIN_AVG_UPDATE_INTERVAL) return;

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

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error CurrentProverCannotWithdraw();
    error FeeMustBeLower();
    error FeeTooHigh();
    error InsufficientBond();
    error InvalidBps();
    error InvalidEjectionThreshold();
    error InvalidMaxFeeDoublings();
    error NotCurrentProver();
    error OnlyInbox();
    error WithdrawalDelayNotPassed();
    error ZeroAddress();
    error ZeroValue();
}
