// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";

contract DeployHeklaPreconf is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public taikoWrapper = vm.envAddress("TAIKO_WRAPPER");
    address public rollupResolver = vm.envAddress("ROLLUP_RESOLVER");
    address public fallbackPreconfProposer = vm.envAddress("FALLBACK_PRECONF_PROPOSER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (address(0), 2)),
            registerTo: rollupResolver
        });

        deployProxy({
            name: "preconf_router",
            impl: address(
                new PreconfRouter(taikoWrapper, whitelist, fallbackPreconfProposer)
            ),
            data: abi.encodeCall(PreconfRouter.init, (address(0))),
            registerTo: rollupResolver
        });
    }
}
