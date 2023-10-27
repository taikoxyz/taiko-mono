// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { TransparentUpgradeableProxy } from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

library LibDeploy {
    error DEPLOY_INVALID_IMPL();

    /// @dev Deploys a contract (via proxy)
    /// @param implementation The new implementation address
    /// @param owner The owner of the proxy admin contract
    /// @param initializationData Data for the initialization
    function deployProxy(
        address implementation,
        address owner,
        bytes memory initializationData
    )
        external
        returns (address proxy)
    {
        if (implementation == address(0)) revert DEPLOY_INVALID_IMPL();
        proxy = address(
            new TransparentUpgradeableProxy(implementation, owner, initializationData)
        );
    }
}
