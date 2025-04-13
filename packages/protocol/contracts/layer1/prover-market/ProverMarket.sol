// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "./IProverMarket.sol";

/// @title ProverMarket
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;

    event ProverChanged(address indexed prover, uint256 fee, uint256 exitTimestamp);

    error InsufficientBondBalance();
    error InvalidBid();
    error InvalidThresholds();
    error NotCurrentProver();
    error FeeNotDivisibleByFeeUnit();
    error FeeBiggerThanMax();
    error FeeTooLarge();
    error TooEarly();

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
    /// @dev The unit of fee to make sure fee can fit into uint64
    uint256 public immutable feeUnit;

    /// @dev Slot 1
    address internal prover;
    uint64 internal fee; // proving fee per batch

    /// @dev Slot 2
    mapping(address account => uint256 exitTimestamp) internal exitTimestamps;

    uint256[48] private __gap;

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
        require(_fee % feeUnit == 0, FeeNotDivisibleByFeeUnit());
        require(_fee / feeUnit <= type(uint64).max, FeeTooLarge());

        uint256 maxFee = getMaxFee();
        require(maxFee == 0 || _fee <= maxFee, FeeBiggerThanMax());
        uint64 fee_ = uint64(_fee / feeUnit);

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

        emit ProverChanged(msg.sender, _fee, _exitTimestamp);
    }

    function requestExit(uint256 _exitTimestamp)
        external
        validExitTimestamp(_exitTimestamp)
        onlyCurrentProver
    {
        exitTimestamps[msg.sender] = _exitTimestamp;
        emit ProverChanged(msg.sender, feeUnit * fee, _exitTimestamp);
    }

    /// @inheritdoc IProverMarket
    function getCurrentProver() public view returns (address, uint256) {
        (address currentProver, uint64 currentFee, uint256 currentProverBalance) =
            _getCurrentProver();
        return currentProverBalance < provingThreshold
            ? (address(0), 0)
            : (currentProver, feeUnit * currentFee);
    }

    /// @dev The maximum fee that can be used by provers to bid.
    /// The current implementation returns a 5 times of the average fee.
    function getMaxFee() public view returns (uint256) {
        return 5 gwei * inbox.getStats1().avgProverMarketFee;
    }

    function _getCurrentProver() internal view returns (address, uint64, uint256) {
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
