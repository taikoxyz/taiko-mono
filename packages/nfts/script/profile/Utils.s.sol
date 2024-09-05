// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console } from "forge-std/src/Script.sol";
import "forge-std/src/StdJson.sol";

contract UtilsScript is Script {
    using stdJson for string;

    uint256 public chainId;

    string public lowercaseNetworkKey;
    string public uppercaseNetworkKey;

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
    }

    function getPrivateKey() public view returns (uint256) {
        string memory lookupKey = string.concat(uppercaseNetworkKey, "_PRIVATE_KEY");
        return vm.envUint(lookupKey);
    }

    function getAddress() public view returns (address) {
        string memory lookupKey = string.concat(uppercaseNetworkKey, "_ADDRESS");
        return vm.envAddress(lookupKey);
    }

    function getContractJsonLocation() public view returns (string memory) {
        string memory root = vm.projectRoot();
        return string.concat(root, "/deployments/profile/", lowercaseNetworkKey, ".json");
    }

    function run() public { }
}
