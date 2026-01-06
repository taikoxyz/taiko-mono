// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProverAuction } from "../iface/IProverAuction.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

import "./ProverAuction_Layout.sol"; // DO NOT DELETE

/// @title ProverAuction
/// @notice Single-prover auction.
/// @custom:security-contact security@taiko.xyz
contract ProverAuction is EssentialContract, IProverAuction {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Bond information for a prover.
    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }

    /// @notice Configuration parameters for the prover auction constructor.
    struct ConstructorConfig {
        address inbox;
        address bondToken;
        uint96 livenessBond;
        uint128 ejectionThreshold;
        uint16 minFeeReductionBps;
        uint16 rewardBps;
        uint48 bondWithdrawalDelay;
    }

    /// @notice Configuration parameters returned by getConfig().
    struct Config {
        address inbox;
        address bondToken;
        uint96 livenessBond;
        uint128 ejectionThreshold;
        uint128 requiredBond;
        uint16 minFeeReductionBps;
        uint16 rewardBps;
        uint48 bondWithdrawalDelay;
    }

    /// @dev Internal packed storage struct for prover state (31 bytes, fits in 1 slot).
    struct ProverState {
        address currentProver; // 20 bytes
        uint32 currentFeeInGwei; // 4 bytes
        uint48 vacantSince; // 6 bytes
        bool everHadProver; // 1 byte
    }


    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new bid is placed.
    /// @param newProver The address of the new prover.
    /// @param feeInGwei The new fee per proposal in Gwei.
    /// @param oldProver The address of the previous prover (address(0) if none).
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);

    /// @notice Emitted when a prover is ejected due to insufficient bond.
    /// @param prover The prover that was ejected.
    event ProverEjected(address indexed prover);

    /// @notice Emitted when bond tokens are deposited.
    /// @param account The account that deposited.
    /// @param amount The amount deposited.
    event Deposited(address indexed account, uint128 amount);

    /// @notice Emitted when bond tokens are withdrawn.
    /// @param account The account that withdrew.
    /// @param amount The amount withdrawn.
    event Withdrawn(address indexed account, uint128 amount);

    /// @notice Emitted when the current prover requests to exit.
    /// @param prover The prover that requested exit.
    /// @param withdrawableAt Timestamp when bond becomes withdrawable.
    event ExitRequested(address indexed prover, uint48 withdrawableAt);

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev The Inbox contract address (only caller for slashProver/checkBondDeferWithdrawal).
    address internal immutable _inbox;

    /// @dev The ERC20 token used for bonds (TAIKO token).
    IERC20 internal immutable _bondToken;

    /// @dev Minimum fee reduction in basis points to outbid (e.g., 500 = 5%).
    uint16 internal immutable _minFeeReductionBps;

    /// @dev Reward percentage in basis points for slashing (e.g., 6000 = 60%).
    uint16 internal immutable _rewardBps;

    /// @dev Time after exit before bond withdrawal is allowed.
    uint48 internal immutable _bondWithdrawalDelay;

    /// @dev Bond amount slashed per failed proof.
    uint96 internal immutable _livenessBond;

    /// @dev Pre-computed required bond amount (ejectionThreshold * 2).
    uint128 internal immutable _requiredBond;

    /// @dev Bond threshold that triggers ejection.
    uint128 internal immutable _ejectionThreshold;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    // Slot 251: packed prover state (31 bytes used)
    ProverState public proverState;

    // Slot 252: totalSlashedAmount (16 bytes used)
    uint256 public totalSlashedAmount;

    // Slot 253: mapping (uses separate slots via hashing)
    mapping(address account => BondInfo info) internal _bonds;

    uint256[47] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @param _config Configuration struct containing all constructor parameters.
    constructor(ConstructorConfig memory _config) {
        require(_config.inbox != address(0), ZeroAddress());
        require(_config.bondToken != address(0), ZeroAddress());
        require(_config.livenessBond > 0, ZeroValue());
        require(_config.ejectionThreshold > _config.livenessBond, InvalidEjectionThreshold());
        require(_config.minFeeReductionBps <= 10_000, InvalidBps());
        require(_config.rewardBps <= 10_000, InvalidBps());

        _inbox = _config.inbox;
        _bondToken = IERC20(_config.bondToken);
        _livenessBond = _config.livenessBond;
        _ejectionThreshold = _config.ejectionThreshold;
        _requiredBond = _config.ejectionThreshold * 2;
        _minFeeReductionBps = _config.minFeeReductionBps;
        _rewardBps = _config.rewardBps;
        _bondWithdrawalDelay = _config.bondWithdrawalDelay;
    }

    // ---------------------------------------------------------------
    // Initializer Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract (for upgradeable proxy pattern).
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

    /// @notice Deposits bond tokens into the auction.
    /// @param _amount The amount of tokens to deposit.
    function deposit(uint128 _amount) external nonReentrant {
        BondInfo storage info = _bonds[msg.sender];
        info.balance += _amount;
        _bondToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposited(msg.sender, _amount);
    }

    /// @notice Withdraws bond tokens after withdrawal delay has passed.
    function withdraw() external nonReentrant {
        BondInfo memory info = _bonds[msg.sender]; // Single SLOAD for packed slot

        if (info.withdrawableAt == 0) {
            require(proverState.currentProver != msg.sender, CurrentProverCannotWithdraw());
        } else {
            require(block.timestamp >= info.withdrawableAt, WithdrawalDelayNotPassed());
        }

        require(info.balance > 0, InsufficientBond());

        _bonds[msg.sender] = BondInfo(0,0);
        _bondToken.safeTransfer(msg.sender, info.balance);
        emit Withdrawn(msg.sender, info.balance);
    }

    /// @notice Places a bid to become the designated prover.
    /// @param _feeInGwei The fee per proposal in Gwei (must be > 0).
    function bid(uint32 _feeInGwei) external nonReentrant {
        require(_feeInGwei != 0, ZeroFee());

        BondInfo memory info = _bonds[msg.sender]; // Single SLOAD for packed slot
        require(info.balance >= _requiredBond, InsufficientBond());

        ProverState memory state = proverState; // Single SLOAD for packed slot
        address oldProver = state.currentProver;

        if (oldProver != address(0)) {
            // Slot occupied - must meet minimum fee reduction
            uint32 maxAllowedFee =
                uint32(uint256(state.currentFeeInGwei) * (10_000 - _minFeeReductionBps) / 10_000);
            require(_feeInGwei <= maxAllowedFee, FeeTooHigh());

            if (oldProver != msg.sender) {
                // Outbidding another prover - set their withdrawal delay
                _bonds[oldProver].withdrawableAt = _withdrawableAt();
            }
        }
        // else: vacant slot - any fee is accepted

        // Clear new prover's withdrawal delay if set
        if (info.withdrawableAt != 0) {
            _bonds[msg.sender].withdrawableAt = 0;
        }

        _setProver(msg.sender, _feeInGwei);
        emit BidPlaced(msg.sender, _feeInGwei, oldProver);
    }

    /// @notice Requests to exit as the current prover.
    function requestExit() external nonReentrant {
        require(proverState.currentProver == msg.sender, NotCurrentProver());

        uint48 withdrawableAt = _withdrawableAt();
        _bonds[msg.sender].withdrawableAt = withdrawableAt;
        _vacateProver();

        emit ExitRequested(msg.sender, withdrawableAt);
    }

    /// @inheritdoc IProverAuction
    function slashProver(address _proverAddr, address _recipient) external nonReentrant {
        unchecked{
        require(msg.sender == _inbox, OnlyInbox());

        BondInfo memory bond = _bonds[_proverAddr]; // Single SLOAD for packed slot

        uint128 actualSlash = uint128(LibMath.min(_livenessBond, bond.balance));
        uint128 actualReward;
        if (_recipient != address(0)) {
            actualReward = uint128(uint256(actualSlash) * _rewardBps / 10_000);
        }

        uint128 newBalance = bond.balance - actualSlash;
        totalSlashedAmount += actualSlash - actualReward;

        if (actualReward > 0) {
            _bondToken.safeTransfer(_recipient, actualReward);
        }

        emit ProverSlashed(_proverAddr, actualSlash, _recipient, actualReward);

        if (newBalance < _ejectionThreshold && proverState.currentProver == _proverAddr) {
            _bonds[_proverAddr] = BondInfo(newBalance, _withdrawableAt());
            _vacateProver();
            emit ProverEjected(_proverAddr);
        } else {
            _bonds[_proverAddr].balance = newBalance;
        }
    }}

    /// @inheritdoc IProverAuction
    function checkBondDeferWithdrawal(address _prover) external nonReentrant returns (bool success_) {
        require(msg.sender == _inbox, OnlyInbox());

        BondInfo memory bond = _bonds[_prover]; // Single SLOAD for packed slot
        if (bond.balance < _ejectionThreshold) {
            return false;
        }

        if (proverState.currentProver != _prover || bond.withdrawableAt != 0) {
            _bonds[_prover].withdrawableAt = _withdrawableAt();
        }

        return true;
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProverAuction
    function getProver(uint32 _maxFeeInGwei)
        external
        view
        returns (address prover_, uint32 feeInGwei_)
    {
        ProverState memory state = proverState;
        if (state.currentProver == address(0)) {
            return (address(0), 0);
        }
        if (state.currentFeeInGwei > _maxFeeInGwei) {
            return (address(0), 0);
        }
        return (state.currentProver, state.currentFeeInGwei);
    }

    /// @notice Get the configuration parameters (immutables).
    /// @return config_ The configuration struct.
    function getConfig() external view returns (Config memory config_) {
        config_ = Config({
            inbox: _inbox,
            bondToken: address(_bondToken),
            livenessBond: _livenessBond,
            ejectionThreshold: _ejectionThreshold,
            requiredBond: _requiredBond,
            minFeeReductionBps: _minFeeReductionBps,
            rewardBps: _rewardBps,
            bondWithdrawalDelay: _bondWithdrawalDelay
        });
    }

    /// @notice Get bond information for an account.
    /// @param _account The account to query.
    /// @return bondInfo_ The bond information struct.
    function bondInfo(address _account) external view returns (BondInfo memory bondInfo_) {
        return _bonds[_account];
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Sets the current prover and fee.
    /// @param _prover The prover address.
    /// @param _feeInGwei The fee per proposal in Gwei.
    function _setProver(address _prover, uint32 _feeInGwei) internal {
        proverState = ProverState({
            currentProver: _prover,
            currentFeeInGwei: _feeInGwei,
            vacantSince: 0,
            everHadProver: true
        });
    }

    /// @dev Vacates the current prover slot.
    function _vacateProver() internal {
        proverState.currentProver = address(0);
        proverState.vacantSince = uint48(block.timestamp);
    }

    /// @dev Returns the timestamp when withdrawals become available.
    function _withdrawableAt() internal view returns (uint48) {
        unchecked{
        return uint48(block.timestamp + _bondWithdrawalDelay);
    }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error CurrentProverCannotWithdraw();
    error FeeTooHigh();
    error InsufficientBond();
    error InvalidBps();
    error InvalidEjectionThreshold();
    error NotCurrentProver();
    error OnlyInbox();
    error WithdrawalDelayNotPassed();
    error ZeroAddress();
    error ZeroFee();
    error ZeroValue();
}
