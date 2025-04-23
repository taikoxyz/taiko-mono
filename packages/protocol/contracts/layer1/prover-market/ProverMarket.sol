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
    error FeeLargerThanAllowed();
    error FeeNotDivisibleByFeeUnit();
    error InsufficientBondBalance();
    error InvalidThresholds();
    error NotCurrentProver();
    error TooEarly();

    uint256 public constant NEW_BID_PERCENTAGE = 95;
    uint256 internal constant GWEI = 10 ** 9;

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
    mapping(address account => Prover prover) public provers;

    /// @dev Slot 2
    address internal prover;
    uint64 internal feeInGwei; // proving fee per batch

    uint256[48] private __gap;

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

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function bid(uint256 _fee, uint64 _exitTimestamp) external validExitTimestamp(_exitTimestamp) {
        require(_fee > 0 && _fee % GWEI == 0, FeeNotDivisibleByFeeUnit());
        require(_fee / GWEI <= type(uint64).max, CannotFitToUint64());

        uint64 _newFeeInGwei = uint64(_fee / GWEI);

        require(inbox.v4BondBalanceOf(msg.sender) >= biddingThreshold, InsufficientBondBalance());

        (address currentProver, uint64 currentFeeInGwei) = _getCurrentProverAndFeeInGwei();

        // If there is no prover, the new prover can set any fee.
        if (currentProver != address(0)) {
            uint256 maxFeeInGwei;

            if (inbox.v4BondBalanceOf(currentProver) < outbidThreshold) {
                // The current prover has less than outbidThreshold, so the new prover can set any
                // fee as long as it's not larger than the current fee
                maxFeeInGwei = currentFeeInGwei;
            } else {
                // The current prover has more than outbidThreshold, so the new prover can set any
                // fee as long as it's not larger than 95% of the current fee
                maxFeeInGwei = currentFeeInGwei * NEW_BID_PERCENTAGE / 100;
            }

            require(_newFeeInGwei <= maxFeeInGwei, FeeLargerThanAllowed());
        }

        prover = msg.sender;
        feeInGwei = _newFeeInGwei;
        provers[msg.sender].exitTimestamp = _exitTimestamp;

        emit ProverChanged(msg.sender, _fee, _exitTimestamp);
    }

    function requestExit(uint64 _exitTimestamp) external validExitTimestamp(_exitTimestamp) {
        (address currentProver, uint64 currentFeeInGwei) = _getCurrentProverAndFeeInGwei();

        require(currentProver != address(0) && msg.sender == currentProver, NotCurrentProver());

        provers[msg.sender].exitTimestamp = _exitTimestamp;
        emit ProverChanged(msg.sender, currentFeeInGwei * GWEI, _exitTimestamp);
    }

    /// @inheritdoc IProverMarket
    function getCurrentProver() public view returns (address, uint256) {
        (address currentProver, uint64 currentFeeInGwei) = _getCurrentProverAndFeeInGwei();
        return
            currentProver == address(0) ? (address(0), 0) : (currentProver, currentFeeInGwei * GWEI);
    }

    function _getCurrentProverAndFeeInGwei() internal view returns (address, uint64) {
        address currentProver = prover;
        if (
            currentProver == address(0) // no bidding
                || block.timestamp >= provers[currentProver].exitTimestamp // exited already
                || inbox.v4BondBalanceOf(currentProver) < provingThreshold // not eligible
        ) {
            return (address(0), 0);
        } else {
            return (currentProver, feeInGwei);
        }
    }
}
