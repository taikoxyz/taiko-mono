// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";

contract UpgradeMainnetPacayaL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public newTaikoAnchor = vm.envAddress("NEW_TAIKO_ANCHOR");
    address public newSignalService = vm.envAddress("NEW_SIGNAL_SERVICE");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        UUPSUpgradeable(0x1670000000000000000000000000000000010001).upgradeTo(newTaikoAnchor);
        UUPSUpgradeable(0x1670000000000000000000000000000000000005).upgradeTo(newSignalService);
    }
}
