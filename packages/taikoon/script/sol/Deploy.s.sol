// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/Script.sol";
import { MerkleMintersScript } from "./MerkleMinters.s.sol";
import { Merkle } from "murky/Merkle.sol";
import { Upgrades } from "@openzeppelin/foundry-upgrades/Upgrades.sol";

import { TaikoonToken } from "../../contracts/TaikoonToken.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    MerkleMintersScript public merkleMinters = new MerkleMintersScript();
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();

        merkleMinters.setUp();
    }

    function run() public {
        string memory jsonRoot = "root";

        vm.startBroadcast(deployerPrivateKey);

        bytes32 root = merkleMinters.root();

        string memory baseURI = utils.getIpfsBaseURI();

        // deploy token with empty root
        address proxy = Upgrades.deployUUPSProxy(
            "TaikoonToken.sol", abi.encodeCall(TaikoonToken.initialize, (baseURI, root))
        );

        TaikoonToken token = TaikoonToken(proxy);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed TaikoonToken to:", address(token));

        vm.serializeBytes32(jsonRoot, "MerkleRoot", root);

        string memory finalJson = vm.serializeAddress(jsonRoot, "TaikoonToken", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
