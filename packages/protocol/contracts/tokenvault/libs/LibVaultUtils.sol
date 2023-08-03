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
}
