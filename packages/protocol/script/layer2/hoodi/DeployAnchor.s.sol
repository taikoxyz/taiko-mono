// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer2/based/TaikoAnchor.sol";

contract DeployAnchor is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
       address sharedResolver = 0x1670130000000000000000000000000000000006;
        address signalService = 0x1670130000000000000000000000000000000005;
        uint64 pacayaForkHeight = 0;
        // Taiko Anchor
        address taikoAnchorImpl =
            address(new TaikoAnchor(sharedResolver, signalService, pacayaForkHeight));
        console2.log("taikoAnchor", taikoAnchorImpl);
    }
}
