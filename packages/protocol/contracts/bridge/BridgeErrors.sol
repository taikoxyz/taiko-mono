// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

abstract contract BridgeErrors {
    /// Emitted when the contract is not intended to receive Ether
    error B_CANNOT_RECEIVE();

    /// Emitted when the contract is not intended to receive ERC721
    error B_ERC721_CANNOT_RECEIVE();

    /// Emitted when the contract is not intended to receive ERC1155
    error B_ERC1155_CANNOT_RECEIVE();

    /// Emitted when an operation is denied due to incorrect permissions
    error B_DENIED();

    /// Emitted when the contract is not designed to receive ERC20 tokens
    error B_ERC20_CANNOT_RECEIVE();

    /// Emitted when Ether has already been released as part of a transfer
    error B_ETHER_RELEASED_ALREADY();

    /// Emitted when attempting to burn Ether in EtherVault
    error B_EV_DO_NOT_BURN();

    /// Emitted when an unauthorized action is attempted in EtherVault
    error B_EV_NOT_AUTHORIZED();

    /// Emitted when an incorrect parameter is passed in EtherVault
    error B_EV_PARAM();

    /// Emitted when an ERC20 token transfer fails
    error B_FAILED_TRANSFER();

    /// Emitted when an action is forbidden
    error B_FORBIDDEN();

    /// Emitted when the gas limit for an operation is exceeded
    error B_GAS_LIMIT();

    /// Emitted when an incorrect value is used in an operation
    error B_INCORRECT_VALUE();

    /// Emitted when an incorrect parameter is passed during initialization
    error B_INIT_PARAM_ERROR();

    /// Emitted when a null message hash is used
    error B_MSG_HASH_NULL();

    /// Emitted when a non-retriable message is retried
    error B_MSG_NON_RETRIABLE();

    /// Emitted when a message that hasn't failed is retried
    error B_MSG_NOT_FAILED();

    /// Emitted when a null address is used in an application
    error B_NULL_APP_ADDR();

    /// Emitted when a null owner address is used
    error B_OWNER_IS_NULL();

    /// Emitted when a signal has not been received
    error B_SIGNAL_NOT_RECEIVED();

    /// Emitted when the status of an operation does not match the expected
    /// status
    error B_STATUS_MISMATCH();

    /// Emitted when an incorrect chain ID is used
    error B_WRONG_CHAIN_ID();

    /// Emitted when an incorrect recipient address is used
    error B_WRONG_TO_ADDRESS();

    /// Emitted when a signal of zero is used
    error B_ZERO_SIGNAL();

    // NFTVault related errors

    /// Emitted when a canonical token counterpart is not found for the bridged one
    error NFTVAULT_CANONICAL_TOKEN_NOT_FOUND();

    /// Emitted when opts.amount is 0
    error NFTVAULT_INVALID_AMOUNT();

    /// Emitted when the set type is neither erc1155 nor erc721
    error NFTVAULT_INVALID_NFT_TYPE();

    /// Emitted when user/owner has not enough balance (erc1155) or not owner of the asset (erc721)
    error NFTVAULT_INVALID_OWNER();

    /// Emitted when the sender (origin) is not the vault address - tho it should be
    error NFTVAULT_INVALID_SENDER();

    /// Emitted when opts.to is address(0)
    error NFTVAULT_INVALID_TO();

    /// Emitted when invalid opts.token is address(0)
    error NFTVAULT_INVALID_TOKEN();
}
