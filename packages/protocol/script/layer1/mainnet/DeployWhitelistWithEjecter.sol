// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/forced-inclusion/TaikoWrapper.sol";
import "src/layer1/mainnet/MainnetInbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";

/// @title DeployWhitelistWithEjecter
/// @notice This script deploys the whitelist contract with ejecter functionality
/// @dev IMPORTANT: After this script is run, two things need to be done:
/// 1. Upgrade the whitelist proxy to the new implementation
/// 2. Set the ejecter address on the whitelist proxy(from the owner address)
contract DeployWhitelistWithEjecter is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // https://etherscan.io/address/0xFD019460881e6EeC632258222393d5821029b2ac
        address preconfWhitelist = 0xFD019460881e6EeC632258222393d5821029b2ac;

        // deploy new whitelist implementation with ejecter functionality
        address whitelist = address(new PreconfWhitelist());
        console2.log("whitelist", whitelist);
    }
}
