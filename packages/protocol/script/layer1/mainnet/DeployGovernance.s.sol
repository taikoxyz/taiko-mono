// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/governance/IntermediateOwner.sol";
import "src/layer1/governance/TaikoTreasuryVault.sol";
import "src/layer1/governance/TokenLocker.sol";
import "script/BaseScript.sol";

contract DeployGovernanceSet is BaseScript {
    function run() external broadcast {
        address dao = vm.envOr("OWNER", msg.sender);
        address taikoToken = vm.envAddress("TAIKO_TOKEN");
        uint256 duration = 416 weeks; // 8 years

        IntermediateOwner intermediateOwner = new IntermediateOwner(dao);
        address owner = address(intermediateOwner);
        console.log("Deployed IntermediateOwner to:", owner);

        TokenLocker tokenLocker = new TokenLocker(owner, taikoToken, duration);
        console.log("Deployed TokenLocker to:", address(tokenLocker));

        address impl = address(new TaikoTreasuryVault());
        deploy({ name: "", impl: impl, data: abi.encodeCall(TaikoTreasuryVault.init, (owner)) });
    }
}
