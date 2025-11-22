// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/team/SimpleTokenUnlock.sol";
import "script/BaseScript.sol";

contract DeploySimpleTokenUnlock is BaseScript {
    using stdJson for string;

    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    uint64 public GRANT_TIMESTAMP = 1_764_460_800; // 30 Nov 2025, 00:00:00 UTC.
    // NOT YET DEPLOYED
    // address public SIMPLE_TOKEN_UNLOCK_IMPL =

    function run() external broadcast {
        require(SIMPLE_TOKEN_UNLOCK_IMPL != address(0), "SIMPLE_TOKEN_UNLOCK_IMPL not set");

        string memory path = "/script/simpletokenunlock/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            address proxy = deploy({
                name: "",
                impl: SIMPLE_TOKEN_UNLOCK_IMPL,
                data: abi.encodeCall(SimpleTokenUnlock.init, (OWNER, recipients[i], GRANT_TIMESTAMP))
            });
            console2.log("grantee:", recipients[i]);
            console2.log("proxy. :", proxy);
        }
    }
}
