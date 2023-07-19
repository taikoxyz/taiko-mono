// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { IBridge } from "../bridge/IBridge.sol";
import { AddressResolver } from "../common/AddressResolver.sol";
import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract BaseVault is EssentialContract {
    // Released message hashes
    mapping(bytes32 msgHash => bool released) public releasedMessages;

    uint256[49] private __gap;

    error VAULT_INIT_PARAM_ERROR();
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
     * Thrown when the new proxy owner is zero address.
     */
    error VAULT_INVALID_PROXY_OWNER();
    /**
     * Thrown when the interface (ERC1155/ERC721) is not supported.
     */
    error VAULT_INTERFACE_NOT_SUPPORTED();

    /**
     * Thrown when a message has not failed.
     * This could happen if trying to release a message deposit without proof of
     * failure.
     */
    error VAULT_MESSAGE_NOT_FAILED();

    /**
     * Thrown when a message has already released
     */
    error VAULT_MESSAGE_RELEASED_ALREADY();

    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error VAULT_INVALID_SENDER();

    modifier onlyValidAddresses(
        uint256 chainId,
        bytes32 name,
        address to,
        address token
    ) {
        if (to == address(0) || to == resolve(chainId, name, false)) {
            revert VAULT_INVALID_TO();
        }

        if (token == address(0)) revert VAULT_INVALID_TOKEN();
        _;
    }

    function init(address addressManager) external initializer {
        EssentialContract._init(addressManager);
    }

    /**
     * @dev Deploys a contract (via proxy)
     * @param implementation The new implementation address
     * @param initializationData Data for the initialization
     */
    function _deployProxy(
        address implementation,
        bytes memory initializationData
    )
        internal
        returns (address proxy)
    {
        assert(implementation != address(0));
        proxy = address(
            new TransparentUpgradeableProxy(implementation, owner(), initializationData)
        );
    }

    /**
     * @dev Checks if context is valid
     * @param validSender The valid sender to be allowed
     */
    function _checkValidContext(bytes32 validSender)
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

    /**
     * @dev Returns the decoded data without selector
     * @param calldataWithSelector Encoded data with selector
     */
    function _extractCalldata(bytes memory calldataWithSelector)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory calldataWithoutSelector;

        assert(calldataWithSelector.length >= 4);

        assembly {
            let totalLength := mload(calldataWithSelector)
            let targetLength := sub(totalLength, 4)
            calldataWithoutSelector := mload(0x40)

            // Set the length of callDataWithoutSelector (initial length - 4)
            mstore(calldataWithoutSelector, targetLength)

            // Mark the memory space taken for callDataWithoutSelector as
            // allocated
            mstore(0x40, add(calldataWithoutSelector, add(0x20, targetLength)))

            // Process first 32 bytes (we only take the last 28 bytes)
            mstore(
                add(calldataWithoutSelector, 0x20),
                shl(0x20, mload(add(calldataWithSelector, 0x20)))
            )

            // Process all other data by chunks of 32 bytes
            for { let i := 0x1C } lt(i, targetLength) { i := add(i, 0x20) } {
                mstore(
                    add(add(calldataWithoutSelector, 0x20), i),
                    mload(add(add(calldataWithSelector, 0x20), add(i, 0x04)))
                )
            }
        }

        return calldataWithoutSelector;
    }
}
