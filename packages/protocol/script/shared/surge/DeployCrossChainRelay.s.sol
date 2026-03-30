// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { CrossChainRelay } from "../../../contracts/shared/bridge/CrossChainRelay.sol";

contract DeployCrossChainRelay is Script {
    function run() external {
        vm.startBroadcast();
        CrossChainRelay relay = new CrossChainRelay();
        console2.log("CrossChainRelay:", address(relay));
        vm.stopBroadcast();

        _writeJson("cross_chain_relay", address(relay));
    }

    /// @dev Writes an address to the deployment JSON file
    function _writeJson(string memory _name, address _addr) internal {
        vm.writeJson(
            vm.serializeAddress("deployment", _name, _addr),
            string.concat(vm.projectRoot(), "/deployments/relay.json")
        );
    }
}
