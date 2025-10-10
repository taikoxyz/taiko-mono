// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/mainnet/TokenUnlock.sol";
import "script/BaseScript.sol";

contract DeployTokenUnlockNewImpl is Script {
    address public TAIKO_TOKEN = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
    address public PROVER_SET_IMPL = 0x280eAbfd252f017B78e15b69580F249F45FB55Fa;

    function run() external {
        vm.startBroadcast();
        address tokenUnlockImpl = address(new TokenUnlock(TAIKO_TOKEN, PROVER_SET_IMPL));
        console2.log("tokenUnlockImpl:", tokenUnlockImpl);

        vm.stopBroadcast();
    }
}

contract DeployTokenUnlock is BaseScript {
    using stdJson for string;

    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    address public TOKEN_UNLOCK_IMPL = 0x5c475bB14727833394b0704266f14157678A72b6;

    function run() external broadcast {
        require(TOKEN_UNLOCK_IMPL != address(0), "TOKEN_UNLOCK_IMPL not set");

        string memory path = "/script/tokenunlock/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            address proxy = deploy({
                name: "",
                impl: TOKEN_UNLOCK_IMPL,
                data: abi.encodeCall(TokenUnlock.init, (OWNER, recipients[i], 1_717_588_800))
            });
            console2.log("grantee:", recipients[i]);
            console2.log("proxy. :", proxy);
        }
    }
}
