// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../contracts/team/tokenunlock/TokenUnlock.sol";

contract DeployTokenUnlock is Script {
    using stdJson for string;

    address public OWNER = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F; // admin.taiko.eth
    address public ROLLUP_ADDRESS_MANAGER = 0x579f40D0BE111b823962043702cabe6Aaa290780;
    uint64 public TGE = 1_716_767_999; // Date and time (GMT): Sunday, May 26, 2024 11:59:59 PM
    address public TOKEN_UNLOCK_IMPL = 0x88F4039C2fD4489cdca4E2ce6917a81a38509F2E;

    function setUp() public { }

    function run() external {
        string memory path = "/script/tokenunlock/Deploy.data.json";
        address[] memory recipients = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), path))), (address[])
        );

        for (uint256 i; i < recipients.length; i++) {
            console2.log("grantee:", recipients[i]);

            vm.startBroadcast();
            address proxy = deployProxy({
                impl: TOKEN_UNLOCK_IMPL,
                data: abi.encodeCall(
                    TokenUnlock.init, (OWNER, ROLLUP_ADDRESS_MANAGER, recipients[i], TGE)
                )
            });
            vm.stopBroadcast();
            console2.log("tokenUnlock:", proxy);
        }
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));
        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
