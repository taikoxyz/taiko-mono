// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { Create2Upgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/utils/Create2Upgradeable.sol";
import { TransparentUpgradeableProxy } from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

library LibDeploy {
    error DEPLOY_INVALID_IMPL();

    /// @dev Deploys a contract (via proxy)
    function deployTransparentUpgradeableProxyFor(
        address owner,
        bytes32 salt,
        bytes memory bytecode,
        bytes memory initialization
    )
        external
        returns (address)
    {
        address logic = Create2Upgradeable.deploy({
            amount: 0,
            salt: salt,
            bytecode: bytecode
        });

        return address(
            new TransparentUpgradeableProxy(logic, owner, initialization)
        );
    }
}
