// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SnaefellToken } from "../../../contracts/snaefell/SnaefellToken.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // Please set owner to labs.taiko.eth (0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D) on Mainnnet.
    address owner = vm.envAddress("OWNER");
    bytes32 root = vm.envBytes32("MERKLE_ROOT");

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        string memory jsonRoot = "root";

        require(owner != address(0), "Owner must be specified");

        vm.startBroadcast(deployerPrivateKey);

        string memory baseURI = utils.getIpfsBaseURI();

        address impl = address(new SnaefellToken());
        address proxy = address(
            new ERC1967Proxy(impl, abi.encodeCall(SnaefellToken.initialize, (owner, baseURI, root)))
        );

        SnaefellToken token = SnaefellToken(proxy);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed SnaefellToken to:", address(token));

        vm.serializeAddress(jsonRoot, "Owner", token.owner());

        string memory finalJson = vm.serializeAddress(jsonRoot, "SnaefellToken", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
