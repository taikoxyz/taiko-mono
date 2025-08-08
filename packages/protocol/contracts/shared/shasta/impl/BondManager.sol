// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title BondManager
/// @notice Abstract contract for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
abstract contract BondManager is IBondManager {
    using SafeERC20 for IERC20;
    // -------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------

    /// @notice The address of the inbox contract that is allowed to call debitBond and creditBond
    address public immutable authorized;

    /// @notice ERC20 token used as bond.
    IERC20 public immutable bondToken;

    /// @notice Per-user bond state
    mapping(address proposer => Bond bond) public bond;

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------

    /// @notice Ensures only the inbox contract can call the function.
    modifier onlyAuthorized() {
        require(msg.sender == authorized, Unauthorized());
        _;
    }

    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

    /// @notice Initializes the BondManager with the inbox address
    /// @param _authorized The address of the authorized contract
    /// @param _bondToken The ERC20 bond token address
    constructor(address _authorized, address _bondToken) {
        authorized = _authorized;
        bondToken = IERC20(_bondToken);
    }

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @inheritdoc IBondManager
    function debitBond(
        address _address,
        uint96 _bond
    )
        external
        onlyAuthorized
        returns (uint96 amountDebited_)
    {
        amountDebited_ = _debitBond(_address, _bond);
        if (amountDebited_ > 0) {
            emit BondDebited(_address, amountDebited_);
        }
    }

    /// @inheritdoc IBondManager
    function creditBond(address _address, uint96 _bond) external onlyAuthorized {
        uint96 amountCredited = _creditBond(_address, _bond);
        if (amountCredited > 0) {
            emit BondCredited(_address, amountCredited);
        }
    }

    /// @inheritdoc IBondManager
    function getBondBalance(address _address) external view returns (uint96) {
        return _getBondBalance(_address);
    }

    /// @inheritdoc IBondManager
    function withdraw(address to, uint96 amount) external virtual;

    /// @inheritdoc IBondManager
    function deposit(uint96 amount) external {
        _creditBond(msg.sender, amount);

        bondToken.safeTransferFrom(msg.sender, address(this), amount);

        emit BondCredited(msg.sender, amount);
    }

    // -------------------------------------------------------------------------
    // Internal Functions
    // -------------------------------------------------------------------

    /// @dev Internal implementation for debiting a bond
    /// @param _address The address to debit the bond from
    /// @param _bond The amount of bond to debit
    /// @return amountDebited_ The actual amount debited
    function _debitBond(address _address, uint96 _bond) internal returns (uint96) {
        Bond storage bond_ = bond[_address];

        require(bond_.balance >= _bond, InsufficientBond());

        bond_.balance = bond_.balance - _bond;
        return _bond;
    }

    /// @dev Internal implementation for crediting a bond
    /// @param _address The address to credit the bond to
    /// @param _bond The amount of bond to credit
    function _creditBond(address _address, uint96 _bond) internal returns (uint96) {
        Bond storage bond_ = bond[_address];

        bond_.balance = bond_.balance + _bond;

        return _bond;
    }

    /// @dev Internal implementation for withdrawing funds from a user's bond balance
    /// @param from The address whose balance will be reduced
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function _withdraw(address from, address to, uint96 amount) internal {
        _debitBond(from, amount);
        bondToken.safeTransfer(to, amount);
        emit BondWithdrawn(from, amount);
    }

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view returns (uint96) {
        return bond[_address].balance;
    }

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error Unauthorized();
    error InsufficientBond();
}
