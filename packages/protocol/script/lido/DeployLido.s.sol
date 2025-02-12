// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";

import { LidoL1Bridge } from "../../contracts/lido/LidoL1Bridge.sol";
import { LidoL2Bridge } from "../../contracts/lido/LidoL2Bridge.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { StandardERC20 } from "../../contracts/shared/token/StandardERC20.sol";


// FOUNDRY_PROFILE=lidol1 NETWORK=L1 forge script script/lido/DeployLido.s.sol --broadcast --verify
// FOUNDRY_PROFILE=lidol2  NETWORK=L2  forge script script/lido/DeployLido.s.sol --broadcast  --verify
contract LidoDeploy is DeployCapability {
    string private NETWORK = vm.envString("NETWORK");

    uint256 private L1_DEPLOYER_PRIVATE_KEY = vm.envUint("L1_DEPLOYER_PRIVATE_KEY");
    uint256 private L2_DEPLOYER_PRIVATE_KEY = vm.envUint("L2_DEPLOYER_PRIVATE_KEY");


    address private l1AdminAddress = vm.envAddress("L1_ADMIN_ADDRESS");




    function run() external {
        if (keccak256(abi.encodePacked(NETWORK)) == keccak256(abi.encodePacked("L1"))) {
            vm.startBroadcast(L1_DEPLOYER_PRIVATE_KEY);
            LidoL1Bridge l1Bridge = new LidoL1Bridge();

            address l1BridgeProxy =   deployProxy({
                name: "LidoL1Bridge",
                impl: address(l1Bridge),
                data: ""
            });

            logAddress("l1Bridge", address(l1Bridge));
            logAddress("l1BridgeProxy", l1BridgeProxy);

        } else if (keccak256(abi.encodePacked(NETWORK)) == keccak256(abi.encodePacked("L2"))) {
            vm.startBroadcast(L2_DEPLOYER_PRIVATE_KEY);
            LidoL2Bridge l2Bridge = new LidoL2Bridge();


            address l2BridgeProxy =   deployProxy({
                name: "LidoL2Bridge",
                impl: address(l2Bridge),
                data: ""
            });

            logAddress("l2Bridge", address(l2Bridge));
            logAddress("l2BridgeProxy", address(l2BridgeProxy));


            StandardERC20 wstETH = new StandardERC20();


            address wstETHProxy =   deployProxy({
                name: "wstETH",
                impl: address(wstETH),
                data: ""
            });
            logAddress("wstETH", address(wstETH));
            logAddress("wstETHProxy", address(wstETHProxy));

        }

        vm.stopBroadcast();
    }

    function logAddress(string memory name, address addr) internal view {
        console.log(string(abi.encodePacked(name, "=", vm.toString(address(addr)))));
    }
}
