// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/team/SimpleTokenUnlock.sol";
import "script/BaseScript.sol";

contract DeploySimpleTokenUnlock is BaseScript {
    using stdJson for string;

    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    address public SIMPLE_TOKEN_UNLOCK_IMPL = 0x03198cBa3719E5a30F1DCAD757a295Df709E69a9;

    function run() external broadcast {
        require(SIMPLE_TOKEN_UNLOCK_IMPL != address(0), "SIMPLE_TOKEN_UNLOCK_IMPL not set");

        string memory path = "/script/layer1/team/simpletokenunlock/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            require(recipients[i] != address(0), "zero recipient");
            for (uint256 j; j < i; j++) {
                require(recipients[j] != recipients[i], "duplicate recipient");
            }
            // Use unique name per deployment so JSON entries are not overwritten.
            bytes32 slotName = bytes32(i + 1);
            address proxy = deploy({
                name: slotName,
                impl: SIMPLE_TOKEN_UNLOCK_IMPL,
                data: abi.encodeCall(SimpleTokenUnlock.init, (OWNER, recipients[i]))
            });
            console2.log("grantee:", recipients[i]);
            console2.log("proxy. :", proxy);
        }
    }
}
