// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";

import "src/shared/common/DefaultResolver.sol";

/// @title DeployCapability
abstract contract DeployCapability is Script {
    error ADDRESS_NULL();

    function deployProxy(
        string memory name,
        address impl,
        bytes memory data,
        address registerTo
    )
        internal
        returns (address proxy)
    {
        proxy = address(new ERC1967Proxy(impl, data));

        if (registerTo != address(0)) {
            DefaultResolver(registerTo).registerAddress(
                uint64(block.chainid), bytes32(bytes(name)), proxy
            );
        }

        console2.log(">", name, "@", registerTo);
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
        // Surge: Not all contracts are ownable
        // console2.log("  owner      :", OwnableUpgradeable(proxy).owner());
        // Surge: Irrelevant logs
        // console2.log("  msg.sender :", msg.sender);
        // console2.log("  this       :", address(this));

        // Surge: Write the addresses to a json file
        writeJson(name, proxy);
    }

    function deployProxy(
        string memory name,
        address impl,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        return deployProxy(name, impl, data, address(0));
    }

    function writeJson(string memory name, address addr) internal {
        // Surge: Create a function to write the addresses to a json file
        vm.writeJson(
            vm.serializeAddress("deployment", name, addr),
            string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        );
    }

    function register(address registerTo, string memory name, address addr) internal {
        register(registerTo, name, addr, uint64(block.chainid));
    }

    function register(
        address registerTo,
        string memory name,
        address addr,
        uint64 chainId
    )
        internal
    {
        if (registerTo == address(0)) revert ADDRESS_NULL();
        if (addr == address(0)) revert ADDRESS_NULL();
        DefaultResolver(registerTo).registerAddress(chainId, bytes32(bytes(name)), addr);
        console2.log("> ", name, "@", registerTo);
        console2.log("\t addr : ", addr);
    }

    function copyRegister(address registerTo, address readFrom, string memory name) internal {
        if (registerTo == address(0)) revert ADDRESS_NULL();
        if (readFrom == address(0)) revert ADDRESS_NULL();

        IResolver resolver = IResolver(EssentialContract(readFrom).resolver());
        register({
            registerTo: registerTo,
            name: name,
            addr: resolver.resolve(uint64(block.chainid), bytes32(bytes(name)), true),
            chainId: uint64(block.chainid)
        });
    }
}
