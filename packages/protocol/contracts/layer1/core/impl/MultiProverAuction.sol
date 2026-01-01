// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProverAuction } from "../iface/IProverAuction.sol";
import { IProverAuctionInbox } from "./IProverAuctionInbox.sol";
import { ProverAuctionTypes } from "./ProverAuctionTypes.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

/// @title MultiProverAuction
/// @notice Multi-prover auction with pooled provers at the same fee.
/// @dev Option 1 (bond premium) + Option 3 (weighted selection) combined.
/// @custom:security-contact security@taiko.xyz
contract MultiProverAuction is EssentialContract, IProverAuctionInbox {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Minimum time between self-bids to prevent moving average manipulation.
    uint48 public constant MIN_SELF_BID_INTERVAL = 2 minutes;

    /// @notice Maximum number of provers in the pool.
    uint8 public constant MAX_POOL_SIZE = 16;

    /// @notice Slot table size for O(1) weighted selection.
    uint16 public constant SLOT_TABLE_SIZE = 256;

    /// @notice Bond premium per join order in basis points (5%).
    uint16 public constant JOIN_BOND_PREMIUM_BPS = 500;

    /// @notice Weight decay per join order in basis points (10%).
    uint16 public constant WEIGHT_DECAY_BPS = 1000;

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

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when bond tokens are deposited.
    /// @param account The account that deposited.
    /// @param amount The amount deposited.
    event Deposited(address indexed account, uint128 amount);

    /// @notice Emitted when bond tokens are withdrawn.
    /// @param account The account that withdrew.
    /// @param amount The amount withdrawn.
    event Withdrawn(address indexed account, uint128 amount);

    /// @notice Emitted when a new bid is placed or pool is reset.
    /// @param newProver The address of the new leader prover.
    /// @param feeInGwei The new fee per proposal in Gwei.
    /// @param oldProver The address of the previous leader (address(0) if none).
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);

    /// @notice Emitted when a prover joins the current pool.
    /// @param prover The prover that joined.
    /// @param joinOrder The join order in the pool.
    event PoolJoined(address indexed prover, uint8 joinOrder);

    /// @notice Emitted when the current prover requests to exit.
    /// @param prover The prover that requested exit.
    /// @param withdrawableAt Timestamp when bond becomes withdrawable.
    event ExitRequested(address indexed prover, uint48 withdrawableAt);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The Inbox contract address (only caller for slashProver/checkBondDeferWithdrawal).
    address public immutable inbox;

    /// @notice The ERC20 token used for bonds (TAIKO token).
    IERC20 public immutable bondToken;

    /// @notice Multiplier for livenessBond to calculate required/threshold bond amounts.
    uint16 public immutable bondMultiplier;

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

    /// @notice Pre-computed required bond amount (livenessBond * bondMultiplier * 2).
    uint128 private immutable _requiredBond;

    /// @notice Pre-computed ejection threshold (livenessBond * bondMultiplier).
    uint128 private immutable _ejectionThreshold;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    PoolState internal _pool;

    address[MAX_POOL_SIZE] internal _activeProvers;
    uint8[SLOT_TABLE_SIZE] internal _slotTable;

    mapping(address account => PoolMember member) internal _members;
    mapping(address account => ProverAuctionTypes.BondInfo info) internal _bonds;

    uint32 internal _movingAverageFee;
    uint128 internal _totalSlashedAmount;
    uint48 internal _contractCreationTime;
    uint48 internal _lastAvgUpdate;

    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

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

        unchecked {
            uint128 ejectionThreshold = uint128(_livenessBondAmount) * _bondMultiplier;
            _ejectionThreshold = ejectionThreshold;
            _requiredBond = ejectionThreshold * 2;
        }
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
        ProverAuctionTypes.BondInfo storage info = _bonds[msg.sender];

        if (info.withdrawableAt == 0) {
            require(!_members[msg.sender].active, CurrentProverCannotWithdraw());
        } else {
            require(block.timestamp >= info.withdrawableAt, WithdrawalDelayNotPassed());
        }

        require(info.balance >= _amount, InsufficientBond());
        unchecked {
            info.balance -= _amount;
        }
        bondToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProverAuction
    function bid(uint32 _feeInGwei) external nonReentrant {
        ProverAuctionTypes.BondInfo storage bond = _bonds[msg.sender];
        PoolState memory pool = _pool;
        address oldLeader = _activeProvers[0];

        bool isVacant = pool.poolSize == 0 || pool.vacantSince > 0;
        PoolMember memory member = _members[msg.sender];
        bool isMember = member.active;

        if (isMember) {
            require(block.timestamp >= _lastAvgUpdate + MIN_SELF_BID_INTERVAL, SelfBidTooFrequent());
            require(_feeInGwei < pool.feeInGwei, FeeMustBeLower());
            if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

            _clearPoolMembersToWithdrawable(msg.sender);
            _resetPool(msg.sender, _feeInGwei);
            _updateMovingAverage(_feeInGwei);
            emit BidPlaced(msg.sender, _feeInGwei, oldLeader);
            return;
        }

        if (isVacant) {
            require(_feeInGwei <= getMaxBidFee(), FeeTooHigh());
            require(bond.balance >= getRequiredBond(), InsufficientBond());
            if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

            _clearPoolMembersToWithdrawable(address(0));
            _resetPool(msg.sender, _feeInGwei);
            _updateMovingAverage(_feeInGwei);
            emit BidPlaced(msg.sender, _feeInGwei, oldLeader);
            return;
        }

        if (_feeInGwei == pool.feeInGwei) {
            require(pool.poolSize < MAX_POOL_SIZE, PoolFull());
            uint8 joinOrder = pool.poolSize + 1;
            uint128 requiredBond = _requiredBondForJoin(joinOrder);
            require(bond.balance >= requiredBond, InsufficientBond());
            if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

            _addToPool(msg.sender, joinOrder);
            emit PoolJoined(msg.sender, joinOrder);
            return;
        }

        require(_feeInGwei < pool.feeInGwei, FeeMustBeLower());
        uint32 maxAllowedFee;
        unchecked {
            maxAllowedFee =
                uint32(uint256(pool.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
        }
        require(_feeInGwei <= maxAllowedFee, FeeTooHigh());
        require(bond.balance >= getRequiredBond(), InsufficientBond());
        if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

        _clearPoolMembersToWithdrawable(address(0));
        _resetPool(msg.sender, _feeInGwei);
        _updateMovingAverage(_feeInGwei);
        emit BidPlaced(msg.sender, _feeInGwei, oldLeader);
    }

    /// @inheritdoc IProverAuction
    function requestExit() external {
        PoolMember storage member = _members[msg.sender];
        require(member.active, NotInPool());

        _removeFromPool(msg.sender);

        uint48 withdrawableAt;
        unchecked {
            withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        }
        _bonds[msg.sender].withdrawableAt = withdrawableAt;

        emit ExitRequested(msg.sender, withdrawableAt);
    }

    /// @inheritdoc IProverAuctionInbox
    function slashProver(address _proverAddr, address _recipient) external nonReentrant {
        require(msg.sender == inbox, OnlyInbox());

        ProverAuctionTypes.BondInfo storage bond = _bonds[_proverAddr];

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
            PoolMember storage member = _members[_proverAddr];
            if (member.active) {
                _removeFromPool(_proverAddr);
                unchecked {
                    bond.withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
                }
                emit ProverEjected(_proverAddr);
            }
        }
    }

    /// @inheritdoc IProverAuction
    function checkBondDeferWithdrawal(address _proverAddr) external returns (bool success_) {
        require(msg.sender == inbox, OnlyInbox());

        ProverAuctionTypes.BondInfo storage bond = _bonds[_proverAddr];
        if (bond.balance < _ejectionThreshold) {
            return false;
        }

        if (!_members[_proverAddr].active || bond.withdrawableAt != 0) {
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
    function getProver() external view returns (address prover_, uint32 feeInGwei_) {
        PoolState memory pool = _pool;
        if (pool.poolSize == 0 || pool.vacantSince > 0) {
            return (address(0), 0);
        }
        if (pool.poolSize == 1) {
            return (_activeProvers[0], pool.feeInGwei);
        }
        uint8 slot = uint8(uint256(block.number) % SLOT_TABLE_SIZE);
        uint8 idx = _slotTable[slot];
        return (_activeProvers[idx], pool.feeInGwei);
    }

    /// @notice Get the maximum allowed bid fee at the current time.
    /// @return maxFee_ Maximum fee in Gwei that a bid can specify.
    function getMaxBidFee() public view returns (uint32 maxFee_) {
        PoolState memory pool = _pool;

        if (pool.poolSize != 0 && pool.vacantSince == 0) {
            unchecked {
                return uint32(uint256(pool.feeInGwei) * (10_000 - minFeeReductionBps) / 10_000);
            }
        }

        uint32 feeFloor;
        unchecked {
            uint256 movingAvgFee = uint256(_movingAverageFee) * movingAverageMultiplier;
            uint256 cappedMovingAvg = LibMath.min(movingAvgFee, type(uint32).max);
            feeFloor = uint32(LibMath.max(initialMaxFee, cappedMovingAvg));
        }

        uint32 baseFee;
        uint48 startTime;

        if (pool.everHadPool == 0) {
            baseFee = feeFloor;
            startTime = _contractCreationTime;
        } else {
            baseFee = uint32(LibMath.max(pool.feeInGwei, feeFloor));
            startTime = pool.vacantSince;
        }

        uint256 elapsed;
        uint256 periods;
        unchecked {
            elapsed = block.timestamp - startTime;
            periods = elapsed / feeDoublingPeriod;
            periods = LibMath.min(periods, uint256(maxFeeDoublings));
        }

        uint256 maxFee = uint256(baseFee) << periods;
        return uint32(LibMath.min(maxFee, type(uint32).max));
    }

    /// @notice Get bond information for an account.
    /// @param _account The account to query.
    /// @return bondInfo_ The bond information struct.
    function getBondInfo(address _account)
        external
        view
        returns (ProverAuctionTypes.BondInfo memory bondInfo_)
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

    function _requiredBondForJoin(uint8 joinOrder) internal view returns (uint128) {
        uint256 bps = 10_000 + uint256(joinOrder - 1) * JOIN_BOND_PREMIUM_BPS;
        return uint128(uint256(getRequiredBond()) * bps / 10_000);
    }

    function _weightForJoin(uint8 joinOrder) internal pure returns (uint16) {
        uint256 decay = uint256(joinOrder - 1) * WEIGHT_DECAY_BPS;
        if (decay >= 10_000) {
            return 1;
        }
        return uint16(10_000 - decay);
    }

    function _resetPool(address leader, uint32 fee) internal {
        _pool.feeInGwei = fee;
        _pool.poolSize = 1;
        _pool.vacantSince = 0;
        _pool.everHadPool = 1;

        _activeProvers[0] = leader;
        _members[leader] = PoolMember({
            index: 0,
            joinOrder: 1,
            weightBps: _weightForJoin(1),
            active: true
        });

        _rebuildSlotTable();
    }

    function _addToPool(address prover, uint8 joinOrder) internal {
        uint8 size = _pool.poolSize;
        _activeProvers[size] = prover;
        _members[prover] = PoolMember({
            index: size,
            joinOrder: joinOrder,
            weightBps: _weightForJoin(joinOrder),
            active: true
        });
        _pool.poolSize = size + 1;
        _rebuildSlotTable();
    }

    function _removeFromPool(address prover) internal {
        PoolMember storage member = _members[prover];
        if (!member.active) return;

        uint8 last = _pool.poolSize - 1;
        if (member.index != last) {
            address swapped = _activeProvers[last];
            _activeProvers[member.index] = swapped;
            _members[swapped].index = member.index;
        }

        _activeProvers[last] = address(0);
        member.active = false;
        _pool.poolSize = last;
        if (_pool.poolSize == 0) {
            _pool.vacantSince = uint48(block.timestamp);
        }

        _rebuildSlotTable();
    }

    function _clearPoolMembersToWithdrawable(address skip) internal {
        uint8 size = _pool.poolSize;
        if (size == 0) return;

        uint48 withdrawableAt;
        unchecked {
            withdrawableAt = uint48(block.timestamp) + bondWithdrawalDelay;
        }

        for (uint8 i = 0; i < size; i++) {
            address prover = _activeProvers[i];
            if (prover == address(0)) continue;
            _members[prover].active = false;
            if (prover != skip) {
                _bonds[prover].withdrawableAt = withdrawableAt;
            } else if (_bonds[prover].withdrawableAt != 0) {
                _bonds[prover].withdrawableAt = 0;
            }
            _activeProvers[i] = address(0);
        }

        _pool.poolSize = 0;
        _pool.vacantSince = uint48(block.timestamp);
    }

    function _rebuildSlotTable() internal {
        uint8 size = _pool.poolSize;
        if (size == 0) return;

        uint256 totalWeight = 0;
        for (uint8 i = 0; i < size; i++) {
            totalWeight += _members[_activeProvers[i]].weightBps;
        }

        uint16 assigned = 0;
        uint16[MAX_POOL_SIZE] memory slots;
        for (uint8 i = 0; i < size; i++) {
            uint16 weight = _members[_activeProvers[i]].weightBps;
            uint16 slotCount = uint16(uint256(SLOT_TABLE_SIZE) * weight / totalWeight);
            if (slotCount == 0) slotCount = 1;
            slots[i] = slotCount;
            assigned += slotCount;
        }

        while (assigned > SLOT_TABLE_SIZE) {
            for (uint8 i = 0; i < size && assigned > SLOT_TABLE_SIZE; i++) {
                if (slots[i] > 1) {
                    slots[i] -= 1;
                    assigned -= 1;
                }
            }
        }

        if (assigned < SLOT_TABLE_SIZE) {
            slots[0] += uint16(SLOT_TABLE_SIZE - assigned);
        }

        uint16 cursor = 0;
        for (uint8 i = 0; i < size; i++) {
            for (uint16 j = 0; j < slots[i]; j++) {
                _slotTable[cursor++] = i;
            }
        }
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
    error InsufficientBond();
    error InvalidMaxFeeDoublings();
    error InvalidBps();
    error OnlyInbox();
    error PoolFull();
    error NotInPool();
    error SelfBidTooFrequent();
    error WithdrawalDelayNotPassed();
    error ZeroAddress();
    error ZeroValue();
}
