// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IL1Executor } from "./interfaces/IL1Executor.sol";

/// @dev Helper contract for contracts performing cross-domain communications
contract L1Executor {
    /// @notice Messenger contract used to send and receive messages from the other domain
    IL1Executor public immutable messenger;

    /// @param messenger_ Address of the CrossDomainMessenger on the current layer
    constructor(address messenger_) {
        messenger = IL1Executor(messenger_);
    }

    /// @dev Sends a message to an account on another domain
    /// @param crossDomainTarget_ Intended recipient on the destination domain
    /// @param message_ Data to send to the target (usually calldata to a function with
    ///     `onlyFromCrossDomainAccount()`)
    /// @param gasLimit_ gasLimit for the receipt of the message on the target domain.
    function sendMessage(
        address crossDomainTarget_,
        uint32 gasLimit_,
        bytes memory message_
    )
        internal
    {
        messenger.sendMessage(crossDomainTarget_, message_, gasLimit_);
    }

    /// @dev Enforces that the modified function is only callable by a specific cross-domain account
    modifier onlyFromCrossDomainAccount() {
        if (msg.sender != address(messenger)) {
            revert ErrorUnauthorizedMessenger();
        }
        _;
    }

    error ErrorUnauthorizedMessenger();
}
