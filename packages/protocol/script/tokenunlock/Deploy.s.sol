// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../test/DeployCapability.sol";
import "../../contracts/team/tokenunlock/TokenUnlock.sol";

contract DeployTokenUnlock is DeployCapability {
    using stdJson for string;

    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    address public ROLLUP_ADDRESS_MANAGER = 0x579f40D0BE111b823962043702cabe6Aaa290780;
    uint64 public TGE = 1_716_767_999; // Date and time (GMT): Sunday, May 26, 2024 11:59:59 PM
    address public TOKEN_UNLOCK_IMPL = 0x035AFfC82612de31E9Db2259B9482D0Dd53B7819;

    function setUp() public { }

    function run() external {
        require(TOKEN_UNLOCK_IMPL != address(0), "zero TOKEN_UNLOCK_IMPL");

        string memory path = "/script/tokenunlock/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            vm.startBroadcast();
            address proxy = deployProxy({
                name: "TokenUnlock",
                impl: TOKEN_UNLOCK_IMPL,
                data: abi.encodeCall(
                    TokenUnlock.init, (OWNER, ROLLUP_ADDRESS_MANAGER, recipients[i], TGE)
                )
            });
            vm.stopBroadcast();
            console2.log("grantee:", recipients[i]);
            console2.log("proxy. :", proxy);
        }
    }
}
