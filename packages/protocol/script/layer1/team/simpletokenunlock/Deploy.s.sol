// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/team/SimpleTokenUnlock.sol";
import "script/BaseScript.sol";

contract DeploySimpleTokenUnlock is BaseScript {
    using stdJson for string;

    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    address public SIMPLE_TOKEN_UNLOCK_IMPL = 0x01228372cDDb72e6830B1CD8e3006ecfa0E2d99B;

    function run() external broadcast {
        require(SIMPLE_TOKEN_UNLOCK_IMPL != address(0), "SIMPLE_TOKEN_UNLOCK_IMPL not set");

        string memory path = "/script/simpletokenunlock/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            require(recipients[i] != address(0), "zero recipient");
            address proxy = deploy({
                name: "",
                impl: SIMPLE_TOKEN_UNLOCK_IMPL,
                data: abi.encodeCall(SimpleTokenUnlock.init, (OWNER, recipients[i]))
            });
            console2.log("grantee:", recipients[i]);
            console2.log("proxy. :", proxy);
        }
    }
}
