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
    uint256 public immutable minExitDelay;
    uint256 private feeHistory; // Packed storage for last 4 fees
    address internal prover;
    /// @dev If there are no fees yet (new deployment), just use it until someone bids.
    uint64 public immutable firstFee;
    uint64 internal fee; // proving fee per batch
    uint8 private feeCount; // Number of fees recorded (max 4)
    mapping(address account => uint256 exitTimestamp) internal exitTimestamps;
    /// @notice Gap for upgrade safety
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
        uint256 _minExitDelay,
        uint64 _firstFee
    )
        nonZeroAddr(_inbox)
        nonZeroValue(_minExitDelay)
        EssentialContract(address(0))
    {
        require(_biddingThreshold > _outbidThreshold, InvalidThresholds());
        require(_outbidThreshold > _provingThreshold, InvalidThresholds());
        require(_provingThreshold > 0, InvalidThresholds());
        require(_firstFee > 0, InvalidThresholds());

        inbox = ITaikoInbox(_inbox);

        biddingThreshold = _biddingThreshold;
        outbidThreshold = _outbidThreshold;
        provingThreshold = _provingThreshold;
        firstFee = _firstFee;

        minExitDelay = _minExitDelay;
    }

    function bid(uint64 _fee, uint256 _exitTimestamp) external validExitTimestamp(_exitTimestamp) {
        require(inbox.bondBalanceOf(msg.sender) >= biddingThreshold, InsufficientBondBalance());

        (address currentProver, uint64 currentFee, uint256 currentProverBalance) =
            _getCurrentProver();

        if (currentProver == address(0) || currentProverBalance < outbidThreshold) {
            require(uint256(_fee) <= uint256(_getMaxFeeTreshold()), InvalidBid());
        } else {
            require(_fee < currentFee * 9 / 10, InvalidBid());
        }

        prover = msg.sender;
        fee = _fee;
        exitTimestamps[msg.sender] = _exitTimestamp;

        _updateFeeHistory(_fee);

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

    function _getMaxFeeTreshold() internal view returns (uint256) {
        if (feeCount == 0) {
            return firstFee;
        }
        
        uint256 sum = 0;
        uint256 mask = uint256(type(uint64).max);
        
        for (uint8 i = 0; i < feeCount; i++) {
            uint256 shiftedMask = mask << (i * 64);
            uint256 currentFee = (feeHistory & shiftedMask) >> (i * 64);
            sum += currentFee;
        }
        
        // add 10% margin to the average
        return (sum / feeCount) * 110 / 100;
    }

    function _updateFeeHistory(uint64 _newFee) private {
        // shift existing fees to the left (discard oldest)
        feeHistory = feeCount < 4 
            ? feeHistory 
            : (feeHistory << 64);
        
        // _newfee always placed in the rightmost position
        feeHistory = (feeHistory & ~uint256(type(uint64).max)) | uint256(_newFee);
        
        // feeCount max 4 (4 x 8 bytes = 32 bytes)
        feeCount = feeCount < 4 ? feeCount + 1 : 4;
    }
}
