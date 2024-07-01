// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SnaefellToken } from "../../../contracts/snaefell/SnaefellToken.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // V2 Taiko Mainnet data
    address owner = 0x7d70236E2517f5B95247AF1d806A9E3C328a7860;
    bytes32 root = 0xb5edb18eeaeb9c03bde474b7dd392d0594ecc3d9066c7e3c90d611086543d01e;
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafkreib2bkniueraowa23nga3cdijcx7lo4734dmkpgbeiz7hu2yfop4je";
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xfA5EA6f9A13532cd64e805996a941F101CCaAc9a);

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

        address impl = address(new SnaefellToken());
        address proxy = address(
            new ERC1967Proxy(
                impl, abi.encodeCall(SnaefellToken.initialize, (owner, baseURI, root, blacklist))
            )
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
