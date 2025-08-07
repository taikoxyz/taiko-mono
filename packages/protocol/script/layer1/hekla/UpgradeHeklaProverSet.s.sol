// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/provers/ProverSet.sol";

contract UpgradeHeklaProverSet is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address rollupResolver = 0x3C82907B5895DB9713A0BB874379eF8A37aA2A68;
        address taikoInbox = 0x79C9109b764609df928d16fC4a91e9081F7e87DB;
        address taikoToken = 0x6490E12d480549D333499236fF2Ba6676C296011;
        address proverSet = 0xD3f681bD6B49887A48cC9C9953720903967E9DC0;
        address preconfRouter = 0xce04A91Db63aDBe26c83c761f99933CE5f09cf6C;

        address proverSetImpl =
            address(new ProverSet(rollupResolver, taikoInbox, taikoToken, preconfRouter));

        UUPSUpgradeable(proverSet).upgradeTo(proverSetImpl);
    }
}
