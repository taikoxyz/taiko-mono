// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/// @title LibDeploy
/// @dev Provides utilities for deploying contracts
library LibDeploy {
    error INVALID_PARAM();

    function deployTransparentUpgradeableProxyForOwnable(
        address impl,
        address owner,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        if (impl == address(0) || owner == address(0)) revert INVALID_PARAM();
        // The owner will become the `admin` of the proxy
        proxy = address(new TransparentUpgradeableProxy(impl, owner, data ));

        // Transfer ownership from this contract to the owner.
        OwnableUpgradeable(proxy).transferOwnership(owner);
    }
}
