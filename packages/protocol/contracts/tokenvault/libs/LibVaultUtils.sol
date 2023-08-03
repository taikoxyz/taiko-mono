// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TransparentUpgradeableProxy } from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IBridge } from "../../bridge/IBridge.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";

library LibVaultUtils {
    uint256 public constant MAX_TOKEN_PER_TXN = 10;

    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error VAULT_INVALID_SENDER();

    /**
     * Thrown when token contract is 0 address.
     */
    error VAULT_INVALID_TOKEN();

    /**
     * Thrown when the 'to' is an invalid address.
     */
    error VAULT_INVALID_TO();

    /**
     * Thrown when the length of the tokenIds array and the amounts
     * array differs.
     */
    error VAULT_TOKEN_ARRAY_MISMATCH();

    /**
     * Thrown when more tokens are about to be bridged than allowed.
     */
    error VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();

    /**
     * Thrown when the amount in a transaction is invalid.
     * This could happen if the amount is zero or exceeds the sender's balance.
     */
    error VAULT_INVALID_AMOUNT();

    /**
     * @dev Deploys a contract (via proxy)
     * @param implementation The new implementation address
     * @param owner The owner of the proxy admin contract
     * @param initializationData Data for the initialization
     */
    function deployProxy(
        address implementation,
        address owner,
        bytes memory initializationData
    )
        external
        returns (address proxy)
    {
        assert(implementation != address(0));
        proxy = address(
            new TransparentUpgradeableProxy(implementation, owner, initializationData)
        );
    }

    /**
     * @dev Checks if context is valid
     * @param validSender The valid sender to be allowed
     * @param resolver The address of the resolver
     */
    function checkValidContext(
        bytes32 validSender,
        address resolver
    )
        external
        view
        returns (IBridge.Context memory ctx)
    {
        ctx = IBridge(msg.sender).context();
        if (
            ctx.sender
                != AddressResolver(resolver).resolve(
                    ctx.srcChainId, validSender, false
                )
        ) {
            revert VAULT_INVALID_SENDER();
        }
    }

    /**
     * @dev Checks if token is invalid and returns the message hash
     * @param message The bridged message struct data
     * @param bridgeAddress The bridge contract
     * @param tokenAddress The token address to be checked
     */
    function hashAndCheckToken(
        IBridge.Message calldata message,
        address bridgeAddress,
        address tokenAddress
    )
        external
        pure
        returns (bytes32 msgHash)
    {
        IBridge bridge = IBridge(bridgeAddress);
        msgHash = bridge.hashMessage(message);

        if (tokenAddress == address(0)) revert VAULT_INVALID_TOKEN();
    }

    function checkIfValidAddresses(
        address vault,
        address to,
        address token
    )
        external
        pure
    {
        if (to == address(0) || to == vault) {
            revert VAULT_INVALID_TO();
        }

        if (token == address(0)) revert VAULT_INVALID_TOKEN();
    }

    function checkIfValidAmounts(
        uint256[] memory amounts,
        uint256[] memory tokenIds,
        bool isERC721
    )
        external
        pure
    {
        if (tokenIds.length != amounts.length) {
            revert VAULT_TOKEN_ARRAY_MISMATCH();
        }

        if (tokenIds.length > MAX_TOKEN_PER_TXN) {
            revert VAULT_MAX_TOKEN_PER_TXN_EXCEEDED();
        }

        if (isERC721) {
            for (uint256 i; i < tokenIds.length; i++) {
                if (amounts[i] != 0) {
                    revert VAULT_INVALID_AMOUNT();
                }
            }
        } else {
            for (uint256 i; i < amounts.length; i++) {
                if (amounts[i] == 0) {
                    revert VAULT_INVALID_AMOUNT();
                }
            }
        }
    }
}
