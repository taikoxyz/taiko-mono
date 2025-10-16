// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../../contracts/blacklist/Blacklist.sol";

contract DeployBlacklist is Script {
    using stdJson for string;

    uint256 public chainId;

    string public lowercaseNetworkKey;
    string public uppercaseNetworkKey;
    string public jsonLocation;

    uint256 public deployerPrivateKey;
    address public deployerAddress;

    function getPrivateKey() public view returns (uint256) {
        string memory lookupKey = string.concat(uppercaseNetworkKey, "_PRIVATE_KEY");
        return vm.envUint(lookupKey);
    }

    function getContractJsonLocation() public view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/blacklist/", lowercaseNetworkKey, ".json");
    }

    function setUp() public {
        // load all network configs
        chainId = block.chainid;

        if (chainId == 31_337) {
            lowercaseNetworkKey = "localhost";
            uppercaseNetworkKey = "LOCALHOST";
        } else if (chainId == 17_000) {
            lowercaseNetworkKey = "holesky";
            uppercaseNetworkKey = "HOLESKY";
        } else if (chainId == 167_001) {
            lowercaseNetworkKey = "devnet";
            uppercaseNetworkKey = "DEVNET";
        } else if (chainId == 11_155_111) {
            lowercaseNetworkKey = "sepolia";
            uppercaseNetworkKey = "SEPOLIA";
        } else if (chainId == 167_008) {
            lowercaseNetworkKey = "katla";
            uppercaseNetworkKey = "KATLA";
        } else if (chainId == 167_000) {
            lowercaseNetworkKey = "mainnet";
            uppercaseNetworkKey = "MAINNET";
        } else if (chainId == 167_009) {
            lowercaseNetworkKey = "hekla";
            uppercaseNetworkKey = "HEKLA";
        } else {
            revert("Unsupported chainId");
        }

        deployerPrivateKey = getPrivateKey();
        deployerAddress = vm.addr(deployerPrivateKey);
        jsonLocation = getContractJsonLocation();
    }

    function run() external {
        string memory path = "/script/blacklist/Deploy.data.json";

        string memory json = vm.readFile(string.concat(vm.projectRoot(), path));
        // get initial blacklist
        bytes memory rawPortion = json.parseRaw(".blacklist");
        address[] memory blacklist = abi.decode(rawPortion, (address[]));

        vm.startBroadcast(deployerPrivateKey);

        Blacklist target = new Blacklist(deployerAddress, deployerAddress, blacklist);
        console2.log("Blacklist deployed to ", address(target));

        string memory finalJson = vm.serializeAddress("", "Blacklist", address(target));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
