// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/based/ITaikoInbox.sol";

/// @title IProverMarket
/// @custom:security-contact security@taiko.xyz
interface IProverMarket {
    function getCurrentProver() external view returns (address, uint64);
}

/// @title ProverMarket
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;

    event ProverChanged(address indexed prover, uint64 fee, uint256 exitTimestamp);

    error InsufficientBondBalance();
    error InvalidBid();
    error InvalidThresholds();
    error NotCurrentProver();
    error TooEarly();

    ITaikoInbox public immutable inbox;
    /// @dev The minimal token balance of the new prover
    /// @dev The minimum token balance required to place a bid and become the current prover.
    uint256 public immutable biddingThreshold;
    /// @dev The minimum token balance of the current prover below which they can be outbid by a higher bid.
    uint256 public immutable outbidThreshold;
    /// @dev The minimum token balance required for the current prover to maintain their status.
    uint256 public immutable provingThreshold;
    uint256 public immutable minExitDelay;
    address internal prover;
    uint64 internal fee; // proving fee per batch
    mapping(address account => uint256 exitTimestamp) internal exitTimestamps;

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

    function bid(uint64 _fee, uint256 _exitTimestamp) external validExitTimestamp(_exitTimestamp) {
        require(inbox.bondBalanceOf(msg.sender) >= biddingThreshold, InsufficientBondBalance());

        (address currentProver, uint64 currentFee, uint256 currentProverBalance) =
            _getCurrentProver();

        if (currentProver == address(0) || currentProverBalance < outbidThreshold) {
            // TODO(dani): ensure the new _fee cannot be too large right...
            // Using a moving average???
        } else {
            require(_fee < currentFee * 9 / 10, InvalidBid());
        }

        prover = msg.sender;
        fee = _fee;
        exitTimestamps[msg.sender] = _exitTimestamp;

        emit ProverChanged(msg.sender, _fee, _exitTimestamp);
    }

    function requestExit(uint256 _exitTimestamp)
        external
        validExitTimestamp(_exitTimestamp)
        onlyCurrentProver
    {
        exitTimestamps[msg.sender] = _exitTimestamp;
        emit ProverChanged(msg.sender, fee, _exitTimestamp);
    }

    function getCurrentProver() public view returns (address, uint64) {
        (address currentProver, uint64 currentFee, uint256 currentBalance) = _getCurrentProver();
        return currentBalance < provingThreshold // balance too low
            ? (address(0), 0)
            : (currentProver, currentFee);
    }

    function _getCurrentProver() public view returns (address, uint64, uint256) {
        address _prover = prover;
        if (
            _prover == address(0) // no bidding
                || block.timestamp >= exitTimestamps[_prover] // exited already
                // || inbox.bondBalanceOf(_prover) < provingThreshold // not enough bond
        ) {
            return (address(0), 0, 0);
        } else {
            return (_prover, fee, inbox.bondBalanceOf(_prover));
        }
    }
}
