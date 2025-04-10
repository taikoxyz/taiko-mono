// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/common/EssentialContract.sol";

interface IProverMarket { }

/// @title ProverMarket
/// @custom:security-contact security@taiko.xyz
abstract contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;

    event ProverAssigned(uint64 indexed batchId, address indexed prover, uint64 provingFee, uint32 numAssignments);
    event ProverChanged(
        address indexed prevProver,
        uint64 prevProvingFee,
        address indexed newProver,
        uint64 newProvingFee
    );

    error NoProverAvailable();
    error NotCurrentProver();
    error InvalidThresholds();
    error InsufficientDeposit();
    error NotEnoughAssignments();

    address public immutable feeToken;
    address public immutable inbox;
    uint256 public immutable biddingThreshold;
    uint256 public immutable provingThreshold;
    uint256 public immutable minAssignmentsBeforeExisting;

    address internal prover;
    uint64 internal provingFee;
    mapping(address account => uint256 deposit) internal deposits;
    uint32 internal nextAssignmentId;

    constructor(
        address _feeToken,
        address _inbox,
        uint256 _biddingThreshold,
        uint256 _provingThreshold,
        uint256 _minAssignmentsBeforeExisting
    )
        nonZeroAddr(_feeToken)
        nonZeroAddr(_inbox)
        nonZeroValue(_biddingThreshold)
        nonZeroValue(_provingThreshold)
    {
        require(_biddingThreshold > _provingThreshold, InvalidThresholds());
        feeToken = _feeToken;
        inbox = _inbox;
        biddingThreshold = _biddingThreshold;
        provingThreshold = _provingThreshold;
        minAssignmentsBeforeExisting = _minAssignmentsBeforeExisting;
    }

    function bid(uint64 _provingFee) external {
        require(deposits[msg.sender] >= biddingThreshold, InsufficientDeposit());
        _checkBiddingFee(_provingFee);
        emit ProverChanged(prover, provingFee, msg.sender, _provingFee);
        prover = msg.sender;
        provingFee = _provingFee;
        nextAssignmentId = 1;
    }

    function exit() external {
        require(msg.sender != prover, NotCurrentProver());
        require(nextAssignmentId > minAssignmentsBeforeExisting, NotEnoughAssignments());
        emit ProverChanged(prover, provingFee, address(0), 0);
        prover = address(0);
        provingFee = 0;
        nextAssignmentId = 1;
    }

    function assignProver(uint64 _batchId)
        external
        onlyFrom(inbox)
        returns (address prover_, uint64 provingFee_)
    {
        (prover_, provingFee_) = getCurrentProver();
        require(prover_ != address(0), NoProverAvailable());

        deposits[prover_] -= provingFee_;
        emit ProverAssigned(_batchId, prover_, provingFee_, nextAssignmentId++);
    }

    function getCurrentProver() public view returns (address, uint64) {
        address _prover = prover;
        if (_prover == address(0) || deposits[_prover] < provingThreshold) {
            return (address(0), 0);
        }

        return (_prover, provingFee);
    }

    function deposit(uint256 _amount) external {
        deposits[msg.sender] += _amount;
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender != prover, NotCurrentProver());
        deposits[msg.sender] -= _amount;
    }

    function _checkBiddingFee(uint64 _provingFee) internal virtual;
}
