// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IBondManager } from "contracts/shared/shasta/iface/IBondManager.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
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

    /// @notice Whether to enforce L1 finalization guard in withdraw.
    bool public immutable enforceFinalizationGuard;

    /// @notice ERC20 token used as bond.
    IERC20 public immutable bondToken;

    /// @notice Minimum bond required on L1 to propose; can be zero on L2. uint96-bounded.
    uint96 public immutable minBond;

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
    /// @param _enforceFinalizationGuard Whether to enforce the proposal finalization guard. This
    /// should be set to true on L1 and false on L2.
    /// @param _minBond The minimum bond required for proposers. This should be set to zero on L2.
    constructor(
        address _authorized,
        address _bondToken,
        bool _enforceFinalizationGuard,
        uint96 _minBond
    ) {
        authorized = _authorized;
        bondToken = IERC20(_bondToken);
        enforceFinalizationGuard = _enforceFinalizationGuard;
        minBond = _minBond;
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
    /// @dev Since the inbox contract is trusted, we can always assume that the proposalId is bigger
    /// than the current maxProposedId.
    function notifyProposed(address proposer, uint48 proposalId) external onlyAuthorized {
        Bond storage bond_ = bond[proposer];
        if (bond_.balance < minBond) revert InsufficientBond();
        bond_.maxProposedId = proposalId;
    }

    /// @inheritdoc IBondManager
    /// @dev On L1, we only allow withdrawals that do not have unfinalized proposals or that are
    /// down to the minimum bond.
    function withdraw(address to, uint96 amount, IInbox.CoreState calldata coreState) external {
        if (enforceFinalizationGuard) {
            bytes32 expected = IInbox(authorized).getCoreStateHash();
            if (keccak256(abi.encode(coreState)) != expected) revert InvalidState();

            IBondManager.Bond storage bond_ = bond[msg.sender];
            bool hasUnfinalized = bond_.maxProposedId > coreState.lastFinalizedProposalId;
            if (hasUnfinalized) {
                // Allow withdrawal only down to minBond
                require(bond_.balance - amount >= minBond, UnfinalizedProposals());
            }
        }

        _withdraw(msg.sender, to, amount);
        emit BondWithdrawn(msg.sender, amount);
    }

    /// @inheritdoc IBondManager
    function deposit(uint96 amount) external {
        _creditBond(msg.sender, amount);

        bondToken.safeTransferFrom(msg.sender, address(this), amount);

        emit BondCredited(msg.sender, amount);
    }

    // No setter for minBond since it's immutable

    // -------------------------------------------------------------------------
    // Internal Functions - Abstract
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
    function _withdraw(address from, address to, uint96 amount) internal virtual {
        _debitBond(from, amount);

        // Transfer ERC20 bond tokens out to recipient
        bondToken.safeTransfer(to, amount);
    }

    /// @dev Internal implementation for getting the bond balance
    /// @param _address The address to get the bond balance for
    /// @return The bond balance of the address
    function _getBondBalance(address _address) internal view virtual returns (uint96) {
        return bond[_address].balance;
    }

    // -------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------

    error Unauthorized();
    error UnfinalizedProposals();
    error InvalidState();
    error InsufficientBond();
}
