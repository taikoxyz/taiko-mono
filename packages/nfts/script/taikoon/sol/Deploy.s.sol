// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { MerkleMintersScript } from "./MerkleMinters.s.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TaikoonToken } from "../../../contracts/taikoon/TaikoonToken.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    MerkleMintersScript public merkleMinters = new MerkleMintersScript();
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // Please set owner to labs.taiko.eth (0xB73b0FC4C0Cfc73cF6e034Af6f6b42Ebe6c8b49D) on Mainnnet.
    address owner = vm.envAddress("OWNER");

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

        require(owner != address(0), "Owner must be specified");

        vm.startBroadcast(deployerPrivateKey);

        bytes32 root = merkleMinters.getMerkleRoot();

        string memory baseURI = utils.getIpfsBaseURI();

        // deploy token with empty root
        address impl = address(new TaikoonToken());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TaikoonToken.initialize, (owner, baseURI, root, utils.getBlacklist())
                )
            )
        );

        TaikoonToken token = TaikoonToken(proxy);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed TaikoonToken to:", address(token));

        vm.serializeBytes32(jsonRoot, "MerkleRoot", root);
        vm.serializeAddress(jsonRoot, "Owner", token.owner());

        string memory finalJson = vm.serializeAddress(jsonRoot, "TaikoonToken", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
