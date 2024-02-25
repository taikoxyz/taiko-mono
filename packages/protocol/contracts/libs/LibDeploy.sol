// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "../L1/gov/TaikoTimelockController.sol";

/// @title LibDeploy
/// @dev Provides utilities for deploying contracts
library LibDeploy {
    error NULL_IMPL_ADDR();

    function deployERC1967Proxy(
        address impl,
        address owner,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        if (impl == address(0)) revert NULL_IMPL_ADDR();
        proxy = address(new ERC1967Proxy(impl, data));

        if (owner != address(0) && owner != OwnableUpgradeable(proxy).owner()) {
            OwnableUpgradeable(proxy).transferOwnership(owner);
        }
    }

    function deployERC1967Proxy(
        address impl,
        address owner,
        bytes memory data,
        TimelockControllerUpgradeable timelock
    )
        internal
        returns (address proxy)
    {
        proxy = deployERC1967Proxy(impl, owner, data);
        if (
            address(timelock) != address(0)
                && address(timelock) != OwnableUpgradeable(proxy).owner()
        ) {
            acceptProxyOwnershipByTimelock(proxy, timelock);
        }
    }

    function acceptProxyOwnershipByTimelock(
        address proxy,
        TimelockControllerUpgradeable timelock
    )
        internal
    {
        bytes32 salt = bytes32(block.timestamp);
        bytes memory payload = abi.encodeCall(Ownable2StepUpgradeable(proxy).acceptOwnership, ());

        timelock.schedule(proxy, 0, payload, bytes32(0), salt, 0);
        timelock.execute(proxy, 0, payload, bytes32(0), salt);
    }
}
