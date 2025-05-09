// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/governance/IntermediateOwner.sol";
import "src/layer1/governance/TaikoTreasuryVault.sol";
import "src/layer1/governance/TokenLocker.sol";
import "script/BaseScript.sol";

contract DeployDAOVaults is BaseScript {
    function run() external broadcast {
        address dao = vm.envAddress("TAIKO_DAO");
        address taikoToken = vm.envAddress("TAIKO_TOKEN");

        address intermediateOwner = address(new IntermediateOwner(dao));
        console.log("Deployed IntermediateOwner to:", intermediateOwner);

        TokenLocker tokenLocker = new TokenLocker(intermediateOwner, taikoToken, 8 * 365 days);
        console.log("Deployed TokenLocker to:", address(tokenLocker));

        deploy({
            name: "TaikoTreasuryVault",
            impl: address(new TaikoTreasuryVault()),
            data: abi.encodeCall(TaikoTreasuryVault.init, (intermediateOwner))
        });
    }
}
