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

    event ProverChanged(
        address indexed prevProver, uint64 prevFee, address indexed newProver, uint64 newFee
    );

    error InsufficientBondBalance();
    error InvalidBid();
    error InvalidThresholds();
    error NotCurrentProver();
    error TooEarly();

    ITaikoInbox public immutable inbox;
    uint256 public immutable biddingThreshold;
    uint256 public immutable provingThreshold;
    uint256 public immutable minExitDelay;
    address internal prover;
    uint64 internal fee;
    mapping(address account => uint256 exitTimestamp) internal exitTimestamps;

    modifier onlyCurrentProver() {
        require(msg.sender == prover, NotCurrentProver());
        _;
    }

    constructor(
        address _inbox,
        uint256 _biddingThreshold,
        uint256 _provingThreshold,
        uint256 _minExitDelay
    )
        nonZeroAddr(_inbox)
        nonZeroValue(_biddingThreshold)
        nonZeroValue(_provingThreshold)
        nonZeroValue(_minExitDelay)
        EssentialContract(address(0))
    {
        require(_biddingThreshold > _provingThreshold, InvalidThresholds());
        inbox = ITaikoInbox(_inbox);
        biddingThreshold = _biddingThreshold;
        provingThreshold = _provingThreshold;
        minExitDelay = _minExitDelay;
    }

    function bid(uint64 _fee) external {
        require(inbox.bondBalanceOf(msg.sender) >= biddingThreshold, InsufficientBondBalance());
        _checkBiddingFee(_fee);

        emit ProverChanged(prover, fee, msg.sender, _fee);

        prover = msg.sender;
        fee = _fee;
        exitTimestamps[msg.sender] = type(uint64).max;
    }

    function requestExit(uint256 _exitTimestamp) external onlyCurrentProver {
        require(_exitTimestamp >= block.timestamp + minExitDelay, TooEarly());
        exitTimestamps[msg.sender] = _exitTimestamp;
    }

    function getCurrentProver() public view returns (address, uint64) {
        address _prover = prover;
        if (
            _prover == address(0) // no bidding
                || block.timestamp >= exitTimestamps[_prover] // exited already
                || inbox.bondBalanceOf(_prover) < provingThreshold // not enough bond
        ) {
            return (address(0), 0);
        } else {
            return (_prover, fee);
        }
    }

    function _checkBiddingFee(uint64 _fee) internal virtual {
        (address currentProver, uint64 currentProvingFee) = getCurrentProver();
        if (currentProver != address(0)) {
            require(_fee < currentProvingFee * 9 / 10, InvalidBid());
        }
    }
}
