// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../test/DeployCapability.sol";
import "../../contracts/team/tokenunlock/TokenUnlock.sol";

contract DeployTokenUnlock is DeployCapability {
    using stdJson for string;

    // On L2 it shall be: 0xCa5b76Cc7A38b86Db11E5aE5B1fc9740c3bA3DE8
    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    // On L2 it shall be: 0x1670000000000000000000000000000000010002
    address public ROLLUP_ADDRESS_MANAGER = 0x579f40D0BE111b823962043702cabe6Aaa290780;
    // Fine as is
    uint64 public TGE = 1_717_588_800; // Wednesday, June 5, 2024 12:00:00 PM
    // On L2 is shall be: 0x806A3D0B9540655454Dd9dd9922B1321f0cfA2ED
    // Deployed (and verified) with TXN:
    // https://taikoscan.io/tx/0x3100bc89ba700400f81d7823898f0f43a0dd5ce5507b13c4ad9e625dc0497909
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
