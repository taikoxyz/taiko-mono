// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/DeployCapability.sol";

/// @title DeployMainnetPreconf2
/// @notice Second step in enabling preconfirmations on mainnet.
/// @dev This script registers the PreconfRouter on the resolver to enable preconfirmations.
///      IMPORTANT: Should only be run after :
///     1. `DeployMainnetPreconf1.s.sol` has been run
///     2. `TaikoWrapper` and `MainnetInbox` have been upgraded to the new implementation
///     3. The desired operators have been whitelisted and enabled on the PreconfWhitelist
contract DeployMainnetPreconf2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address rollupResolver = 0x5A982Fb1818c22744f5d7D36D0C4c9f61937b33a;
        address preconfRouter = vm.envAddress("PRECONF_ROUTER");
        
        // Register the PreconfRouter on the resolver to enable preconfirmations
        register(rollupResolver, "preconf_router", preconfRouter);
        
        console2.log("Preconfirmations are now enabled on mainnet!");
    }
}
