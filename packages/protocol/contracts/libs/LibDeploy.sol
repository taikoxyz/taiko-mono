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
    /// @dev Deploys a TransparentUpgradeableProxy proxy with deterministic
    /// address before a given implementation.
    function deployDetermisticUpgradableProxy(
        address owner,
        address logic,
        bytes32 salt,
        bytes memory data
    )
        external
        returns (address)
    {
        // TODO: check owner, logic
        return Create2Upgradeable.deploy(
            0,
            salt,
            abi.encodePacked(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(logic, owner, data)
            )
        );
    }
}
