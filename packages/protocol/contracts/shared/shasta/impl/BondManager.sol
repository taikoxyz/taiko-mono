// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";

/// @title BondManager
/// @notice Abstract contract for managing bonds in the Based3 protocol
/// @custom:security-contact security@taiko.xyz
abstract contract BondManager is IBondManager {
    // -------------------------------------------------------------------
    // State Variables
    // -------------------------------------------------------------------

    /// @notice The address of the inbox contract that is allowed to call debitBond and creditBond
    address public immutable authorized;

    /// @notice Whether to enforce L1 finalization guard in withdraw.
    bool public immutable enforceFinalizationGuard;

    /// @notice Max proposal id per proposer. Used for L1 withdraw guard.
    mapping(address => uint48) internal maxProposedId;

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
    /// @param _enforceFinalizationGuard Whether to enforce L1 guard on withdraw
    constructor(address _authorized, bool _enforceFinalizationGuard) {
        authorized = _authorized;
        enforceFinalizationGuard = _enforceFinalizationGuard;
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

    /// @inheritdoc IBondManager
    /// @dev Since the inbox contract is trusted, we can always assume that the proposalId is bigger than the current maxProposedId.
    function notifyProposed(address proposer, uint48 proposalId) external onlyAuthorized {
        maxProposedId[proposer] = proposalId;
    }

    /// @inheritdoc IBondManager
    function withdraw(address to, uint256 amount, IInbox.CoreState calldata coreState) external {
        if (enforceFinalizationGuard) {
            // Validate coreState against Inbox coreStateHash without adding new storage to Inbox
            bytes32 expected = IInbox(authorized).getCoreStateHash();
            if (keccak256(abi.encode(coreState)) != expected) revert InvalidState();

            // Guard: caller must have no unfinalized proposals on L1
            if (maxProposedId[msg.sender] > coreState.lastFinalizedProposalId) {
                revert UnfinalizedProposals();
            }
        }

        _withdraw(msg.sender, to, amount);
    }

    // -------------------------------------------------------------------------
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

    /// @dev Internal implementation for withdrawing funds from a user's bond balance
    /// @param from The address whose balance will be reduced
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function _withdraw(address from, address to, uint256 amount) internal virtual;

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view virtual returns (uint256);

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error Unauthorized();
    error UnfinalizedProposals();
    error InvalidState();
}
