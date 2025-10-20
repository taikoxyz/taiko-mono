// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "./IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title BondManager
/// @notice L1 implementation of BondManager with time-based withdrawal mechanism
/// @custom:security-contact security@taiko.xyz
contract BondManager is EssentialContract, IBondManager {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The address of the inbox contract that is allowed to call debitBond and creditBond
    address public immutable authorized;

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

    /// @notice Per-account bond state
    mapping(address account => Bond bond) public bond;

    uint256[49] private __gap;

    // ---------------------------------------------------------------
    // Constructor and Initialization
    // ---------------------------------------------------------------

    /// @notice Constructor disables initializers for upgradeable pattern
    /// @param _authorized The address of the authorized contract (Inbox)
    /// @param _bondToken The ERC20 bond token address
    /// @param _minBond The minimum bond required
    /// @param _withdrawalDelay The delay period for withdrawals (e.g., 7 days)
    constructor(
        address _authorized,
        address _bondToken,
        uint256 _minBond,
        uint48 _withdrawalDelay
    ) {
        authorized = _authorized;
        bondToken = IERC20(_bondToken);
        minBond = _minBond;
        withdrawalDelay = _withdrawalDelay;
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
    function debitBond(
        address _address,
        uint256 _bond
    )
        external
        onlyFrom(authorized)
        returns (uint256 amountDebited_)
    {
        amountDebited_ = _debitBond(_address, _bond);
        if (amountDebited_ > 0) {
            emit BondDebited(_address, amountDebited_);
        }
    }

    /// @inheritdoc IBondManager
    function creditBond(address _address, uint256 _bond) external onlyFrom(authorized) {
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

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view returns (uint256) {
        return bond[_address].balance;
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientBond();
    error InvalidRecipient();
    error MustMaintainMinBond();
    error NoBondToWithdraw();
    error NoWithdrawalRequested();
    error WithdrawalAlreadyRequested();
}
