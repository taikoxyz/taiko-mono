// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { UtilsScript, MockBlacklist } from "./Utils.s.sol";
import { Script, console } from "forge-std/src/Script.sol";
import { Merkle } from "murky/Merkle.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract DeployScript is Script {
    UtilsScript public utils;
    string public jsonLocation;
    uint256 public deployerPrivateKey;
    address public deployerAddress;

    // Taiko Mainnet Values
    //address owner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be;
    //bytes32 root = 0xa7e510d5aed347e65609cf6f0e0738cdd752ffdf5980749057c634489fd09fc3;
    // string baseURI = "bafybeiebmvj6roz4iuoinackb5c6eeshvppctkydrckqrnxexdnzh6odq4";
    // IMinimalBlacklist blacklist = IMinimalBlacklist(0xfA5EA6f9A13532cd64e805996a941F101CCaAc9a);

    // Holesky Testnet Values
    // address owner = 0xf8ff2AF0DC1D5BA4811f22aCb02936A1529fd2Be;
    // bytes32 root = 0xf1359c4c4ba41a72025f2534ea8ad23c6b941b55a715838ebdc71202a78c6c87;
    // string baseURI = "bafybeiebmvj6roz4iuoinackb5c6eeshvppctkydrckqrnxexdnzh6odq4";
    // IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

    // Hardhat Testnet Values
    address owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address mintSigner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    string baseURI =
        "https://taikonfts.4everland.link/ipfs/bafybeiebmvj6roz4iuoinackb5c6eeshvppctkydrckqrnxexdnzh6odq4";
    IMinimalBlacklist blacklist = IMinimalBlacklist(0xe61E9034b5633977eC98E302b33e321e8140F105);

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

        if (block.chainid == 167_000) {
            // mainnet, use existing blacklist
        } else {
            blacklist = new MockBlacklist();
        }

        // deploy token with empty root
        address impl = address(new TrailblazersBadges());
        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    TrailblazersBadges.initialize, (owner, baseURI, mintSigner, blacklist)
                )
            )
        );

        TrailblazersBadges token = TrailblazersBadges(proxy);

        console.log("Token Base URI:", baseURI);
        console.log("Deployed TrailblazersBadges to:", address(token));

        vm.serializeAddress(jsonRoot, "Owner", token.owner());
        vm.serializeAddress(jsonRoot, "MintSigner", token.mintSigner());

        string memory finalJson =
            vm.serializeAddress(jsonRoot, "TrailblazersBadges", address(token));
        vm.writeJson(finalJson, jsonLocation);

        vm.stopBroadcast();
    }
}
