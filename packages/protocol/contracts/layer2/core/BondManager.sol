// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "./IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";

/// @title BondManager
/// @notice L2 bond manager handling deposits/withdrawals and L1 bond-signal processing.
/// @dev Combines bond accounting and signal verification so bond movements happen in one place:
///      - Standard deposit/withdraw logic with optional minimum bond and withdrawal delay.
///      - Processes proved L1 bond signals (provability/liveness) with best-effort debits/credits.
/// @custom:security-contact security@taiko.xyz
contract BondManager is EssentialContract, IBondManager {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Address allowed to call debitBond and creditBond.
    address public immutable bondOperator;

    /// @notice ERC20 token used as bond.
    IERC20 public immutable bondToken;

    /// @notice Minimum bond required
    uint256 public immutable minBond;

    /// @notice Time delay required before withdrawal after request
    /// @dev WARNING: In theory operations can remain unfinalized indefinitely, but in practice
    /// after
    ///      the `extendedProvingWindow` the incentives are very strong for finalization.
    ///      A safe value for this is `extendedProvingWindow` + buffer, for example, 2 weeks.
    uint48 public immutable withdrawalDelay;

    /// @notice L2 signal service used to verify bond processing signals.
    ISignalService public immutable signalService;

    /// @notice L1 inbox address expected to emit bond signals.
    address public immutable l1Inbox;

    /// @notice L1 chain ID where bond signals originate.
    uint64 public immutable l1ChainId;

    /// @notice Bond amounts (Wei) for liveness and provability bonds.
    uint256 public immutable livenessBond;
    uint256 public immutable provabilityBond;

    /// @notice Per-account bond state
    mapping(address account => Bond bond) public bond;


    /// @notice Tracks processed bond signals to prevent double application.
    mapping(bytes32 signalId => bool processed) public processedSignals;

    uint256[44] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initialization
    // ---------------------------------------------------------------

    /// @notice Constructor disables initializers for upgradeable pattern
    /// @param _bondToken The ERC20 bond token address
    /// @param _minBond The minimum bond required
    /// @param _withdrawalDelay The delay period for withdrawals (e.g., 7 days)
    /// @param _bondOperator Address allowed to debit/credit bonds.
    /// @param _signalService Signal service contract on L2.
    /// @param _l1Inbox L1 inbox address expected to emit bond signals.
    /// @param _l1ChainId Source chain ID for bond signals.
    /// @param _livenessBond Liveness bond amount (Wei).
    /// @param _provabilityBond Provability bond amount (Wei).
    constructor(
        address _bondToken,
        uint256 _minBond,
        uint48 _withdrawalDelay,
        address _bondOperator,
        ISignalService _signalService,
        address _l1Inbox,
        uint64 _l1ChainId,
        uint256 _livenessBond,
        uint256 _provabilityBond
    ) {
        require(_bondToken != address(0), InvalidAddress());
        require(_bondOperator != address(0), InvalidAddress());
        require(address(_signalService) != address(0) && _l1Inbox != address(0), InvalidAddress());
        require(_l1ChainId != 0, InvalidL1ChainId());

        bondToken = IERC20(_bondToken);
        minBond = _minBond;
        withdrawalDelay = _withdrawalDelay;
        bondOperator = _bondOperator;
        signalService = _signalService;
        l1Inbox = _l1Inbox;
        l1ChainId = _l1ChainId;
        livenessBond = _livenessBond;
        provabilityBond = _provabilityBond;
    }

    /// @notice Initializes the BondManager contract
    /// @param _owner The owner of this contract
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IBondManager
    function debitBond(address _address, uint256 _bond)
        external
        onlyFrom(bondOperator)
        returns (uint256 amountDebited_)
    {
        amountDebited_ = _debitBond(_address, _bond);
    }

    /// @inheritdoc IBondManager
    function creditBond(address _address, uint256 _bond) external onlyFrom(bondOperator) {
        _creditBond(_address, _bond);
    }


    /// @inheritdoc IBondManager
    function getBondBalance(address _address) external view returns (uint256) {
        return _getBondBalance(_address);
    }

    /// @inheritdoc IBondManager
    function deposit(uint256 _amount) external nonReentrant {
        bondToken.safeTransferFrom(msg.sender, address(this), _amount);

        _creditBond(msg.sender, _amount);

        emit BondDeposited(msg.sender, _amount);
    }

    /// @inheritdoc IBondManager
    function depositTo(address _recipient, uint256 _amount) external nonReentrant {
        require(_recipient != address(0), InvalidRecipient());

        bondToken.safeTransferFrom(msg.sender, address(this), _amount);

        _creditBond(_recipient, _amount);

        emit BondDepositedFor(msg.sender, _recipient, _amount);
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

     /// @inheritdoc IBondManager
    function processBondSignal(LibBonds.BondInstruction calldata _instruction, bytes calldata _proof)
        external
        nonReentrant
    {
        _validateBondInstruction(_instruction);

        bytes32 signal = _bondSignalHash(_instruction);
        bytes32 signalId = _signalId(signal);
        require(!processedSignals[signalId], SignalAlreadyProcessed());

        signalService.proveSignalReceived(l1ChainId, l1Inbox, signal, _proof);
        processedSignals[signalId] = true;

        uint256 amount = _bondAmountFor(_instruction.bondType);
        if (amount != 0 && _instruction.payer != _instruction.payee) {
            uint256 debited = _debitBond(_instruction.payer, amount);
            _creditBond(_instruction.payee, debited);
            emit BondSignalProcessed(signal, _instruction, debited);
        } else {
            emit BondSignalProcessed(signal, _instruction, 0);
        }
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

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
        if (_bondType == LibBonds.BondType.PROVABILITY) {
            return provabilityBond;
        }
        return 0;
    }

    /// @dev Calculates the hash of a bond instruction
    /// @param _instruction The bond instruction to hash
    /// @return The hash of the bond instruction
    function _bondSignalHash(LibBonds.BondInstruction memory _instruction)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_instruction));
    }

    /// @dev Calculates the id of a given signal
    /// @param _signal The signal to calculate the id for
    /// @return The id of the signal
    function _signalId(bytes32 _signal) internal view returns (bytes32) {
        return keccak256(abi.encode(l1ChainId, l1Inbox, _signal));
    }

    /// @dev Validates a bond instruction. Reverts if the bond instruction is invalid.
    /// @param _instruction The bond instruction to validate
    function _validateBondInstruction(LibBonds.BondInstruction memory _instruction) internal pure {
        if (_instruction.bondType == LibBonds.BondType.NONE) revert NoBondInstruction();
        if (uint8(_instruction.bondType) > uint8(LibBonds.BondType.LIVENESS)) {
            revert InvalidBondType();
        }
    }

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view returns (uint256) {
        return bond[_address].balance;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InvalidRecipient();
    error MustMaintainMinBond();
    error NoBondToWithdraw();
    error NoWithdrawalRequested();
    error WithdrawalAlreadyRequested();
    error InvalidAddress();
    error InvalidL1ChainId();
    error InvalidBondType();
    error NoBondInstruction();
    error SignalAlreadyProcessed();

}
