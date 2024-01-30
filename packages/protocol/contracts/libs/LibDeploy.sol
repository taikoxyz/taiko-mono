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

import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

/// @title TaikoERC1967Proxy
/// @dev A proxy that allows for reading its implementation address.
contract TaikoERC1967Proxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data) { }

    function implementation() public view returns (address) {
        return _implementation();
    }
}

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
        proxy = address(new TaikoERC1967Proxy(impl, data));

        if (owner != address(0) && owner != OwnableUpgradeable(proxy).owner()) {
            OwnableUpgradeable(proxy).transferOwnership(owner);
        }
    }
}
