// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BondManager } from "contracts/shared/shasta/impl/BondManager.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";

/// @title BondManagerL2
/// @notice L2 implementation of BondManager without finalization guards
/// @custom:security-contact security@taiko.xyz
contract BondManagerL2 is BondManager {
    // -------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------

    /// @notice Initializes the L2 BondManager
    /// @param _authorized The address of the authorized contract
    /// @param _bondToken The ERC20 bond token address
    constructor(address _authorized, address _bondToken) BondManager(_authorized, _bondToken) { }

    // -------------------------------------------------------------------
    // External Functions
    // -------------------------------------------------------------------

    /// @notice Withdraw bond to a recipient without restrictions
    /// @dev On L2, withdrawals are unrestricted - no finalization guard needed
    function withdraw(
        address to,
        uint96 amount,
        IInbox.CoreState calldata /* coreState */
    )
        external
        override
    {
        _withdraw(msg.sender, to, amount);
    }
}
