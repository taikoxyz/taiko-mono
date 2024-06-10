// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script, console } from "forge-std/src/Script.sol";
import "forge-std/src/StdJson.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { MockBlacklist } from "../../../test/util/Blacklist.sol";

contract UtilsScript is Script {
    using stdJson for string;

    address public nounsTokenAddress;

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
        return
            string.concat(root, "/deployments/trailblazers-badges/", lowercaseNetworkKey, ".json");
    }

    function getBlacklist() public view returns (IMinimalBlacklist blacklistAddress) {
        if (block.chainid == 167_000) {
            // mainnet blacklist address
            blacklistAddress = IMinimalBlacklist(vm.envAddress("BLACKLIST_ADDRESS"));
        } else {
            // deploy a mock blacklist otherwise
            blacklistAddress = IMinimalBlacklist(0xbdEd0D2bf404bdcBa897a74E6657f1f12e5C6fb6);
        }

        return blacklistAddress;
    }

    function run() public { }
}
