// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../contracts/TokenUnlocking.sol";

contract DeployTokenUnlocking is Script {
    using stdJson for string;

    struct DeploymentJsonData {
        address[] recipients;
    }

    address public OWNER = vm.envAddress("OWNER");
    address public TAIKO_TOKEN = vm.envAddress("TAIKO_TOKEN");
    uint256 public TGE = vm.envUint("TGE_TIMESTAMP");

    string internal deploymentJsonPath =
        "/script/unlocking-contract-deployment-data/example-deployment-data.json";

    function setUp() public { }

    function run() external {
        vm.startBroadcast();

        string memory recipientsJsonStr =
            vm.readFile(string.concat(vm.projectRoot(), deploymentJsonPath));
        bytes memory recipientsPacked = vm.parseJson(recipientsJsonStr);

        DeploymentJsonData memory recipientsData =
            abi.decode(recipientsPacked, (DeploymentJsonData));

        for (uint256 i; i < recipientsData.recipients.length; i++) {
            console2.log("Grantee      :", recipientsData.recipients[i]);

            deployProxy({
                impl: address(new TokenUnlocking()),
                data: abi.encodeCall(
                    TokenUnlocking.init, (OWNER, TAIKO_TOKEN, recipientsData.recipients[i], uint64(TGE))
                    )
            });

            console2.log("\n");
        }

        vm.stopBroadcast();
    }

    function deployProxy(address impl, bytes memory data) public returns (address proxy) {
        proxy = address(new ERC1967Proxy(impl, data));

        console2.log("  proxy      :", proxy);
        console2.log("  impl       :", impl);
    }
}
