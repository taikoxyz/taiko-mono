// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/AddressManager.sol";
import "../../contracts/layer2/hekla/HeklaTaikoL2.sol";
import "../../contracts/shared/tokenvault/BridgedERC20V2.sol";

contract DeployHeklaL2Contracts is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // TaikoL1
        address heklaTaikoL2 = address(new HeklaTaikoL2());
        // Bridge
        address bridge = address(new Bridge());
        // Address manager
        address addressManager = address(new AddressManager());
        // Bridged ERC20 V2
        address bridgedERC20V2 = address(new BridgedERC20V2());
        console2.log("> hekla_taiko_l2@", heklaTaikoL2);
        console2.log("> bridge@", bridge);
        console2.log("> address_manager@", addressManager);
        console2.log("> bridged_erc20_v2@", bridgedERC20V2);
    }
}
