// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";

/// @title ShastaBondManager
/// @notice Abstract contract for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
abstract contract BondManager is IBondManager {
    // -------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------

    /// @notice The address of the inbox contract that is allowed to call debitBond and creditBond
    address public immutable authorized;

    // -------------------------------------------------------------------
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
    constructor(address _authorized) {
        authorized = _authorized;
    }

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @inheritdoc IBondManager
    function debitBond(
        address _address,
        uint256 _bond
    )
        external
        onlyAuthorized
        returns (uint256 amountDebited_)
    {
        amountDebited_ = _debitBond(_address, _bond);
        if (amountDebited_ > 0) {
            emit BondDebited(_address, amountDebited_);
        }
    }

    /// @inheritdoc IBondManager
    function creditBond(address _address, uint256 _bond) external onlyAuthorized {
        _creditBond(_address, _bond);
        emit BondCredited(_address, _bond);
    }

    /// @inheritdoc IBondManager
    function getBondBalance(address _address) external view returns (uint256) {
        return _getBondBalance(_address);
    }

    // -------------------------------------------------------------------
    // Internal Functions - Abstract
    // -------------------------------------------------------------------

    /// @dev Internal implementation for debiting a bond
    /// @param _address The address to debit the bond from
    /// @param _bond The amount of bond to debit
    /// @return amountDebited_ The actual amount debited
    function _debitBond(
        address _address,
        uint256 _bond
    )
        internal
        virtual
        returns (uint256 amountDebited_);

    /// @dev Internal implementation for crediting a bond
    /// @param _address The address to credit the bond to
    /// @param _bond The amount of bond to credit
    function _creditBond(address _address, uint256 _bond) internal virtual;

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view virtual returns (uint256);

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error Unauthorized();
}
