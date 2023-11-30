// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import "../contracts/common/AddressManager.sol";
import "../contracts/libs/LibDeploy.sol";

/// @title DeployCapability
abstract contract DeployCapability is Script {
    error ADDRESS_NULL();

    function deployProxy(
        bytes32 name,
        address impl,
        bytes memory data,
        address registerTo,
        address owner
    )
        internal
        returns (address proxy)
    {
        proxy = LibDeploy.deployERC1967Proxy(impl, owner, data);

        if (registerTo != address(0)) {
            AddressManager(registerTo).setAddress(uint64(block.chainid), name, proxy);
        }

        console2.log(">", string(abi.encodePacked(name)), "@", registerTo);
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
        console2.log("  owner      :", OwnableUpgradeable(proxy).owner());
        console2.log("  msg.sender :", msg.sender);
        console2.log("  this       :", address(this));

        vm.writeJson(
            vm.serializeAddress("deployment", Strings.toString(uint256(name)), proxy),
            string.concat(vm.projectRoot(), "/deployments/deploy_l1.json")
        );
    }

    function deployProxy(
        bytes32 name,
        address impl,
        bytes memory data
    )
        internal
        returns (address proxy)
    {
        return deployProxy(name, impl, data, address(0), address(0));
    }

    function register(address registerTo, bytes32 name, address addr) internal {
        register(registerTo, name, addr, uint64(block.chainid));
    }

    function register(address registerTo, bytes32 name, address addr, uint64 chainId) internal {
        if (registerTo == address(0)) revert ADDRESS_NULL();
        if (addr == address(0)) revert ADDRESS_NULL();
        AddressManager(registerTo).setAddress(chainId, name, addr);
        console2.log("> ", Strings.toString(uint256(name)), "@", registerTo);
        console2.log("\t addr : ", addr);
    }

    function copyRegister(address registerTo, address readFrom, bytes32 name) internal {
        if (registerTo == address(0)) revert ADDRESS_NULL();
        if (readFrom == address(0)) revert ADDRESS_NULL();

        register({
            registerTo: registerTo,
            name: name,
            addr: AddressManager(readFrom).getAddress(uint64(block.chainid), name),
            chainId: uint64(block.chainid)
        });
    }
}
