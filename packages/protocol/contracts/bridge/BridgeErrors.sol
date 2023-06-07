// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

abstract contract BridgeErrors {
    /// @notice Emitted when the contract is not intended to receive Ether
    error B_CANNOT_RECEIVE();

    /// @notice Emitted when an operation is denied due to incorrect permissions
    error B_DENIED();

    /// @notice Emitted when the contract is not designed to receive ERC20 tokens
    error B_ERC20_CANNOT_RECEIVE();

    /// @notice Emitted when Ether has already been released as part of a transfer
    error B_ETHER_RELEASED_ALREADY();

    /// @notice Emitted when attempting to burn Ether in EtherVault
    error B_EV_DO_NOT_BURN();

    /// @notice Emitted when an unauthorized action is attempted in EtherVault
    error B_EV_NOT_AUTHORIZED();

    /// @notice Emitted when an incorrect parameter is passed in EtherVault
    error B_EV_PARAM();

    /// @notice Emitted when an ERC20 token transfer fails
    error B_FAILED_TRANSFER();

    /// @notice Emitted when an action is forbidden
    error B_FORBIDDEN();

    /// @notice Emitted when the gas limit for an operation is exceeded
    error B_GAS_LIMIT();

    /// @notice Emitted when an incorrect value is used in an operation
    error B_INCORRECT_VALUE();

    /// @notice Emitted when an incorrect parameter is passed during initialization
    error B_INIT_PARAM_ERROR();

    /// @notice Emitted when a null message hash is used
    error B_MSG_HASH_NULL();

    /// @notice Emitted when a non-retriable message is retried
    error B_MSG_NON_RETRIABLE();

    /// @notice Emitted when a message that hasn't failed is retried
    error B_MSG_NOT_FAILED();

    /// @notice Emitted when a null address is used in an application
    error B_NULL_APP_ADDR();

    /// @notice Emitted when a null owner address is used
    error B_OWNER_IS_NULL();

    /// @notice Emitted when a signal has not been received
    error B_SIGNAL_NOT_RECEIVED();

    /// @notice Emitted when the status of an operation does not match the expected status
    error B_STATUS_MISMATCH();

    /// @notice Emitted when an incorrect chain ID is used
    error B_WRONG_CHAIN_ID();

    /// @notice Emitted when an incorrect recipient address is used
    error B_WRONG_TO_ADDRESS();

    /// @notice Emitted when a signal of zero is used
    error B_ZERO_SIGNAL();
}
