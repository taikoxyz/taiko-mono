// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { AddressResolver } from "../common/AddressResolver.sol";

abstract contract BaseVault is EssentialContract {
    error VAULT_INIT_PARAM_ERROR();
    error VAULT_CANONICAL_TOKEN_NOT_FOUND();

    /**
     * Thrown when the `to` address in an operation is invalid.
     * This can happen if it's zero address or the address of the token vault.
     */
    error VAULT_INVALID_TO();

    /**
     * Thrown when the token address in a transaction is invalid.
     * This could happen if the token address is zero or doesn't conform to the
     * ERC20 standard.
     */
    error VAULT_INVALID_TOKEN();

    /**
     * Thrown when the amount in a transaction is invalid.
     * This could happen if the amount is zero or exceeds the sender's balance.
     */
    error VAULT_INVALID_AMOUNT();

    /**
     * Thrown when the owner address in a message is invalid.
     * This could happen if the owner address is zero or doesn't match the
     * expected owner.
     */
    error VAULT_INVALID_OWNER();

    /**
     * Thrown when the source chain ID in a message is invalid.
     * This could happen if the source chain ID doesn't match the current
     * chain's ID.
     */
    error VAULT_INVALID_SRC_CHAIN_ID();

    /**
     * Thrown when the interface (erc1155/erc721) is not supported.
     */
    error VAULT_INTERFACE_NOT_SUPPORTED();

    /**
     * Thrown when a message has not failed.
     * This could happen if trying to release a message deposit without proof of
     * failure.
     */
    error VAULT_MESSAGE_NOT_FAILED();

    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error VAULT_INVALID_SENDER();

    modifier onlyValidAddresses(uint256 chainId, bytes32 name, address to, address token) {
        if (
            to == address(0)
                || to == resolve(chainId, name, false)
        ) revert VAULT_INVALID_TO();

        if (token == address(0)) revert VAULT_INVALID_TOKEN();
        _;
    }

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * @dev Checks if context is valid
     * @param validSender The valid sender to be allowed
     */
    function checkValidContext(bytes32 validSender)
        internal
        view
        returns (IBridge.Context memory ctx)
    {
        ctx = IBridge(msg.sender).context();
        if (
            ctx.sender
                != AddressResolver(this).resolve(ctx.srcChainId, validSender, false)
        ) {
            revert VAULT_INVALID_SENDER();
        }
    }
}
