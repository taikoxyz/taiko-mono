// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IBridge } from "../../bridge/IBridge.sol";
import { AddressResolver } from "../../common/AddressResolver.sol";

library LibVaultUtils {
    /**
     * Thrown when the sender in a message context is invalid.
     * This could happen if the sender isn't the expected token vault on the
     * source chain.
     */
    error VAULT_INVALID_SENDER();

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
     * @dev Returns the decoded data without selector
     * @param calldataWithSelector Encoded data with selector
     */
    function extractCalldata(bytes memory calldataWithSelector)
        external
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
