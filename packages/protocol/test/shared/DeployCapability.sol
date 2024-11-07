// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";

import "src/shared/common/DefaultResolver.sol";

/// @title DeployCapability
abstract contract DeployCapability is Script {
    error ADDRESS_NULL();

    function deployProxy(
        bytes32 name,
        address impl,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        proxy = address(new ERC1967Proxy(impl, data));
        string memory _name = Strings.toString(uint256(name));
        vm.writeJson(
            vm.serializeAddress("deployment", _name, proxy),
            string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        );

        console2.log(">", _name);
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
        console2.log("  owner      :", OwnableUpgradeable(proxy).owner());
    }

    function deployProxy(
        bytes32 name,
        address impl,
        bytes memory data,
        DefaultResolver resolver
    )
        internal
        returns (address proxy)
    {
        require(address(resolver) != address(0), "resolver is address(0)");
        proxy = deployProxy(name, impl, data);
        console2.log("  registered :", address(resolver));
        resolver.setAddress(block.chainid, name, proxy);
    }
}
