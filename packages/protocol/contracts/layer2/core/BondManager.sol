// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "./IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

import "./BondManager_Layout.sol"; // DO NOT DELETE

/// @title BondManager
/// @notice L2 bond manager handling deposits/withdrawals and L1 bond instruction processing.
/// @dev Combines bond accounting and bridge message handling so bond movements happen in one place:
///      - Standard deposit/withdraw logic with optional minimum bond and withdrawal delay.
///      - Processes bond instructions received via bridge from L1.
/// @custom:security-contact security@taiko.xyz
contract BondManager is EssentialContract, IBondManager, IMessageInvocable {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice L1 chain ID where bond instructions originate.
    uint64 public immutable l1ChainId;

    /// @notice L1 inbox address expected to send bond instructions.
    address public immutable l1Inbox;

    /// @notice L2 bridge contract for receiving bond instructions from L1.
    address public immutable bridge;

    /// @notice ERC20 token used as bond.
    IERC20 public immutable bondToken;

    /// @notice Minimum bond required
    uint256 public immutable minBond;

    /// @notice Time delay required before withdrawal after request
    /// @dev WARNING: In theory operations can remain unfinalized indefinitely, but in practice
    /// after the `extendedProvingWindow` the incentives are very strong for finalization.
    /// A safe value for this is `extendedProvingWindow` + buffer, for example, 2 weeks.
    uint48 public immutable withdrawalDelay;

    /// @notice Bond amount (Wei) for liveness bond.
    uint256 public immutable livenessBond;

    /// @notice Anchor contract authorized to call debitBond/creditBond.
    address public immutable anchor;

    /// @notice Per-account bond state
    mapping(address account => Bond bond) public bond;

    uint256[46] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initialization
    // ---------------------------------------------------------------

    /// @notice Constructor disables initializers for upgradeable pattern
    /// @param _l1ChainId Source chain ID for bond instructions.
    /// @param _l1Inbox L1 inbox address expected to send bond instructions.
    /// @param _bridge L2 bridge contract address.
    /// @param _bondToken The ERC20 bond token address.
    /// @param _minBond The minimum bond required.
    /// @param _withdrawalDelay The delay period for withdrawals (e.g., 7 days).
    /// @param _livenessBond Liveness bond amount (Wei).
    /// @param _anchor Anchor contract authorized to call debitBond/creditBond.
    constructor(
        uint64 _l1ChainId,
        address _l1Inbox,
        address _bridge,
        address _bondToken,
        uint256 _minBond,
        uint48 _withdrawalDelay,
        uint256 _livenessBond,
        address _anchor
    ) {
        require(
            _bridge != address(0) && _l1Inbox != address(0) && _bondToken != address(0),
            InvalidAddress()
        );
        require(_l1ChainId != 0, InvalidL1ChainId());

        l1ChainId = _l1ChainId;
        l1Inbox = _l1Inbox;
        bridge = _bridge;
        bondToken = IERC20(_bondToken);
        minBond = _minBond;
        withdrawalDelay = _withdrawalDelay;
        livenessBond = _livenessBond;
        anchor = _anchor;
    }

    /// @notice Initializes the BondManager contract
    /// @param _owner The owner of this contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Transactional Functions
    // ---------------------------------------------------------------

       
    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) external payable whenNotPaused nonReentrant {
        if (msg.sender != bridge) revert InvalidCaller();

        IBridge.Context memory ctx = IBridge(bridge).context();
        require(ctx.srcChainId == l1ChainId, InvalidSourceChainId());
        require(ctx.from == l1Inbox, InvalidSourceSender());

        LibBonds.BondInstruction memory instruction = abi.decode(_data, (LibBonds.BondInstruction));
        _processBondInstruction(ctx.msgHash, instruction);
    }

  /// @inheritdoc IBondManager
    function debitBond(address _address, uint256 _amount) external onlyFrom(anchor) nonReentrant returns (uint256) {
        require(msg.sender == anchor, InvalidCaller());
        return _debitBond(_address, _amount);
    }

    /// @inheritdoc IBondManager
    function creditBond(address _address, uint256 _amount) external onlyFrom(anchor) nonReentrant  {
        require(msg.sender == anchor, InvalidCaller());
        _creditBond(_address, _amount);
    }
 

    /// @inheritdoc IBondManager
    function deposit(address _recipient, uint256 _amount) external nonReentrant {
        address recipient = _recipient == address(0) ? msg.sender : _recipient;

        bondToken.safeTransferFrom(msg.sender, address(this), _amount);
        _creditBond(recipient, _amount);
        emit BondDeposited(msg.sender, recipient, _amount);
    }

    /// @inheritdoc IBondManager
    function requestWithdrawal() external nonReentrant {
        Bond storage bond_ = bond[msg.sender];
        require(bond_.balance > 0, NoBondToWithdraw());
        require(bond_.withdrawalRequestedAt == 0, WithdrawalAlreadyRequested());

        bond_.withdrawalRequestedAt = uint48(block.timestamp);
        emit WithdrawalRequested(msg.sender, block.timestamp + withdrawalDelay);
    }

    /// @inheritdoc IBondManager
    function cancelWithdrawal() external nonReentrant {
        Bond storage bond_ = bond[msg.sender];
        require(bond_.withdrawalRequestedAt > 0, NoWithdrawalRequested());

        bond_.withdrawalRequestedAt = 0;
        emit WithdrawalCancelled(msg.sender);
    }

    /// @inheritdoc IBondManager
    function withdraw(address _to, uint256 _amount) external nonReentrant {
        Bond storage bond_ = bond[msg.sender];

        if (
            bond_.withdrawalRequestedAt == 0
                || block.timestamp < bond_.withdrawalRequestedAt + withdrawalDelay
        ) {
            // Active account or withdrawal delay not passed yet, can only withdraw excess above
            // minBond
            require(bond_.balance - _amount >= minBond, MustMaintainMinBond());
        }

        _withdraw(msg.sender, _to, _amount);
    }

  

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IBondManager
    function getBondBalance(address _address) external view returns (uint256) {
        return _getBondBalance(_address);
    }

    /// @inheritdoc IBondManager
    function hasSufficientBond(
        address _address,
        uint256 _additionalBond
    )
        external
        view
        returns (bool)
    {
        Bond storage bond_ = bond[_address];
        return bond_.balance >= minBond + _additionalBond && bond_.withdrawalRequestedAt == 0;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Processes a bond instruction received from L1.
    /// @param _msgHash The hash of the bridge message.
    /// @param _instruction The bond instruction to process.
    function _processBondInstruction(
        bytes32 _msgHash,
        LibBonds.BondInstruction memory _instruction
    )
        internal
    {
        require(_instruction.bondType == LibBonds.BondType.LIVENESS, InvalidBondType());
        require(_instruction.payer != _instruction.payee, InvalidRecipient());

        uint256 amount = _bondAmountFor(_instruction.bondType);
        require(amount != 0, NoBondInstruction());

        uint256 debited = _debitBond(_instruction.payer, amount);
        _creditBond(_instruction.payee, debited);

        emit BondInstructionProcessed(_msgHash, _instruction, debited);
    }

    /// @dev Internal implementation for debiting a bond
    /// @param _address The address to debit the bond from
    /// @param _bond The amount of bond to debit in gwei
    /// @return bondDebited_ The actual amount debited in gwei
    function _debitBond(
        address _address,
        uint256 _bond
    )
        internal
        returns (uint256 bondDebited_)
    {
        Bond storage bond_ = bond[_address];

        if (bond_.balance <= _bond) {
            bondDebited_ = bond_.balance;
            bond_.balance = 0;
        } else {
            bondDebited_ = _bond;
            bond_.balance = bond_.balance - _bond;
        }

        if (bondDebited_ > 0) {
            emit BondDebited(_address, bondDebited_);
        }
    }

    /// @dev Internal implementation for crediting a bond
    /// @param _address The address to credit the bond to
    /// @param _bond The amount of bond to credit in gwei
    function _creditBond(address _address, uint256 _bond) internal {
        Bond storage bond_ = bond[_address];
        bond_.balance = bond_.balance + _bond;
        emit BondCredited(_address, _bond);
    }

    /// @dev Internal implementation for withdrawing funds from a user's bond balance
    /// @param _from The address whose balance will be reduced
    /// @param _to The recipient address
    /// @param _amount The amount to withdraw
    function _withdraw(address _from, address _to, uint256 _amount) internal {
        uint256 debited = _debitBond(_from, _amount);
        bondToken.safeTransfer(_to, debited);
        emit BondWithdrawn(_from, debited);
    }

    /// @dev Returns the bond amount for a given bond type
    /// @param _bondType The type of bond to get the amount for
    /// @return The amount of bond for the given bond type. 0 if the bond type does not exist.
    function _bondAmountFor(LibBonds.BondType _bondType) internal view returns (uint256) {
        if (_bondType == LibBonds.BondType.LIVENESS) {
            return livenessBond;
        }
        return 0;
    }

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view returns (uint256) {
        return bond[_address].balance;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bond instruction is processed.
    /// @param msgHash The hash of the bridge message.
    /// @param instruction The bond instruction that was processed.
    /// @param debitedAmount The amount debited from the payer.
    event BondInstructionProcessed(
        bytes32 indexed msgHash, LibBonds.BondInstruction instruction, uint256 debitedAmount
    );

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
    error InvalidBondType();
    error InvalidCaller();
    error InvalidL1ChainId();
    error InvalidRecipient();
    error InvalidSourceChainId();
    error InvalidSourceSender();
    error MustMaintainMinBond();
    error NoBondInstruction();
    error NoBondToWithdraw();
    error NoWithdrawalRequested();
    error WithdrawalAlreadyRequested();
}
