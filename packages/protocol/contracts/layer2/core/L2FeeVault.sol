// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

import "./IL2FeeVault.sol";
import "./L2FeeVault_Layout.sol"; // DO NOT DELETE

/// @title L2FeeVault
/// @notice Collects L2 basefees and reimburses L1 proposal costs based on canonical L1 data.
///
/// @dev ## Overview
/// This vault acts as the financial settlement layer between L2 fee revenue and L1 cost
/// reimbursements to proposers. It maintains solvency through a dynamic fee adjustment mechanism.
///
/// ## Balance Sheet Model
/// The vault uses simple accounting:
/// - **Assets**: ETH balance in the contract (accumulated from L2 basefee revenue)
/// - **Liabilities**: Total unpaid reimbursements owed to proposers (`totalLiabilities`)
/// - **Effective Balance**: Assets - Liabilities (the vault's true solvency position)
///
/// ## Fee Adjustment Mechanism (P Controller)
/// The vault exposes `feePerGasWei`, which L2 clients read as the L1-cost component of the L2
/// basefee. The adjustment rule is simple:
///
/// 1. **Deficit Detection**: If `effective balance < targetBalanceWei`, the vault is underfunded.
///    The fee increases proportionally to accumulate more revenue from future L2 transactions.
///
/// 2. **At/Above Target**: If `effective balance >= targetBalanceWei`, the proportional term
///    becomes zero and final bounds are applied via clamping.
///
/// Terms used in this controller:
/// - `epsilon`: deficit ratio (`(targetBalanceWei - effectiveBalance) / targetBalanceWei`)
/// - `Kp`: how aggressively fee reacts to deficits (`kpWad = Kp * 1e18`)
/// - `pTerm`: proportional output before min/max bounds
///
/// The adjustment formula:
/// ```
/// epsilon = max(0, (targetBalanceWei - effectiveBalance) / targetBalanceWei)
/// pTerm = Kp * epsilon * (maxFeePerGasWei - minFeePerGasWei)
/// newFee = clamp(pTerm, minFeePerGasWei, maxFeePerGasWei)
/// ```
///
/// Example (`Kp = 5`, i.e. `kpWad = 5e18`, `minFeePerGasWei = 0`,
/// `maxFeePerGasWei = 1 gwei`):
/// - At 0% deficit (`epsilon = 0`): fee is 0 gwei
/// - At 5% deficit (`epsilon = 0.05`): fee is 0.25 gwei
/// - At 10% deficit (`epsilon = 0.10`): fee is 0.5 gwei
/// - At 20% deficit (`epsilon = 0.20`): fee is 1.0 gwei (reaches max)
/// - At >=20% deficit: fee stays clamped at 1.0 gwei
///
/// ## Reimbursement Policy
/// When proposals are imported:
/// - **Profitable proposals** (L2 revenue ≥ L1 cost): Proposer gets 100% of L1 cost reimbursed
/// - **Loss-making proposals** (L2 revenue < L1 cost): Proposer gets only `lossReimbursementBps`%
///   of L1 cost, protecting the vault from unlimited losses during low-activity periods or proposers
///   who intentionally post unprofitable proposals.
///
/// ## Trust Assumptions
/// The fee data imported via `importProposalFeeList` must be validated by the validity proof.
/// The proof should verify:
/// 1) `hashProposal(proposal)` matches the proposal hash stored in the L1 Inbox ring buffer
///    for the given proposalId (cost fields are part of the Proposal struct), and
/// 2) L2 basefee revenue for the proposal's blocks.
/// The vault itself does not validate proofs on-chain.
///
/// @custom:security-contact security@taiko.xyz
contract L2FeeVault is EssentialContract, IL2FeeVault {
    using LibAddress for address;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Blob gas per blob (EIP-4844).
    uint256 public constant BLOB_GAS_PER_BLOB = 131_072;

    /// @dev Basis points denominator.
    uint256 private constant _BPS = 10_000;

    /// @dev WAD precision used for controller math.
    uint256 private constant _WAD = 1e18;

    // ---------------------------------------------------------------
    // Immutables
    // ---------------------------------------------------------------

    /// @notice Target effective balance (balance - liabilities) the vault aims to maintain.
    /// @dev Acts as a solvency buffer. The fee adjustment mechanism drives effective balance toward
    ///      this target. Higher target = more conservative but requires higher fees to maintain.
    uint256 public immutable targetBalanceWei;

    /// @notice Minimum allowed value for `feePerGasWei` (floor).
    uint256 public immutable minFeePerGasWei;

    /// @notice Maximum allowed value for `feePerGasWei` (ceiling).
    uint256 public immutable maxFeePerGasWei;

    /// @notice Percentage of L1 cost reimbursed when a proposal is unprofitable (L2 revenue < L1 cost).
    /// @dev In basis points. 10000 = 100%. Protects the vault from unbounded losses during low activity.
    uint16 public immutable lossReimbursementBps;

    /// @notice Proportional gain (Kp) for the fee controller, scaled by 1e18.
    /// @dev Higher values increase how aggressively fees react when the vault is below target.
    uint256 public immutable kpWad;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Anchor contract authorized to call `importProposalFeeList`.
    address public anchor;

    /// @notice Sum of all unpaid reimbursements owed to proposers (the vault's liabilities).
    /// @dev This is subtracted from ETH balance to compute the effective balance for fee adjustment.
    uint256 public totalLiabilities;

    /// @notice Mapping of proposer address to their claimable reimbursement amount.
    mapping(address proposer => uint256 amount) public claimable;

    /// @notice The L1-cost fee component per gas, read by L2 clients to set basefee.
    /// @dev This is the primary output of the balancing mechanism. When the vault has a deficit,
    ///      this value increases to collect more revenue, subject to configured min/max bounds.
    uint256 public feePerGasWei;

    /// @notice Storage gap for upgrade safety.
    uint256[51] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event AnchorUpdated(address anchor);
    event FeePerGasUpdated(uint256 feePerGasWei);
    event ProposalFeesImported(
        uint48 indexed proposalId,
        address indexed proposer,
        uint256 l1CostWei,
        uint256 l2RevenueWei,
        uint256 reimbursedWei
    );
    event Claimed(address indexed proposer, address indexed to, uint256 amount);

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    modifier onlyAnchor() {
        require(msg.sender == anchor, ACCESS_DENIED());
        _;
    }

    // ---------------------------------------------------------------
    // Constructor / Initializer
    // ---------------------------------------------------------------

    /// @notice Initializes the L2FeeVault contract.
    /// @param _targetBalanceWei The target effective balance to maintain.
    /// @param _minFeePerGasWei The minimum fee per gas (floor).
    /// @param _maxFeePerGasWei The maximum fee per gas (ceiling).
    /// @param _lossReimbursementBps The percentage of L1 cost reimbursed for unprofitable proposals.
    /// @param _kpWad The P-controller gain (Kp) scaled by 1e18.
    constructor(
        uint256 _targetBalanceWei,
        uint256 _minFeePerGasWei,
        uint256 _maxFeePerGasWei,
        uint16 _lossReimbursementBps,
        uint256 _kpWad
    ) {
        // Validate configuration parameters
        require(_lossReimbursementBps <= _BPS, InvalidBps());
        require(_minFeePerGasWei <= _maxFeePerGasWei, InvalidBounds());

        // Assign immutables
        targetBalanceWei = _targetBalanceWei;
        minFeePerGasWei = _minFeePerGasWei;
        maxFeePerGasWei = _maxFeePerGasWei;
        lossReimbursementBps = _lossReimbursementBps;
        kpWad = _kpWad;

        _disableInitializers();
    }

    /// @notice Initializes the fee vault.
    /// @param _owner The owner of the contract.
    /// @param _anchor The anchor contract allowed to import fee data.
    function init(address _owner, address _anchor) external initializer {
        __Essential_init(_owner);
        _setAnchor(_anchor);
        feePerGasWei = minFeePerGasWei;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IL2FeeVault
    function importProposalFeeList(ProposalFeeData[] calldata _fees) external onlyAnchor {
        uint256 feesLength = _fees.length;
        if (feesLength == 0) return;

        for (uint256 i; i < feesLength; ++i) {
            ProposalFeeData calldata feeData = _fees[i];
            uint256 l1CostWei = _calcL1Cost(feeData);
            uint256 reimbursedWei = _calcReimbursement(l1CostWei, feeData.l2BasefeeRevenue);

            claimable[feeData.proposer] += reimbursedWei;
            totalLiabilities += reimbursedWei;

            emit ProposalFeesImported(
                feeData.proposalId,
                feeData.proposer,
                l1CostWei,
                feeData.l2BasefeeRevenue,
                reimbursedWei
            );
        }

        _updateFeePerGas();
    }

    /// @notice Accepts ETH transfers (L2 basefee revenue flows in here).
    receive() external payable { }

    /// @notice Allows proposers to withdraw their accrued reimbursements.
    /// @param _to Destination address for the withdrawal.
    /// @param _amount Amount to claim in wei. Pass 0 to claim the full available balance.
    function claim(address _to, uint256 _amount) external nonReentrant {
        require(_to != address(0), InvalidAddress());
        uint256 available = claimable[msg.sender];
        uint256 amount = _amount == 0 ? available : _amount;
        require(amount != 0, InvalidAmount());
        require(amount <= available, InsufficientBalance());

        claimable[msg.sender] = available - amount;
        totalLiabilities -= amount;
        _to.sendEtherAndVerify(amount);
        emit Claimed(msg.sender, _to, amount);
    }

    /// @notice Sets the anchor address.
    /// @param _anchor The anchor address.
    function setAnchor(address _anchor) external onlyOwner {
        _setAnchor(_anchor);
        emit AnchorUpdated(_anchor);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Sets the anchor address used for fee imports.
    /// @param _anchor The anchor contract address.
    function _setAnchor(address _anchor) internal {
        require(_anchor != address(0), InvalidAddress());
        anchor = _anchor;
    }

    /// @dev Computes total L1 cost for a proposal: execution gas + blob data.
    ///
    /// L1 cost has two components:
    /// - **Execution gas**: `l1GasUsed * l1Basefee` (regular EVM execution on L1)
    /// - **Blob gas**: `numBlobs * BLOB_GAS_PER_BLOB * l1BlobBasefee` (EIP-4844 blob posting)
    ///
    /// @param _data The proposal fee data containing L1 gas and blob information.
    /// @return l1Cost_ The total L1 cost in wei.
    function _calcL1Cost(ProposalFeeData calldata _data) internal pure returns (uint256 l1Cost_) {
        unchecked {
            uint256 gasCost = uint256(_data.l1GasUsed) * uint256(_data.l1Basefee);
            uint256 blobCost =
                uint256(_data.numBlobs) * BLOB_GAS_PER_BLOB * uint256(_data.l1BlobBasefee);
            l1Cost_ = gasCost + blobCost;
        }
    }

    /// @dev Computes reimbursement based on proposal profitability.
    ///
    /// **Profitable proposal** (L2 revenue ≥ L1 cost):
    /// - Proposer is reimbursed 100% of their L1 cost
    /// - The surplus (revenue - cost) remains in vault as profit
    ///
    /// **Loss-making proposal** (L2 revenue < L1 cost):
    /// - Proposer receives only `lossReimbursementBps`% of L1 cost
    /// - This protects the vault from unbounded losses during low-activity periods
    /// - Proposers bear partial risk, incentivizing efficient proposal timing
    ///
    /// @param _l1CostWei L1 cost in wei (gas cost + blob cost).
    /// @param _l2RevenueWei L2 basefee revenue collected for this proposal's blocks.
    /// @return reimbursedWei_ The amount to reimburse the proposer.
    function _calcReimbursement(
        uint256 _l1CostWei,
        uint256 _l2RevenueWei
    )
        internal
        view
        returns (uint256 reimbursedWei_)
    {
        unchecked {
            // Full reimbursement if profitable, partial if loss-making
            uint256 bps = _l2RevenueWei >= _l1CostWei ? _BPS : lossReimbursementBps;
            reimbursedWei_ = (_l1CostWei * bps) / _BPS;
        }
    }

    /// @dev Updates `feePerGasWei` using a proportional (P) controller:
    ///      `epsilon = max(0, (targetBalanceWei - effectiveBalance) / targetBalanceWei)`
    ///      `pTerm = Kp * epsilon * feeRange`
    ///      `fee = clamp(pTerm, minFee, maxFee)`
    function _updateFeePerGas() internal {
        uint256 target = targetBalanceWei;
        if (target == 0) return;

        uint256 minFee = minFeePerGasWei;
        uint256 maxFee = maxFeePerGasWei;
        uint256 feeRange = maxFee - minFee;

        // Step 1: Compute effective balance (assets minus liabilities)
        uint256 balance = address(this).balance;
        uint256 liabilities = totalLiabilities;
        uint256 effective = balance > liabilities ? balance - liabilities : 0;

        // Step 2: Compute proportional term for deficit only.
        uint256 pTermWei;
        if (effective < target && feeRange != 0) {
            uint256 epsilonWad = Math.mulDiv(target - effective, _WAD, target);
            uint256 scaledGain = Math.mulDiv(kpWad, epsilonWad, _WAD);
            pTermWei = Math.mulDiv(scaledGain, feeRange, _WAD);
        }

        // Step 3: Clamp to configured fee bounds.
        uint256 newFee = pTermWei;
        if (newFee < minFee) newFee = minFee;
        if (newFee > maxFee) newFee = maxFee;

        if (newFee != feePerGasWei) {
            feePerGasWei = newFee;
            emit FeePerGasUpdated(newFee);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
    error InvalidAmount();
    error InvalidBounds();
    error InvalidBps();
    error InsufficientBalance();
}
