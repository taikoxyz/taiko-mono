// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

import "./L2FeeVault_Layout.sol"; // DO NOT DELETE

/// @title L2FeeVault
/// @notice Holds the L2 transaction fees of the Etna chain until the owner withdraws them.
/// @dev This contract's address is the Etna node's `fee_vault` chain constant: the coinbase and
/// suggested fee recipient of every Etna block. Each block credits it the whole base fee
/// (`basefeeSharingPctg` is pinned to 100) and the priority fees. Coinbase credits run no code,
/// so most of the balance arrives without calling `receive`. The owner, the L2
/// `DelegateController`, moves funds out with `withdraw` until a fee ledger and an L2-to-L1 sweep
/// replace it.
/// @custom:security-contact security@taiko.xyz
contract L2FeeVault is EssentialContract {
    using LibAddress for address;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when the owner withdraws Ether from the vault.
    /// @param to The recipient of the Ether.
    /// @param amount The amount of Ether sent, in wei.
    event FeesWithdrawn(address indexed to, uint256 amount);

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the vault.
    /// @param _owner The owner of the vault (the L2 `DelegateController`). `msg.sender` is used if
    /// this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Accepts Ether sent directly to the vault.
    /// @dev Block fees are credited to the coinbase without a call, so they bypass this function.
    /// Behind the proxy, a transfer limited to the 2300-gas stipend (`transfer`, `send`) can run out
    /// of gas.
    receive() external payable { }

    /// @notice Sends Ether from the vault to a recipient.
    /// @dev Forwards all remaining gas, so contract recipients such as multisigs can receive. Reverts
    /// with `LibAddress.ETH_TRANSFER_FAILED` if the recipient rejects the Ether or `_amount`
    /// exceeds the balance. A zero `_amount` sends nothing and still emits `FeesWithdrawn`.
    /// @param _to The recipient of the Ether; must not be the zero address.
    /// @param _amount The amount of Ether to send, in wei.
    function withdraw(address _to, uint256 _amount) external onlyOwner nonReentrant {
        require(_to != address(0), InvalidAddress());
        _to.sendEtherAndVerify(_amount);
        emit FeesWithdrawn(_to, _amount);
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error InvalidAddress();
}
