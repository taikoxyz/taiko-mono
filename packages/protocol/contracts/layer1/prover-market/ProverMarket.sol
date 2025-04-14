// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibMath.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "./IProverMarket.sol";

/// @title ProverMarket
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;
    using LibMath for uint256;

    error CannotFitToUint64();
    error FeeLargerThanCurrent();
    error FeeLargerThanMax();
    error FeeLargerTooLarge();
    error FeeNotDivisibleByFeeUnit();
    error FeeTooLarge();
    error InsufficientBondBalance();
    error InvalidThresholds();
    error NotCurrentProver();
    error TooEarly();

    uint256 public constant FEE_CHANGE_FACTOR = 100;
    uint16 public constant FEE_CHANGE_THRESHOLD = 10;
    uint256 public constant MAX_FEE_MULTIPLIER = 2;
    uint256 public constant NEW_BID_PERCENTAGE = 95;

    struct Prover {
        uint64 exitTimestamp;
    }

    ITaikoInbox public immutable inbox;
    /// @dev If a prover’s available bond balance is below this threshold, they are not eligible
    /// to participate in the bidding process.
    uint256 public immutable biddingThreshold;
    /// @dev If the current prover’s bond balance falls below this value, they can be outbid by
    /// another prover even if the new bid offers the same proving fee or only a slightly higher one
    /// (e.g., 1.01× or 1.05× the current fee).
    uint256 public immutable outbidThreshold;
    /// @dev If the current prover’s bond balance drops below this threshold, they are considered
    /// disqualified (evicted), and the active prover is reset to address(0).
    uint256 public immutable provingThreshold;
    /// @dev The minimum delay required before a prover can exit the prover market.
    uint256 public immutable minExitDelay;

    /// @dev Slot 1
    address internal prover;
    uint64 internal fee; // proving fee per batch in gwei

    /// @dev Slot 2
    uint64 public avgFee; // moving average of fees in gwei
    uint16 internal assignmentCount; // number of assignments

    /// @dev Slot 3
    mapping(address account => Prover prover) public provers;

    uint256[47] private __gap;

    modifier onlyCurrentProver() {
        require(msg.sender == prover, NotCurrentProver());
        _;
    }

    modifier validExitTimestamp(uint256 _exitTimestamp) {
        require(_exitTimestamp >= block.timestamp + minExitDelay, TooEarly());
        _;
    }

    constructor(
        address _inbox,
        uint256 _biddingThreshold,
        uint256 _outbidThreshold,
        uint256 _provingThreshold,
        uint256 _minExitDelay
    )
        nonZeroAddr(_inbox)
        nonZeroValue(_minExitDelay)
        EssentialContract(address(0))
    {
        require(_biddingThreshold > _outbidThreshold, InvalidThresholds());
        require(_outbidThreshold > _provingThreshold, InvalidThresholds());
        require(_provingThreshold > 0, InvalidThresholds());

        inbox = ITaikoInbox(_inbox);

        biddingThreshold = _biddingThreshold;
        outbidThreshold = _outbidThreshold;
        provingThreshold = _provingThreshold;
        minExitDelay = _minExitDelay;
    }

    function bid(uint256 _fee, uint64 _exitTimestamp) external validExitTimestamp(_exitTimestamp) {
        require(_fee % (1 gwei) == 0, FeeNotDivisibleByFeeUnit());
        require(_fee / (1 gwei) <= type(uint64).max, CannotFitToUint64());
        uint64 feeInGwei = uint64(_fee / (1 gwei));

        require(inbox.bondBalanceOf(msg.sender) >= biddingThreshold, InsufficientBondBalance());

        (address prover_, uint64 feeInGwei_) = _getCurrentProver();

        if (prover_ == address(0)) {
            // There is no prover, so the new prover can set any fee as long as it's not larger than
            // the max allowed
            uint256 _max = getMaxFee();
            require(_max == 0 || _fee <= _max, FeeLargerThanMax());
        } else if (inbox.bondBalanceOf(prover_) < outbidThreshold) {
            // The current prover has less than outbidThreshold, so the new prover can set any
            // fee
            // as long as it's not larger than the current fee
            require(feeInGwei <= feeInGwei_, FeeLargerThanCurrent());
        } else {
            // The current prover has more than outbidThreshold, so the new prover can set any
            // fee
            // as long as it's not larger than 90% of the current fee
            require(feeInGwei <= feeInGwei_ * NEW_BID_PERCENTAGE / 100, FeeLargerTooLarge());
        }

        prover = msg.sender;
        fee = feeInGwei;
        provers[msg.sender].exitTimestamp = _exitTimestamp;
        assignmentCount = 0;

        emit ProverChanged(msg.sender, _fee, _exitTimestamp);
    }

    function requestExit(uint64 _exitTimestamp)
        external
        validExitTimestamp(_exitTimestamp)
        onlyCurrentProver
    {
        provers[msg.sender].exitTimestamp = _exitTimestamp;
        emit ProverChanged(msg.sender, 1 gwei * fee, _exitTimestamp);
    }

    /// @inheritdoc IProverMarket
    function getCurrentProver() public view returns (address prover_, uint256 fee_) {
        (prover_, fee_) = _getCurrentProver();

        if (prover_ != address(0)) {
            if (inbox.bondBalanceOf(prover_) < provingThreshold) {
                (prover_, fee_) = (address(0), 0);
            } else {
                fee_ *= 1 gwei;
            }
        }
    }

    /// @inheritdoc IProverMarket
    function onProverAssigned(
        address, /*_prover*/
        uint256 _fee,
        uint64 _batchId
    )
        external
        onlyFrom(address(inbox))
    {
        emit ProverAssigned(msg.sender, _fee, _batchId);
        if (assignmentCount > FEE_CHANGE_THRESHOLD) {
            // No need to update assignmentCount nor avgFee
            return;
        }

        if (++assignmentCount <= FEE_CHANGE_THRESHOLD) {
            uint64 _avgFee = avgFee;
            uint64 feeInGwei = uint64(_fee / 1 gwei);

            unchecked {
                avgFee = _avgFee == 0
                    ? feeInGwei
                    : uint64(((FEE_CHANGE_FACTOR - 1) * _avgFee + feeInGwei) / FEE_CHANGE_FACTOR);
            }
        }
    }

    function getMaxFee() public view returns (uint256) {
        uint256 _max = MAX_FEE_MULTIPLIER * avgFee;
        return _max.min(type(uint64).max) * 1 gwei;
    }

    function _getCurrentProver() public view returns (address, uint64) {
        address _prover = prover;
        if (
            _prover == address(0) // no bidding
                || block.timestamp >= provers[_prover].exitTimestamp // exited already
        ) {
            return (address(0), 0);
        } else {
            return (_prover, fee);
        }
    }
}
