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

    event ProverChanged(address indexed prover, uint256 fee, uint256 exitTimestamp);

    error InsufficientBondBalance();
    error InvalidBid();
    error InvalidThresholds();
    error NotCurrentProver();
    error FeeNotDivisibleByFeeUnit();
    error FeeTooLarge();
    error TooEarly();

    uint256 public constant FEE_CHANGE_FACTOR = 32;
    uint16 public constant FEE_CHANGE_THRESHOLD = 16;
    uint256 public constant MAX_FEE_MULTIPLIER = 2;

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
    uint64 internal fee; // proving fee per batch

    /// @dev Slot 2
    uint64 internal avgFee; // moving average of fees
    uint16 internal assignmentCount; // number of assignments

    /// @dev Slot 3
    mapping(address account => uint256 exitTimestamp) internal exitTimestamps;

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
        uint256 _biddingThreshold, // = livenessBond * 2000
        uint256 _outbidThreshold, // = livenessBond * 1000
        uint256 _provingThreshold, // livenessBond * 100
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

    function bid(
        uint256 _fee,
        uint256 _exitTimestamp
    )
        external
        validExitTimestamp(_exitTimestamp)
    {
        require(_fee % (1 gwei) == 0, FeeNotDivisibleByFeeUnit());
        require(_fee <= getMaxFee(), FeeTooLarge());
        uint64 fee_ = uint64(_fee / (1 gwei));

        require(inbox.bondBalanceOf(msg.sender) >= biddingThreshold, InsufficientBondBalance());

        (address currentProver, uint64 currentFee, uint256 currentProverBalance) =
            _getCurrentProver();

        if (currentProver == address(0) || currentProverBalance < outbidThreshold) {
            // TODO(dani): ensure the new _fee cannot be too large right...
            // Using a moving average???
        } else {
            require(fee_ < currentFee * 9 / 10, InvalidBid());
        }

        prover = msg.sender;
        fee = fee_;
        exitTimestamps[msg.sender] = _exitTimestamp;
        assignmentCount = 0;

        emit ProverChanged(msg.sender, _fee, _exitTimestamp);
    }

    function requestExit(uint256 _exitTimestamp)
        external
        validExitTimestamp(_exitTimestamp)
        onlyCurrentProver
    {
        exitTimestamps[msg.sender] = _exitTimestamp;
        emit ProverChanged(msg.sender, 1 gwei * fee, _exitTimestamp);
    }

    /// @inheritdoc IProverMarket
    function getCurrentProver() public view returns (address, uint256) {
        (address currentProver, uint64 currentFee, uint256 currentProverBalance) =
            _getCurrentProver();
        return currentProverBalance < provingThreshold
            ? (address(0), 0)
            : (currentProver, 1 gwei * currentFee);
    }

    function onProverAssigned() external onlyFrom(address(inbox)) {
        if (assignmentCount > FEE_CHANGE_THRESHOLD) {
            return;
        }

        if (++assignmentCount == FEE_CHANGE_THRESHOLD) {
            uint64 _avgFee = avgFee;

            avgFee = _avgFee == 0
                ? fee
                : uint64((_avgFee * (FEE_CHANGE_FACTOR - 1) + fee) / FEE_CHANGE_FACTOR);
        }
    }

    function getMaxFee() public view returns (uint256) {
        uint256 _max = MAX_FEE_MULTIPLIER * avgFee;
        return _max.min(type(uint64).max) * 1 gwei;
    }

    function _getCurrentProver() public view returns (address, uint64, uint256) {
        address currentProver = prover;
        if (
            currentProver == address(0) // no bidding
                || block.timestamp >= exitTimestamps[currentProver] // exited already
        ) {
            return (address(0), 0, 0);
        } else {
            return (currentProver, fee, inbox.bondBalanceOf(currentProver));
        }
    }
}
