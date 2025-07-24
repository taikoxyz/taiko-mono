// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Foundry
import "forge-std/src/Script.sol";

// Local imports
import "src/layer1/surge/common/SurgeProposerWrapper.sol";

contract DeployProposerWrapper is Script {
    // Execution configuration
    // ---------------------------------------------------------------------------------------------
    uint256 internal immutable privateKey = vm.envUint("PRIVATE_KEY");

    // Proposer wrapper configuration
    // ---------------------------------------------------------------------------------------------
    address internal taikoWrapper = vm.envAddress("TAIKO_WRAPPER");
    address internal taikoInbox = vm.envAddress("TAIKO_INBOX");
    address internal admin = vm.envAddress("ADMIN");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(taikoWrapper != address(0), "config: TAIKO_WRAPPER");
        require(taikoInbox != address(0), "config: TAIKO_INBOX");
        require(admin != address(0), "config: ADMIN");

        SurgeProposerWrapper proposerWrapper =
            new SurgeProposerWrapper(admin, taikoWrapper, taikoInbox);

        // Log the proposer wrapper address to Json
        vm.writeJson(
            vm.serializeAddress(
                "proposer_wrappers",
                "proposer_wrapper",
                address(proposerWrapper)
            ),
            string.concat(vm.projectRoot(), "/deployments/proposer_wrappers.json")
        );
        console2.log("Surge proposer wrapper deployed at: ", address(proposerWrapper));
    }
}
