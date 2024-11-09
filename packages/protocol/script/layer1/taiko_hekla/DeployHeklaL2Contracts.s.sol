// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/Bridge.sol";
import "src/shared/tokenvault/BridgedERC20V2.sol";
import "src/layer2/hekla/HeklaTaikoL2.sol";
import "script/BaseScript.sol";

contract DeployHeklaL2Contracts is BaseScript {
    function run() external broadcast {
        // TaikoL2
        address heklaTaikoL2 = address(new HeklaTaikoL2());
        // Bridge
        address bridge = address(new Bridge());
        // Bridged ERC20 V2
        address bridgedERC20V2 = address(new BridgedERC20V2());

        console2.log("> hekla_taiko_l2@", heklaTaikoL2);
        console2.log("> bridge@", bridge);
        console2.log("> bridged_erc20_v2@", bridgedERC20V2);
    }
}
