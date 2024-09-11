// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { MerkleMintersScript } from "./MerkleMinters.s.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TaikoonToken } from "../../../contracts/taikoon/TaikoonToken.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    MerkleMintersScript public merkleMinters = new MerkleMintersScript();
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // Taiko Mainnet Values
    //   address owner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be;
    //  bytes32 root = 0xa7e510d5aed347e65609cf6f0e0738cdd752ffdf5980749057c634489fd09fc3;
    //  string baseURI =
    // "https://taikonfts.4everland.link/ipfs/bafybeiegdqpwx3he5dvoxqklspdjekjepjcobfaakyficksratn73qbbyy";
    //  IMinimalBlacklist blacklist = IMinimalBlacklist(0xfA5EA6f9A13532cd64e805996a941F101CCaAc9a);

    // Holesky Testnet Values
    // address owner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be;
    // bytes32 root = 0xf1359c4c4ba41a72025f2534ea8ad23c6b941b55a715838ebdc71202a78c6c87;
    // string baseURI = "bafybeierqzehlrqeqqeb6fwmil4dj3ij2p6exgoj4lysl53fsxwob6wbdy";
    // IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

    // Hardhat Testnet Values
    address owner = 0x4100a9B680B1Be1F10Cb8b5a57fE59eA77A8184e;
    bytes32 root = 0x1c3b504b4d5640d26ad1aa3b57a9df9ec034f19239768e734b849c306d10b110;
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiegdqpwx3he5dvoxqklspdjekjepjcobfaakyficksratn73qbbyy";
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

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

        //string memory baseURI = utils.getIpfsBaseURI();

        // deploy token with empty root
        address impl = address(new TaikoonToken());
        address proxy = address(
            new ERC1967Proxy(
                impl, abi.encodeCall(TaikoonToken.initialize, (owner, baseURI, root, blacklist))
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
