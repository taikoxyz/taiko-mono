// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { MerkleMintersScript } from "./MerkleMinters.s.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TaikoonToken } from "../../../contracts/taikoon/TaikoonToken.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract UpgradeV2 is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    address tokenV1 = 0x4A045C5016B200F7E08a4caBB2cdA6E85bF53295;

    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiegdqpwx3he5dvoxqklspdjekjepjcobfaakyficksratn73qbbyy";

    TaikoonToken public token;

    function setUp() public {
        utils = new UtilsScript();
        utils.setUp();

        jsonLocation = utils.getContractJsonLocation();
        deployerPrivateKey = utils.getPrivateKey();
        deployerAddress = utils.getAddress();
    }

    function run() public {
        token = TaikoonToken(tokenV1);
        vm.startBroadcast(deployerPrivateKey);

        token.upgradeToAndCall(
            address(new TaikoonToken()), abi.encodeCall(TaikoonToken.updateBaseURI, (baseURI))
        );

        token = TaikoonToken(token);

        console.log("Upgraded TaikoonToken to:", address(token));
    }
}
