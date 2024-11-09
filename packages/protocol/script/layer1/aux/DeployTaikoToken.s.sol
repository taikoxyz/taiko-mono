// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/layer1/token/TaikoToken.sol";

contract DeployTaikoToken is BaseScript {
    address public owner = vm.envAddress("OWNER");
    address public premintRecipient = vm.envOr("TAIKO_TOKEN_PREMINT_RECIPIENT", owner);

    function run() external broadcast {
        require(owner != address(0), "invalid owner address");
        require(premintRecipient != address(0), "invalid premint recipient address");

        deploy({
            name: "taiko_token",
            impl: address(new TaikoToken()),
            data: abi.encodeCall(TaikoToken.init, (owner, premintRecipient))
        });
    }
}
