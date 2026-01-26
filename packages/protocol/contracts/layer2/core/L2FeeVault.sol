// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
/// ## Fee Adjustment Mechanism (EIP-1559 Style)
/// The vault exposes `feePerGasWei` which L2 clients read to set the L1-cost component of L2
/// basefee. This creates a feedback loop using an EIP-1559-inspired proportional controller:
///
/// 1. **Deficit Detection**: If `effective balance < targetBalanceWei`, the vault is underfunded.
///    The fee increases proportionally to accumulate more revenue from future L2 transactions.
///
/// 2. **Surplus Detection**: If `effective balance > targetBalanceWei`, the vault has excess funds.
///    The fee decreases proportionally, returning value to L2 users via lower basefees.
///
/// The adjustment formula (similar to EIP-1559):
/// ```
/// errorRatio = (targetBalanceWei - effectiveBalance) / targetBalanceWei
/// adjustmentFactor = 1 + errorRatio / BASE_FEE_MAX_CHANGE_DENOMINATOR
/// newFee = clamp(oldFee * adjustmentFactor, minFeePerGasWei, maxFeePerGasWei)
/// ```
///
/// With `BASE_FEE_MAX_CHANGE_DENOMINATOR = 8`, the maximum fee change per update is ±12.5%:
/// - At 100% deficit (broke): fee increases by 12.5%
/// - At 50% deficit: fee increases by 6.25%
/// - At target: no change
/// - At 50% surplus: fee decreases by 6.25%
/// - At 100% surplus (2x target): fee decreases by 12.5%
///
/// This proportional response naturally stabilizes at equilibrium and requires no prediction
/// of future gas consumption, making it simpler and more robust than time-based recovery models.
///
/// ## Reimbursement Policy
/// When proposals are imported:
/// - **Profitable proposals** (L2 revenue ≥ L1 cost): Proposer gets 100% of L1 cost reimbursed
/// - **Loss-making proposals** (L2 revenue < L1 cost): Proposer gets only `lossReimbursementBps`%
///   of L1 cost, protecting the vault from unlimited losses during low-activity periods or proposers
///   who intentionally post unprofitable proposals.
///
/// ## Trust Assumptions
/// The fee data imported via `importProposalFee` must be validated by the validity proof.
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

    /// @notice EIP-1559 style fee adjustment denominator.
    /// @dev With value 8, allows max ±12.5% fee change per update (same as EIP-1559).
    ///      Lower values = faster adjustment, higher values = slower adjustment.
    uint256 public constant BASE_FEE_MAX_CHANGE_DENOMINATOR = 8;

    /// @dev Basis points denominator.
    uint256 private constant _BPS = 10_000;

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


    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Anchor contract authorized to call `importProposalFee`.
    address public anchor;

    /// @notice Sum of all unpaid reimbursements owed to proposers (the vault's liabilities).
    /// @dev This is subtracted from ETH balance to compute the effective balance for fee adjustment.
    uint256 public totalLiabilities;

    /// @notice Mapping of proposer address to their claimable reimbursement amount.
    mapping(address proposer => uint256 amount) public claimable;

    /// @notice The L1-cost fee component per gas, read by L2 clients to set basefee.
    /// @dev This is the primary output of the balancing mechanism. When the vault has a deficit,
    ///      this value increases to collect more revenue. When there's a surplus, it decreases.
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
    constructor(
        uint256 _targetBalanceWei,
        uint256 _minFeePerGasWei,
        uint256 _maxFeePerGasWei,
        uint16 _lossReimbursementBps
    ) {
        // Validate configuration parameters
        require(_lossReimbursementBps <= _BPS, InvalidBps());
        require(_minFeePerGasWei <= _maxFeePerGasWei, InvalidBounds());

        // Assign immutables
        targetBalanceWei = _targetBalanceWei;
        minFeePerGasWei = _minFeePerGasWei;
        maxFeePerGasWei = _maxFeePerGasWei;
        lossReimbursementBps = _lossReimbursementBps;

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
    /// @dev Called by Anchor during the first block of a proposal. Sequential validation
    ///      is performed by Anchor before calling this function.
    ///
    /// Steps:
    /// 1. Computes L1 cost from gas and blob fees
    /// 2. Determines reimbursement based on profitability
    /// 3. Credits proposer's claimable balance and increases totalLiabilities
    /// 4. Triggers fee adjustment via `_updateFeePerGas()`
    function importProposalFee(ProposalFeeData calldata _fee) external onlyAnchor {
        uint256 l1CostWei = _calcL1Cost(_fee);
        uint256 reimbursedWei = _calcReimbursement(l1CostWei, _fee.l2BasefeeRevenue);

        claimable[_fee.proposer] += reimbursedWei;
        totalLiabilities += reimbursedWei;

        emit ProposalFeesImported(
            _fee.proposalId, _fee.proposer, l1CostWei, _fee.l2BasefeeRevenue, reimbursedWei
        );

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
    function _calcL1Cost(ProposalFeeData calldata _data)
        internal
        pure
        returns (uint256 l1Cost_)
    {
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
    function _calcReimbursement(uint256 _l1CostWei, uint256 _l2RevenueWei)
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

    /// @dev Updates `feePerGasWei` using an EIP-1559-style proportional controller.
    ///
    /// **Algorithm** (inspired by EIP-1559 base fee adjustment):
    /// 1. Compute effective balance: `balance - totalLiabilities` (clamped to 0)
    /// 2. Compute error ratio: `(targetBalanceWei - effectiveBalance) / targetBalanceWei`
    ///    - Positive ratio → deficit (need to increase fee)
    ///    - Negative ratio → surplus (can decrease fee)
    /// 3. Compute adjustment factor: `1 + errorRatio / BASE_FEE_MAX_CHANGE_DENOMINATOR`
    /// 4. Apply multiplicative adjustment: `newFee = oldFee * adjustmentFactor`
    /// 5. Clamp result to [minFeePerGasWei, maxFeePerGasWei] bounds
    ///
    /// **Examples** (with denominator = 8):
    /// - 100% deficit (broke): errorRatio = 1.0 → adjustment = 1.125 → +12.5% fee
    /// - 50% deficit: errorRatio = 0.5 → adjustment = 1.0625 → +6.25% fee
    /// - At target: errorRatio = 0.0 → adjustment = 1.0 → no change
    /// - 50% surplus: errorRatio = -0.5 → adjustment = 0.9375 → -6.25% fee
    /// - 100% surplus (2x target): errorRatio = -1.0 → adjustment = 0.875 → -12.5% fee
    ///
    /// This proportional response naturally stabilizes at equilibrium without requiring
    /// prediction of future gas consumption.
    function _updateFeePerGas() internal {
        uint256 target = targetBalanceWei;
        if (target == 0) return;

        // Step 1: Compute effective balance (assets minus liabilities)
        uint256 balance = address(this).balance;
        uint256 liabilities = totalLiabilities;
        uint256 effective = balance > liabilities ? balance - liabilities : 0;

        // Step 2: Compute error ratio (scaled by 1e18 for precision)
        // errorRatio ∈ [-8, 1] where:
        //   1 = completely broke (0% of target)
        //   0 = exactly at target
        //  -1 = 200% of target (double surplus)
        //  -8 = 900% of target (adjustmentFactor reaches 0)
        int256 errorRatio = (int256(target) - int256(effective)) * 1e18 / int256(target);

        // Cap extreme values to prevent overflow and negative adjustment factor
        // Max deficit: 100% (errorRatio = 1) → +12.5% fee change
        if (errorRatio > 1e18) errorRatio = 1e18;
        // Max surplus: 800% (errorRatio = -8) → fee goes to 0 (clamped to minFee)
        // This prevents adjustmentFactor from becoming negative
        if (errorRatio < -8e18) errorRatio = -8e18;

        // Step 3: EIP-1559 style multiplicative adjustment
        // adjustmentFactor = 1 + errorRatio / BASE_FEE_MAX_CHANGE_DENOMINATOR
        int256 adjustmentFactor =
            1e18 + errorRatio / int256(BASE_FEE_MAX_CHANGE_DENOMINATOR);

        // Step 4: Apply adjustment
        uint256 currentFee = feePerGasWei;
        int256 newFee = int256(currentFee) * adjustmentFactor / 1e18;

        // Step 5: Apply safety bounds
        if (newFee < int256(minFeePerGasWei)) newFee = int256(minFeePerGasWei);
        if (newFee > int256(maxFeePerGasWei)) newFee = int256(maxFeePerGasWei);

        // Update only if changed
        if (uint256(newFee) != currentFee) {
            feePerGasWei = uint256(newFee);
            emit FeePerGasUpdated(uint256(newFee));
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
    error InvalidAmount();
    error InvalidBounds();
    error InvalidBps();
    error InvalidValue();
    error InsufficientBalance();
}
